"""Open a validated NAS share from khoanas:// links. No passwords or shell commands."""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
from urllib.parse import parse_qs, urlsplit

SCHEME = 'khoanas'
APP_VERSION = '1.1.0'
RUN_KEY = r'Software\Microsoft\Windows\CurrentVersion\Run'
RUN_NAME = 'KhoaNAS-Open'
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
    # Use the real installed path even when an installer was launched from a
    # packaged desktop host with AppData virtualization. A logon launch must
    # not resolve back to a different copy through its parent's environment.
    executable = Path(sys.executable).resolve()
    if getattr(sys, 'frozen', False) and executable.parent.name.casefold() == 'khoanas-open':
        return executable.parent
    directory = Path(os.environ['LOCALAPPDATA']) / 'KhoaNAS-Open'
    installed = directory / 'KhoaNAS-Open.exe'
    return installed.resolve().parent if installed.is_file() else directory.resolve()


def launch_arguments(*args):
    if getattr(sys, 'frozen', False):
        return [str(install_dir() / 'KhoaNAS-Open.exe'), *args]
    return [str(Path(sys.executable).with_name('pythonw.exe')),
            str(install_dir() / 'open_nas.py'), *args]


def startup_command():
    command = subprocess.list2cmdline(launch_arguments('--background'))
    if len(command) > 260:
        raise ValueError('Đường dẫn cài đặt quá dài để khởi động cùng Windows.')
    return command


def startup_enabled():
    import winreg
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as key:
            value, kind = winreg.QueryValueEx(key, RUN_NAME)
        return kind == winreg.REG_SZ and value == startup_command()
    except FileNotFoundError:
        return False


def set_startup(enabled):
    import winreg
    if enabled:
        command = startup_command()
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as key:
            winreg.SetValueEx(key, RUN_NAME, 0, winreg.REG_SZ, command)
    else:
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
                winreg.DeleteValue(key, RUN_NAME)
        except FileNotFoundError:
            pass


def copy_installed_files():
    destination = install_dir()
    destination.mkdir(parents=True, exist_ok=True)
    if getattr(sys, 'frozen', False):
        target = destination / 'KhoaNAS-Open.exe'
        if Path(sys.executable).resolve() != target.resolve():
            temporary = destination / ('update-' + uuid.uuid4().hex + '.exe')
            try:
                shutil.copy2(sys.executable, temporary)
                os.replace(temporary, target)
            except PermissionError:
                raise ValueError('Đóng Khoa NAS ở khay hệ thống rồi chạy lại bản cập nhật.') from None
            finally:
                temporary.unlink(missing_ok=True)
    else:
        target = destination / 'open_nas.py'
        if Path(__file__).resolve() != target.resolve():
            shutil.copy2(__file__, target)
        for name in ('setup_ui.py', 'desktop_runtime.py'):
            source_ui = Path(__file__).resolve().parent / name
            if source_ui.is_file() and source_ui.resolve() != (destination / name).resolve():
                shutil.copy2(source_ui, destination / name)
        source_assets = Path(__file__).resolve().parent / 'assets'
        if source_assets.is_dir() and source_assets.resolve() != (destination / 'assets').resolve():
            shutil.copytree(source_assets, destination / 'assets', dirs_exist_ok=True)
    return target


def register_shortcut():
    # A single user-level Start Menu entry always targets the installed copy.
    # Paths are passed as environment values, never interpolated into code.
    folder = Path(os.environ['APPDATA']) / 'Microsoft/Windows/Start Menu/Programs'
    folder.mkdir(parents=True, exist_ok=True)
    args = launch_arguments('--settings')
    environment = os.environ.copy()
    environment.update(KHOANAS_SHORTCUT=str(folder / 'Khoa NAS.lnk'),
                       KHOANAS_TARGET=args[0],
                       KHOANAS_ARGS=subprocess.list2cmdline(args[1:]),
                       KHOANAS_DIRECTORY=str(install_dir()),
                       KHOANAS_ICON=str(install_dir() / 'assets/khoa-nas.ico') if not getattr(sys, 'frozen', False) else args[0])
    powershell = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
    script = ('$ErrorActionPreference="Stop"; $shell=New-Object -ComObject WScript.Shell; '
              '$link=$shell.CreateShortcut($env:KHOANAS_SHORTCUT); '
              '$link.TargetPath=$env:KHOANAS_TARGET; $link.Arguments=$env:KHOANAS_ARGS; '
              '$link.WorkingDirectory=$env:KHOANAS_DIRECTORY; $link.IconLocation=$env:KHOANAS_ICON; '
              '$link.Description="Khoa NAS"; $link.Save()')
    subprocess.run([str(powershell), '-NoProfile', '-NonInteractive', '-Command', script],
                   check=True, timeout=20, env=environment,
                   creationflags=subprocess.CREATE_NO_WINDOW,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def load_hosts():
    try:
        value = json.loads((install_dir() / 'allowed-hosts.json').read_text(encoding='utf-8'))
        if not isinstance(value, list):
            return []
        return sorted(set(valid_host(host) for host in value))
    except (OSError, ValueError, TypeError):
        return []


def install(hosts, startup=None):
    import winreg
    allowed = sorted(set(valid_host(host) for host in hosts))
    if not allowed:
        raise ValueError('Hãy nhập ít nhất một địa chỉ router được phép.')
    # Validate startup before changing any setting.
    if startup:
        startup_command()
    copy_installed_files()
    destination = install_dir()
    command = subprocess.list2cmdline(launch_arguments('%1'))
    # The protocol argument must always stay quoted, including encoded spaces.
    command = command.removesuffix('%1') + '"%1"'
    (destination / 'allowed-hosts.json').write_text(json.dumps(allowed), encoding='utf-8')
    base = 'Software\\Classes\\' + SCHEME
    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, base) as key:
        winreg.SetValueEx(key, '', 0, winreg.REG_SZ, 'URL:Khoa NAS Open')
        winreg.SetValueEx(key, 'URL Protocol', 0, winreg.REG_SZ, '')
    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, base + r'\shell\open\command') as key:
        winreg.SetValueEx(key, '', 0, winreg.REG_SZ, command)
    register_shortcut()
    if startup is not None:
        set_startup(startup)


def asset(name):
    return Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parent)) / 'assets' / name


def show_setup():
    from desktop_runtime import run
    return run()


def open_link(link):
    host, unc = parse_link(link)
    if host not in load_hosts():
        raise ValueError('IP này chưa được cho phép. Mở Khoa NAS để cập nhật IP router.')
    os.startfile(unc, 'explore')


def main():
    if os.name != 'nt':
        raise SystemExit('Windows is required.')
    parser = argparse.ArgumentParser()
    parser.add_argument('link', nargs='?')
    parser.add_argument('--install', action='store_true')
    parser.add_argument('--allow-host', action='append', default=[])
    parser.add_argument('--settings', action='store_true')
    parser.add_argument('--background', action='store_true')
    args = parser.parse_args()
    if args.install and args.allow_host:
        install(args.allow_host)
        return
    from desktop_runtime import run
    return run(link=args.link, background=args.background)


if __name__ == '__main__':
    sys.exit(main())
