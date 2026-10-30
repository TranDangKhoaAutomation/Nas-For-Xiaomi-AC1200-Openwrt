"""Collect upstream copyright/license notices alongside the embedded native library."""
import json
from pathlib import Path
import subprocess

def collect(root):
    raw = subprocess.check_output(['go', 'list', '-m', '-json', 'all'], cwd=root, text=True)
    decoder, remaining, modules = json.JSONDecoder(), raw, []
    while remaining.strip():
        item, end = decoder.raw_decode(remaining.lstrip())
        modules.append(item)
        remaining = remaining.lstrip()[end:]
    output = ['Khoa NAS — native dependency notices\n'
              'The following notices apply to their respective upstream components.\n']
    goroot = Path(subprocess.check_output(['go', 'env', 'GOROOT'], text=True).strip())
    output.append('=== Go standard library ===\n' + (goroot / 'LICENSE').read_text())
    for module in modules:
        if module.get('Main') or not module.get('Dir'):
            continue
        directory = Path(module['Dir'])
        candidates = [p for p in directory.iterdir() if p.is_file() and
                      p.name.upper().startswith(('LICENSE', 'LICENCE', 'COPYING', 'NOTICE', 'PATENTS'))]
        extra = directory / 'licenses'
        if extra.is_dir():
            candidates.extend(p for p in extra.rglob('*') if p.is_file())
        for path in sorted(candidates):
            content = path.read_text(encoding='utf-8', errors='replace')
            output.append(f"=== {module['Path']} {module.get('Version', '')} / {path.relative_to(directory)} ===\n{content}")
    destination = root.parent / 'assets/native-licenses.txt'
    destination.write_text('\n\n'.join(output), encoding='utf-8')

if __name__ == '__main__':
    collect(Path(__file__).resolve().parent)
