#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$SCRIPT_DIR/lib/runtime.sh"
require_test_node

TEMP_ROOT=$(mktemp -d /tmp/kde-rice-workspaces-preview.XXXXXX)
cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-workspaces-preview.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing unsafe cleanup: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v04"
PREFLIGHT="$LAYOUT/contents/workspaces-preflight.js"
WRITER="$LAYOUT/contents/workspaces-layout.js"
POSTCHECK="$LAYOUT/contents/workspaces-postcheck.js"
CLEANUP="$LAYOUT/contents/workspaces-cleanup.js"
REFRESH_RESTORE="$LAYOUT/contents/workspaces-refresh-restore.js"
PLASMOID="$REPO_ROOT/plasmoids/org.kde.minimalist.workspaces"
QML="$PLASMOID/contents/ui/main.qml"
APPLY_SCRIPT="$REPO_ROOT/scripts/apply-workspaces-preview"
TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
MOCK_QML="$TEMP_ROOT/qml"
MOCK_PANEL_STATE="$TEMP_ROOT/panel-state"
MOCK_WORKSPACE_REVISION="$TEMP_ROOT/workspace-revision"
MOCK_PREFLIGHT_COUNT="$TEMP_ROOT/preflight-count"
MOCK_KWIN_COUNT="$TEMP_ROOT/kwin-count"
MOCK_KWIN_CURRENT="$TEMP_ROOT/kwin-current"
MOCK_KWIN_NAMES="$TEMP_ROOT/kwin-names.tsv"
MOCK_KWIN_CALL_LOG="$TEMP_ROOT/kwin-calls.tsv"

[[ -x $APPLY_SCRIPT ]] || fail "Workspaces-preview entry point is not executable"
bash -n "$APPLY_SCRIPT"
jq -e '.KPlugin.Id == "org.kde.minimalist.workspaces" and .KPlugin.Version == "2.0"' \
    "$PLASMOID/metadata.json" >/dev/null || fail "Workspaces metadata is invalid"
for script in "$PREFLIGHT" "$WRITER" "$POSTCHECK" "$CLEANUP" "$REFRESH_RESTORE"; do
    "$NODE_BIN" --check "$script" >/dev/null
done

grep -Fq 'TaskManager.VirtualDesktopInfo' "$QML" \
    || fail "Workspaces does not use the reactive virtual-desktop API"
grep -Fq 'import org.kde.plasma.workspace.dbus as DBus' "$QML" \
    || fail "Workspaces does not use the public Plasma D-Bus QML module"
grep -Fq 'difference > 0 ? "nextDesktop" : "previousDesktop"' "$QML" \
    || fail "Workspaces does not call the confirmed no-argument KWin switch APIs"
grep -Fq 'root.switchDesktopSteps(member, remaining - 1);' "$QML" \
    || fail "Workspaces cannot reach a non-adjacent desktop"
if rg -n 'setCurrentDesktop|DBus\.int32|"signature"|"arguments"' "$QML" >/dev/null; then
    fail "Workspaces still relies on the broken typed D-Bus call"
fi
grep -Fq 'Layout.maximumWidth: hiddenByPolicy ? 0 : preferredSwitcherWidth' "$QML" \
    || fail "Workspaces width is not compact and deterministic"
grep -Fq 'onWheel: wheel =>' "$QML" || fail "Workspaces wheel navigation is missing"
grep -Fq 'Accessible.role: Accessible.Button' "$QML" \
    || fail "Workspaces buttons are not exposed to accessibility tools"
grep -Fq 'focused: desktopMouseArea.activeFocus' "$QML" \
    || fail "Workspaces keyboard focus is not visually exposed"
if ! grep -Fq 'border.color: root.tokens.accent' \
    "$PLASMOID/contents/ui/chimera/ChimeraFrame.qml"; then
    fail "Workspaces keyboard focus does not follow the active color theme"
fi
if rg -n 'plasma\.applet\.org\.kde\.plasma\.pager|pagerItemSize|screen.*aspect' "$QML" >/dev/null; then
    fail "Workspaces depends on the stock Pager private/aspect-ratio implementation"
fi
if rg -n 'writeConfig\("AppletOrder"|\.index[[:space:]]*=' "$WRITER" >/dev/null; then
    fail "Workspaces writer relies on an ineffective live AppletOrder/index rewrite"
fi

