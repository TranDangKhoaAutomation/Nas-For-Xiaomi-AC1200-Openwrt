"""Build the Qt 6 opener without shadowing Windows' native ICU library."""
import argparse
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--work', type=Path, required=True)
args = parser.parse_args()
source = Path(__file__).resolve().parent
args.output.mkdir(parents=True, exist_ok=True)
args.work.mkdir(parents=True, exist_ok=True)
spec = args.work / 'KhoaNAS-Open.spec'
spec.write_text(f'''
from pathlib import PureWindowsPath
a = Analysis([{str(source / 'open_nas.py')!r}], pathex=[{str(source)!r}],
    binaries=[], datas=[({str(source / 'assets')!r}, 'assets')],
    hiddenimports=[], hookspath=[], runtime_hooks=[],
    excludes=['tkinter', 'PySide6.QtQml', 'PySide6.QtQuick'],
    noarchive=False)
# Qt on current Windows uses the OS ICU API. A developer PATH may contain
# an unrelated ICU build with versioned exports (for example ICU 78). Never
# bundle that library over Windows' unversioned icuuc.dll.
a.binaries = [item for item in a.binaries
    if PureWindowsPath(item[0]).name.lower() not in ('icuuc.dll', 'icudt78.dll')]
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, a.binaries, a.datas, [], name='KhoaNAS-Open',
    debug=False, bootloader_ignore_signals=False, strip=False, upx=False,
    console=False, icon={str(source / 'assets' / 'khoa-nas.ico')!r})
''', encoding='utf-8')
subprocess.run([sys.executable, '-m', 'PyInstaller', '--noconfirm', str(spec),
    '--distpath', str(args.output.resolve()), '--workpath', str((args.work / 'build').resolve())], check=True)
