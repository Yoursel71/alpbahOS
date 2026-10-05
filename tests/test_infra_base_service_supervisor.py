import importlib.util
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/infra-base-stage.py'
SPEC = importlib.util.spec_from_file_location('infra_base_service_test', SCRIPT)
base_stage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(base_stage)


class BaseGuestServiceSupervisorTests(unittest.TestCase):
    def command(self, run_id='a' * 32):
        return base_stage.base_guest_service_command(run_id, 'b' * 64)

    def test_guest_runner_identity_is_validated_before_shell_generation(self):
        with self.assertRaisesRegex(RuntimeError, 'Invalid stage run identity'):
            base_stage.base_guest_service_command('../unsafe', 'b' * 64)
        with self.assertRaisesRegex(RuntimeError, 'Guest runner hash is invalid'):
            base_stage.base_guest_service_command('a' * 32, 'not-a-hash')

    def test_service_command_is_detached_and_waits_for_bound_summary(self):
        args = shlex.split(self.command())
        self.assertEqual(args[:2], ['bash', '-c'])
        script = args[2]
        self.assertEqual(subprocess.run(['bash', '-n', '-c', script]).returncode, 0)
        self.assertIn('systemd-run --unit="$unit" --no-block', script)
        self.assertIn('--property=RuntimeMaxSec=infinity', script)
        self.assertIn('--property=StandardOutput=journal', script)
        self.assertIn('/opt/alp-infra/infra-base-guest-run.py ' + 'b' * 64, script)
        self.assertLess(script.index('flock -u 9'), script.index('systemd-run --unit="$unit"'))
        self.assertLess(script.index('exec 9<&-'), script.index('systemd-run --unit="$unit"'))
        self.assertIn('source /opt/alp-infra/scripts/infra/guest-guard.sh', script)
        self.assertIn('guest_guard', script)
        self.assertIn('/bin/bash -c', script)
        self.assertIn('systemctl show --property=ActiveState --value', script)
        self.assertIn('"$result_state" == success', script)
        self.assertIn('-f "$summary" && ! -L "$summary"', script)

    def run_supervisor(self, run_id, success):
        script = shlex.split(self.command(run_id))[2]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            results = root / 'results'
            result = results / run_id
            result.mkdir(parents=True)
            script = script.replace('/srv/lfs/results/base', str(results))
            if success:
                (result / 'summary.json').write_text('{}')
            fake_bin = root / 'bin'
            fake_bin.mkdir()
            systemd_run = fake_bin / 'systemd-run'
            systemd_run.write_text('#!/usr/bin/env bash\nexit 0\n')
            systemd_run.chmod(0o755)
            flock = fake_bin / 'flock'
            flock.write_text('#!/usr/bin/env bash\nexit 0\n')
            flock.chmod(0o755)
            systemctl = fake_bin / 'systemctl'
            systemctl.write_text('''#!/usr/bin/env bash
set -euo pipefail
case "$2" in
  --property=ActiveState) printf 'inactive\\n' ;;
  --property=Result) [[ "$SIM_SUCCESS" == 1 ]] && printf 'success\\n' || printf 'exit-code\\n' ;;
  --property=ExecMainCode) printf 'exited\\n' ;;
  --property=ExecMainStatus) [[ "$SIM_SUCCESS" == 1 ]] && printf '0\\n' || printf '1\\n' ;;
  *) exit 1 ;;
esac
''')
            systemctl.chmod(0o755)
            journalctl = fake_bin / 'journalctl'
            journalctl.write_text('#!/usr/bin/env bash\nprintf "service output from journal\\n"\n')
            journalctl.chmod(0o755)
            env = {'PATH': str(fake_bin) + ':/usr/bin:/bin', 'SIM_SUCCESS': '1' if success else '0'}
            completed = subprocess.run(['bash', '-c', script], capture_output=True, text=True, env=env)
            return completed

    def test_service_success_requires_systemd_success_and_summary(self):
        completed = self.run_supervisor('d' * 32, True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn('service output from journal', completed.stdout)

    def test_service_error_cannot_be_reported_as_success(self):
        completed = self.run_supervisor('c' * 32, False)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn('Guest service failed', completed.stderr)


if __name__ == '__main__':
    unittest.main()
