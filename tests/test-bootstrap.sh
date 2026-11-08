#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-bootstrap.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-bootstrap.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing to clean unexpected test directory: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

BOOTSTRAP="$REPO_ROOT/scripts/bootstrap"
MOCK_BIN="$TEMP_ROOT/bin"
DOCTOR="$TEMP_ROOT/doctor"
STEP_RUNNER="$TEMP_ROOT/step-runner"
VERIFY="$TEMP_ROOT/verify"
CALL_LOG="$TEMP_ROOT/calls.log"
mkdir -p -- "$MOCK_BIN"

cat > "$DOCTOR" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == --target && ${2:-} == minimalist-v04 ]] || {
    printf 'unexpected doctor target: %s\n' "$*" >&2
    exit 64
}
status=${MOCK_DOCTOR_STATUS:-0}
case "$status" in
    0) printf 'KDE rice doctor\nStatus: supported\n' ;;
    1) printf 'KDE rice doctor\nStatus: degraded\nReason: unconfirmed Plasma 6 minor\n' ;;
    2) printf 'KDE rice doctor\nStatus: unsupported\nMissing: Wayland\n' ;;
    *) printf 'doctor internal error\n' >&2 ;;
esac
exit "$status"
EOF

cat > "$MOCK_BIN/qdbus6" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
signature=${MOCK_PANEL_SIGNATURE:-plasma6-stock}
target='org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
v03_target='org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.minimalist.resources,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
v04_staged_target='org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.panelspacer,org.kde.minimalist.resources,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
v04_task_front_target='org.kde.plasma.icontasks,org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.panelspacer,org.kde.minimalist.resources,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
v04_target='org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.icontasks,org.kde.plasma.panelspacer,org.kde.minimalist.resources,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
v04_pager_target='org.kde.plasma.kickoff,org.kde.plasma.pager,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.icontasks,org.kde.plasma.panelspacer,org.kde.minimalist.resources,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
v04_workspaces_target='org.kde.plasma.kickoff,org.kde.minimalist.workspaces,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.icontasks,org.kde.plasma.panelspacer,org.kde.minimalist.resources,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
case "$signature" in
    plasma6-stock)
        transition=replace-fresh-panel
        panels=42
        widgets='101:org.kde.plasma.kickoff,102:org.kde.plasma.pager,103:org.kde.plasma.icontasks,104:org.kde.plasma.marginsseparator,105:org.kde.plasma.systemtray,106:org.kde.plasma.digitalclock,107:org.kde.plasma.showdesktop'
        current_widgets='org.kde.plasma.kickoff;org.kde.plasma.pager;org.kde.plasma.icontasks;org.kde.plasma.marginsseparator;org.kde.plasma.systemtray;org.kde.plasma.digitalclock;org.kde.plasma.showdesktop'
        geometry='0,bottom,horizontal,44,adaptive,fill,1920,1920,1920'
        ;;
    minimalist-v01)
        transition=managed-v02-transition
        panels=none
        widgets=none
        current_widgets=${target//,/;}
        geometry='0,top,horizontal,28,opaque,fill,1920,1920,1920'
        ;;
    minimalist-v02)
        transition=already-target
        panels=none
        widgets=none
        current_widgets=${target//,/;}
        geometry='0,top,horizontal,28,opaque,fill,1920,1920,1920'
        ;;
    minimalist-v03)
        transition=v03-target
        panels=none
        widgets=none
        current_widgets=${v03_target//,/;}
        geometry='0,top,horizontal,28,opaque,fill,1920,1920,1920'
        ;;
    minimalist-v04-spacer-staged)
        transition=v04-recover-spacer
        panels=none
        widgets=none
        current_widgets=${v04_staged_target//,/;}
        geometry='0,top,horizontal,28,opaque,fill,1920,1920,1920'
        ;;
    minimalist-v04-task-front-staged)
        transition=repair-v04-task-order
        panels=none
        widgets=none
        current_widgets=${v04_task_front_target//,/;}
        geometry='0,top,horizontal,28,opaque,fill,1920,1920,1920'
        ;;
    minimalist-v04)
        transition=v04-target
        panels=none
        widgets=none
        current_widgets=${v04_target//,/;}
        geometry='0,top,horizontal,28,opaque,fill,1920,1920,1920'
        ;;
    minimalist-v04-pager)
        transition=v04-pager-target
        panels=none
        widgets=none
        current_widgets=${v04_pager_target//,/;}
        geometry='0,top,horizontal,32,opaque,fill,1920,1920,1920'
        ;;
    minimalist-v04-workspaces)
        transition=v04-workspaces-target
        panels=none
        widgets=none
        current_widgets=${v04_workspaces_target//,/;}
        geometry='0,top,horizontal,32,opaque,fill,1920,1920,1920'
        ;;
    *)
        transition=refuse
        panels=none
        widgets=none
        current_widgets=none
        geometry=none
        ;;