"$NODE_BIN" - "$PREFLIGHT" "$WRITER" "$POSTCHECK" "$CLEANUP" "$REFRESH_RESTORE" <<'NODE'
const fs = require("fs");
const vm = require("vm");
const sources = process.argv.slice(2).map(path => fs.readFileSync(path, "utf8"));
const pagerType = "org.kde.plasma.pager";
const workspaceType = "org.kde.minimalist.workspaces";
const baseTypes = [
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
const pagerTypes = baseTypes.slice();
pagerTypes.splice(1, 0, pagerType);
const workspaceTypes = baseTypes.slice();
workspaceTypes.splice(1, 0, workspaceType);

function assert(condition, message) {
    if (!condition) throw new Error(message);
}

function makeWidget(type, id, x) {
    return {
        id, type,
        geometry: {x, y: 0, width: type === "org.kde.plasma.kickoff" ? 24 : 80, height: 28},
        group: [], config: {"General:userSetting": "preserve-" + id}, writes: [],
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            const composite = this.group.join("/") + ":" + key;
            return Object.prototype.hasOwnProperty.call(this.config, composite)
                ? this.config[composite] : fallback;
        },
        writeConfig(key, value) {
            const composite = this.group.join("/") + ":" + key;
            this.config[composite] = value;
            this.writes.push(composite);
        },
        reloadConfig() {},
        remove() {
            const index = this.panel.items.indexOf(this);
            if (index >= 0) this.panel.items.splice(index, 1);
            this.panel.order = this.panel.order.filter(idValue => idValue !== String(this.id));
        }
    };
}

function makePanel(types = pagerTypes, workspaceRevision = 0) {
    const items = types.map((type, index) => makeWidget(type, index + 1,
        index === 0 ? 5 : 33 + index * 90));
    const workspace = items.find(widget => widget.type === workspaceType);
    if (workspace) {
        Object.assign(workspace.config, {
            "General:packageRevision": workspaceRevision,
            "General:labelMode": 1,
            "General:hideWhenSingle": true,
            "General:wrapWheel": true,
            "General:invertWheel": true,
            "General:density": 1,
            "General:surfaceStyle": 2,
            "General:bevelDepth": 1,
            "General:motionEnabled": false
        });
    }
    const panel = {
        id: 17, screen: 0, location: "top", formFactor: "horizontal", height: 32,
        lengthMode: "fill", hiding: "none", floating: false, opacity: "opaque",
        group: [], items, order: items.map(widget => String(widget.id)), nextId: 99,
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            return this.group.join("/") === "General" && key === "AppletOrder"
                ? this.order.join(";") : fallback;
        },
        widgets() { return this.items.slice(); },
        addWidget(type, x, y, width, height) {
            const widget = makeWidget(type, this.nextId++, x);
            widget.geometry = {x, y, width, height};
            widget.panel = this;
            this.items.splice(1, 0, widget);
            this.order.splice(1, 0, String(widget.id));
            return widget;
        }
    };
    items.forEach(widget => { widget.panel = panel; });
    return panel;
}

function run(source, panel) {
    const output = [];
    vm.runInNewContext(source, {
        panelIds: [panel.id], panelById: id => id === panel.id ? panel : null,
        knownWidgetTypes: baseTypes.concat([pagerType, workspaceType]),
        print: value => output.push(String(value)),
        JSON, String, Number, Array, Object, Error
    });
    return output.join("\n");
}

function preservedDigest(panel) {
    return JSON.stringify(panel.items.filter(widget => widget.type !== pagerType
        && widget.type !== workspaceType).map(widget => ({
        id: widget.id, type: widget.type, config: widget.config, geometry: widget.geometry
    })));
}

function panelDigest(panel) {
    return JSON.stringify({
        order: panel.order,
        widgets: panel.items.map(widget => ({
            id: widget.id, type: widget.type, config: widget.config, geometry: widget.geometry
        })),
        geometry: [panel.screen, panel.location, panel.formFactor, panel.height,
            panel.lengthMode, panel.hiding, panel.floating, panel.opacity]
    });
}

function workspaceUserDigest(panel) {
    const workspace = panel.items.find(widget => widget.type === workspaceType);
    if (!workspace) return "none";
    const keys = [
        "labelMode", "hideWhenSingle", "wrapWheel", "invertWheel",
        "density", "surfaceStyle", "bevelDepth", "motionEnabled"
    ];
    return JSON.stringify(keys.map(key => [key, workspace.config["General:" + key]]));
}

const panel = makePanel();
const preservedBefore = preservedDigest(panel);
assert(run(sources[0], panel).includes("topology=minimalist-v04-pager"),
    "Pager source preflight failed");
