#!/usr/bin/env bash
set -euo pipefail
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-component-diagnosis.XXXXXX)
trap 'rm -rf -- "$TEMP_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# No KDE process or live home is involved: only the doctor's exit contract.
cat > "$TEMP_ROOT/doctor" <<'MOCK'
#!/usr/bin/env bash
[[ $# == 2 && $1 == --target && $2 == minimalist-v04 ]] || exit 64
printf 'mock diagnosis %s\n' "$MOCK_STATUS"
exit "$MOCK_STATUS"
MOCK
chmod +x "$TEMP_ROOT/doctor"
for status in 0 1 2 64 127; do
    for apply in false true; do
        for allow in false true; do
            result=0
            MOCK_STATUS=$status bash -euo pipefail -c '
                source "$1/scripts/lib/common.sh"
                require_component_diagnosis "$2" minimalist-v04 "$3" "$4" "component apply is refused"
                [[ $- == *e* ]] || exit 65
                printf "accepted\n"
            ' _ "$REPO_ROOT" "$TEMP_ROOT/doctor" "$apply" "$allow" > "$TEMP_ROOT/result" 2>&1 || result=$?
            expected=1
            if [[ $status == 0 || ( $status == 1 && ( $apply == false || $allow == true ) ) ]]; then
                expected=0
            fi
            [[ $result == "$expected" ]] || fail "wrong decision: status=$status apply=$apply allow=$allow"
            grep -Fq "mock diagnosis $status" "$TEMP_ROOT/result" || fail "diagnosis output lost"
            if [[ $status == 2 ]]; then
                grep -Fq 'unsupported; component apply is refused' "$TEMP_ROOT/result" || fail "unsupported refusal lost"
            fi
        done
    done
done
printf 'PASS: component compatibility decisions, refusal, and shell option preservation\n'