esac
printf 'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"signature":"%s"}' "$signature"
printf 'KDE_RICE_PANEL_STATE schema=1 panelCount=1 desktopCount=1 signature=%s transition=%s supported=%s targetComplete=false widgetTypes=%s geometry=%s removePanelIds=%s removeWidgetIds=none removeWidgetEntries=%s createPanel=true targetWidgets=%s\n' \
    "$signature" "$transition" "$([[ $signature == unknown ]] && printf false || printf true)" \
    "$current_widgets" "$geometry" "$panels" "$widgets" "$target"
EOF

cat > "$VERIFY" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$STEP_RUNNER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
step=$(basename -- "$1")
shift
[[ -f ${KDE_RICE_TRANSACTION_SNAPSHOT:?}/complete ]] || {
    printf 'component ran before the transaction snapshot completed\n' >&2
    exit 90
}
printf '%s\n' "$step" >> "${MOCK_CALL_LOG:?}"
if [[ $step == verify ]]; then
    case " $* " in
        *' --panel-target minimalist-v04 '* \
            | *' --panel-target minimalist-v04-pager '* \
            | *' --panel-target minimalist-v04-workspaces '*) ;;
        *) printf 'verify did not receive the v0.4.1 target: %s\n' "$*" >&2; exit 91 ;;
    esac
fi
if [[ $step == verify && ${MOCK_VERIFY_FAIL:-0} == 1 ]]; then
    exit 24
fi
if [[ $step == apply-black ]]; then
    printf 'applied-black\n' > "${HOME:?}/.config/kdeglobals"
fi
if [[ $step == apply-modern && ${MOCK_CHANGE_DISPLAY:-0} == 1 ]]; then
    printf 'changed-display\n' > "${HOME:?}/.config/kwinoutputconfig.json"
fi
if [[ $step == "${MOCK_FAIL_STEP:-never}" ]]; then
    exit 23
fi
exit 0
EOF
chmod +x "$DOCTOR" "$MOCK_BIN/qdbus6" "$VERIFY" "$STEP_RUNNER" "$BOOTSTRAP"

new_home() {
    local name=$1
    local home="$TEMP_ROOT/$name"
    mkdir -p -- "$home/.config"
    printf 'baseline-kdeglobals\n' > "$home/.config/kdeglobals"
    printf '[Containments][1][Wallpaper][org.kde.image][General]\nImage=file:///user-owned/desktop-wallpaper.png\n' \
        > "$home/.config/plasma-org.kde.plasma.desktop-appletsrc"
    printf 'baseline-shell\n' > "$home/.config/plasmashellrc"
    printf '[Wallpapers]\nusersWallpapers=file:///user-owned/wallpaper.png\n' \
        > "$home/.config/plasmarc"
    printf '%s\n' "$home"
}

run_bootstrap() {
    local home=$1
    shift
    HOME="$home" XDG_CONFIG_HOME="$home/.config" \
        XDG_DATA_HOME="$home/.local/share" XDG_STATE_HOME="$home/.local/state" \
        PATH="$MOCK_BIN:$PATH" KDE_RICE_TEST_MODE=1 \
        KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
        KDE_RICE_DOCTOR_COMMAND="$DOCTOR" KDE_RICE_VERIFY_COMMAND="$VERIFY" \
        KDE_RICE_STEP_RUNNER="$STEP_RUNNER" MOCK_CALL_LOG="$CALL_LOG" \
        MOCK_FAIL_STEP="${MOCK_FAIL_STEP:-never}" \
        MOCK_VERIFY_FAIL="${MOCK_VERIFY_FAIL:-0}" \
        "$BOOTSTRAP" --home "$home" "$@"
}