assert(run(sources[1], panel).includes("transition=replace-pager-after-launcher"),
    "Workspaces writer failed");
assert(panel.items.map(widget => widget.type)[1] === workspaceType,
    "Workspaces was not inserted after launcher");
assert(!panel.items.some(widget => widget.type === pagerType), "stock Pager was not removed");
assert(preservedDigest(panel) === preservedBefore, "an existing widget changed during replacement");
const workspaces = panel.items[1];
assert(JSON.stringify(workspaces.writes) === JSON.stringify(["General:packageRevision"]),
    "Workspaces writer touched keys outside its revision policy");
assert(run(sources[2], panel).includes("MINIMALIST_WORKSPACES_POSTCHECK_OK"),
    "Workspaces postcheck failed");
const postDigest = panelDigest(panel);
run(sources[2], panel);
assert(panelDigest(panel) === postDigest, "Workspaces postcheck was not read-only");

assert(run(sources[3], panel).includes("transition=restore-pager"),
    "Workspaces cleanup did not restore Pager");
assert(panel.items.map(widget => widget.type).join("|") === pagerTypes.join("|"),
    "cleanup did not restore the exact Pager topology");
const restoredPager = panel.items[1];
assert(restoredPager.config["General:displayedText"] === 0
    && restoredPager.config["General:showWindowOutlines"] === false
    && restoredPager.config["General:showWindowIcons"] === false,
    "cleanup restored Pager with the wrong policy");
assert(preservedDigest(panel) === preservedBefore, "cleanup changed a preserved widget");

const upgrade = makePanel(workspaceTypes, 1);
const upgradePreserved = preservedDigest(upgrade);
const upgradeUserConfig = workspaceUserDigest(upgrade);
const oldWorkspaceId = upgrade.items[1].id;
assert(run(sources[0], upgrade).includes("workspaceRevision=1"),
    "revision-1 Workspaces source was not identified");
assert(run(sources[1], upgrade).includes("transition=refresh-workspaces-after-launcher"),
    "revision-1 Workspaces was not refreshed");
assert(upgrade.items[1].id !== oldWorkspaceId,
    "Workspaces refresh reused the stale live component");
assert(upgrade.items[1].config["General:packageRevision"] === 2,
    "Workspaces refresh did not write revision 2");
assert(workspaceUserDigest(upgrade) === upgradeUserConfig,
    "Workspaces refresh changed user configuration");
assert(run(sources[2], upgrade).includes("MINIMALIST_WORKSPACES_POSTCHECK_OK"),
    "revision-2 Workspaces failed postcheck");
assert(preservedDigest(upgrade) === upgradePreserved,
    "Workspaces refresh changed a preserved widget");
assert(run(sources[4], upgrade).includes("MINIMALIST_WORKSPACES_REFRESH_RESTORE_OK"),
    "refresh failure recovery did not recreate the restored revision-1 widget");
assert(upgrade.items[1].config["General:packageRevision"] === 1,
    "refresh failure recovery did not restore revision 1");
assert(workspaceUserDigest(upgrade) === upgradeUserConfig,
    "Workspaces refresh recovery changed user configuration");
assert(preservedDigest(upgrade) === upgradePreserved,
    "refresh failure recovery changed a preserved widget");

const unsafe = makePanel();
run(sources[1], unsafe);
const foreign = makeWidget("org.example.foreign", 500, 900);
foreign.panel = unsafe;
unsafe.items.push(foreign);
unsafe.order.push(String(foreign.id));
const unsafeBefore = panelDigest(unsafe);
let refused = false;
try { run(sources[3], unsafe); } catch (error) { refused = true; }
assert(refused && panelDigest(unsafe) === unsafeBefore,
    "cleanup mutated an unknown concurrent topology");
NODE

mkdir -p -- "$TARGET_HOME/.config" \
    "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents" \
    "$TARGET_HOME/.local/state" "$MOCK_BIN" \
    "$MOCK_QML/org/kde/plasma/workspace/dbus" "$MOCK_QML/org/kde/taskmanager"
printf 'exports: ["org.kde.plasma.workspace.dbus/SessionBus 1.0"]\n' \
    > "$MOCK_QML/org/kde/plasma/workspace/dbus/dbusplugin.qmltypes"
printf 'exports: ["org.kde.taskmanager/VirtualDesktopInfo 0.0"]\n' \
    > "$MOCK_QML/org/kde/taskmanager/taskmanager.qmltypes"
