#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$SCRIPT_DIR/lib/runtime.sh"
require_test_node

TEMP_ROOT=$(mktemp -d /tmp/kde-rice-clock-policy.XXXXXX)
cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-clock-policy.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing unsafe cleanup: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v04"
PREFLIGHT_SCRIPT="$LAYOUT/contents/clock-preflight.js"
POLICY_SCRIPT="$LAYOUT/contents/clock-policy.js"
POSTCHECK_SCRIPT="$LAYOUT/contents/clock-postcheck.js"
APPLY_SCRIPT="$REPO_ROOT/scripts/apply-clock-policy"
TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
MOCK_STATE="$TEMP_ROOT/plasma-state"
MOCK_PREFLIGHT_COUNT="$TEMP_ROOT/preflight-count"
MOCK_WORKSPACE_REVISION="$TEMP_ROOT/workspace-revision"

[[ -x $APPLY_SCRIPT ]] || fail "clock-policy entry point is not executable"
bash -n "$APPLY_SCRIPT"
for script in "$PREFLIGHT_SCRIPT" "$POLICY_SCRIPT" "$POSTCHECK_SCRIPT"; do
    "$NODE_BIN" --check "$script" >/dev/null
done

for expected_write in \
    'clock.writeConfig("showDate", false);' \
    'clock.writeConfig("showSeconds", 2);' \
    'clock.writeConfig("use24hFormat", 2);' \
    'clock.writeConfig("autoFontAndSize", false);' \
    'clock.writeConfig("fontFamily", "Noto Sans");' \
    'clock.writeConfig("fontSize", 11);' \
    'clock.writeConfig("fontStyleName", "Regular");' \
    'clock.writeConfig("fontWeight", 400);'; do
    grep -Fq "$expected_write" "$POLICY_SCRIPT" \
        || fail "clock writer is missing: $expected_write"
done
grep -Fq '"Always"' "$POSTCHECK_SCRIPT" \
    || fail "clock postcheck omits canonical showSeconds enum compatibility"
for unmanaged_date_key in dateDisplayFormat dateFormat customDateFormat; do
    if grep -Fq "writeConfig(\"$unmanaged_date_key\"" "$POLICY_SCRIPT"; then
        fail "clock writer changed hidden date preference: $unmanaged_date_key"
    fi
done
grep -Fq '__KDE_RICE_MISSING__' "$POSTCHECK_SCRIPT" \
    || fail "clock postcheck does not use a string missing-value sentinel"
if rg -n 'addWidget|removePanel|\.remove\(|new Panel|panel\.(height|location|screen|lengthMode|hiding|floating|opacity)[[:space:]]*=[^=]' \
    "$POLICY_SCRIPT" "$POSTCHECK_SCRIPT" >/dev/null; then
    fail "clock-only scripts contain a panel/widget topology or geometry mutation"
fi

"$NODE_BIN" - "$POLICY_SCRIPT" "$POSTCHECK_SCRIPT" <<'NODE'
const fs = require("fs");
const vm = require("vm");

const policySource = fs.readFileSync(process.argv[2], "utf8");
const postcheckSource = fs.readFileSync(process.argv[3], "utf8");
const types = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];

function assert(condition, message) {
    if (!condition) throw new Error(message);
}

function makePanel(overrides = {}) {
    const widgets = types.map((type, index) => {
        const config = type === "org.kde.plasma.digitalclock" ? {
            "Appearance:showSeconds": 0,
            "Appearance:use24hFormat": 0,
            "Appearance:dateDisplayFormat": 2,
            "Appearance:dateFormat": "shortDate",
            "Appearance:customDateFormat": "yyyy-MM-dd",
            "Appearance:fontFamily": "User Fixed Font",
            "Appearance:fontSize": 17,
            "General:userClockSetting": "preserve-me"
        } : {"General:sentinel": type};
        return {
            id: index + 1,
            type,
            geometry: {x: index * 100, y: 0, width: 80, height: 28},
            group: [],
            config,
            writes: [],
            get currentConfigGroup() { return this.group.slice(); },
            set currentConfigGroup(value) { this.group = value.slice(); },
            writeConfig(key, value) {
                const composite = this.group.join("/") + ":" + key;
                this.config[composite] = value;
                this.writes.push(composite);
            },
            readConfig(key, fallback) {
                const composite = this.group.join("/") + ":" + key;
                if (!Object.prototype.hasOwnProperty.call(this.config, composite)) return fallback;
                const value = this.config[composite];
                if (typeof fallback === "number" && typeof value === "string") return fallback;
                return value;
            },
            reloadConfig() {}
        };
    });
    const panel = {
        id: 17,
        screen: 0,
        location: "top",
        formFactor: "horizontal",
        height: 32,
        lengthMode: "fill",
        hiding: "none",
        floating: false,
        opacity: "opaque",
        group: [],
        order: widgets.map(widget => String(widget.id)),
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            return this.group.join("/") === "General" && key === "AppletOrder"
                ? this.order.join(";") : fallback;
        },
        widgets() { return widgets.slice(); }
    };
    Object.assign(panel, overrides);
    return panel;
}

