#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-resume.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-resume.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing to clean unexpected test directory: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

RESUME="$REPO_ROOT/scripts/resume-bootstrap"
TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
DOCTOR="$MOCK_BIN/doctor"
VERIFY="$MOCK_BIN/verify"
DBUS="$MOCK_BIN/qdbus6"
STEP_RUNNER="$TEMP_ROOT/step-runner"
SNAPSHOT="$TARGET_HOME/.local/state/kde-rice/snapshots/failed-transaction"
RECEIPT="$TARGET_HOME/.local/state/kde-rice/bootstrap/failed-transaction"
TARGET_LOG="$TEMP_ROOT/targets.log"
STEP_LOG="$TEMP_ROOT/steps.log"
mkdir -p -- "$MOCK_BIN" "$TARGET_HOME/.config" "$SNAPSHOT" "$RECEIPT"
printf 'managed sentinel\n' > "$TARGET_HOME/.config/kdeglobals"
printf 'complete\n' > "$SNAPSHOT/complete"
printf '%s\n' "$SNAPSHOT" > "$RECEIPT/snapshot-path"
printf 'supported\n' > "$RECEIPT/compatibility"
printf 'plasma6-stock\n' > "$RECEIPT/panel-signature.before"
printf 'minimalist-v04\n' > "$RECEIPT/panel-target"
printf 'verify\t1\n' > "$RECEIPT/failed"
printf '%s\n' \
    $'.config/kwinoutputconfig.json\tabsent' \
    $'.local/share/kscreen\tabsent' \
    > "$RECEIPT/display-state.before.tsv"
printf 'failure fingerprint\n' > "$RECEIPT/display-state.failure.tsv"

cat > "$DOCTOR" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == --target ]] || exit 9
case "${2:-}" in
    minimalist-v03 | minimalist-v04) ;;
    *) exit 10 ;;
esac
printf 'doctor:%s\n' "$2" >> "${MOCK_TARGET_LOG:?}"
printf 'KDE Rice Doctor\nStatus: supported\nExit code: 0\n'
MOCK
cat > "$VERIFY" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
resume=false
receipt=
panel_target=
while (($#)); do
    case "$1" in
        --resume-receipt) resume=true; receipt=$2; shift 2 ;;
        --receipt) receipt=$2; shift 2 ;;
        --panel-target) panel_target=$2; shift 2 ;;
        *) shift ;;
    esac
done
[[ -n $receipt && -n $panel_target ]] || exit 10
case "$panel_target" in
    minimalist-v03 | minimalist-v04 | minimalist-v04-pager | minimalist-v04-workspaces) ;;
    *) exit 13 ;;
esac
printf 'verify:%s:%s\n' "$panel_target" "$resume" >> "${MOCK_TARGET_LOG:?}"
if $resume; then
    [[ -f $receipt/failed && ! -e $receipt/complete ]] || exit 11
else
    [[ ! -e $receipt/failed && -f $receipt/verification-ready \
        && -f $receipt/display-state.after.tsv ]] || exit 12
fi
[[ ${MOCK_VERIFY_FAIL:-0} != 1 ]] || exit 23
printf '%s verification: VERIFIED\n' "$panel_target"
MOCK
cat > "$DBUS" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
signature=${MOCK_PANEL_SIGNATURE:-minimalist-v04}
case "$signature" in
    minimalist-v02)
        transition=already-target
        widgets='org.kde.plasma.kickoff;org.kde.minimalist.activewindowtitle;org.kde.plasma.panelspacer;org.kde.plasma.marginsseparator;org.kde.plasma.kimpanel;org.kde.plasma.systemtray;org.kde.plasma.digitalclock'
        ;;
    minimalist-v04)
        transition=v04-target
        widgets='org.kde.plasma.kickoff;org.kde.minimalist.activewindowtitle;org.kde.plasma.panelspacer;org.kde.plasma.icontasks;org.kde.plasma.panelspacer;org.kde.minimalist.resources;org.kde.plasma.marginsseparator;org.kde.plasma.kimpanel;org.kde.plasma.systemtray;org.kde.plasma.digitalclock'
        ;;
    *) transition=refuse; widgets=none ;;
esac
printf 'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"signature":"%s"}' "$signature"
printf 'KDE_RICE_PANEL_STATE schema=1 panelCount=1 desktopCount=1 signature=%s transition=%s supported=true targetComplete=false orderValid=true geometryOk=true widgetTypes=%s geometry=0,top,horizontal,28,opaque,fill,1920,1920,1920\n' \
    "$signature" "$transition" "$widgets"