printf 'baseline panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'old layout\n' > "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt"
printf 'minimalist-v04-pager\n' > "$MOCK_PANEL_STATE"
printf 'none\n' > "$MOCK_WORKSPACE_REVISION"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
printf '4\n' > "$MOCK_KWIN_COUNT"
printf 'desktop-1\n' > "$MOCK_KWIN_CURRENT"
printf 'desktop-1\tDesktop 1\ndesktop-2\t2\ndesktop-3\t3\ndesktop-4\t4\n' > "$MOCK_KWIN_NAMES"
: > "$MOCK_KWIN_CALL_LOG"

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
state=$(< "${MOCK_PANEL_STATE:?}")
revision=$(< "${MOCK_WORKSPACE_REVISION:?}")
if [[ $script == *MINIMALIST_WORKSPACES_PREFLIGHT* ]]; then
    count=$(( $(< "${MOCK_PREFLIGHT_COUNT:?}") + 1 ))
    printf '%s\n' "$count" > "$MOCK_PREFLIGHT_COUNT"
    if [[ ${MOCK_PANEL_TOCTOU:-false} == true && $count -gt 1 ]]; then state=unknown; fi
    workspace_known=false
    [[ -f ${MOCK_TARGET_HOME:?}/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces/metadata.json ]] \
        && workspace_known=true
    printf 'MINIMALIST_WORKSPACES_PREFLIGHT panelCount=1 topology=%s height=32 geometryOk=true anchorReady=true pagerKnown=true workspaceKnown=%s workspaceRevision=%s widgets=mock\n' \
        "$state" "$workspace_known" "$revision"
    if [[ $state == minimalist-v04-pager \
        || ( $state == minimalist-v04-workspaces && $workspace_known == true ) ]]; then
        printf '%s\n' ' MINIMALIST_WORKSPACES_PREFLIGHT_OK'
    fi
elif [[ $script == *MINIMALIST_WORKSPACES_LAYOUT_OK* ]]; then
    snapshot_complete=false
    shopt -s nullglob
    for complete in "${MOCK_TARGET_HOME:?}/.local/state/kde-rice/snapshots/"*/complete; do
        [[ -f $complete ]] && snapshot_complete=true
    done
    $snapshot_complete || { printf 'Workspaces ran before snapshot\n' >&2; exit 70; }
    printf 'minimalist-v04-workspaces\n' > "$MOCK_PANEL_STATE"
    printf '2\n' > "$MOCK_WORKSPACE_REVISION"
    printf 'Workspaces applied\n' > "${MOCK_APPLETSRC:?}"
    if [[ $state == minimalist-v04-pager ]]; then
        transition=replace-pager-after-launcher
    else
        transition=refresh-workspaces-after-launcher
    fi
    printf 'MINIMALIST_WORKSPACES_LAYOUT_OK transition=%s panelId=17 workspaceId=99\n' "$transition"
elif [[ $script == *MINIMALIST_WORKSPACES_POSTCHECK* ]]; then
    if [[ ${MOCK_POSTCHECK_FAIL:-false} == true ]]; then
        printf 'MINIMALIST_WORKSPACES_POSTCHECK panelCount=1 topologyOk=false geometryOk=true workspaceSwitcherOk=false widgets=mock\n'
    else
        printf 'MINIMALIST_WORKSPACES_POSTCHECK panelCount=1 topologyOk=true geometryOk=true workspaceSwitcherOk=true widgets=mock\n'
        printf '%s\n' ' MINIMALIST_WORKSPACES_POSTCHECK_OK'
    fi
elif [[ $script == *MINIMALIST_WORKSPACES_CLEANUP_OK* ]]; then
    printf 'minimalist-v04-pager\n' > "$MOCK_PANEL_STATE"
    printf 'none\n' > "$MOCK_WORKSPACE_REVISION"
    printf 'MINIMALIST_WORKSPACES_CLEANUP_OK transition=restore-pager removedWorkspaceId=99 pagerId=100\n'
elif [[ $script == *MINIMALIST_WORKSPACES_REFRESH_RESTORE_OK* ]]; then
    printf 'minimalist-v04-workspaces\n' > "$MOCK_PANEL_STATE"
    printf '1\n' > "$MOCK_WORKSPACE_REVISION"
    printf 'MINIMALIST_WORKSPACES_REFRESH_RESTORE_OK removedWorkspaceId=99 workspaceId=100 packageRevision=1\n'
else
    printf 'unexpected Plasma script\n' >&2
    exit 2
fi
MOCK

