"""Exercise real per-user IPC/locking in isolated processes, without touching Run."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import desktop_runtime
import open_nas
from setup_ui import application


def fixture(root, probe=False):
    os.environ['LOCALAPPDATA'] = root
    directory = open_nas.install_dir()
    directory.mkdir(exist_ok=True)
    app = application(open_nas.asset('khoa-nas.ico'))
    app.setQuitOnLastWindowClosed(False)
    runtime = desktop_runtime.DesktopRuntime(app)
    started = runtime.start()
    print(json.dumps({'started': started}), flush=True)
    if probe:
        if started: runtime.cleanup()
        return
    if not started: raise RuntimeError('fixture lock unavailable')
    events = directory/'events.jsonl'
    def record(value):
        with events.open('a',encoding='utf8') as file:file.write(json.dumps(value)+'\n')
    runtime.settings = lambda: record('settings')
    open_nas.os.startfile = lambda path,verb:record({'path':path,'verb':verb})
    from PySide6.QtCore import QTimer
    QTimer.singleShot(15000,app.quit)
    app.exec()


class RuntimeTests(unittest.TestCase):
    def test_real_ipc_has_one_owner_and_revalidates_links(self):
        app = application(open_nas.asset('khoa-nas.ico'))
        with tempfile.TemporaryDirectory(prefix='khoanas-ipc-') as root, patch.dict(os.environ,LOCALAPPDATA=root):
            directory=open_nas.install_dir();directory.mkdir()
            (directory/'allowed-hosts.json').write_text(json.dumps(['192.168.1.1']))
            process=subprocess.Popen([sys.executable,__file__,'--fixture',root],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            try:
                self.assertEqual(json.loads(process.stdout.readline()),{'started':True})
                probe=subprocess.run([sys.executable,__file__,'--probe',root],capture_output=True,text=True,timeout=5,check=True)
                self.assertEqual(json.loads(probe.stdout),{'started':False})
                self.assertEqual(desktop_runtime.relay({'action':'background'}),{'ok':True})
                self.assertFalse((directory/'events.jsonl').exists())
                self.assertEqual(desktop_runtime.relay({'action':'settings'}),{'ok':True})
                self.assertEqual(desktop_runtime.relay({'action':'open','link':'khoanas://open?host=8.8.8.8&share=bad'}),{'ok':False})
                self.assertEqual(desktop_runtime.relay({'action':'execute','link':'calc.exe'}),{'ok':False})
                self.assertEqual(desktop_runtime.relay({'action':'open','link':'khoanas://open?host=192.168.1.1&share=Photos'}),{'ok':True})
                records=[json.loads(line) for line in (directory/'events.jsonl').read_text().splitlines()]
                self.assertEqual(records,['settings',{'path':r'\\192.168.1.1\Photos','verb':'explore'}])
                self.assertEqual(desktop_runtime.relay({'action':'quit-for-update'}),{'ok':True})
                self.assertEqual(process.wait(timeout=5),0)
            finally:
                if process.poll() is None:process.terminate();process.wait(timeout=5)
                process.stdout.close();process.stderr.close()
        app.processEvents()

    def test_disabled_startup_exits_without_installing_or_showing_settings(self):
        with patch.object(open_nas,'startup_enabled',return_value=False), patch.object(desktop_runtime,'relocate') as relocate, patch.object(desktop_runtime,'DesktopRuntime') as runtime:
            self.assertEqual(desktop_runtime.run(background=True),0)
            relocate.assert_not_called();runtime.assert_not_called()


if __name__=='__main__':
    if len(sys.argv)>1 and sys.argv[1] in ('--fixture','--probe'):
        fixture(sys.argv[2],probe=sys.argv[1]=='--probe')
    else: unittest.main()