MOCK
cat > "$STEP_RUNNER" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
step=$(basename -- "$1")
[[ -f ${KDE_RICE_TRANSACTION_SNAPSHOT:?}/complete ]] || exit 20
[[ ! -e ${KDE_RICE_TRANSACTION_RECEIPT:?}/failed ]] || exit 21
printf '%s\n' "$step" >> "${MOCK_STEP_LOG:?}"
[[ ${MOCK_CONTINUE_FAIL_STEP:-none} != "$step" ]] || exit 24
MOCK
chmod +x "$DOCTOR" "$VERIFY" "$DBUS" "$STEP_RUNNER" "$RESUME"

run_resume() {
    HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        XDG_DATA_HOME="$TARGET_HOME/.local/share" XDG_STATE_HOME="$TARGET_HOME/.local/state" \
        PATH="$MOCK_BIN:$PATH" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$DBUS" \
        KDE_RICE_DOCTOR_COMMAND="$DOCTOR" KDE_RICE_VERIFY_COMMAND="$VERIFY" \
        KDE_RICE_STEP_RUNNER="$STEP_RUNNER" MOCK_TARGET_LOG="$TARGET_LOG" \
        MOCK_STEP_LOG="$STEP_LOG" \
        MOCK_PANEL_SIGNATURE="${MOCK_PANEL_SIGNATURE:-minimalist-v04}" \
        MOCK_CONTINUE_FAIL_STEP="${MOCK_CONTINUE_FAIL_STEP:-none}" \
        "$RESUME" --home "$TARGET_HOME" --receipt "$RECEIPT" "$@"
}

bash -n "$RESUME"
before=$(sha256sum "$TARGET_HOME/.config/kdeglobals" "$RECEIPT/failed" \
    "$RECEIPT/display-state.before.tsv" "$RECEIPT/panel-target")
run_resume > "$TEMP_ROOT/dry-run.txt"
after=$(sha256sum "$TARGET_HOME/.config/kdeglobals" "$RECEIPT/failed" \
    "$RECEIPT/display-state.before.tsv" "$RECEIPT/panel-target")
[[ $before == "$after" ]] || fail "resume dry-run changed managed or receipt state"
[[ ! -e $RECEIPT/history && ! -e $RECEIPT/complete ]] \
    || fail "resume dry-run created transaction state"
grep -Fq 'managed desktop writes: none' "$TEMP_ROOT/dry-run.txt" \
    || fail "resume plan omitted its no-desktop-write boundary"
grep -Fq 'receipt panel target: minimalist-v04' "$TEMP_ROOT/dry-run.txt" \
    || fail "resume plan omitted its recorded v0.4.1 target"
grep -Fxq 'doctor:minimalist-v04' "$TARGET_LOG" \
    || fail "resume doctor did not receive the recorded v0.4.1 target"
grep -Fxq 'verify:minimalist-v04:true' "$TARGET_LOG" \
    || fail "resume verification did not receive the recorded v0.4.1 target"

managed_before=$(sha256sum "$TARGET_HOME/.config/kdeglobals")
run_resume --apply > "$TEMP_ROOT/apply.txt"
[[ $(sha256sum "$TARGET_HOME/.config/kdeglobals") == "$managed_before" ]] \
    || fail "resume apply changed a managed desktop file"
[[ -f $RECEIPT/complete && ! -e $RECEIPT/failed ]] \
    || fail "resume apply did not finalize the failed receipt"
[[ -L $TARGET_HOME/.local/state/kde-rice/bootstrap/latest ]] \
    || fail "resumed receipt was not selected as latest"
history_failed=$(find "$RECEIPT/history" -name failed -type f -print -quit)
[[ -n $history_failed ]] || fail "original failure status was not preserved"
grep -Fq 'No managed desktop, panel, widget, KWin, or display setting was written.' \
    "$TEMP_ROOT/apply.txt" || fail "resume completion omitted its write boundary"

WORKSPACES_RECEIPT="$TARGET_HOME/.local/state/kde-rice/bootstrap/workspaces-verify-transaction"
mkdir -p -- "$WORKSPACES_RECEIPT"
printf '%s\n' "$SNAPSHOT" > "$WORKSPACES_RECEIPT/snapshot-path"
printf 'supported\n' > "$WORKSPACES_RECEIPT/compatibility"
printf 'minimalist-v04-workspaces\n' > "$WORKSPACES_RECEIPT/panel-signature.before"
printf 'minimalist-v04-workspaces\n' > "$WORKSPACES_RECEIPT/panel-target"
printf 'verify\t1\n' > "$WORKSPACES_RECEIPT/failed"
printf '%s\n' \
    $'.config/kwinoutputconfig.json\tabsent' \
    $'.local/share/kscreen\tabsent' \
    > "$WORKSPACES_RECEIPT/display-state.before.tsv"