cat > "$MOCK_BIN/busctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
args=" $* "
count=$(< "${MOCK_KWIN_COUNT:?}")
desktops_json() {
    jq -Rsc '
        split("\n") | map(select(length > 0) | split("\t")) | to_entries
        | {type:"a(iss)", data: map([.key, .value[0], .value[1]])}
    ' "${MOCK_KWIN_NAMES:?}"
}
if [[ $args == *' introspect '* ]]; then
    printf '%s\n' '.nextDesktop method - - -'
    printf '%s\n' '.previousDesktop method - - -'
    printf '%s\n' '.createDesktop method us - -'
    printf '%s\n' '.setDesktopName method ss - -'
    printf '%s\n' '.removeDesktop method s - -'
    printf '%s\n' '.current property s "desktop-1" emits-change writable'
elif [[ $args == *' get-property '* ]]; then
    property=${!#}
    case "$property" in
        count) printf '{"type":"u","data":%s}\n' "$count" ;;
        rows) printf '%s\n' '{"type":"u","data":1}' ;;
        desktops) desktops_json "$count" ;;
        current) printf '{"type":"s","data":"%s"}\n' "$(< "${MOCK_KWIN_CURRENT:?}")" ;;
        *) exit 2 ;;
    esac
elif [[ $args == *' createDesktop '* ]]; then
    snapshot_complete=false
    shopt -s nullglob
    for complete in "${MOCK_TARGET_HOME:?}/.local/state/kde-rice/snapshots/"*/complete; do
        [[ -f $complete ]] && snapshot_complete=true
    done
    $snapshot_complete || { printf 'desktop created before snapshot\n' >&2; exit 70; }
    position=${@: -2:1}
    name=${!#}
    count=$((count + 1))
    desktop_id="desktop-$count"
    printf '%s\t%s\n' "$desktop_id" "$name" >> "$MOCK_KWIN_NAMES"
    printf 'create\t%s\t%s\t%s\n' "$position" "$desktop_id" "$name" >> "$MOCK_KWIN_CALL_LOG"
    if [[ ${MOCK_FOREIGN_ON_CREATE_POSITION:-none} == "$position" ]]; then
        printf 'foreign-%s\tForeign %s\n' "$position" "$position" >> "$MOCK_KWIN_NAMES"
        count=$((count + 1))
        printf 'foreign\t%s\tforeign-%s\n' "$position" "$position" >> "$MOCK_KWIN_CALL_LOG"
    fi
    printf '%s\n' "$count" > "$MOCK_KWIN_COUNT"
    printf '%s\n' 's ""'
elif [[ $args == *' setDesktopName '* ]]; then
    desktop_id=${@: -2:1}
    name=${!#}
    awk -F '\t' -v OFS='\t' -v wanted="$desktop_id" -v replacement="$name" \
        '{$2 = ($1 == wanted ? replacement : $2); print}' \
        "$MOCK_KWIN_NAMES" > "$MOCK_KWIN_NAMES.new"
    mv -- "$MOCK_KWIN_NAMES.new" "$MOCK_KWIN_NAMES"
    printf 'name\t%s\t%s\n' "$desktop_id" "$name" >> "$MOCK_KWIN_CALL_LOG"
    printf '%s\n' 's ""'
elif [[ $args == *' removeDesktop '* ]]; then
    desktop_id=${!#}
    ((count > 1)) || exit 2
    count=$((count - 1))
    printf '%s\n' "$count" > "$MOCK_KWIN_COUNT"
    awk -F '\t' -v wanted="$desktop_id" '$1 != wanted' \
        "$MOCK_KWIN_NAMES" > "$MOCK_KWIN_NAMES.new"
    mv -- "$MOCK_KWIN_NAMES.new" "$MOCK_KWIN_NAMES"
    printf 'remove\t%s\n' "$desktop_id" >> "$MOCK_KWIN_CALL_LOG"
    printf '%s\n' 's ""'
elif [[ $args == *' set-property '* && $args == *' current '* ]]; then
    current=${!#}
    printf '%s\n' "$current" > "$MOCK_KWIN_CURRENT"
    printf 'current\t%s\n' "$current" >> "$MOCK_KWIN_CALL_LOG"
else
    exit 2
fi
MOCK

cat > "$MOCK_BIN/verify" <<'MOCK'
#!/usr/bin/env bash
[[ $* == *'--panel-target minimalist-v04-workspaces'* ]] || exit 2
if [[ ${MOCK_VERIFY_FAIL:-false} == true ]]; then
    printf '%s\n' '{"schema_version":1,"status":"mismatch","checks":[{"name":"workspace_switcher_policy","ok":false}]}'
    exit 1
fi
printf '%s\n' '{"schema_version":1,"status":"mismatch","checks":[{"name":"workspace_switcher_policy","ok":true},{"name":"virtual_desktop_count","ok":true},{"name":"display_configuration_unchanged","ok":false}]}'
exit 1
MOCK
chmod +x "$MOCK_BIN/doctor" "$MOCK_BIN/qdbus6" "$MOCK_BIN/busctl" "$MOCK_BIN/verify"

run_workspaces() {
    HOME="$TARGET_HOME" \
    XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" \
    XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    KDE_RICE_VERIFY_COMMAND="$MOCK_BIN/verify" \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    KDE_RICE_KWIN_BUSCTL="$MOCK_BIN/busctl" \
    KDE_RICE_QML_IMPORT_ROOT="$MOCK_QML" \
    MOCK_TARGET_HOME="$TARGET_HOME" \
    MOCK_APPLETSRC="$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
    MOCK_PANEL_STATE="$MOCK_PANEL_STATE" \
    MOCK_WORKSPACE_REVISION="$MOCK_WORKSPACE_REVISION" \
    MOCK_PREFLIGHT_COUNT="$MOCK_PREFLIGHT_COUNT" \
    MOCK_KWIN_COUNT="$MOCK_KWIN_COUNT" \
    MOCK_KWIN_CURRENT="$MOCK_KWIN_CURRENT" \
    MOCK_KWIN_NAMES="$MOCK_KWIN_NAMES" \
    MOCK_KWIN_CALL_LOG="$MOCK_KWIN_CALL_LOG" \
    "$APPLY_SCRIPT" "$@"
}

run_workspaces --dry-run > "$TEMP_ROOT/dry-run.txt"
grep -Fq 'current accepted topology: minimalist-v04-pager on one screen-0 top panel at 32 logical px' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted exact current topology"
grep -Fq 'panel removal: exactly one built-in org.kde.plasma.pager' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted exact Pager removal"
grep -Fq 'panel addition: exactly one org.kde.minimalist.workspaces' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted exact Workspaces addition"
grep -Fq 'virtual desktop additions: none' "$TEMP_ROOT/dry-run.txt" \
    || fail "dry-run omitted unchanged KWin scope"
[[ $(< "$MOCK_PANEL_STATE") == minimalist-v04-pager ]] || fail "dry-run changed panel"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "dry-run created transaction state"

set +e
MOCK_DOCTOR_STATUS=2 run_workspaces --dry-run > "$TEMP_ROOT/unsupported.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "unsupported diagnosis was not refused"

printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
set +e
MOCK_PANEL_TOCTOU=true run_workspaces --apply > "$TEMP_ROOT/toctou.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "panel TOCTOU change was not refused"
grep -Fq 'pre-apply managed files were restored automatically' "$TEMP_ROOT/toctou.txt" \
    || fail "TOCTOU refusal did not restore snapshot"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces ]] \
    || fail "TOCTOU rollback left the Workspaces package installed"
mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/toctou-state"

printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
run_workspaces --apply > "$TEMP_ROOT/apply.txt"
[[ $(< "$MOCK_PANEL_STATE") == minimalist-v04-workspaces ]] \
    || fail "apply did not create Workspaces target"
diff -qr "$REPO_ROOT/plasmoids/org.kde.minimalist.workspaces" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces" >/dev/null \
    || fail "installed Workspaces package differs from source"
grep -Fq 'MINIMALIST_WORKSPACES_POSTCHECK_OK' "$TEMP_ROOT/apply.txt" \
    || fail "postcheck success missing"
snapshot=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt" | tail -n 1)
[[ -f $snapshot/complete ]] || fail "complete snapshot missing"
cmp -- "$REPO_ROOT/config/managed-paths.txt" "$snapshot/managed-paths.txt" >/dev/null \
    || fail "snapshot did not capture complete exact manifest"
grep -Fq $'absent\t.local/share/plasma/plasmoids/org.kde.minimalist.workspaces' \
    "$snapshot/state.tsv" || fail "snapshot omitted the previously absent Workspaces path"

mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/success-state"
mv -- "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces" \
    "$TEMP_ROOT/success-workspaces-package"
printf 'minimalist-v04-pager\n' > "$MOCK_PANEL_STATE"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
printf 'pre-failure panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'old layout again\n' > "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt"
set +e
MOCK_POSTCHECK_FAIL=true run_workspaces --apply > "$TEMP_ROOT/postcheck-fail.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "Workspaces postcheck failure did not fail apply"
[[ $(< "$MOCK_PANEL_STATE") == minimalist-v04-pager ]] \
    || fail "failure did not restore stock Pager live"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'pre-failure panel config' ]] \
    || fail "failure did not restore panel config"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces ]] \
    || fail "failure did not restore the absent Workspaces package"
