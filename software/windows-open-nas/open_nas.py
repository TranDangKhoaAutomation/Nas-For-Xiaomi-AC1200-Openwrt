"""Open a validated NAS share from khoanas:// links. No passwords or shell commands."""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import parse_qs, urlsplit

SCHEME = 'khoanas'
NETWORKS = tuple(ipaddress.ip_network(s) for s in (
    '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '100.64.0.0/10'))


def valid_host(value):
    try:
        address = ipaddress.IPv4Address(value)
    except (ipaddress.AddressValueError, ValueError):
        raise ValueError('Địa chỉ NAS phải là IPv4 trong mạng nhà hoặc Tailscale.') from None
    if not any(address in net for net in NETWORKS):
        raise ValueError('Chỉ mở NAS trong mạng nhà hoặc Tailscale, không mở SMB ra Internet.')
    return str(address)


def parse_link(link):
    if len(link) > 2048 or any(ord(c) < 32 for c in link):
        raise ValueError('Liên kết NAS không hợp lệ.')
    uri = urlsplit(link)
    if uri.scheme.lower() != SCHEME or uri.netloc != 'open' or uri.path not in ('', '/') or uri.fragment:
        raise ValueError('Liên kết NAS không hợp lệ.')
    fields = parse_qs(uri.query, strict_parsing=True, keep_blank_values=True)
    if set(fields) != {'host', 'share'} or any(len(v) != 1 for v in fields.values()):
        raise ValueError('Liên kết NAS không hợp lệ.')
    host, share = valid_host(fields['host'][0]), fields['share'][0]
    if (not share or len(share) > 80 or share in ('.', '..') or share.endswith((' ', '.')) or
            any(ord(c) < 32 or c in '\\/:*?"<>|' for c in share)):
        raise ValueError('Tên thư mục chia sẻ không hợp lệ.')
    return host, '\\\\' + host + '\\' + share


def install_dir():
    return Path(os.environ['LOCALAPPDATA']) / 'KhoaNAS-Open'


def install(hosts):
    import winreg
    allowed = sorted(set(valid_host(host) for host in hosts))
    if not allowed:
        raise ValueError('Hãy nhập ít nhất một địa chỉ router được phép.')
    destination = install_dir()
    destination.mkdir(exist_ok=True)
    if getattr(sys, 'frozen', False):
        target = destination / 'KhoaNAS-Open.exe'
        if Path(sys.executable).resolve() != target.resolve():
            shutil.copy2(sys.executable, target)
        command = subprocess.list2cmdline([str(target), '%1'])
    else:
        target = destination / 'open_nas.py'
        if Path(__file__).resolve() != target.resolve():
            shutil.copy2(__file__, target)
        interpreter = Path(sys.executable).with_name('pythonw.exe')
        command = subprocess.list2cmdline([str(interpreter), str(target), '%1'])
        source_ui = Path(__file__).resolve().parent / 'setup_ui.py'
        if source_ui.is_file() and source_ui.resolve() != (destination / 'setup_ui.py').resolve():
            shutil.copy2(source_ui, destination / 'setup_ui.py')
        source_assets = Path(__file__).resolve().parent / 'assets'
        if source_assets.is_dir() and source_assets.resolve() != (destination / 'assets').resolve():
            shutil.copytree(source_assets, destination / 'assets', dirs_exist_ok=True)
    # The protocol argument must always stay quoted, including encoded spaces.
    command = command.removesuffix('%1') + '"%1"'
    (destination / 'allowed-hosts.json').write_text(json.dumps(allowed), encoding='utf-8')
    base = 'Software\\Classes\\' + SCHEME
    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, base) as key:
        winreg.SetValueEx(key, '', 0, winreg.REG_SZ, 'URL:Khoa NAS Open')
        winreg.SetValueEx(key, 'URL Protocol', 0, winreg.REG_SZ, '')
    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, base + r'\shell\open\command') as key:
        winreg.SetValueEx(key, '', 0, winreg.REG_SZ, command)


def asset(name):
    return Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parent)) / 'assets' / name


def show_setup():
    from setup_ui import run_setup
    run_setup(install, install_dir, valid_host, asset)


def main():
    if os.name != 'nt':
        raise SystemExit('Windows is required.')
    parser = argparse.ArgumentParser()
    parser.add_argument('link', nargs='?')
    parser.add_argument('--install', action='store_true')
    parser.add_argument('--allow-host', action='append', default=[])
    args = parser.parse_args()
    if args.install or not args.link:
        if args.allow_host:
            install(args.allow_host)
        else:
            show_setup()
        return
    try:
        host, unc = parse_link(args.link)
        allowed = json.loads((install_dir() / 'allowed-hosts.json').read_text(encoding='utf-8'))
        if host not in allowed:
            raise ValueError('IP này chưa được cho phép. Chạy bộ cài để cập nhật IP router.')
        # ShellExecute opens only a share root, with the current Windows SMB login.
        # No file path, credentials, executable or command line comes from the URL.
        os.startfile(unc, 'explore')
    except Exception as exc:
        from setup_ui import show_error
        show_error(str(exc), asset('khoa-nas.ico'))


if __name__ == '__main__':
    main()
