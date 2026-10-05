from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'scripts/run-persistent-base-stage.sh'


class PersistentBaseLauncherTests(unittest.TestCase):
    def test_launcher_uses_user_systemd_and_an_independent_log(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            fake_bin = root / 'bin'
            fake_bin.mkdir()
            capture = root / 'args.txt'
            fake = fake_bin / 'systemd-run'
            fake.write_text('''#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$@" > "$CAPTURE_ARGS"
''')
            fake.chmod(0o755)
            env = {'PATH': str(fake_bin) + ':/usr/bin:/bin', 'CAPTURE_ARGS': str(capture)}
            run = subprocess.run(['/bin/bash', str(SCRIPT)], capture_output=True, text=True, env=env)
            self.assertEqual(run.returncode, 0, run.stderr)
            args = capture.read_text().splitlines()
            self.assertIn('--user', args)
            self.assertIn('--no-block', args)
            self.assertTrue(any(x.startswith('--unit=alpbahos-infra-base-') for x in args))
            self.assertTrue(any(x.startswith('--property=RuntimeMaxSec=infinity') for x in args))
            self.assertTrue(any(x.startswith('--property=WorkingDirectory=') for x in args))
            self.assertTrue(any(x.startswith('--property=StandardOutput=append:') for x in args))
            self.assertEqual(args[args.index('/usr/bin/python3'):args.index('/usr/bin/python3') + 2],
                             ['/usr/bin/python3', '-u'])
            self.assertIn(str(REPO / 'scripts/infra-base-stage.py'), args)
            self.assertIn('unit=', run.stdout)
            self.assertIn('log=', run.stdout)

    def test_launcher_rejects_an_unexpected_build_command(self):
        run = subprocess.run(['/bin/bash', str(SCRIPT), 'rm', '-rf', '/'],
                             capture_output=True, text=True, env={'PATH': '/usr/bin:/bin'})
        self.assertNotEqual(run.returncode, 0)


if __name__ == '__main__':
    unittest.main()