[[ $(< "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt") == 'old layout again' ]] \
    || fail "failure did not restore the previous layout asset"

if [[ -d $TARGET_HOME/.local/state/kde-rice ]]; then
    mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/pager-failure-state"
fi
cp -a -- "$TEMP_ROOT/success-workspaces-package" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces"
printf 'revision-1 package sentinel\n' \
    > "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces/revision-1.txt"
printf 'minimalist-v04-workspaces\n' > "$MOCK_PANEL_STATE"
printf '1\n' > "$MOCK_WORKSPACE_REVISION"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
printf 'pre-refresh panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

run_workspaces --dry-run > "$TEMP_ROOT/refresh-dry-run.txt"
grep -Fq 'panel removal: exactly one revision-1 org.kde.minimalist.workspaces' \
    "$TEMP_ROOT/refresh-dry-run.txt" || fail "refresh plan omitted the stale Workspaces removal"
grep -Fq 'panel addition: exactly one revision-2 org.kde.minimalist.workspaces' \
    "$TEMP_ROOT/refresh-dry-run.txt" || fail "refresh plan omitted the fixed Workspaces addition"
[[ $(< "$MOCK_WORKSPACE_REVISION") == 1 ]] || fail "refresh dry-run changed the live revision"

set +e
MOCK_POSTCHECK_FAIL=true run_workspaces --apply > "$TEMP_ROOT/refresh-fail.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "Workspaces refresh postcheck failure did not fail apply"
[[ $(< "$MOCK_PANEL_STATE") == minimalist-v04-workspaces \
    && $(< "$MOCK_WORKSPACE_REVISION") == 1 ]] \
    || fail "refresh failure did not reload the restored revision-1 Workspaces live"