bash -n "$BOOTSTRAP"
if grep -Eq 'kwinoutputconfig[^\n]*(cp|mv|rm)|\.local/share/kscreen[^\n]*(cp|mv|rm)' "$BOOTSTRAP"; then
    fail "bootstrap contains a display-configuration mutation"
fi
retired_wallpaper_pattern='Minimalist''V02|apply-personal-''wallpaper|wallpaper-''variant|plasma-apply-''wallpaperimage'
if grep -Eq "$retired_wallpaper_pattern" \
    "$REPO_ROOT/scripts/bootstrap" "$REPO_ROOT/scripts/doctor" "$REPO_ROOT/scripts/verify"; then
    fail "active desktop entry points retain a private wallpaper dependency"
fi

set +e
"$BOOTSTRAP" --unknown > /dev/null 2>&1
status=$?
set -e
[[ $status == 64 ]] || fail "bootstrap usage errors do not exit 64"

SPOOF_HOME=$(new_home spoof-home)
set +e
HOME="$SPOOF_HOME" PATH="$MOCK_BIN:$PATH" KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    KDE_RICE_DOCTOR_COMMAND="$DOCTOR" KDE_RICE_VERIFY_COMMAND="$VERIFY" \
    KDE_RICE_STEP_RUNNER="$STEP_RUNNER" \
    "$BOOTSTRAP" --home "$SPOOF_HOME" > "$TEMP_ROOT/spoof-home.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "bootstrap trusted a spoofed HOME without the isolated test gate"
grep -Eq 'isolated test mode|current account home' "$TEMP_ROOT/spoof-home.txt" \
    || fail "spoofed HOME refusal reason is missing"
[[ ! -e $SPOOF_HOME/.local ]] || fail "spoofed HOME refusal wrote state"

XDG_HOME=$(new_home custom-xdg-home)
mkdir -p -- "$TEMP_ROOT/foreign-config"
set +e
HOME="$XDG_HOME" XDG_CONFIG_HOME="$TEMP_ROOT/foreign-config" PATH="$MOCK_BIN:$PATH" \
    KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    KDE_RICE_DOCTOR_COMMAND="$DOCTOR" KDE_RICE_VERIFY_COMMAND="$VERIFY" \
    KDE_RICE_STEP_RUNNER="$STEP_RUNNER" \
    "$BOOTSTRAP" --home "$XDG_HOME" > "$TEMP_ROOT/custom-xdg.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "bootstrap accepted an XDG config root outside the managed home"
grep -Fq 'XDG_CONFIG_HOME must be unset or equal' "$TEMP_ROOT/custom-xdg.txt" \
    || fail "custom XDG root refusal reason is missing"
[[ ! -e $XDG_HOME/.local ]] || fail "custom XDG root refusal wrote state"

XDG_SYMLINK_HOME=$(new_home symlink-xdg-home)
mv -- "$XDG_SYMLINK_HOME/.config" "$XDG_SYMLINK_HOME/actual-config"
ln -s -- actual-config "$XDG_SYMLINK_HOME/.config"
set +e
HOME="$XDG_SYMLINK_HOME" XDG_CONFIG_HOME="$XDG_SYMLINK_HOME/.config" PATH="$MOCK_BIN:$PATH" \
    KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    KDE_RICE_DOCTOR_COMMAND="$DOCTOR" KDE_RICE_VERIFY_COMMAND="$VERIFY" \
    KDE_RICE_STEP_RUNNER="$STEP_RUNNER" \
    "$BOOTSTRAP" --home "$XDG_SYMLINK_HOME" > "$TEMP_ROOT/symlink-xdg.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "bootstrap accepted a symlinked canonical XDG root"
grep -Fq 'XDG_CONFIG_HOME must not be a symlink' "$TEMP_ROOT/symlink-xdg.txt" \
    || fail "symlinked XDG root refusal reason is missing"

