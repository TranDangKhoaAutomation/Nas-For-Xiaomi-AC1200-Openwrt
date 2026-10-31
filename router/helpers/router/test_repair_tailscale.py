"""Exercise the recovery script with mocked service/process commands, never a router."""
import os
from pathlib import Path
import shutil
import subprocess
import unittest


class RecoveryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.shell = shutil.which('bash') or (
            'C:/Program Files/Git/bin/bash.exe' if os.name == 'nt' else None)
        if not cls.shell:
            raise unittest.SkipTest('bash unavailable')
        source = Path(__file__).with_name('repair-tailscale.sh').read_text(encoding='utf-8')
        cls.functions = source.rsplit('\nnas_ts_main "$@"', 1)[0]

    def run_script(self, body, session=''):
        env = dict(os.environ, SSH_CONNECTION=session)
        return subprocess.run([self.shell, '-c', self.functions + '\n' + body],
                              env=env, capture_output=True, encoding='utf-8')

    def test_tailnet_session_is_refused_before_any_service_action(self):
        for session in [
            '100.85.51.71 1234 100.114.53.95 22',
            '192.168.1.2 1234 100.114.53.95 22',
            'fd7a:115c:a1e0::1 1234 fd7a:115c:a1e0::2 22',
            '::ffff:100.85.51.71 1234 192.168.1.1 22',
            'FD7A:115C:A1E0::1 1234 192.168.1.1 22',
            '100.64.0.1 1234 192.168.1.1 22',
            '100.127.255.254 1234 192.168.1.1 22',
        ]:
            with self.subTest(session=session):
                result = self.run_script('nas_ts_service() { echo UNEXPECTED_SERVICE; }; nas_ts_restart', session)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('UNEXPECTED_SERVICE', result.stdout)

    def test_lan_console_and_non_cgnat_addresses_are_allowed(self):
        for session in ['', '192.168.1.2 1234 192.168.1.1 22',
                        '100.63.255.254 1234 192.168.1.1 22',
                        '100.128.0.1 1234 192.168.1.1 22']:
            with self.subTest(session=session):
                self.assertEqual(self.run_script('nas_ts_guard_session', session).returncode, 0)

    def test_old_process_must_exit_before_start(self):
        result = self.run_script('''
process_checks=0
nas_ts_service() { echo "SERVICE:$1"; }
pidof() { process_checks=$((process_checks + 1)); [ "$process_checks" -le 2 ]; }
sleep() { echo WAIT; }
nas_ts_restart
''', '192.168.1.2 1234 192.168.1.1 22')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([line for line in result.stdout.splitlines()
                          if line == 'WAIT' or line.startswith('SERVICE:')],
                         ['SERVICE:stop', 'WAIT', 'WAIT', 'SERVICE:start'])

    def test_stop_failure_prevents_start(self):
        result = self.run_script('nas_ts_service() { echo "SERVICE:$1"; return 1; }; nas_ts_restart')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SERVICE:start', result.stdout)

    def test_stuck_process_is_not_killed_or_started_again(self):
        result = self.run_script('''
nas_ts_service() { echo "SERVICE:$1"; }
pidof() { return 0; }
sleep() { :; }
nas_ts_restart
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SERVICE:start', result.stdout)

    def test_start_failure_is_reported(self):
        result = self.run_script('''
nas_ts_service() { [ "$1" != start ]; }
pidof() { return 1; }
nas_ts_restart
''')
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