[[ -f $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces/revision-1.txt ]] \
    || fail "refresh failure did not restore the revision-1 package files"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'pre-refresh panel config' ]] \
    || fail "refresh failure did not restore the panel config"
grep -Fq 'the restored revision-1 Workspaces package was reloaded on the live panel' \
    "$TEMP_ROOT/refresh-fail.txt" || fail "refresh failure omitted live package reload confirmation"

mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/refresh-failure-state"
mv -- "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces" \
    "$TEMP_ROOT/revision-1-workspaces-package"
cp -a -- "$TEMP_ROOT/success-workspaces-package" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces"
printf 'minimalist-v04-workspaces\n' > "$MOCK_PANEL_STATE"
printf '2\n' > "$MOCK_WORKSPACE_REVISION"
printf '1\n' > "$MOCK_KWIN_COUNT"
printf 'desktop-1\n' > "$MOCK_KWIN_CURRENT"
printf 'desktop-1\tDesktop 1\n' > "$MOCK_KWIN_NAMES"
: > "$MOCK_KWIN_CALL_LOG"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
printf 'single-desktop kwin config\n' > "$TARGET_HOME/.config/kwinrc"
printf 'repair-only package sentinel\n' \
    > "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces/repair-only.txt"
repair_panel_before=$(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc")

run_workspaces --dry-run > "$TEMP_ROOT/single-desktop-dry-run.txt"
grep -Fq 'current KWin topology: 1 virtual desktop(s) in one horizontal row' \
    "$TEMP_ROOT/single-desktop-dry-run.txt" || fail "single-desktop plan omitted current KWin topology"
grep -Fq 'virtual desktop additions: exactly three' \
    "$TEMP_ROOT/single-desktop-dry-run.txt" || fail "single-desktop plan omitted exact additions"
grep -Fq 'managed config that may change: .config/kwinrc' \
    "$TEMP_ROOT/single-desktop-dry-run.txt" || fail "single-desktop plan omitted managed KWin config"
grep -Fq 'read-only integrity guard: .config/plasma-org.kde.plasma.desktop-appletsrc' \
    "$TEMP_ROOT/single-desktop-dry-run.txt" || fail "single-desktop plan omitted panel integrity guard"
[[ $(< "$MOCK_KWIN_COUNT") == 1 ]] || fail "single-desktop dry-run changed KWin"

printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
run_workspaces --apply > "$TEMP_ROOT/single-desktop-apply.txt" 2>&1
[[ $(< "$MOCK_KWIN_COUNT") == 4 ]] || fail "Workspaces repair did not create four desktops"
[[ $(< "$MOCK_KWIN_CURRENT") == desktop-1 ]] \
    || fail "Workspaces repair changed the current desktop"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == "$repair_panel_before" ]] \
    || fail "Workspaces repair changed the panel config"
