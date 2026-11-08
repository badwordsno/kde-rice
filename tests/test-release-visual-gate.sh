#!/usr/bin/env bash
set -euo pipefail
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-visual-gate.XXXXXX)
trap 'rm -rf -- "$TEMP_ROOT"' EXIT
python3 - "$REPO_ROOT" "$TEMP_ROOT" <<'PY'
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

repo, temp = map(Path, sys.argv[1:])
fixture = temp / 'source'
(fixture / 'scripts').mkdir(parents=True)
(fixture / 'tests').mkdir()
(fixture / 'VERSION').write_text('0.0.0\n')
shutil.copy2(repo / 'scripts/check-release', fixture / 'scripts/check-release')
(fixture / 'tests/test-noop.sh').write_text('#!/usr/bin/env bash\nexit 0\n')
visual = fixture / 'tests/test-panel-readability.py'
visual.write_text('import os, sys\nprint("visual fixture")\nsys.exit(int(os.environ["TEST_VISUAL_STATUS"]))\n')
builder = fixture / 'scripts/build-release'
builder.write_text('''#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 && $1 == --output ]]
output=$2
root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$output/stage/minimalist-black-kde-0.0.0"
cp -a "$root/." "$output/stage/minimalist-black-kde-0.0.0/"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cJf "$output/minimalist-black-kde-0.0.0.tar.xz" -C "$output/stage" minimalist-black-kde-0.0.0
(cd "$output" && sha256sum minimalist-black-kde-0.0.0.tar.xz > SHA256SUMS)
''')
builder.chmod(0o755)
for status in [0, 77, 1]:
    result = subprocess.run(['bash', str(fixture / 'scripts/check-release')], env={**os.environ, 'TEST_VISUAL_STATUS': str(status)}, capture_output=True, text=True)
    output = result.stdout + result.stderr
    assert result.returncode == status, output
    assert ('Automated release gate passed.' in output) == (status == 0), output
    if status == 77:
        assert 'NOT RUN candidate/test-panel-readability.py' in output, output
        assert 'NOT RUN extracted/test-panel-readability.py' in output, output
        assert 'INCOMPLETE:' in output, output
    if status == 0:
        assert 'PASS candidate/test-panel-readability.py' in output, output
        assert 'PASS extracted/test-panel-readability.py' in output, output
    if status == 1:
        assert 'FAIL candidate/test-panel-readability.py' in output, output
# A missing distributed test must fail, not masquerade as unavailable Qt.
visual.unlink()
result = subprocess.run(['bash', str(fixture / 'scripts/check-release')], capture_output=True, text=True)
assert result.returncode != 0 and result.returncode != 77, result.stdout + result.stderr

# The actual readability child must return 77 for absent PySide6. -S excludes
# site packages without changing any installed dependency or using a live bus.
with tempfile.TemporaryDirectory(prefix='kde-rice-readability-', dir='/tmp') as directory:
    target = Path(directory)
    for part in ['.config', '.local/share', '.local/state', '.cache', 'runtime']:
        (target / part).mkdir(parents=True, exist_ok=True)
    (target / 'runtime').chmod(0o700)
    env = {
        'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'LANG': 'C.UTF-8',
        'HOME': directory, 'XDG_CONFIG_HOME': str(target / '.config'),
        'XDG_DATA_HOME': str(target / '.local/share'), 'XDG_STATE_HOME': str(target / '.local/state'),
        'XDG_CACHE_HOME': str(target / '.cache'), 'XDG_RUNTIME_DIR': str(target / 'runtime'),
        'DBUS_SESSION_BUS_ADDRESS': 'unix:path=' + str(target / 'no-session-bus'),
        'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
    }
    result = subprocess.run([sys.executable, '-S', str(repo / 'tests/test-panel-readability.py'), '--isolated-child'], env=env, capture_output=True, text=True)
    assert result.returncode == 77 and 'NOT RUN:' in result.stderr, result.stdout + result.stderr
# Check the launcher's sandbox root even when an unrelated TMPDIR is exported.
# Intercept only its child dispatch; Qt itself is exercised by check-release.
code = r'''
import os, runpy, subprocess, sys
from pathlib import Path

def child(command, *, env, timeout):
    assert Path(env['HOME']).parent == Path('/tmp')
    assert env['HOME'] != os.environ['TMPDIR']
    assert env['DBUS_SESSION_BUS_ADDRESS'].endswith('/no-session-bus')
    return subprocess.CompletedProcess(command, 77)

subprocess.run = child
sys.argv = [sys.argv[1]]
runpy.run_path(sys.argv[0], run_name='__main__')
'''
result = subprocess.run([sys.executable, '-c', code, str(repo / 'tests/test-panel-readability.py')], env={**os.environ, 'TMPDIR': str(temp)}, capture_output=True, text=True)
assert result.returncode == 77, result.stdout + result.stderr
print('PASS: visual gate success, failure, missing-test refusal, and explicit unavailable state')
PY
