#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$TEST_DIR/lib/runtime.sh"
require_test_node
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-doctor.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-doctor.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing to clean unexpected test directory: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

MOCK_BIN="$TEMP_ROOT/bin"
TARGET_HOME="$TEMP_ROOT/home"
mkdir -p -- "$MOCK_BIN" "$TARGET_HOME/.config" "$TARGET_HOME/.local/share" "$TARGET_HOME/.local/state"
printf 'home sentinel\n' > "$TARGET_HOME/.config/doctor-sentinel"

cat > "$MOCK_BIN/mock-command" <<'MOCK'
#!/bin/bash
set -u
name=${0##*/}
case "$name" in
    qdbus6 | qdbus-qt6 | qdbus)
        [[ ${MOCK_QDBUS_FAIL:-0} != 1 ]] || exit 1
        printf '%s\n' "${MOCK_QDBUS_RESULT:-}"
        ;;
    fc-list)
        printf '%s\n' "${MOCK_FONTS:-}"
        ;;
    plasma-apply-desktoptheme)
        [[ ${1:-} == --list-themes ]] && printf '%s\n' 'Breeze (theme name: default)'
        ;;
    kwin-applywindowdecoration)
        [[ ${1:-} == --list-themes ]] && printf '%s\n' 'Breeze (theme name: Breeze)'
        ;;
    fastfetch)
        [[ ${1:-} == --version ]] || exit 70
        printf 'fastfetch 2.66.0\n'
        ;;
    pacman)
        [[ $# == 2 && $1 == -Q ]] || exit 70
        package=$2
        case "$package" in
            plasma-workspace | kwin) ;;
            *) exit 1 ;;
        esac
        printf '%s\t%s\n' "$name" "$package" >> "${MOCK_PACKAGE_CALL_LOG:?}"
        printf '%s 6.7.4-1\n' "$package"
        ;;
    rpm)
        [[ $# == 4 && $1 == -q && $2 == --qf ]] || exit 70
        package=$4
        case "$package" in
            plasma-workspace | kwin) ;;
            *) exit 1 ;;
        esac
        printf '%s\t%s\n' "$name" "$package" >> "${MOCK_PACKAGE_CALL_LOG:?}"
        printf '6.7.5\n'
        ;;
    dpkg-query)
        [[ $# == 3 && $1 == -W && $2 == -f=* ]] || exit 70
        package=$3
        case "$package" in
            plasma-workspace | kwin) ;;
            *) exit 1 ;;
        esac
        printf '%s\t%s\n' "$name" "$package" >> "${MOCK_PACKAGE_CALL_LOG:?}"
        printf '4:6.7.6-1~deb13u1\n'
        ;;
    *)
        exit 0
        ;;
esac
MOCK
chmod +x "$MOCK_BIN/mock-command"
ln -s /usr/bin/dirname "$MOCK_BIN/dirname"
ln -s /usr/bin/realpath "$MOCK_BIN/realpath"
ln -s /usr/bin/sed "$MOCK_BIN/sed"

commands=(
    qdbus6
    kwriteconfig6
    kreadconfig6
    plasma-apply-colorscheme
    plasma-apply-desktoptheme
    kwin-applywindowdecoration
    konsole
    fastfetch
    fc-list
)
for command_name in "${commands[@]}"; do
    ln -s mock-command "$MOCK_BIN/$command_name"
done