function run(source, panel) {
    const output = [];
    vm.runInNewContext(source, {
        panelIds: [panel.id],
        panelById: id => id === panel.id ? panel : null,
        print: value => output.push(String(value)),
        JSON, String, Number, Math, Array, Object, Error
    });
    return output.join("\n");
}

function digest(panel) {
    return JSON.stringify({
        geometry: {
            screen: panel.screen,
            location: panel.location,
            formFactor: panel.formFactor,
            height: panel.height,
            lengthMode: panel.lengthMode,
            hiding: panel.hiding,
            floating: panel.floating,
            opacity: panel.opacity
        },
        order: panel.order,
        widgets: panel.widgets().map(widget => ({id: widget.id, type: widget.type, config: widget.config}))
    });
}

const panel = makePanel();
const clock = panel.widgets()[9];
const topologyBefore = JSON.stringify({order: panel.order, ids: panel.widgets().map(widget => widget.id)});
const nonClockBefore = JSON.stringify(panel.widgets().slice(0, 9).map(widget => widget.config));
assert(run(policySource, panel).includes("MINIMALIST_CLOCK_POLICY_OK"),
    "exact v0.4.1 clock writer did not report success");
const expected = {
    showDate: false,
    showSeconds: 2,
    use24hFormat: 2,
    autoFontAndSize: false,
    fontFamily: "Noto Sans",
    fontSize: 11,
    fontStyleName: "Regular",
    fontWeight: 400
};
for (const [key, value] of Object.entries(expected)) {
    assert(clock.config["Appearance:" + key] === value, "wrong clock policy for " + key);
}
assert(JSON.stringify(clock.writes) === JSON.stringify(Object.keys(expected).map(key => "Appearance:" + key)),
    "writer touched a key outside the eight-key clock policy");
assert(clock.config["Appearance:dateDisplayFormat"] === 2
    && clock.config["Appearance:dateFormat"] === "shortDate"
    && clock.config["Appearance:customDateFormat"] === "yyyy-MM-dd",
    "writer changed hidden date-format preferences");
assert(clock.config["General:userClockSetting"] === "preserve-me",
    "writer changed an unrelated clock setting");
assert(JSON.stringify(panel.widgets().slice(0, 9).map(widget => widget.config)) === nonClockBefore,
    "writer changed a non-clock widget");
assert(JSON.stringify({order: panel.order, ids: panel.widgets().map(widget => widget.id)}) === topologyBefore,
    "writer changed widget instances or order");
assert(run(postcheckSource, panel).includes("MINIMALIST_CLOCK_POSTCHECK_OK"),
    "numeric clock policy failed postcheck");

const valuesAfterFirstApply = JSON.stringify(clock.config);
run(policySource, panel);
assert(JSON.stringify(clock.config) === valuesAfterFirstApply, "clock policy is not value-idempotent");

clock.config["Appearance:showSeconds"] = "Always";
clock.config["Appearance:showDate"] = "false";
clock.config["Appearance:autoFontAndSize"] = "false";
clock.config["Appearance:fontSize"] = "11";
clock.config["Appearance:fontWeight"] = "400";
const symbolicBefore = digest(panel);
assert(run(postcheckSource, panel).includes("MINIMALIST_CLOCK_POSTCHECK_OK"),
    "postcheck rejected canonical enum names or string policy values");
assert(digest(panel) === symbolicBefore, "clock postcheck was not read-only");

clock.config["Appearance:showSeconds"] = "ToolTip";
const badPolicyBefore = digest(panel);
assert(!run(postcheckSource, panel).includes("MINIMALIST_CLOCK_POSTCHECK_OK"),
    "postcheck accepted a non-Always enum");
assert(digest(panel) === badPolicyBefore, "failed postcheck changed the panel");

clock.config["Appearance:showSeconds"] = "Always";
clock.config["Appearance:showDate"] = true;
assert(!run(postcheckSource, panel).includes("MINIMALIST_CLOCK_POSTCHECK_OK"),
    "postcheck accepted a visible date");

