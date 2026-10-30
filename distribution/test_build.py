import io
import tarfile
import unittest
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from build import make_tar, validate_tar, router_payload

class PackageTests(unittest.TestCase):
    def test_running_tailnet_is_not_started_again(self):
        shell = shutil.which('bash') or ('C:/Program Files/Git/bin/bash.exe' if os.name == 'nt' else None)
        if not shell: self.skipTest('bash unavailable')
        helper=Path(__file__).with_name('service-helper.sh').read_text()
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for process,service,expected in [(0,1,'enable\n'),(1,0,'enable\nstatus\n'),(1,1,'enable\nstatus\nstart\n')]:
                (root/'test.sh').write_text(helper+f'''
pidof() {{ return {process}; }}
service() {{ echo "$1" >> trace; if [ "$1" = status ]; then return {service}; fi; }}
nas_start_if_stopped service tailscaled
''',newline='\n')
                trace=root/'trace'
                if trace.exists(): trace.unlink()
                subprocess.run([shell,'test.sh'],cwd=root,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
                self.assertEqual(trace.read_text(),expected)
    def test_payload_has_no_device_state(self):
        payload=router_payload({'version':'test'})
        self.assertIn('payload/luci/nas-smb.uc',payload)
        self.assertIn('payload/luci/nas-accounts.js',payload)
        for name in payload:
            self.assertFalse(any(bad in name for bad in ('/keys/','ksmbdpwd.db','tailscaled.state','etc/config','id_ed25519')))

    def test_archive_roundtrip_is_deterministic(self):
        data={'install.sh':b'echo ok\n','payload/a':b'test'}
        blob=make_tar(data)
        self.assertEqual(blob,make_tar(dict(reversed(list(data.items())))))
        validate_tar(blob,data)
        with self.assertRaises(ValueError): validate_tar(blob,{'install.sh':b'other'})

    def test_archive_rejects_links_and_path_traversal(self):
        for name,kind in [('KhoaNAS-Router/../../etc/passwd',tarfile.REGTYPE),('KhoaNAS-Router/a',tarfile.SYMTYPE)]:
            buffer=io.BytesIO()
            with tarfile.open(fileobj=buffer,mode='w:gz') as archive:
                item=tarfile.TarInfo(name); item.type=kind; item.linkname='/etc/passwd'
                archive.addfile(item,io.BytesIO())
            with self.assertRaises(ValueError): validate_tar(buffer.getvalue(),{})

if __name__ == '__main__': unittest.main()
