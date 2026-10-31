import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import open_nas


class RegistryKey:
    def __init__(self, values): self.values = values
    def __enter__(self): return self
    def __exit__(self, *args): pass


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='Khoa NAS test ')
        self.addCleanup(self.temp.cleanup)
        self.env = patch.dict(os.environ, LOCALAPPDATA=self.temp.name)
        self.env.start(); self.addCleanup(self.env.stop)
        self.keys = {open_nas.RUN_KEY: {'UnrelatedApp': ('untouched', 1)}}
        def create(_root, name): return RegistryKey(self.keys.setdefault(name, {}))
        def opened(_root, name, *_args):
            if name not in self.keys: raise FileNotFoundError(name)
            return RegistryKey(self.keys[name])
        def query(key, name):
            if name not in key.values: raise FileNotFoundError(name)
            return key.values[name]
        def delete(key, name):
            if name not in key.values: raise FileNotFoundError(name)
            del key.values[name]
        self.registry = SimpleNamespace(HKEY_CURRENT_USER=1, REG_SZ=1, KEY_SET_VALUE=2,
            CreateKey=create, OpenKey=opened, QueryValueEx=query,
            SetValueEx=lambda key, name, _unused, kind, value: key.values.__setitem__(name, (value,kind)),
            DeleteValue=delete)
        self.fake = patch.dict(sys.modules, winreg=self.registry)
        self.fake.start(); self.addCleanup(self.fake.stop)

    def test_startup_defaults_off_and_only_touches_own_run_value(self):
        with patch.object(sys,'frozen',True,create=True):
            self.assertFalse(open_nas.startup_enabled())
            open_nas.set_startup(True)
            command = self.keys[open_nas.RUN_KEY][open_nas.RUN_NAME][0]
            self.assertEqual(command, subprocess.list2cmdline([str(open_nas.install_dir()/'KhoaNAS-Open.exe'),'--background']))
            self.assertNotIn('--settings',command)
            self.assertTrue(open_nas.startup_enabled())
            open_nas.set_startup(False)
            open_nas.set_startup(False)
            self.assertFalse(open_nas.startup_enabled())
        self.assertEqual(self.keys[open_nas.RUN_KEY], {'UnrelatedApp':('untouched',1)})

    def test_save_keeps_hosts_and_canonical_protocol_when_toggling(self):
        with patch.object(sys,'frozen',True,create=True), patch.object(open_nas,'copy_installed_files') as copy, patch.object(open_nas,'register_shortcut') as shortcut:
            open_nas.install_dir().mkdir()
            hosts=['100.100.10.1','192.168.1.1']
            for enabled in [True,False,True]:
                open_nas.install(hosts,enabled)
                self.assertEqual(open_nas.load_hosts(),sorted(hosts))
                self.assertEqual(open_nas.startup_enabled(),enabled)
                command=self.keys[r'Software\Classes\khoanas\shell\open\command'][''][0]
                self.assertEqual(command,subprocess.list2cmdline([str(open_nas.install_dir()/'KhoaNAS-Open.exe')])+' "%1"')
            self.assertEqual(shortcut.call_count,3)
            self.assertEqual(copy.call_count,3)

    def test_update_preserves_startup_choice_and_invalid_hosts_do_not_mutate(self):
        with patch.object(sys,'frozen',True,create=True), patch.object(open_nas,'copy_installed_files') as copy, patch.object(open_nas,'register_shortcut'):
            open_nas.install_dir().mkdir()
            open_nas.set_startup(True)
            before=dict(self.keys[open_nas.RUN_KEY])
            open_nas.install(['192.168.1.1'])
            self.assertEqual(before,self.keys[open_nas.RUN_KEY])
            copy.reset_mock()
            with self.assertRaises(ValueError):open_nas.install(['8.8.8.8'],False)
            copy.assert_not_called()
            self.assertEqual(before,self.keys[open_nas.RUN_KEY])

    def test_long_startup_path_refused_before_installing(self):
        with patch.object(sys,'frozen',True,create=True), patch.dict(os.environ,LOCALAPPDATA='C:/'+('x'*245)), patch.object(open_nas,'copy_installed_files') as copy:
            with self.assertRaises(ValueError):open_nas.install(['192.168.1.1'],True)
            copy.assert_not_called()

    def test_logon_uses_real_installed_directory_instead_of_parent_appdata(self):
        actual=Path(self.temp.name)/'installed'/'KhoaNAS-Open'/'KhoaNAS-Open.exe'
        with patch.object(sys,'frozen',True,create=True), patch.object(sys,'executable',str(actual)):
            self.assertEqual(open_nas.install_dir(),actual.parent.resolve())
            self.assertEqual(open_nas.launch_arguments('--background'),[str(actual.parent.resolve()/'KhoaNAS-Open.exe'),'--background'])


os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
from PySide6.QtWidgets import QCheckBox, QLabel, QLineEdit, QPushButton
from setup_ui import application, create_setup


class DialogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.app=application(Path(__file__).parent/'assets/khoa-nas.ico')

    def test_checkbox_loads_and_saves_with_hosts_without_forcing_startup(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'allowed-hosts.json').write_text(json.dumps(['192.168.1.1']))
            calls=[]
            window=create_setup(lambda hosts,startup:calls.append((hosts,startup)),lambda:root,open_nas.valid_host,open_nas.asset,lambda:False)
            checkbox=window.findChild(QCheckBox,'startup')
            self.assertFalse(checkbox.isChecked())
            checkbox.setChecked(True)
            window.findChild(QPushButton,'primary').click()
            self.assertEqual(calls,[(['192.168.1.1'],True)])
            checkbox.setChecked(False)
            window.findChild(QPushButton,'primary').click()
            self.assertEqual(calls[-1],(['192.168.1.1'],False))
            self.assertFalse(window.findChild(QLineEdit).isReadOnly())
            window.close();window.deleteLater();self.app.processEvents()

    def test_failed_save_remains_editable_and_displays_error(self):
        def failed(*args):raise ValueError('Kiểm thử lỗi lưu')
        with tempfile.TemporaryDirectory() as directory:
            window=create_setup(failed,lambda:Path(directory),open_nas.valid_host,open_nas.asset,lambda:True)
            self.assertTrue(window.findChild(QCheckBox,'startup').isChecked())
            window.findChild(QPushButton,'primary').click()
            self.assertIn('Kiểm thử lỗi lưu',window.findChild(QLabel,'notice').text())
            self.assertTrue(window.findChild(QCheckBox,'startup').isEnabled())
            window.close();window.deleteLater();self.app.processEvents()


if __name__=='__main__':unittest.main()