for (const [label, refusedPanel] of [
    ["wrong height", makePanel({height: 28})],
    ["wrong topology", makePanel()],
    ["malformed order", makePanel()]
]) {
    if (label === "wrong topology") refusedPanel.widgets()[4].type = "org.example.foreign";
    if (label === "malformed order") refusedPanel.order[1] = refusedPanel.order[0];
    const before = digest(refusedPanel);
    let refused = false;
    try {
        run(policySource, refusedPanel);
    } catch (error) {
        refused = true;
    }
    assert(refused, label + " was not refused");
    assert(digest(refusedPanel) === before, label + " was mutated before refusal");
}
NODE

mkdir -p -- "$TARGET_HOME/.config" "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources" \
    "$TARGET_HOME/.local/state" "$MOCK_BIN"
printf 'baseline panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'old layout\n' > "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt"
printf 'resource sentinel\n' > "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources/sentinel"
printf 'minimalist-v04\n' > "$MOCK_STATE"
printf 'none\n' > "$MOCK_WORKSPACE_REVISION"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"

cat > "$MOCK_BIN/doctor" <<'MOCK'
#!/usr/bin/env bash
[[ $# == 2 && $1 == --target && $2 == minimalist-v04 ]] || exit 64
printf 'mock doctor status=%s\n' "${MOCK_DOCTOR_STATUS:-0}"
exit "${MOCK_DOCTOR_STATUS:-0}"
MOCK

cat > "$MOCK_BIN/qdbus6" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
script=${4:-}
state_file=${MOCK_PLASMA_STATE:?}
count_file=${MOCK_PREFLIGHT_COUNT:?}
topology=$(< "$state_file")
workspace_revision=$(< "${MOCK_WORKSPACE_REVISION:?}")
if [[ $script == *MINIMALIST_CLOCK_PREFLIGHT* ]]; then
    count=$(( $(< "$count_file") + 1 ))
    printf '%s\n' "$count" > "$count_file"
    if [[ ${MOCK_TOCTOU_FAIL:-false} == true && $count -gt 1 ]]; then
        topology=unknown
    fi
    height=${MOCK_PANEL_HEIGHT:-32}
    geometry=true
    [[ $height == 32 ]] || geometry=false
    printf 'MINIMALIST_CLOCK_PREFLIGHT panelCount=1 topology=%s height=%s geometryOk=%s clockKnown=true workspaceRevision=%s widgets=mock\n' \
        "$topology" "$height" "$geometry" "$workspace_revision"
    if [[ ( $topology == minimalist-v04 || $topology == minimalist-v04-pager \
        || $topology == minimalist-v04-workspaces ) && $geometry == true ]]; then
        printf '%s\n' ' MINIMALIST_CLOCK_PREFLIGHT_OK'
    fi
elif [[ $script == *MINIMALIST_CLOCK_POLICY_OK* ]]; then
    snapshot_complete=false
    shopt -s nullglob
    for complete in "${MOCK_TARGET_HOME:?}/.local/state/kde-rice/snapshots/"*/complete; do
        [[ -f $complete ]] && snapshot_complete=true
    done
    $snapshot_complete || { printf 'writer ran before a complete snapshot\n' >&2; exit 70; }
    [[ -f ${MOCK_TARGET_HOME}/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/clock-policy.js ]] \
        || { printf 'writer did not run from an installed exact layout\n' >&2; exit 71; }
    printf 'clock policy applied\n' > "${MOCK_APPLETSRC:?}"
    printf 'MINIMALIST_CLOCK_POLICY_OK topology=%s panelId=17 clockId=10 clockOk=true\n' "$topology"
elif [[ $script == *MINIMALIST_CLOCK_POSTCHECK* ]]; then
    if [[ ${MOCK_POSTCHECK_FAIL:-false} == true ]]; then
        printf 'MINIMALIST_CLOCK_POSTCHECK panelCount=1 topologyOk=true geometryOk=true clockOk=false widgets=mock\n'
    else
        printf 'MINIMALIST_CLOCK_POSTCHECK panelCount=1 topologyOk=true geometryOk=true clockOk=true widgets=mock\n'
        printf '%s\n' ' MINIMALIST_CLOCK_POSTCHECK_OK'
    fi
else
    printf 'unexpected Plasma script\n' >&2
    exit 2
fi
MOCK

cat > "$MOCK_BIN/verify" <<'MOCK'
#!/usr/bin/env bash
case " $* " in
    *' --panel-target minimalist-v04 '*) ;;
    *' --panel-target minimalist-v04-pager '*) ;;
    *' --panel-target minimalist-v04-workspaces '*) ;;
    *) exit 2 ;;
