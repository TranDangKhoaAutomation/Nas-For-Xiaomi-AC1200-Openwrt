"""Build the embedded Tailscale/SMB AAR with the pinned Go mobile tools."""
import os
from pathlib import Path
import shutil
import subprocess
from licenses import collect

ROOT = Path(__file__).resolve().parent
MOBILE = 'v0.0.0-20261011034528-197770444867'

def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)

if __name__ == '__main__':
    version = subprocess.check_output(['go', 'version'], text=True)
    if 'go1.27.3 ' not in version:
        raise SystemExit('Use Go 1.27.3 for this Tailscale release.')
    if not os.environ.get('ANDROID_NDK_HOME'):
        raise SystemExit('Set ANDROID_NDK_HOME to the installed NDK 28.2.13676358.')
    tools_dir = Path(os.environ.get('GOPATH', Path.home() / 'go')) / 'bin-khoanas'
    tools_dir.mkdir(parents=True, exist_ok=True)
    os.environ['GOBIN'] = str(tools_dir)
    os.environ['PATH'] = str(tools_dir) + os.pathsep + os.environ['PATH']
    os.environ['GOTOOLCHAIN'] = 'local'
    for tool in ('gomobile', 'gobind'):
        run('go', 'install', f'golang.org/x/mobile/cmd/{tool}@{MOBILE}')
    run(shutil.which('gomobile'), 'init')
    output = ROOT.parent / 'android/app/libs/nasnet.aar'
    output.parent.mkdir(parents=True, exist_ok=True)
    run(shutil.which('gomobile'), 'bind', '-target=android/arm64,android/amd64',
        '-androidapi', '26', '-javapkg', 'com.trandangkhoa.bridge',
        '-ldflags=-s -w', '-o', str(output), './nasnet')
    collect(ROOT)