[[ -f $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces/repair-only.txt ]] \
    || fail "Workspaces repair replaced the installed package"
grep -Fq 'Creating exactly three KWin virtual desktops' \
    "$TEMP_ROOT/single-desktop-apply.txt" || fail "Workspaces repair omitted desktop creation"
grep -Fq 'no Workspaces or panel writer is executed' \
    "$TEMP_ROOT/single-desktop-apply.txt" || fail "Workspaces repair did not use the repair-only path"
[[ $(awk -F '\t' '{print $1 ":" $2}' "$MOCK_KWIN_CALL_LOG" | paste -sd, -) \
    == 'create:1,name:desktop-2,create:2,name:desktop-3,create:3,name:desktop-4' ]] \
    || fail "Workspaces repair did not create and name the exact desktop IDs in order"
single_snapshot=$(sed -n 's/^Pre-apply snapshot: //p' \
    "$TEMP_ROOT/single-desktop-apply.txt" | tail -n 1)
grep -Fq $'file\t.config/kwinrc' "$single_snapshot/state.tsv" \
    || fail "single-desktop repair snapshot omitted kwinrc"
repair_receipt=$(sed -n 's/^Repair receipt: //p' \
    "$TEMP_ROOT/single-desktop-apply.txt" | tail -n 1)
[[ -f $repair_receipt/complete && ! -e $repair_receipt/failed ]] \
    || fail "single-desktop repair receipt is not complete"
[[ $(cut -f2 "$repair_receipt/created-desktop-ids.tsv" | paste -sd, -) \
    == 'desktop-2,desktop-3,desktop-4' ]] \
    || fail "repair receipt omitted exact created desktop IDs"

mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/single-desktop-success-state"
printf '1\n' > "$MOCK_KWIN_COUNT"
printf 'desktop-1\n' > "$MOCK_KWIN_CURRENT"
printf 'desktop-1\tDesktop 1\n' > "$MOCK_KWIN_NAMES"
: > "$MOCK_KWIN_CALL_LOG"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
printf 'pre-repair-failure kwin config\n' > "$TARGET_HOME/.config/kwinrc"
set +e
MOCK_POSTCHECK_FAIL=true run_workspaces --apply \
    > "$TEMP_ROOT/single-desktop-failure.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "single-desktop postcheck failure did not fail apply"
[[ $(< "$MOCK_KWIN_COUNT") == 1 ]] \
    || fail "single-desktop failure did not remove transaction desktops"
[[ $(< "$TARGET_HOME/.config/kwinrc") == 'pre-repair-failure kwin config' ]] \
    || fail "single-desktop failure did not restore kwinrc"
[[ $(awk -F '\t' '$1 == "remove" {print $2}' "$MOCK_KWIN_CALL_LOG" | paste -sd, -) \
    == 'desktop-4,desktop-3,desktop-2' ]] \
    || fail "single-desktop failure did not remove only recorded IDs in reverse order"

mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/single-desktop-failure-state"
printf '1\n' > "$MOCK_KWIN_COUNT"
printf 'desktop-1\n' > "$MOCK_KWIN_CURRENT"
printf 'desktop-1\tDesktop 1\n' > "$MOCK_KWIN_NAMES"
: > "$MOCK_KWIN_CALL_LOG"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
set +e
MOCK_FOREIGN_ON_CREATE_POSITION=1 run_workspaces --apply \
    > "$TEMP_ROOT/concurrent-foreign.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "concurrent foreign desktop did not stop the repair"
[[ $(< "$MOCK_KWIN_COUNT") == 2 ]] \
    || fail "concurrent foreign rollback removed the wrong number of desktops"
grep -Fq $'foreign-1\tForeign 1' "$MOCK_KWIN_NAMES" \
    || fail "concurrent foreign desktop was not preserved"
if grep -Fq $'desktop-2\t' "$MOCK_KWIN_NAMES"; then
    fail "transaction desktop survived concurrent foreign rollback"
fi
[[ $(awk -F '\t' '$1 == "remove" {print $2}' "$MOCK_KWIN_CALL_LOG" | paste -sd, -) \
    == 'desktop-2' ]] || fail "concurrent rollback did not remove only its recorded ID"

printf 'PASS: guarded Minimalist Workspaces-preview tests\n'