esac
if [[ ${MOCK_VERIFY_FAIL:-false} == true ]]; then
    printf '%s\n' '{"schema_version":1,"status":"mismatch","checks":[{"name":"clock_policy","ok":false}]}'
    exit 1
fi
printf '%s\n' '{"schema_version":1,"status":"mismatch","checks":[{"name":"clock_policy","ok":true},{"name":"display_configuration_unchanged","ok":false}]}'
exit 1
MOCK
chmod +x "$MOCK_BIN/doctor" "$MOCK_BIN/qdbus6" "$MOCK_BIN/verify"

run_clock_policy() {
    HOME="$TARGET_HOME" \
    XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" \
    XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    KDE_RICE_VERIFY_COMMAND="$MOCK_BIN/verify" \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_TARGET_HOME="$TARGET_HOME" \
    MOCK_APPLETSRC="$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
    MOCK_PLASMA_STATE="$MOCK_STATE" \
    MOCK_PREFLIGHT_COUNT="$MOCK_PREFLIGHT_COUNT" \
    MOCK_WORKSPACE_REVISION="$MOCK_WORKSPACE_REVISION" \
    "$APPLY_SCRIPT" "$@"
}

run_clock_policy --dry-run > "$TEMP_ROOT/dry-run.txt"
grep -Fq 'current accepted topology: minimalist-v04 on one screen-0 top panel at 32 logical px' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted the exact topology and geometry"
grep -Fq 'managed asset write: layouts/plasma/org.kde.minimalist-v04 -> .local/share/plasma/layout-templates/org.kde.minimalist-v04' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted the exact layout target"
grep -Fq 'managed Plasma config that may change: .config/plasma-org.kde.plasma.desktop-appletsrc' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted the exact panel-config target"
grep -Fq 'panel removals: none' "$TEMP_ROOT/dry-run.txt" \
    || fail "dry-run omitted zero panel removals"
grep -Fq 'panel additions: none' "$TEMP_ROOT/dry-run.txt" \
    || fail "dry-run omitted zero panel additions"
grep -Fq 'panel and widget geometry changes: none; panel remains 32 logical px' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted the geometry-preservation boundary"
grep -Fq 'rollback apply:' "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted rollback"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'baseline panel config' ]] \
    || fail "dry-run changed the panel config"
[[ -f $TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt ]] \
    || fail "dry-run changed the installed layout"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "dry-run created transaction state"

printf 'minimalist-v04-workspaces\n' > "$MOCK_STATE"
printf '1\n' > "$MOCK_WORKSPACE_REVISION"
run_clock_policy --dry-run > "$TEMP_ROOT/stale-workspaces.txt" 2>&1
grep -Fq 'planning the second step after the Workspaces revision-2 refresh' \
    "$TEMP_ROOT/stale-workspaces.txt" \
    || fail "clock dry-run did not explain the pending Workspaces refresh"
set +e
run_clock_policy --apply > "$TEMP_ROOT/stale-workspaces-apply.txt" 2>&1
stale_workspaces_apply_status=$?
set -e
[[ $stale_workspaces_apply_status == 1 ]] \
    || fail "clock apply accepted the broken Workspaces revision"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] \
    || fail "refused clock apply snapshotted or wrote the target"

printf '2\n' > "$MOCK_WORKSPACE_REVISION"
run_clock_policy --dry-run > "$TEMP_ROOT/workspaces-dry-run.txt"
grep -Fq 'current accepted topology: minimalist-v04-workspaces on one screen-0 top panel at 32 logical px' \
    "$TEMP_ROOT/workspaces-dry-run.txt" || fail "clock policy refused the fixed Workspaces target"

printf 'minimalist-v04\n' > "$MOCK_STATE"
printf 'none\n' > "$MOCK_WORKSPACE_REVISION"

set +e
MOCK_DOCTOR_STATUS=2 run_clock_policy --dry-run > "$TEMP_ROOT/unsupported.txt" 2>&1
unsupported_status=$?
set -e
[[ $unsupported_status == 1 ]] || fail "unsupported doctor result was not refused"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "unsupported diagnosis wrote transaction state"