target_widgets='org.kde.plasma.kickoff;org.kde.minimalist.activewindowtitle;org.kde.plasma.panelspacer;org.kde.plasma.marginsseparator;org.kde.plasma.kimpanel;org.kde.plasma.systemtray;org.kde.plasma.digitalclock'
v04_widgets='org.kde.plasma.kickoff;org.kde.minimalist.activewindowtitle;org.kde.plasma.panelspacer;org.kde.plasma.icontasks;org.kde.plasma.panelspacer;org.kde.minimalist.resources;org.kde.plasma.marginsseparator;org.kde.plasma.kimpanel;org.kde.plasma.systemtray;org.kde.plasma.digitalclock'
supported_panel=$(printf '%s\n%s' \
    'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"panel_count":1,"signature":"minimalist-v04"}' \
    "KDE_RICE_PANEL_STATE schema=1 panelCount=1 desktopCount=1 signature=minimalist-v04 transition=v04-target supported=true targetComplete=true orderValid=true geometryOk=true spacerOk=true activeTitleOk=true resourceOk=true taskManagerOk=true trayOk=true clockOk=true noDuplicateTargetWidgets=true knownTargetWidgets=true knownBuiltInWidgets=true missingBuiltInWidgets=none iconTasksKnown=true activeTitleKnown=true spacerCount=2 spacerExpanding=true,true activeTitleRevision=1 resourceRevision=2 taskManagerFill=false taskManagerMaxStripes=1 taskManagerIconSpacing=0 widgetTypes=$v04_widgets geometry=0,top,horizontal,32,opaque,fill,1920,1920,1920 removePanelIds=none removeWidgetIds=none removeWidgetEntries=none createPanel=false targetWidgets=$target_widgets")
