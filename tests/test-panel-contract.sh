#!/usr/bin/env bash
set -euo pipefail
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-panel-contract.XXXXXX)
trap 'rm -rf -- "$TEMP_ROOT"' EXIT
SYNC="$REPO_ROOT/scripts/sync-panel-contract"
"$SYNC" --check
python3 - "$REPO_ROOT" "$TEMP_ROOT" "$SYNC" <<'PY'
import copy
import json
import shutil
import subprocess
import sys
from pathlib import Path

repo, temp, sync = map(Path, sys.argv[1:])
source = temp / "source"
layout = Path("layouts/plasma/org.kde.minimalist-v04/contents")
for directory in [Path("design/panel"), layout]:
    shutil.copytree(repo / directory, source / directory)

def run(mode, ok):
    result = subprocess.run([str(sync), mode, "--source", str(source)], capture_output=True, text=True)
    assert (result.returncode == 0) == ok, result.stdout + result.stderr
    return result

original = {path: path.read_bytes() for path in (source / layout).glob("*.js")}
run("--write", True)
assert all(path.read_bytes() == text for path, text in original.items()), "generation is not idempotent"
preflight = source / layout / "preflight.js"
preflight.write_text(preflight.read_text().replace('const taskType = "org.kde.plasma.icontasks";', 'const taskType = "org.kde.plasma.tasks";'))
drift = preflight.read_bytes()
assert "stale generated panel constants" in run("--check", False).stderr
assert preflight.read_bytes() == drift, "check wrote a source file"
run("--write", True)
assert all(path.read_bytes() == text for path, text in original.items()), "sync changed consumer logic"

# Invalid roles or transition shapes must fail before writing any consumer,
# even if a source block is already stale. Two spacers need distinct roles.
contract_path = source / "design/panel/v04.json"
contract_text = contract_path.read_text()
contract = json.loads(contract_text)
invalid = []
bad = copy.deepcopy(contract)
bad["roles"]["tasks"] = "resources"
invalid.append((bad, "invalid panel role/type bindings"))
bad = copy.deepcopy(contract)
bad["sequences"]["stagedWidgets"][3] = "leftSpacer"
invalid.append((bad, "invalid panel sequence"))
bad = copy.deepcopy(contract)
bad["sequences"]["v04Widgets"][3], bad["sequences"]["v04Widgets"][5] = (
    bad["sequences"]["v04Widgets"][5], bad["sequences"]["v04Widgets"][3])
invalid.append((bad, "supported insertion/cleanup transitions"))
bad = copy.deepcopy(contract)
bad["sequences"]["v04PagerWidgets"].remove("clock")
invalid.append((bad, "invalid panel sequence"))
bad = copy.deepcopy(contract)
bad["widgets"]["tasks"] = bad["widgets"]["resources"]
invalid.append((bad, "widget identities must be distinct"))
preflight.write_bytes(drift)
before_invalid = {path: path.read_bytes() for path in original}
for bad, message in invalid:
    contract_path.write_text(json.dumps(bad))
    for mode in ("--check", "--write"):
        assert message in run(mode, False).stderr
        assert all(path.read_bytes() == text for path, text in before_invalid.items()), "invalid contract wrote a source file"
contract_path.write_text(contract_text)
run("--write", True)

# A later unsafe destination must refuse the entire write before touching an
# earlier stale file. The external file remains unchanged as well.
preflight.write_bytes(drift)
postcheck = source / layout / "postcheck.js"
postcheck.unlink()
outside = temp / "outside.js"
outside.write_text("preserve this file\n")
postcheck.symlink_to(outside)
run("--write", False)
assert preflight.read_bytes() == drift, "partial write before destination validation"
assert outside.read_text() == "preserve this file\n", "followed destination symlink"
postcheck.unlink()
postcheck.write_bytes(original[postcheck])
postcheck.write_text(postcheck.read_text().replace("// END GENERATED PANEL CONSTANTS", "// missing marker"))
run("--write", False)
assert preflight.read_bytes() == drift, "partial write before marker validation"
PY
printf 'PASS: panel role/type and transition validation, drift detection, and write boundaries\n'