RECEIPT=$WORKSPACES_RECEIPT
: > "$TARGET_LOG"
run_resume > "$TEMP_ROOT/workspaces-dry-run.txt"
grep -Fxq 'doctor:minimalist-v04' "$TARGET_LOG" \
    || fail "Workspaces receipt did not map diagnosis to the v0.4.1 capability target"
grep -Fxq 'verify:minimalist-v04-workspaces:true' "$TARGET_LOG" \
    || fail "Workspaces receipt lost its exact resume verification target"
run_resume --apply > "$TEMP_ROOT/workspaces-apply.txt"
[[ -f $WORKSPACES_RECEIPT/complete && ! -e $WORKSPACES_RECEIPT/failed ]] \
    || fail "Workspaces metadata-only resume did not finalize its receipt"

CONTINUE_RECEIPT="$TARGET_HOME/.local/state/kde-rice/bootstrap/fresh-opacity-transaction"
mkdir -p -- "$CONTINUE_RECEIPT"
printf '%s\n' "$SNAPSHOT" > "$CONTINUE_RECEIPT/snapshot-path"
printf 'degraded\n' > "$CONTINUE_RECEIPT/compatibility"
printf 'plasma6-stock-ime\n' > "$CONTINUE_RECEIPT/panel-signature.before"
printf 'minimalist-v04\n' > "$CONTINUE_RECEIPT/panel-target"
printf 'panel\t1\n' > "$CONTINUE_RECEIPT/failed"
printf '%s\n' \
    $'.config/kwinoutputconfig.json\tabsent' \
    $'.local/share/kscreen\tabsent' \
    > "$CONTINUE_RECEIPT/display-state.before.tsv"
printf 'failure fingerprint\n' > "$CONTINUE_RECEIPT/display-state.failure.tsv"
RECEIPT=$CONTINUE_RECEIPT
: > "$TARGET_LOG"
: > "$STEP_LOG"
MOCK_PANEL_SIGNATURE=minimalist-v02 run_resume > "$TEMP_ROOT/continue-dry-run.txt"
grep -Fq 'resume mode: receipt-bound component continuation' \
    "$TEMP_ROOT/continue-dry-run.txt" \
    || fail "fresh-opacity receipt did not select component continuation"
grep -Fq 'panel additions: one resource widget, one right expanding spacer, one Icons-only Task Manager' \
    "$TEMP_ROOT/continue-dry-run.txt" \
    || fail "fresh-opacity continuation omitted exact panel additions"
[[ ! -s $STEP_LOG && -f $CONTINUE_RECEIPT/failed && ! -e $CONTINUE_RECEIPT/history ]] \
    || fail "fresh-opacity continuation dry-run wrote transaction state"

MOCK_PANEL_SIGNATURE=minimalist-v02 run_resume --apply > "$TEMP_ROOT/continue-apply.txt"
mapfile -t continue_steps < "$STEP_LOG"
expected_continue_steps=(apply-minimalist-v03 apply-minimalist-v04)
[[ ${continue_steps[*]} == "${expected_continue_steps[*]}" ]] \
    || fail "fresh-opacity continuation ran the wrong components: ${continue_steps[*]}"
[[ -f $CONTINUE_RECEIPT/complete && ! -e $CONTINUE_RECEIPT/failed ]] \
    || fail "fresh-opacity continuation did not finalize the receipt"
grep -Fq 'missing v0.3/v0.4.1 managed components were applied against the original baseline snapshot' \
    "$TEMP_ROOT/continue-apply.txt" \
    || fail "fresh-opacity continuation completion omitted baseline reuse"
grep -Fxq 'verify:minimalist-v04:false' "$TARGET_LOG" \
    || fail "fresh-opacity continuation did not run normal final verification"

REFUSE_RECEIPT="$TARGET_HOME/.local/state/kde-rice/bootstrap/unknown-opacity-transaction"
mkdir -p -- "$REFUSE_RECEIPT"
printf '%s\n' "$SNAPSHOT" > "$REFUSE_RECEIPT/snapshot-path"
printf 'degraded\n' > "$REFUSE_RECEIPT/compatibility"
printf 'plasma6-stock\n' > "$REFUSE_RECEIPT/panel-signature.before"
printf 'minimalist-v04\n' > "$REFUSE_RECEIPT/panel-target"
printf 'panel\t1\n' > "$REFUSE_RECEIPT/failed"
cp -- "$CONTINUE_RECEIPT/display-state.before.tsv" "$REFUSE_RECEIPT/display-state.before.tsv"
RECEIPT=$REFUSE_RECEIPT
: > "$STEP_LOG"
set +e
MOCK_PANEL_SIGNATURE=unknown run_resume > "$TEMP_ROOT/continue-unknown.txt" 2>&1
status=$?
set -e
[[ $status == 1 && -f $REFUSE_RECEIPT/failed && ! -e $REFUSE_RECEIPT/history \
    && ! -s $STEP_LOG ]] \
    || fail "fresh-opacity continuation did not refuse unknown topology before writes"
