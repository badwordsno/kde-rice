#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-transaction-snapshot.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-transaction-snapshot.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing to clean unexpected test directory: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

# shellcheck source=../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

TARGET_HOME="$TEMP_ROOT/home"
SNAPSHOT="$TARGET_HOME/.local/state/kde-rice/snapshots/transaction"
RECEIPT="$TARGET_HOME/.local/state/kde-rice/bootstrap/transaction"
MOCK_SNAPSHOT="$TEMP_ROOT/mock-snapshot"
CALL_LOG="$TEMP_ROOT/snapshot-calls"
mkdir -p -- "$SNAPSHOT" "$RECEIPT"
printf 'complete\n' > "$SNAPSHOT/complete"
printf '%s\n' "$SNAPSHOT" > "$RECEIPT/snapshot-path"

cat > "$MOCK_SNAPSHOT" <<'MOCK'
#!/usr/bin/env bash
printf 'called\n' >> "${MOCK_SNAPSHOT_CALL_LOG:?}"
mkdir -p -- "${4:?}"
printf 'complete\n' > "$4/complete"
MOCK
chmod +x "$MOCK_SNAPSHOT"

requested="$TARGET_HOME/.local/state/kde-rice/snapshots/component"
KDE_RICE_TRANSACTION_SNAPSHOT="$SNAPSHOT" \
KDE_RICE_TRANSACTION_RECEIPT="$RECEIPT" \
    capture_or_reuse_snapshot "$TARGET_HOME" "$requested" "$MOCK_SNAPSHOT" effective \
    > "$TEMP_ROOT/reuse.txt"
[[ $effective == "$SNAPSHOT" ]] || fail "component did not reuse the transaction snapshot"
[[ ! -e $CALL_LOG ]] || fail "component captured a redundant nested snapshot"
grep -Fq 'Reusing bootstrap baseline snapshot:' "$TEMP_ROOT/reuse.txt" \
    || fail "transaction snapshot reuse was not reported"

unset KDE_RICE_TRANSACTION_SNAPSHOT KDE_RICE_TRANSACTION_RECEIPT
MOCK_SNAPSHOT_CALL_LOG="$CALL_LOG" \
    capture_or_reuse_snapshot "$TARGET_HOME" "$requested" "$MOCK_SNAPSHOT" effective
[[ $effective == "$requested" && -f $requested/complete ]] \
    || fail "standalone component did not capture its own snapshot"
[[ $(wc -l < "$CALL_LOG") == 1 ]] || fail "standalone snapshot command call count is wrong"

printf 'failed\t1\n' > "$RECEIPT/failed"
set +e
(
    export KDE_RICE_TRANSACTION_SNAPSHOT="$SNAPSHOT"
    export KDE_RICE_TRANSACTION_RECEIPT="$RECEIPT"
    capture_or_reuse_snapshot "$TARGET_HOME" "$requested-second" "$MOCK_SNAPSHOT" effective
) > "$TEMP_ROOT/failed-receipt.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "failed transaction receipt was accepted for snapshot reuse"

printf 'PASS: bootstrap transaction snapshot reuse tests\n'