XDG_DEFAULT_SYMLINK_HOME=$(new_home symlink-default-xdg-home)
mv -- "$XDG_DEFAULT_SYMLINK_HOME/.config" "$XDG_DEFAULT_SYMLINK_HOME/actual-config"
ln -s -- actual-config "$XDG_DEFAULT_SYMLINK_HOME/.config"
set +e
HOME="$XDG_DEFAULT_SYMLINK_HOME" PATH="$MOCK_BIN:$PATH" \
    KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    KDE_RICE_DOCTOR_COMMAND="$DOCTOR" KDE_RICE_VERIFY_COMMAND="$VERIFY" \
    KDE_RICE_STEP_RUNNER="$STEP_RUNNER" \
    "$BOOTSTRAP" --home "$XDG_DEFAULT_SYMLINK_HOME" \
    > "$TEMP_ROOT/symlink-default-xdg.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "bootstrap accepted a symlinked default XDG config root"
grep -Fq 'XDG_CONFIG_HOME must not be a symlink' "$TEMP_ROOT/symlink-default-xdg.txt" \
    || fail "symlinked default XDG root refusal reason is missing"

DRY_HOME=$(new_home dry-home)
before=$(sha256sum "$DRY_HOME/.config"/*)
run_bootstrap "$DRY_HOME" > "$TEMP_ROOT/dry.txt"
after=$(sha256sum "$DRY_HOME/.config"/*)
[[ $after == "$before" ]] || fail "default bootstrap changed existing configuration"
[[ ! -e $DRY_HOME/.local ]] || fail "default bootstrap created state or assets"
[[ ! -e $CALL_LOG ]] || fail "default bootstrap ran an apply component"
grep -Fq 'Minimalist v0.4.1 bootstrap: DRY RUN' "$TEMP_ROOT/dry.txt" || fail "dry-run mode was not explicit"
grep -Fq 'panel class: fresh' "$TEMP_ROOT/dry.txt" || fail "fresh panel was not classified"
grep -Fq 'current panel geometry tuple: 0,bottom,horizontal,44,adaptive,fill,1920,1920,1920' \
    "$TEMP_ROOT/dry.txt" || fail "fresh dry run omitted the current panel geometry"
grep -Fq 'create one panel: screen=0 top horizontal height=32 fill opaque non-floating' \
    "$TEMP_ROOT/dry.txt" || fail "fresh dry run omitted the 32px target height"
grep -Fq 'remove widgets (id:type): 101:org.kde.plasma.kickoff' "$TEMP_ROOT/dry.txt" || fail "fresh removals were not shown exactly"
grep -Fq 'final widget order:' "$TEMP_ROOT/dry.txt" || fail "final v0.4.1 widget order was omitted"
grep -Fq 'pinned/running apps' "$TEMP_ROOT/dry.txt" || fail "v0.4.1 task-manager placement was omitted"
grep -Fq 'task-manager launchers: user-owned' "$TEMP_ROOT/dry.txt" \
    || fail "v0.4.1 plan did not preserve user-owned launchers"
grep -Fq 'fastfetch: install the medium-density privacy-safe config' "$TEMP_ROOT/dry.txt" \
    || fail "v0.4.1 plan omitted the managed Fastfetch config"
grep -Fq 'linux-workstation owns the installed prerequisite' "$TEMP_ROOT/dry.txt" \
    || fail "v0.4.1 plan omitted the Fastfetch package boundary"
grep -Fq 'wallpaper: do not install, select, migrate, or verify; preserve the current user-owned choice' \
    "$TEMP_ROOT/dry.txt" || fail "v0.4.1 plan omitted the wallpaper preservation boundary"
if grep -Eq 'private bundle|Minimalist''V02|apply-personal-''wallpaper' "$TEMP_ROOT/dry.txt"; then
    fail "public bootstrap plan retained a private wallpaper dependency"
fi
grep -Fq 'Dry run only;' "$TEMP_ROOT/dry.txt" || fail "dry-run no-write result was omitted"

set +e
run_bootstrap "$DRY_HOME" --variant primary > "$TEMP_ROOT/retired-variant.txt" 2>&1
status=$?
set -e
[[ $status == 64 ]] || fail "retired wallpaper variant option was still accepted"

UNSUPPORTED_HOME=$(new_home unsupported-home)
set +e
MOCK_DOCTOR_STATUS=2 run_bootstrap "$UNSUPPORTED_HOME" --apply > "$TEMP_ROOT/unsupported.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "unsupported doctor result was not refused"
[[ ! -e $UNSUPPORTED_HOME/.local ]] || fail "unsupported environment wrote state"

DEGRADED_HOME=$(new_home degraded-home)
set +e
MOCK_DOCTOR_STATUS=1 run_bootstrap "$DEGRADED_HOME" --apply > "$TEMP_ROOT/degraded.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "degraded live apply did not require explicit review"
[[ ! -e $DEGRADED_HOME/.local ]] || fail "unapproved degraded environment wrote state"

DEGRADED_APPROVED_HOME=$(new_home degraded-approved-home)
: > "$CALL_LOG"
MOCK_DOCTOR_STATUS=1 run_bootstrap "$DEGRADED_APPROVED_HOME" --apply --allow-degraded \
    > "$TEMP_ROOT/degraded-approved.txt"
grep -Fq 'compatibility: degraded' "$TEMP_ROOT/degraded-approved.txt" \
    || fail "approved degraded apply omitted its compatibility decision"
[[ -f $DEGRADED_APPROVED_HOME/.local/state/kde-rice/bootstrap/latest/complete ]] \
    || fail "explicitly approved degraded apply did not complete"

UNKNOWN_HOME=$(new_home unknown-home)
set +e
MOCK_PANEL_SIGNATURE=unknown run_bootstrap "$UNKNOWN_HOME" --apply > "$TEMP_ROOT/unknown.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "unknown topology was not refused"
[[ ! -e $UNKNOWN_HOME/.local ]] || fail "unknown topology wrote state"

V03_HOME=$(new_home v03-home)
MOCK_PANEL_SIGNATURE=minimalist-v03 run_bootstrap "$V03_HOME" > "$TEMP_ROOT/v03-active.txt"
grep -Fq 'base panel entry point: none; migrate the exact Minimalist v0.3 panel directly' \
    "$TEMP_ROOT/v03-active.txt" || fail "active v0.3 bootstrap did not select the direct migration"
grep -Fq 'resource-strip entry point: none' "$TEMP_ROOT/v03-active.txt" \
    || fail "active v0.3 plan did not skip its redundant v0.3 reapply"
grep -Fq 'final panel entry point: '"$REPO_ROOT"'/scripts/apply-minimalist-v04' \
    "$TEMP_ROOT/v03-active.txt" || fail "active v0.3 plan omitted the v0.4.1 migration entry point"
[[ ! -e $V03_HOME/.local ]] || fail "active v0.3 dry run wrote state"

V03_APPLY_HOME=$(new_home v03-apply-home)
: > "$CALL_LOG"
MOCK_PANEL_SIGNATURE=minimalist-v03 run_bootstrap "$V03_APPLY_HOME" --apply \
    > "$TEMP_ROOT/v03-apply.txt"
mapfile -t v03_calls < "$CALL_LOG"
expected_v03_calls=(apply-fastfetch apply-black apply-modern apply-minimalist-v04 verify)
[[ ${v03_calls[*]} == "${expected_v03_calls[*]}" ]] \
    || fail "active v0.3 bootstrap did not use the direct v0.4.1 migration: ${v03_calls[*]}"
[[ -f $V03_APPLY_HOME/.local/state/kde-rice/bootstrap/latest/complete ]] \
    || fail "active v0.3 migration bootstrap did not complete"

STAGED_HOME=$(new_home staged-home)
MOCK_PANEL_SIGNATURE=minimalist-v04-spacer-staged run_bootstrap "$STAGED_HOME" \
    > "$TEMP_ROOT/staged.txt"
grep -Fq 'recover the recognized v0.4.1 staged spacer state' "$TEMP_ROOT/staged.txt" \
    || fail "recognized staged v0.4.1 topology did not select recovery"
: > "$CALL_LOG"
MOCK_PANEL_SIGNATURE=minimalist-v04-spacer-staged run_bootstrap "$STAGED_HOME" --apply \
    > "$TEMP_ROOT/staged-apply.txt"
mapfile -t staged_calls < "$CALL_LOG"
[[ ${staged_calls[*]} == "${expected_v03_calls[*]}" ]] \
    || fail "staged v0.4.1 recovery used the wrong steps: ${staged_calls[*]}"

TASK_FRONT_HOME=$(new_home task-front-home)
MOCK_PANEL_SIGNATURE=minimalist-v04-task-front-staged run_bootstrap "$TASK_FRONT_HOME" \
    > "$TEMP_ROOT/task-front.txt"
grep -Fq 'recover the recognized v0.4.1 task-front state' "$TEMP_ROOT/task-front.txt" \
    || fail "recognized task-front v0.4.1 topology did not select recovery"
grep -Fq 'recovery removals: the misplaced v0.4.1 task manager and right spacer only' \
    "$TEMP_ROOT/task-front.txt" || fail "task-front bootstrap omitted exact cleanup removals"
grep -Fq 'rebuild only the two v0.4.1 additions after cleanup' \
    "$TEMP_ROOT/task-front.txt" || fail "task-front bootstrap omitted the two-phase rebuild"

V04_HOME=$(new_home v04-home)
MOCK_PANEL_SIGNATURE=minimalist-v04 run_bootstrap "$V04_HOME" > "$TEMP_ROOT/v04-active.txt"
grep -Fq 'the exact Minimalist v0.4.1 panel is already active' "$TEMP_ROOT/v04-active.txt" \
    || fail "exact v0.4.1 topology did not select the idempotent path"
grep -Fq 'panel height migration: 28 -> 32 logical px; preserve the panel and widget instances' \
    "$TEMP_ROOT/v04-active.txt" || fail "v0.4.1 dry run omitted the 28px-to-32px migration"
: > "$CALL_LOG"
MOCK_PANEL_SIGNATURE=minimalist-v04 run_bootstrap "$V04_HOME" --apply \
    > "$TEMP_ROOT/v04-apply.txt"
mapfile -t v04_calls < "$CALL_LOG"
[[ ${v04_calls[*]} == "${expected_v03_calls[*]}" ]] \
    || fail "exact v0.4.1 bootstrap was not idempotently routed: ${v04_calls[*]}"

PAGER_HOME=$(new_home pager-home)
MOCK_PANEL_SIGNATURE=minimalist-v04-pager run_bootstrap "$PAGER_HOME" \
    > "$TEMP_ROOT/pager-active.txt"
grep -Fq 'the exact Minimalist v0.4.1 Pager target is already active' \
    "$TEMP_ROOT/pager-active.txt" || fail "Pager target was not routed as a managed final topology"
grep -Fq 'final widget order: launcher | Pager | active title' \
    "$TEMP_ROOT/pager-active.txt" || fail "Pager bootstrap plan omitted the exact switcher order"

WORKSPACES_HOME=$(new_home workspaces-home)
MOCK_PANEL_SIGNATURE=minimalist-v04-workspaces run_bootstrap "$WORKSPACES_HOME" \
    > "$TEMP_ROOT/workspaces-active.txt"
grep -Fq 'the exact Minimalist v0.4.1 Workspaces target is already active' \
    "$TEMP_ROOT/workspaces-active.txt" \
    || fail "Workspaces target was not routed as a managed final topology"
grep -Fq 'final widget order: launcher | Workspaces | active title' \
    "$TEMP_ROOT/workspaces-active.txt" \
    || fail "Workspaces bootstrap plan omitted the exact switcher order"
: > "$CALL_LOG"
MOCK_PANEL_SIGNATURE=minimalist-v04-workspaces \
    run_bootstrap "$WORKSPACES_HOME" --apply > "$TEMP_ROOT/workspaces-apply.txt"
mapfile -t workspaces_calls < "$CALL_LOG"
[[ ${workspaces_calls[*]} == "${expected_v03_calls[*]}" ]] \
    || fail "Workspaces bootstrap was not idempotently routed: ${workspaces_calls[*]}"
workspaces_receipt=$(sed -n 's/^Transaction receipt: //p' \
    "$TEMP_ROOT/workspaces-apply.txt" | tail -n 1)
[[ $(< "$workspaces_receipt/panel-target") == minimalist-v04-workspaces ]] \
    || fail "Workspaces receipt lost its exact verification target"

MANAGED_HOME=$(new_home managed-home)
MOCK_PANEL_SIGNATURE=minimalist-v01 run_bootstrap "$MANAGED_HOME" > "$TEMP_ROOT/managed-dry.txt"
grep -Fq 'panel class: managed-transition' "$TEMP_ROOT/managed-dry.txt" \
    || fail "known v0.1 state was not routed to the managed transition"
grep -Fq 'base panel entry point: '"$REPO_ROOT"'/scripts/apply-minimalist-v02' "$TEMP_ROOT/managed-dry.txt" \
    || fail "known v0.1 state was routed through the fresh entry point"

V02_HOME=$(new_home v02-home)
: > "$CALL_LOG"
MOCK_PANEL_SIGNATURE=minimalist-v02 run_bootstrap "$V02_HOME" --apply \
    > "$TEMP_ROOT/v02-apply.txt"
mapfile -t v02_calls < "$CALL_LOG"
expected_v02_calls=(apply-fastfetch apply-black apply-modern apply-minimalist-v02 apply-minimalist-v03 apply-minimalist-v04 verify)
[[ ${v02_calls[*]} == "${expected_v02_calls[*]}" ]] \
    || fail "v0.2 bootstrap did not use the complete v0.3/v0.4.1 chain: ${v02_calls[*]}"

APPLY_HOME=$(new_home apply-home)
wallpaper_index_before=$(sha256sum "$APPLY_HOME/.config/plasmarc")
desktop_wallpaper_before=$(sha256sum "$APPLY_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc")
: > "$CALL_LOG"
run_bootstrap "$APPLY_HOME" --apply > "$TEMP_ROOT/apply.txt"
mapfile -t calls < "$CALL_LOG"
expected_calls=(apply-fastfetch apply-black apply-modern apply-fresh apply-minimalist-v03 apply-minimalist-v04 verify)
[[ ${calls[*]} == "${expected_calls[*]}" ]] || fail "bootstrap step order is wrong: ${calls[*]}"
snapshot_path=$(sed -n 's/^Baseline snapshot: //p' "$TEMP_ROOT/apply.txt" | tail -n 1)
receipt_path=$(sed -n 's/^Transaction receipt: //p' "$TEMP_ROOT/apply.txt" | tail -n 1)
[[ -f $snapshot_path/complete ]] || fail "bootstrap baseline snapshot is incomplete"
[[ -f $receipt_path/complete && -f $receipt_path/display-state.before.tsv \
    && -f $receipt_path/display-state.after.tsv \
    && $(< "$receipt_path/panel-target") == minimalist-v04 ]] || fail "bootstrap receipt is incomplete"
[[ ! -e $receipt_path/wallpaper-variant && ! -L $receipt_path/wallpaper-variant ]] \
    || fail "bootstrap receipt retained private wallpaper metadata"
cmp -s "$receipt_path/display-state.before.tsv" "$receipt_path/display-state.after.tsv" \
    || fail "bootstrap receipt did not prove display preservation"
[[ -L $APPLY_HOME/.local/state/kde-rice/bootstrap/latest ]] || fail "successful receipt was not selected as latest"
grep -Fq 'Restore apply:' "$TEMP_ROOT/apply.txt" || fail "bootstrap success omitted restore"
[[ $(< "$APPLY_HOME/.config/kdeglobals") == applied-black ]] || fail "mock managed change did not occur"
[[ $(sha256sum "$APPLY_HOME/.config/plasmarc") == "$wallpaper_index_before" ]] \
    || fail "bootstrap changed the user-owned wallpaper index"
[[ $(sha256sum "$APPLY_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == "$desktop_wallpaper_before" ]] \
    || fail "bootstrap changed the user-owned desktop wallpaper state"

bash "$REPO_ROOT/scripts/restore" --backup "$snapshot_path" --home "$APPLY_HOME" \
    --state-root "$APPLY_HOME/.local/state/kde-rice/bootstrap-test-restore" --apply \
    > "$TEMP_ROOT/restore.txt"
[[ $(< "$APPLY_HOME/.config/kdeglobals") == baseline-kdeglobals ]] \
    || fail "transaction baseline did not fully restore managed configuration"

FAIL_HOME=$(new_home fail-home)
: > "$CALL_LOG"
set +e
MOCK_FAIL_STEP=apply-modern run_bootstrap "$FAIL_HOME" --apply > "$TEMP_ROOT/failure.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "component failure was not propagated"
grep -Fq 'BOOTSTRAP FAILED: Breeze shell step failed' "$TEMP_ROOT/failure.txt" \
    || fail "failed step was hidden"
grep -Fq 'Restore apply:' "$TEMP_ROOT/failure.txt" || fail "failure omitted recovery command"
failed_snapshot=$(sed -n 's/^Baseline snapshot: //p' "$TEMP_ROOT/failure.txt" | tail -n 1)
[[ -f $failed_snapshot/complete ]] || fail "failed transaction lost its baseline snapshot"

OPACITY_FAIL_HOME=$(new_home opacity-fail-home)
: > "$CALL_LOG"
set +e
MOCK_DOCTOR_STATUS=1 MOCK_FAIL_STEP=apply-fresh \
    run_bootstrap "$OPACITY_FAIL_HOME" --apply --allow-degraded \
    > "$TEMP_ROOT/opacity-failure.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "degraded fresh-panel failure was not propagated"
opacity_receipt=$(sed -n 's/^Transaction receipt: //p' \
    "$TEMP_ROOT/opacity-failure.txt" | tail -n 1)
[[ -n $opacity_receipt && -f $opacity_receipt/failed \
    && $(< "$opacity_receipt/failed") == $'panel\t23' ]] \
    || fail "degraded fresh-panel failure omitted its exact failed receipt"
grep -Fq "Resume preview: $BOOTSTRAP" "$TEMP_ROOT/opacity-failure.txt" \
    && fail "resume guidance incorrectly pointed back to bootstrap"
grep -Fq "$REPO_ROOT/scripts/resume-bootstrap --receipt $opacity_receipt --home $OPACITY_FAIL_HOME" \
    "$TEMP_ROOT/opacity-failure.txt" \
    || fail "degraded fresh-panel failure omitted its exact resume preview"
grep -Fq 'do not start a new live bootstrap transaction' \
    "$TEMP_ROOT/opacity-failure.txt" \
    || fail "degraded fresh-panel failure did not prevent a duplicate transaction"
grep -Fq 'do not reorder widgets' "$TEMP_ROOT/opacity-failure.txt" \
    || fail "manual Opaque guidance did not preserve the known topology"

VERIFY_FAIL_HOME=$(new_home verify-fail-home)
: > "$CALL_LOG"
export MOCK_VERIFY_FAIL=1
set +e
run_bootstrap "$VERIFY_FAIL_HOME" --apply > "$TEMP_ROOT/verify-failure.txt" 2>&1
status=$?
set -e
unset MOCK_VERIFY_FAIL
[[ $status == 1 ]] || fail "post-apply verification failure was not propagated"
grep -Fq 'BOOTSTRAP FAILED: post-apply verification failed' "$TEMP_ROOT/verify-failure.txt" \
    || fail "post-apply verification failure reason was hidden"
grep -Fq 'Restore apply:' "$TEMP_ROOT/verify-failure.txt" \
    || fail "post-apply verification failure omitted recovery"
verify_failed_snapshot=$(sed -n 's/^Baseline snapshot: //p' "$TEMP_ROOT/verify-failure.txt" | tail -n 1)
[[ -f $verify_failed_snapshot/complete ]] \
    || fail "post-apply verification failure lost its baseline snapshot"
[[ ! -e $VERIFY_FAIL_HOME/.local/state/kde-rice/bootstrap/latest ]] \
    || fail "failed verification was selected as the latest successful receipt"

DISPLAY_HOME=$(new_home display-home)
printf 'baseline-display\n' > "$DISPLAY_HOME/.config/kwinoutputconfig.json"
: > "$CALL_LOG"
set +e
MOCK_CHANGE_DISPLAY=1 run_bootstrap "$DISPLAY_HOME" --apply > "$TEMP_ROOT/display-failure.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "display change was not detected"
grep -Fq 'excluded display configuration changed during apply' "$TEMP_ROOT/display-failure.txt" \
    || fail "display mismatch reason was not reported"

if rg -n '(sudo|pkexec|killall[[:space:]]+(plasmashell|kwin)|pkill[[:space:]].*(plasmashell|kwin)|systemctl[[:space:]].*(plasmashell|kwin)|pacman[[:space:]]+-[SR]|dnf[[:space:]]+(install|remove|upgrade)|apt(-get)?[[:space:]]+(install|remove|upgrade))' \
    "$REPO_ROOT/scripts" > "$TEMP_ROOT/forbidden-runtime.txt"; then
    fail "runtime scripts contain a privileged/package/restart operation: $(< "$TEMP_ROOT/forbidden-runtime.txt")"
fi

printf 'PASS: integrated bootstrap dry-run, apply, failure, and recovery tests\n'