concatenated_panel=${supported_panel//$'\n'/}

run_doctor() {
    local output=$1
    shift
    set +e
    /usr/bin/env -i \
        PATH="$MOCK_BIN" \
        HOME="$TARGET_HOME" \
        XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        XDG_DATA_HOME="$TARGET_HOME/.local/share" \
        XDG_STATE_HOME="$TARGET_HOME/.local/state" \
        KDE_RICE_TEST_MODE=1 \
        KDE_RICE_DBUS_TOOL="${TEST_DBUS_TOOL:-$MOCK_BIN/qdbus6}" \
        XDG_SESSION_TYPE="${TEST_SESSION_TYPE:-wayland}" \
        KDE_RICE_DISTRIBUTION_ID="${TEST_DISTRIBUTION_ID:-arch}" \
        KDE_RICE_DISTRIBUTION_LIKE="${TEST_DISTRIBUTION_LIKE:-arch}" \
        KDE_RICE_FASTFETCH_VERSION="${TEST_FASTFETCH_VERSION:-}" \
        KDE_RICE_PLASMA_VERSION="${TEST_PLASMA_VERSION:-6.7.4}" \
        KDE_RICE_KWIN_VERSION="${TEST_KWIN_VERSION:-6.7.4}" \
        KDE_RICE_RESOURCE_SENSORS_AVAILABLE="${TEST_RESOURCE_SENSORS_AVAILABLE:-true}" \
        KDE_RICE_VOLUME_QML_AVAILABLE="${TEST_VOLUME_QML_AVAILABLE:-true}" \
        KDE_RICE_BREEZE_PLASMA_STYLE_AVAILABLE="${TEST_BREEZE_STYLE_AVAILABLE:-}" \
        KDE_RICE_BREEZE_DECORATION_AVAILABLE="${TEST_BREEZE_DECORATION_AVAILABLE:-}" \
        KDE_RICE_KWIN_DECORATION_TOOL="${TEST_DECORATION_TOOL:-kwin-applywindowdecoration}" \
        KDE_RICE_KWIN_DECORATION_CANDIDATES="${TEST_DECORATION_CANDIDATES:-}" \
        MOCK_FONTS="${TEST_FONTS:-Hack Noto Sans}" \
        MOCK_QDBUS_FAIL="${TEST_QDBUS_FAIL:-0}" \
        MOCK_QDBUS_RESULT="${TEST_QDBUS_RESULT:-$supported_panel}" \
        /bin/bash "$REPO_ROOT/scripts/doctor" "$@" > "$output" 2>&1
    DOCTOR_STATUS=$?
    set -e
}

TEST_QDBUS_RESULT="$concatenated_panel" run_doctor "$TEMP_ROOT/concatenated-panel.json" --json
[[ $DOCTOR_STATUS == 0 ]] || fail "concatenated live probe output was not accepted"

TEST_RESOURCE_SENSORS_AVAILABLE=false run_doctor "$TEMP_ROOT/v02-without-resource-sensors.json" \
    --target minimalist-v02 --json
[[ $DOCTOR_STATUS == 0 ]] || fail "resource sensors blocked the explicit v0.2 migration diagnosis"
"$NODE_BIN" - "$TEMP_ROOT/v02-without-resource-sensors.json" <<'NODE'
const fs = require("fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (report.checks.resource_sensors || report.checks.gpu_sensor) process.exit(1);
NODE

TEST_RESOURCE_SENSORS_AVAILABLE=false run_doctor "$TEMP_ROOT/missing-resource-sensors.json" \
    --target minimalist-v03 --json
[[ $DOCTOR_STATUS == 2 ]] || fail "v0.3 missing native resource sensors were not classified as unsupported"
"$NODE_BIN" - "$TEMP_ROOT/missing-resource-sensors.json" <<'NODE'
const fs = require("fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const check = report.checks.resource_sensors;
if (!check || check.status !== "unsupported" || check.required !== true) process.exit(1);
NODE

run_package_version_fallback() {
    local manager=$1
    local distribution=$2
    local expected_version=$3
    local output="$TEMP_ROOT/package-$manager.json"
    local call_log="$TEMP_ROOT/package-$manager.calls"
    local status

    [[ ! -e $MOCK_BIN/$manager && ! -L $MOCK_BIN/$manager ]] \
        || fail "package-manager mock path already exists: $manager"
    ln -s mock-command "$MOCK_BIN/$manager"
    : > "$call_log"

    set +e
    /usr/bin/env -i \
        PATH="$MOCK_BIN" \
        HOME="$TARGET_HOME" \
        XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        XDG_DATA_HOME="$TARGET_HOME/.local/share" \
        XDG_STATE_HOME="$TARGET_HOME/.local/state" \
        KDE_RICE_TEST_MODE=1 \
        KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
        XDG_SESSION_TYPE=wayland \
        KDE_RICE_DISTRIBUTION_ID="$distribution" \
        KDE_RICE_DISTRIBUTION_LIKE="$distribution" \
        KDE_RICE_KWIN_DECORATION_TOOL=kwin-applywindowdecoration \
        KDE_RICE_RESOURCE_SENSORS_AVAILABLE=true \
        KDE_RICE_VOLUME_QML_AVAILABLE=true \
        MOCK_FONTS='Hack Noto Sans' \
        MOCK_QDBUS_RESULT="$supported_panel" \
        MOCK_PACKAGE_CALL_LOG="$call_log" \
        /bin/bash "$REPO_ROOT/scripts/doctor" --json > "$output" 2>&1
    status=$?
    set -e
    rm -- "$MOCK_BIN/$manager"

    [[ $status == 0 ]] || {
        /bin/cat "$output" >&2
        fail "$manager version-discovery fallback exited $status"
    }
    grep -Fxq "$manager"$'\t''plasma-workspace' "$call_log" \
        || fail "$manager fallback did not query plasma-workspace read-only"
    grep -Fxq "$manager"$'\t''kwin' "$call_log" \
        || fail "$manager fallback did not query kwin read-only"
    "$NODE_BIN" - "$output" "$expected_version" <<'NODE'
const fs = require("fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const expected = process.argv[3];
for (const id of ["plasma_version", "kwin_version"]) {
    const check = report.checks[id];
    if (!check || check.status !== "supported" || !check.detail.includes(expected)) {
        process.exit(1);
    }
}
if (report.status !== "supported" || report.exit_code !== 0) process.exit(2);
NODE
}

run_doctor "$TEMP_ROOT/supported-human.txt"
if [[ $DOCTOR_STATUS != 0 ]]; then
    /bin/cat "$TEMP_ROOT/supported-human.txt" >&2
    fail "supported human doctor exited $DOCTOR_STATUS"
fi
grep -Fxq 'Status: supported' "$TEMP_ROOT/supported-human.txt" || fail "stable supported status line is missing"
grep -Fq '[OK  ] panels' "$TEMP_ROOT/supported-human.txt" || fail "panel topology was not reported"
grep -Fq 'topology=minimalist-v04' "$TEMP_ROOT/supported-human.txt" || fail "exact panel topology was not reported"

pager_panel=${supported_panel//signature=minimalist-v04/signature=minimalist-v04-pager}
pager_panel=${pager_panel/transition=v04-target/transition=v04-pager-target}
TEST_QDBUS_RESULT="$pager_panel" run_doctor "$TEMP_ROOT/supported-pager.json" --json
[[ $DOCTOR_STATUS == 0 ]] || fail "recognized Pager-preview topology was not supported"
grep -Fq 'topology=minimalist-v04-pager' "$TEMP_ROOT/supported-pager.json" \
    || fail "doctor omitted the recognized Pager-preview topology"

workspaces_panel=${supported_panel//signature=minimalist-v04/signature=minimalist-v04-workspaces}
workspaces_panel=${workspaces_panel/transition=v04-target/transition=v04-workspaces-target}
TEST_QDBUS_RESULT="$workspaces_panel" run_doctor "$TEMP_ROOT/supported-workspaces.json" --json
[[ $DOCTOR_STATUS == 0 ]] || fail "recognized Workspaces-preview topology was not supported"
grep -Fq 'topology=minimalist-v04-workspaces' "$TEMP_ROOT/supported-workspaces.json" \
    || fail "doctor omitted the recognized Workspaces-preview topology"

run_doctor "$TEMP_ROOT/supported.json" --json
[[ $DOCTOR_STATUS == 0 ]] || fail "supported JSON doctor exited $DOCTOR_STATUS"
"$NODE_BIN" - "$TEMP_ROOT/supported.json" <<'NODE'
const fs = require("fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (report.schema_version !== 1 || report.status !== "supported" || report.exit_code !== 0) process.exit(1);
if (!report.summary || !["supported", "degraded", "unsupported"].every((key) => Number.isInteger(report.summary[key]))) process.exit(4);
const required = [
  "user_paths", "distribution", "plasma_version", "kwin_version", "wayland_session", "dbus_tool",
  "kwriteconfig6", "kreadconfig6", "plasma_apply_colorscheme",
  "plasma_apply_desktoptheme",
  "kwin_decoration_tool", "breeze_plasma_style", "breeze_window_decoration",
  "konsole", "fastfetch", "fastfetch_source", "fonts", "resource_sensors", "gpu_sensor", "volume_backend", "plasmashell", "widgets", "panels",
  "panel_opacity_transition", "monitors"
];
for (const key of required) {
  const value = report.checks[key];
  if (!value || typeof value.status !== "string" || typeof value.required !== "boolean" || typeof value.detail !== "string") process.exit(2);
}
if (report.checks.panels.detail.indexOf("topology=minimalist-v04") === -1) process.exit(3);
if (report.checks.resource_sensors.required !== true || report.checks.gpu_sensor.required !== false
    || report.checks.volume_backend.required !== true) process.exit(5);
if (report.checks.panel_opacity_transition.status !== "supported") process.exit(6);
if (report.checks.plasma_apply_wallpaperimage) process.exit(7);
NODE

run_doctor "$TEMP_ROOT/supported-v02.json" --target minimalist-v02 --json
[[ $DOCTOR_STATUS == 0 ]] || fail "supported v0.2 migration JSON doctor exited $DOCTOR_STATUS"
"$NODE_BIN" - "$TEMP_ROOT/supported-v02.json" <<'NODE'
const fs = require("fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (report.checks.resource_sensors || report.checks.gpu_sensor || report.checks.volume_backend
    || report.checks.fastfetch || report.checks.fastfetch_source) process.exit(1);
NODE
[[ $(< "$TARGET_HOME/.config/doctor-sentinel") == 'home sentinel' ]] || fail "doctor changed the test home"
[[ ! -e $TARGET_HOME/.local/state/kde-rice ]] || fail "doctor created state in the test home"

# Exercise each supported distribution family's official read-only package
# query shape without the KDE_RICE_*_VERSION test overrides.  The mocks reject
# every operation other than the exact installed-package query used by doctor.
run_package_version_fallback pacman arch 6.7.4
run_package_version_fallback rpm fedora 6.7.5
run_package_version_fallback dpkg-query debian 6.7.6
[[ $(< "$TARGET_HOME/.config/doctor-sentinel") == 'home sentinel' ]] \
    || fail "package version discovery changed the test home"
[[ ! -e $TARGET_HOME/.local/state/kde-rice ]] \
    || fail "package version discovery created test-home state"

TEST_PLASMA_VERSION=6.8.1 TEST_KWIN_VERSION=6.8.1 run_doctor "$TEMP_ROOT/degraded.json" --json
[[ $DOCTOR_STATUS == 1 ]] || fail "unconfirmed Plasma 6 did not exit degraded"
grep -Fq '"status": "degraded"' "$TEMP_ROOT/degraded.json" || fail "degraded JSON status is missing"

stock_panel=${supported_panel//signature=minimalist-v04/signature=plasma6-stock}
stock_panel=${stock_panel/transition=v04-target/transition=replace-fresh-panel}
stock_panel=${stock_panel/geometry=0,top,horizontal,32,opaque/geometry=0,bottom,horizontal,44,adaptive}
TEST_QDBUS_RESULT="$stock_panel" run_doctor "$TEMP_ROOT/fresh-opacity-degraded.json" --json
[[ $DOCTOR_STATUS == 1 ]] || fail "Plasma 6.7 fresh opacity transition was not degraded"
"$NODE_BIN" - "$TEMP_ROOT/fresh-opacity-degraded.json" <<'NODE'
const fs = require("fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const check = report.checks.panel_opacity_transition;
if (!check || check.status !== "degraded" || !check.detail.includes("manual Opaque")) process.exit(1);
NODE

adaptive_managed=${supported_panel/geometry=0,top,horizontal,32,opaque/geometry=0,top,horizontal,32,adaptive}
TEST_QDBUS_RESULT="$adaptive_managed" run_doctor "$TEMP_ROOT/managed-opacity-degraded.json" --json
[[ $DOCTOR_STATUS == 1 ]] || fail "Plasma 6.7 managed adaptive panel was not degraded"
"$NODE_BIN" - "$TEMP_ROOT/managed-opacity-degraded.json" <<'NODE'
const fs = require("fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const check = report.checks.panel_opacity_transition;
if (!check || check.status !== "degraded" || !check.detail.includes("managed panel is not Opaque")) process.exit(1);
NODE

multi_panel=${supported_panel/desktopCount=1/desktopCount=2}
TEST_QDBUS_RESULT="$multi_panel" run_doctor "$TEMP_ROOT/multi-monitor.json" --json
[[ $DOCTOR_STATUS == 1 ]] || fail "multi-monitor state did not exit degraded"
grep -Fq 'multi-monitor layout is not live-validated' "$TEMP_ROOT/multi-monitor.json" || fail "multi-monitor degraded reason is missing"

TEST_DISTRIBUTION_ID=unmapped TEST_DISTRIBUTION_LIKE=none run_doctor "$TEMP_ROOT/unmapped-distribution.json" --json
[[ $DOCTOR_STATUS == 1 ]] || fail "unmapped distribution did not exit degraded"
grep -Fq 'no maintained package mapping' "$TEMP_ROOT/unmapped-distribution.json" || fail "unmapped distribution reason is missing"

TEST_PLASMA_VERSION=5.27.11 run_doctor "$TEMP_ROOT/plasma5.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "Plasma 5 did not exit unsupported"
grep -Fq 'Plasma 6 is required' "$TEMP_ROOT/plasma5.json" || fail "Plasma 5 reason is missing"

TEST_SESSION_TYPE=x11 run_doctor "$TEMP_ROOT/x11.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "X11 session did not exit unsupported"
grep -Fq 'KWin Wayland session is required' "$TEMP_ROOT/x11.json" || fail "Wayland requirement reason is missing"

TEST_QDBUS_FAIL=1 run_doctor "$TEMP_ROOT/dead-shell.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "dead plasmashell did not exit unsupported"
grep -Fq 'scripting API is not accessible' "$TEMP_ROOT/dead-shell.json" || fail "dead plasmashell reason is missing"

unknown_panel=$(printf '%s\n%s' \
    'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"panel_count":2,"signature":"unknown"}' \
    'KDE_RICE_PANEL_STATE schema=1 panelCount=2 desktopCount=2 signature=unknown transition=refuse supported=false targetComplete=false orderValid=false geometryOk=false spacerOk=false activeTitleOk=false resourceOk=false taskManagerOk=false trayOk=false clockOk=false noDuplicateTargetWidgets=false knownTargetWidgets=true knownBuiltInWidgets=true missingBuiltInWidgets=none iconTasksKnown=true activeTitleKnown=true spacerCount=none spacerExpanding=none activeTitleRevision=none widgetTypes=none geometry=none removePanelIds=none removeWidgetIds=none removeWidgetEntries=none createPanel=false targetWidgets=none')
TEST_QDBUS_RESULT="$unknown_panel" run_doctor "$TEMP_ROOT/unknown-panel.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "unknown panel topology did not exit unsupported"
grep -Fq 'topology=unknown' "$TEMP_ROOT/unknown-panel.json" || fail "unknown topology reason is missing"

rm -- "$MOCK_BIN/fastfetch"
run_doctor "$TEMP_ROOT/missing-fastfetch.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "missing Fastfetch did not exit unsupported for v0.4.1"
grep -Fq 'linux-workstation host prerequisite outside kde-rice package ownership' \
    "$TEMP_ROOT/missing-fastfetch.json" \
    || fail "missing Fastfetch did not report the linux-workstation ownership boundary"
ln -s mock-command "$MOCK_BIN/fastfetch"

TEST_FASTFETCH_VERSION=2.39.0 run_doctor "$TEMP_ROOT/old-fastfetch.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "old Fastfetch did not exit unsupported"
grep -Fq 'older than the supported 2.40' "$TEMP_ROOT/old-fastfetch.json" \
    || fail "old Fastfetch reason is missing"

TEST_VOLUME_QML_AVAILABLE=false run_doctor "$TEMP_ROOT/missing-volume-backend.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "missing event-driven volume backend did not exit unsupported"
grep -Fq 'event-driven volume QML backend is unavailable' \
    "$TEMP_ROOT/missing-volume-backend.json" \
    || fail "missing volume backend reason is absent"

TEST_BREEZE_STYLE_AVAILABLE=false run_doctor "$TEMP_ROOT/missing-breeze-style.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "missing Breeze Plasma Style did not exit unsupported"
grep -Fq 'Breeze Plasma Style' "$TEMP_ROOT/missing-breeze-style.json" || fail "missing Breeze style reason is absent"

missing_tray=${supported_panel/knownBuiltInWidgets=true missingBuiltInWidgets=none/knownBuiltInWidgets=false missingBuiltInWidgets=org.kde.plasma.networkmanagement}
TEST_QDBUS_RESULT="$missing_tray" run_doctor "$TEMP_ROOT/missing-tray-widget.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "missing built-in/tray widget did not exit unsupported"
grep -Fq 'missing required built-in widgets: org.kde.plasma.networkmanagement' "$TEMP_ROOT/missing-tray-widget.json" || fail "missing tray widget reason is absent"

missing_icon_tasks=${supported_panel/iconTasksKnown=true/iconTasksKnown=false}
TEST_QDBUS_RESULT="$missing_icon_tasks" run_doctor "$TEMP_ROOT/missing-icon-tasks.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "missing Icons-only Task Manager did not exit unsupported for v0.4.1"
grep -Fq 'org.kde.plasma.icontasks' "$TEMP_ROOT/missing-icon-tasks.json" \
    || fail "missing Icons-only Task Manager reason is absent"
TEST_QDBUS_RESULT="$missing_icon_tasks" run_doctor "$TEMP_ROOT/v03-without-icon-tasks.json" \
    --target minimalist-v03 --json
[[ $DOCTOR_STATUS == 0 ]] || fail "v0.4.1-only Icons-only Task Manager requirement blocked v0.3 diagnosis"

rm -- "$MOCK_BIN/qdbus6"
ln -s mock-command "$MOCK_BIN/qdbus"
TEST_DBUS_TOOL="$MOCK_BIN/qdbus" run_doctor "$TEMP_ROOT/compatible-qdbus.json" --json
[[ $DOCTOR_STATUS == 0 ]] || fail "compatible qdbus fallback was not accepted"
grep -Fq 'compatible D-Bus tool: qdbus' "$TEMP_ROOT/compatible-qdbus.json" || fail "compatible qdbus fallback was not reported"
ln -s mock-command "$MOCK_BIN/qdbus6"

rm -- "$MOCK_BIN/kwin-applywindowdecoration"
TEST_DECORATION_TOOL="$TEMP_ROOT/missing-decoration-tool" TEST_DECORATION_CANDIDATES="$TEMP_ROOT/no-official-candidate" run_doctor "$TEMP_ROOT/missing-decoration.json" --json
[[ $DOCTOR_STATUS == 2 ]] || fail "missing KWin decoration apply tool did not exit unsupported"
grep -Fq 'kwin-applywindowdecoration was not found' "$TEMP_ROOT/missing-decoration.json" || fail "missing decoration reason is absent"
ln -s mock-command "$MOCK_BIN/kwin-applywindowdecoration"

run_doctor "$TEMP_ROOT/usage.txt" --unknown
[[ $DOCTOR_STATUS == 64 ]] || fail "unknown option did not use exit code 64"

run_doctor "$TEMP_ROOT/missing-target-value.txt" --target
[[ $DOCTOR_STATUS == 64 ]] || fail "missing doctor target did not use exit code 64"

run_doctor "$TEMP_ROOT/unknown-target.txt" --target unknown
[[ $DOCTOR_STATUS == 64 ]] || fail "unknown doctor target did not use exit code 64"

TEST_DISTRIBUTION_ID=$'unmapped\001' TEST_DISTRIBUTION_LIKE=none run_doctor "$TEMP_ROOT/control-character.json" --json
[[ $DOCTOR_STATUS == 1 ]] || fail "control-character distribution fixture did not exit degraded"
"$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' \
    "$TEMP_ROOT/control-character.json" || fail "doctor emitted invalid JSON for a control character"

XDG_PROBE_HOME="$TEMP_ROOT/xdg-probe-home"
mkdir -p -- "$XDG_PROBE_HOME/actual-config" "$XDG_PROBE_HOME/.local/share" "$XDG_PROBE_HOME/.local/state"
ln -s -- actual-config "$XDG_PROBE_HOME/.config"
set +e
/usr/bin/env -i PATH="$MOCK_BIN" HOME="$XDG_PROBE_HOME" XDG_SESSION_TYPE=wayland \
    MOCK_FONTS='Hack Noto Sans' MOCK_QDBUS_RESULT="$supported_panel" \
    /bin/bash "$REPO_ROOT/scripts/doctor" --json > "$TEMP_ROOT/xdg-paths.json" 2>&1
xdg_status=$?
set -e
[[ $xdg_status == 2 ]] || fail "doctor did not classify a symlinked default XDG root as unsupported"
"$NODE_BIN" - "$TEMP_ROOT/xdg-paths.json" <<'NODE'
const fs = require("fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const check = report.checks.user_paths;
if (!check || check.status !== "unsupported" || !check.detail.includes("XDG_CONFIG_HOME")) process.exit(1);
NODE

set +e
/usr/bin/env -i PATH="$MOCK_BIN" HOME="$TARGET_HOME" \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus" KDE_RICE_PLASMA_VERSION=6.7.4 \
    /bin/bash "$REPO_ROOT/scripts/doctor" --json > "$TEMP_ROOT/untrusted-override.txt" 2>&1
override_status=$?
set -e
[[ $override_status == 64 ]] || fail "doctor accepted a capability override outside isolated test mode"

printf 'PASS: doctor capability and isolation tests\n'