grep -Fq 'neither the exact repaired final target nor the documented Opaque-repaired fresh base' \
    "$TEMP_ROOT/continue-unknown.txt" \
    || fail "fresh-opacity unknown-topology refusal reason is missing"

FAILED_CONTINUE_RECEIPT="$TARGET_HOME/.local/state/kde-rice/bootstrap/failed-opacity-continuation"
mkdir -p -- "$FAILED_CONTINUE_RECEIPT"
printf '%s\n' "$SNAPSHOT" > "$FAILED_CONTINUE_RECEIPT/snapshot-path"
printf 'degraded\n' > "$FAILED_CONTINUE_RECEIPT/compatibility"
printf 'plasma6-stock-ime\n' > "$FAILED_CONTINUE_RECEIPT/panel-signature.before"
printf 'minimalist-v04\n' > "$FAILED_CONTINUE_RECEIPT/panel-target"
printf 'panel\t1\n' > "$FAILED_CONTINUE_RECEIPT/failed"
cp -- "$CONTINUE_RECEIPT/display-state.before.tsv" "$FAILED_CONTINUE_RECEIPT/display-state.before.tsv"
RECEIPT=$FAILED_CONTINUE_RECEIPT
: > "$STEP_LOG"
set +e
MOCK_PANEL_SIGNATURE=minimalist-v02 MOCK_CONTINUE_FAIL_STEP=apply-minimalist-v04 \
    run_resume --apply > "$TEMP_ROOT/continue-failure.txt" 2>&1
status=$?
set -e
[[ $status == 24 && ! -e $FAILED_CONTINUE_RECEIPT/complete \
    && $(< "$FAILED_CONTINUE_RECEIPT/failed") == $'resume-task-manager\t24' ]] \
    || fail "component continuation failure did not leave an exact failed receipt"
history_failed=$(find "$FAILED_CONTINUE_RECEIPT/history" -name failed -type f -print -quit)
[[ -n $history_failed ]] \
    || fail "component continuation failure did not preserve the original failure"
grep -Fq 'baseline snapshot:' "$TEMP_ROOT/continue-failure.txt" \
    || fail "component continuation failure omitted rollback baseline"

LEGACY_RECEIPT="$TARGET_HOME/.local/state/kde-rice/bootstrap/legacy-v03-transaction"
mkdir -p -- "$LEGACY_RECEIPT"
printf '%s\n' "$SNAPSHOT" > "$LEGACY_RECEIPT/snapshot-path"
printf 'supported\n' > "$LEGACY_RECEIPT/compatibility"
printf 'minimalist-v03\n' > "$LEGACY_RECEIPT/panel-signature.before"
printf 'verify\t1\n' > "$LEGACY_RECEIPT/failed"
printf '%s\n' \
    $'.config/kwinoutputconfig.json\tabsent' \
    $'.local/share/kscreen\tabsent' \
    > "$LEGACY_RECEIPT/display-state.before.tsv"
RECEIPT=$LEGACY_RECEIPT
: > "$TARGET_LOG"
run_resume > "$TEMP_ROOT/legacy-dry-run.txt"
grep -Fq 'receipt panel target: minimalist-v03 (safe legacy default for pre-v0.4.1 receipts)' \
    "$TEMP_ROOT/legacy-dry-run.txt" \
    || fail "legacy receipt was not safely interpreted as a v0.3 target"
grep -Fxq 'doctor:minimalist-v03' "$TARGET_LOG" \
    || fail "legacy receipt doctor did not receive the v0.3 target"
grep -Fxq 'verify:minimalist-v03:true' "$TARGET_LOG" \
    || fail "legacy receipt verification did not receive the v0.3 target"
[[ ! -e $LEGACY_RECEIPT/panel-target ]] \
    || fail "legacy dry-run synthesized receipt metadata"

run_resume --apply > "$TEMP_ROOT/legacy-apply.txt"
[[ -f $LEGACY_RECEIPT/complete && ! -e $LEGACY_RECEIPT/failed ]] \
    || fail "legacy v0.3 receipt did not resume"
[[ $(realpath -e -- "$TARGET_HOME/.local/state/kde-rice/bootstrap/latest") == "$LEGACY_RECEIPT" ]] \
    || fail "resumed legacy receipt was not selected as latest"

printf 'PASS: failed bootstrap receipt resume tests\n'
