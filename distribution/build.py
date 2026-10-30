"""Build public, reproducible install payloads from an explicit file allowlist."""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
HERE = ROOT / 'distribution'
CORE = ROOT / 'router/luci-disk-manager'
FILES = (
    'install.sh nas-disks-manager nas-disks-job nas-disks-scan nas-disks.init '
    '96-nas-disks disks.uc nas-smb.uc acl.json menu.json nas-disks.js nas-connect.js '
    'nas-accounts.js nas-smb-dialog.js nas-disks.vi.lmo nas-disks.en.lmo '
    'material-layout-fix.css patch-material.uc patch-nas-menu.uc '
    'tests/smb-validation.uc'
).split()
MODULE = ROOT / 'releases/dm-zero/6.12.112/kmod-dm-zero-6.12.112.6.12.112-r1.apk'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def read(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError(f'Expected regular public input: {path}')
    return path.read_bytes()

def text(path):
    return read(path).replace(b'\r\n', b'\n')

def router_payload(config):
    payload = {'install.sh':text(HERE / 'install.sh'),
               'service-helper.sh':text(HERE / 'service-helper.sh'),
               'tailnet-policy.uc':text(HERE / 'tailnet-policy.uc'),
               'BAT-DAU.txt':text(HERE / 'BAT-DAU.txt'),
               'VERSION':(config['version']+'\n').encode()}
    for name in FILES:
        path = CORE / name
        payload['payload/luci/'+name] = read(path) if name.endswith('.lmo') else text(path)
    payload['payload/'+MODULE.name] = read(MODULE)
    payload['SHA256SUMS'] = ''.join(f'{digest(data)}  {name}\n' for name,data in sorted(payload.items())).encode()
    return payload

def make_tar(payload):
    raw = io.BytesIO()
    with gzip.GzipFile(fileobj=raw, mode='wb', filename='', mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as archive:
            for name,data in sorted(payload.items()):
                item = tarfile.TarInfo('KhoaNAS-Router/'+name)
                item.size, item.mtime, item.uid, item.gid = len(data),0,0,0
                item.mode = 0o755 if name.endswith('.sh') else 0o644
                archive.addfile(item, io.BytesIO(data))
    return raw.getvalue()

def validate_tar(blob, payload):
    with tarfile.open(fileobj=io.BytesIO(blob), mode='r:gz') as archive:
        actual = {}
        for member in archive.getmembers():
            if not member.isfile() or not member.name.startswith('KhoaNAS-Router/') or '..' in Path(member.name).parts:
                raise ValueError('Unexpected archive member')
            name = member.name.removeprefix('KhoaNAS-Router/')
            if name in actual: raise ValueError('Duplicate archive member')
            actual[name] = archive.extractfile(member).read()
    if actual != payload: raise ValueError('Router archive differs from current source')

def make_cmd(blob):
    return text(HERE / 'Cai-NAS.cmd.in').replace(b'@@ROUTER_SHA@@',digest(blob).encode()).replace(b'\n',b'\r\n')

def build(output, write_router=False, use_tracked=False):
    config = json.loads(text(HERE / 'release.json'))
    payload = router_payload(config)
    tracked = ROOT / 'releases/router'
    blob = read(tracked / 'KhoaNAS-Router.tar.gz') if use_tracked else make_tar(payload)
    validate_tar(blob, payload)
    cmd = make_cmd(blob)
    if write_router:
        tracked.mkdir(parents=True,exist_ok=True)
        (tracked/'KhoaNAS-Router.tar.gz').write_bytes(blob)
        (tracked/'Cai-NAS.cmd').write_bytes(cmd)
        (tracked/'SHA256SUMS.txt').write_text(f'{digest(blob)}  KhoaNAS-Router.tar.gz\n{digest(cmd)}  Cai-NAS.cmd\n',encoding='utf8',newline='\n')
    output.mkdir(parents=True,exist_ok=True)
    assets = {'KhoaNAS-Router.tar.gz':blob, 'Cai-NAS.cmd':cmd}
    for field,name in [('android_arm64','KhoaNAS-Android.apk'),('android_x86_64','KhoaNAS-Android-x86_64.apk'),('windows','KhoaNAS-Open.exe')]:
        data=read(ROOT / config[field])
        if digest(data) != config['sha256'].get(field): raise ValueError(f'Unverified prebuilt input: {field}')
        assets[name]=data
    inner = {name:data for name,data in assets.items() if name != 'KhoaNAS-Android-x86_64.apk'}
    inner['BAT-DAU.txt']=text(HERE/'BAT-DAU.txt')
    inner['THIRD-PARTY-Android.txt']=text(ROOT/'software/android/assets/native-licenses.txt')
    inner['THIRD-PARTY-Windows.md']=text(ROOT/'software/windows-open-nas/assets/THIRD-PARTY-NOTICES.md')
    inner['SHA256SUMS.txt']=''.join(f'{digest(data)}  {name}\n' for name,data in sorted(inner.items())).encode()
    ready=io.BytesIO()
    with zipfile.ZipFile(ready,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for name,data in sorted(inner.items()):
            info=zipfile.ZipInfo('KhoaNAS-Ready/'+name,date_time=(1980,1,1,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            info.external_attr=0o100644 << 16
            archive.writestr(info,data)
    assets['KhoaNAS-Ready.zip']=ready.getvalue()
    sums=''.join(f'{digest(data)}  {name}\n' for name,data in sorted(assets.items()))
    for name,data in assets.items(): (output/name).write_bytes(data)
    (output/'SHA256SUMS.txt').write_text(sums,encoding='utf8',newline='\n')
    print(f'Validated {len(payload)} public router files; wrote {len(assets)} assets to {output}')

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--write-router-release',action='store_true')
    parser.add_argument('--use-tracked-router',action='store_true')
    args=parser.parse_args()
    build(args.output,args.write_router_release,args.use_tracked_router)