set +e
MOCK_DOCTOR_STATUS=1 run_clock_policy --apply > "$TEMP_ROOT/degraded.txt" 2>&1
degraded_status=$?
set -e
[[ $degraded_status == 1 ]] || fail "unapproved degraded apply was not refused"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "unapproved degraded apply wrote transaction state"

printf 'minimalist-v03\n' > "$MOCK_STATE"
set +e
run_clock_policy --dry-run > "$TEMP_ROOT/wrong-topology.txt" 2>&1
wrong_topology_status=$?
set -e
[[ $wrong_topology_status == 1 ]] || fail "non-v0.4 topology was not refused"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "wrong topology wrote transaction state"

printf 'minimalist-v04\n' > "$MOCK_STATE"
set +e
MOCK_PANEL_HEIGHT=28 run_clock_policy --dry-run > "$TEMP_ROOT/wrong-height.txt" 2>&1
wrong_height_status=$?
set -e
[[ $wrong_height_status == 1 ]] || fail "non-32px geometry was not refused"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "wrong geometry wrote transaction state"

printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
set +e
MOCK_TOCTOU_FAIL=true run_clock_policy --apply > "$TEMP_ROOT/toctou.txt" 2>&1
toctou_status=$?
set -e
[[ $toctou_status == 1 ]] || fail "post-snapshot topology change was not refused"
grep -Fq 'pre-apply managed files were restored automatically' "$TEMP_ROOT/toctou.txt" \
    || fail "TOCTOU refusal did not restore the snapshot"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'baseline panel config' ]] \
    || fail "TOCTOU refusal changed the panel config"
[[ -f $TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt ]] \
    || fail "TOCTOU refusal did not restore the old layout"
mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/toctou-kde-rice-state"

printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
run_clock_policy --apply > "$TEMP_ROOT/apply.txt"
layout_target="$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04"
resource_target="$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources"
diff -qr -- "$LAYOUT" "$layout_target" >/dev/null \
    || fail "clock apply did not install the exact v0.4.1 layout"
[[ $(< "$resource_target/sentinel") == 'resource sentinel' ]] \
    || fail "clock apply changed the resource Plasmoid"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'clock policy applied' ]] \
    || fail "clock apply did not reach the isolated panel config"
snapshot=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt" | tail -n 1)
[[ -d $snapshot && -f $snapshot/complete ]] || fail "clock apply did not create a complete snapshot"
cmp -- "$REPO_ROOT/config/managed-paths.txt" "$snapshot/managed-paths.txt" >/dev/null \
    || fail "clock apply snapshot did not capture the complete current manifest"
grep -Fq $'directory\t.local/share/plasma/layout-templates/org.kde.minimalist-v04' \
    "$snapshot/state.tsv" || fail "snapshot omitted the prior layout directory"
grep -Fq $'file\t.config/plasma-org.kde.plasma.desktop-appletsrc' \
    "$snapshot/state.tsv" || fail "snapshot omitted the panel config"
grep -Fq 'MINIMALIST_CLOCK_POLICY_OK' "$TEMP_ROOT/apply.txt" \
    || fail "clock apply omitted the writer success marker"
grep -Fq 'MINIMALIST_CLOCK_POSTCHECK_OK' "$TEMP_ROOT/apply.txt" \
    || fail "clock apply omitted the postcheck success marker"

first_applet=$(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc")
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
run_clock_policy --apply > "$TEMP_ROOT/reapply.txt"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == "$first_applet" ]] \
    || fail "clock reapply was not value-idempotent"
diff -qr -- "$LAYOUT" "$layout_target" >/dev/null \
    || fail "clock reapply left a layout mismatch"

printf 'pre-failure panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'pre-failure layout\n' > "$layout_target/contents/pre-failure.txt"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
set +e
MOCK_POSTCHECK_FAIL=true run_clock_policy --apply > "$TEMP_ROOT/postcheck-failure.txt" 2>&1
postcheck_status=$?
set -e
[[ $postcheck_status == 1 ]] || fail "clock postcheck failure did not fail the apply"
grep -Fq 'pre-apply managed files were restored automatically' "$TEMP_ROOT/postcheck-failure.txt" \
    || fail "clock postcheck failure did not restore the snapshot"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'pre-failure panel config' ]] \
    || fail "clock postcheck failure did not restore the panel config"
[[ -f $layout_target/contents/pre-failure.txt ]] \
    || fail "clock postcheck failure did not restore the prior layout"
[[ $(< "$resource_target/sentinel") == 'resource sentinel' ]] \
    || fail "clock postcheck failure changed the resource Plasmoid"

printf 'PASS: guarded Minimalist clock-policy tests\n'
