#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$SCRIPT_DIR/lib/runtime.sh"
require_test_node

TEMP_ROOT=$(mktemp -d /tmp/kde-rice-panel-font.XXXXXX)
cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-panel-font.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing unsafe cleanup: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v04"
PREFLIGHT="$LAYOUT/contents/font-preflight.js"
CAPTURE="$LAYOUT/contents/font-capture.js"
WRITER="$LAYOUT/contents/font-layout.js"
POSTCHECK="$LAYOUT/contents/font-postcheck.js"
RESTORE="$LAYOUT/contents/font-restore.js"
RESTORE_POSTCHECK="$LAYOUT/contents/font-restore-postcheck.js"
APPLY_SCRIPT="$REPO_ROOT/scripts/apply-panel-font-policy"
TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
MOCK_STATE="$TEMP_ROOT/font-state"
MOCK_UI_STATE="$TEMP_ROOT/ui-state"
MOCK_PREFLIGHT_COUNT="$TEMP_ROOT/preflight-count"

[[ -x $APPLY_SCRIPT ]] || fail "panel-font entry point is not executable"
bash -n "$APPLY_SCRIPT"
for script in "$PREFLIGHT" "$CAPTURE" "$WRITER" "$POSTCHECK" "$RESTORE" \
    "$RESTORE_POSTCHECK"; do
    "$NODE_BIN" --check "$script" >/dev/null
done
grep -Fq 'font.family: "Noto Sans"' \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle/contents/ui/main.qml" \
    || fail "active-title font differs"
grep -Fq 'metricsFontFamily: "Noto Sans"' \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.resources/contents/ui/main.qml" \
    || fail "resource font differs"
grep -Fq 'font.family: "Noto Sans"' \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.workspaces/contents/ui/main.qml" \
    || fail "Workspaces font differs"
if rg -n 'writeConfig\("AppletOrder"|\.index[[:space:]]*=' "$WRITER" "$RESTORE" >/dev/null; then
    fail "font transaction uses an ineffective live order rewrite"
fi

"$NODE_BIN" - "$PREFLIGHT" "$WRITER" "$POSTCHECK" "$RESTORE" "$CAPTURE" \
    "$RESTORE_POSTCHECK" <<'NODE'
const fs = require("fs");
const vm = require("vm");
const sources = process.argv.slice(2).map(path => fs.readFileSync(path, "utf8"));
const activeType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const types = [
    "org.kde.plasma.kickoff", workspaceType, activeType,
    "org.kde.plasma.panelspacer", "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer", resourceType,
    "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray", clockType
];
const userConfigByType = {};
userConfigByType[activeType] = {
    titleTemplate: "{app} :: {title}", showIcon: true, widthMode: 2,
    minimumWidthUnits: 7, preferredWidthUnits: 23, maximumWidthUnits: 31,
    maximizedOnly: true, wheelSwitch: true, doubleClickMaximize: false,
    middleClickClose: true, density: 1, surfaceStyle: 2, bevelDepth: 1,
    motionEnabled: false
};
userConfigByType[workspaceType] = {
    labelMode: 1, hideWhenSingle: true, wrapWheel: true, invertWheel: true,
    density: 1, surfaceStyle: 2, bevelDepth: 1, motionEnabled: false
};
userConfigByType[resourceType] = {
    metricOrder: "VOL,GPU,RAM,CPU", showCpu: false, showMemory: true,
    showGpu: false, showVolume: true, updateRateMs: 750,
    warningPercent: 61, criticalPercent: 83, showStateRails: false,
    density: 1, surfaceStyle: 2, bevelDepth: 1, motionEnabled: false
};
function assert(value, message) { if (!value) throw new Error(message); }
function widget(type, id, x) {
    const config = {"General:userSetting": "preserve-" + id};
    if (type === activeType) config["General:packageRevision"] = 1;
    if (type === workspaceType || type === resourceType) config["General:packageRevision"] = 2;
    if ([activeType, workspaceType, resourceType].includes(type)) {
        config["General:fontPolicyRevision"] = 1;
    }
    for (const [key, value] of Object.entries(userConfigByType[type] || {})) {
        config["General:" + key] = value;
    }
    if (type === clockType) Object.assign(config, {
        "Appearance:fontFamily": "Noto Sans Mono", "Appearance:autoFontAndSize": false,
        "Appearance:fontSize": 11, "Appearance:fontStyleName": "Regular",
        "Appearance:fontWeight": 400
    });
    const compact = type === workspaceType || type === resourceType;
    const tallTitle = type === activeType;
    return {
        id, type,
        geometry: {x, y: compact ? 4 : 0, width: 60,
            height: compact ? 24 : tallTitle ? 32 : 28},
        group: [], config, writes: [], malformedConfigKeys: false,
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        get configKeys() {
            if (this.malformedConfigKeys) return {length: 1};
            const prefix = this.group.join("/") + ":";
            const keys = Object.keys(this.config).filter(key => key.startsWith(prefix))
                .map(key => key.slice(prefix.length));
            const sequence = {length: keys.length};
            keys.forEach((key, index) => { sequence[index] = key; });
            return sequence;
        },
        readConfig(key, fallback) {
            const name = this.group.join("/") + ":" + key;
            return Object.prototype.hasOwnProperty.call(this.config, name) ? this.config[name] : fallback;
        },
        writeConfig(key, value) {
            const name = this.group.join("/") + ":" + key;
            this.config[name] = value; this.writes.push(name);
        },
        reloadConfig() {},
        remove() {
            this.panel.items = this.panel.items.filter(item => item !== this);
            this.panel.order = this.panel.order.filter(idValue => idValue !== String(this.id));
        }
    };
}
function panel() {
    const items = types.map((type, index) => widget(type, index + 1, index * 100 + 5));
    const result = {
        id: 29, screen: 0, location: "top", formFactor: "horizontal", height: 32,
        lengthMode: "fill", hiding: "none", floating: false, opacity: "opaque",
        items, order: items.map(item => String(item.id)), group: [], nextId: 100,
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            return this.group.join("/") === "General" && key === "AppletOrder"
                ? this.order.join(";") : fallback;
        },
        widgets() { return this.items.slice(); },
        addWidget(type, x, y, width, height) {
            if (this.failAddType === type) {
                this.failAddType = null;
                return null;
            }
            const item = widget(type, this.nextId++, x);
            item.geometry = {x, y, width, height}; item.panel = this;
            let insert = this.items.findIndex(existing => existing.geometry.x > x);
            if (insert < 0) insert = this.items.length;
            this.items.splice(insert, 0, item); this.order.splice(insert, 0, String(item.id));
            return item;
        }
    };
    items.forEach(item => { item.panel = result; });
    return result;
}
function run(source, value, options = {}) {
    const output = [];
    vm.runInNewContext(source, {
        panelIds: [value.id], panelById: id => id === value.id ? value : null,
        knownWidgetTypes: types.slice(), print: text => output.push(String(text)),
        capturedRefreshState: options.capture,
        restoreFontRevision: options.restoreFontRevision ?? 1,
        restoreUiRevision: options.restoreUiRevision ?? 0,
        restoreClockFamily: options.restoreClockFamily ?? "Noto Sans Mono",
        JSON, String, Number, Array, Object, Error
    });
    return output.join("\n");
}
function capture(value) {
    const output = run(sources[4], value);
    const prefix = "MINIMALIST_CHIMERA_CAPTURE=";
    assert(output.startsWith(prefix), "project-applet capture failed");
    return JSON.parse(output.slice(prefix.length));
}
function preserved(value) {
    return JSON.stringify(value.items.filter(item => ![activeType, workspaceType, resourceType].includes(item.type))
        .map(item => ({id: item.id, type: item.type, config: item.config})));
}
function userConfigDigest(value) {
    return JSON.stringify(value.items
        .filter(item => Object.prototype.hasOwnProperty.call(userConfigByType, item.type))
        .sort((left, right) => left.type.localeCompare(right.type))
        .map(item => ({
            type: item.type,
            config: Object.fromEntries(Object.keys(userConfigByType[item.type])
                .sort().map(key => [key, item.config["General:" + key]]))
        })));
}
function fullPanelDigest(value) {
    return JSON.stringify({
        order: value.order,
        items: value.items.map(item => ({
            id: item.id,
            type: item.type,
            geometry: item.geometry,
            config: item.config,
            writes: item.writes
        }))
    });
}
const value = panel();
const sequenceProbe = value.items.find(item => item.type === activeType);
sequenceProbe.currentConfigGroup = ["General"];
assert(!Array.isArray(sequenceProbe.configKeys)
    && sequenceProbe.configKeys.length > 0,
    "mock did not emulate Plasma 6.7 V4Sequence configKeys");
sequenceProbe.currentConfigGroup = [];
const originalCapture = capture(value);
const preservedBefore = preserved(value);
const userConfigBefore = userConfigDigest(value);
const idsBefore = value.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type)).map(item => item.id);
assert(run(sources[0], value).includes("fontState=source"), "source preflight failed");
assert(run(sources[1], value, {capture: originalCapture})
    .includes("transition=refresh-project-widgets"), "writer did not refresh widgets");
assert(value.items.map(item => item.type).join("|") === types.join("|"), "writer changed widget order");
const custom = value.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type));
assert(custom.every(item => !idsBefore.includes(item.id)), "writer reused a stale component");
assert(custom.every(item => item.config["General:fontPolicyRevision"] === 2), "font revision missing");
assert(custom.every(item => item.config["General:chimeraUiRevision"] === 2),
    "Chimera UI revision missing");
assert(custom.every(item => item.geometry.y === 4 && item.geometry.height === 24),
    "project applets did not normalize to the common 24 px geometry");
assert(userConfigDigest(value) === userConfigBefore,
    "font refresh changed Chimera user configuration");
assert(value.items.find(item => item.type === clockType).config["Appearance:fontFamily"] === "Noto Sans",
    "clock family differs");
assert(preserved(value) !== preservedBefore,
    "clock was expected to be the only preserved widget with a managed change");
assert(run(sources[2], value).includes("MINIMALIST_FONT_POSTCHECK_OK"), "postcheck failed");
const targetIds = custom.map(item => item.id);
assert(run(sources[1], value, {capture: capture(value)})
    .includes("transition=already-target"), "target reapply failed");
assert(JSON.stringify(value.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type)).map(item => item.id))
    === JSON.stringify(targetIds), "target reapply replaced widgets");
assert(run(sources[3], value, {capture: originalCapture})
    .includes("MINIMALIST_FONT_RESTORE_OK"), "restore failed");
assert(value.items.map(item => item.type).join("|") === types.join("|"), "restore changed widget order");
assert(value.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type))
    .every(item => item.config["General:fontPolicyRevision"] === 1), "restore revision differs");
assert(value.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type))
    .every(item => item.config["General:chimeraUiRevision"] === 0),
    "restore UI revision differs");
assert(userConfigDigest(value) === userConfigBefore,
    "font restore changed Chimera user configuration");
assert(value.items.find(item => item.type === clockType).config["Appearance:fontFamily"] === "Noto Sans Mono",
    "restore clock family differs");
assert(run(sources[5], value, {capture: originalCapture})
    .includes("MINIMALIST_FONT_RESTORE_POSTCHECK_OK"),
    "restore postcheck did not prove the exact captured state");
const uiUpgrade = panel();
for (const item of uiUpgrade.items) {
    if ([activeType, workspaceType, resourceType].includes(item.type)) {
        item.config["General:fontPolicyRevision"] = 2;
    }
    if (item.type === clockType) item.config["Appearance:fontFamily"] = "Noto Sans";
}
const uiUpgradeIds = uiUpgrade.items
    .filter(item => [activeType, workspaceType, resourceType].includes(item.type))
    .map(item => item.id);
const uiUpgradePreflight = run(sources[0], uiUpgrade);
assert(uiUpgradePreflight.includes("fontState=target")
    && uiUpgradePreflight.includes("uiState=source"),
    "current font target was not accepted as a Chimera UI source");
assert(run(sources[1], uiUpgrade, {capture: capture(uiUpgrade)})
    .includes("transition=refresh-project-widgets"),
    "Chimera UI source did not refresh project applets");
assert(uiUpgrade.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type))
    .every(item => !uiUpgradeIds.includes(item.id)),
    "Chimera UI refresh reused stale applet instances");
assert(run(sources[2], uiUpgrade).includes("MINIMALIST_FONT_POSTCHECK_OK"),
    "Chimera UI refresh failed postcheck");
const failedRefresh = panel();
const failedCapture = capture(failedRefresh);
const failedUserConfig = userConfigDigest(failedRefresh);
failedRefresh.failAddType = activeType;
let partialFailure = false;
try {
    run(sources[1], failedRefresh, {capture: failedCapture});
} catch (error) {
    partialFailure = true;
}
assert(partialFailure, "injected partial applet refresh did not fail");
assert(run(sources[3], failedRefresh, {capture: failedCapture})
    .includes("MINIMALIST_FONT_RESTORE_OK"),
    "partial refresh recovery did not recreate the captured applets");
assert(userConfigDigest(failedRefresh) === failedUserConfig,
    "partial refresh recovery lost captured user configuration");
assert(failedRefresh.items.map(item => item.type).join("|") === types.join("|"),
    "partial refresh recovery changed widget order");
assert(run(sources[5], failedRefresh, {capture: failedCapture})
    .includes("MINIMALIST_FONT_RESTORE_POSTCHECK_OK"),
    "partial refresh recovery failed its exact postcheck");
const staleConfig = panel();
const staleConfigCapture = capture(staleConfig);
const staleActive = staleConfig.items.find(item => item.type === activeType);
staleActive.config["General:titleTemplate"] = "changed after capture";
const staleConfigBefore = fullPanelDigest(staleConfig);
let staleConfigRefused = false;
try {
    run(sources[1], staleConfig, {capture: staleConfigCapture});
} catch (error) {
    staleConfigRefused = true;
}
assert(staleConfigRefused, "stale captured user configuration was accepted");
assert(fullPanelDigest(staleConfig) === staleConfigBefore,
    "stale user configuration refusal mutated the panel");
const stalePresence = panel();
const stalePresenceActive = stalePresence.items.find(item => item.type === activeType);
stalePresenceActive.config["General:surfaceStyle"] = 0;
const stalePresenceCapture = capture(stalePresence);
delete stalePresenceActive.config["General:surfaceStyle"];
const stalePresenceBefore = fullPanelDigest(stalePresence);
let stalePresenceRefused = false;
try {
    run(sources[1], stalePresence, {capture: stalePresenceCapture});
} catch (error) {
    stalePresenceRefused = true;
}
assert(stalePresenceRefused, "stale stored-key presence was accepted");
assert(fullPanelDigest(stalePresence) === stalePresenceBefore,
    "stored-key presence refusal mutated the panel");
const malformedSequence = panel();
const malformedCapture = capture(malformedSequence);
malformedSequence.items.find(item => item.type === activeType).malformedConfigKeys = true;
const malformedBefore = fullPanelDigest(malformedSequence);
let malformedRefused = false;
try {
    run(sources[1], malformedSequence, {capture: malformedCapture});
} catch (error) {
    malformedRefused = true;
}
assert(malformedRefused, "malformed live configKeys sequence was accepted");
assert(fullPanelDigest(malformedSequence) === malformedBefore,
    "malformed configKeys refusal mutated the panel");
const wrongRestoreSlot = panel();
const wrongRestoreCapture = capture(wrongRestoreSlot);
const misplacedWorkspace = wrongRestoreSlot.items.splice(1, 1)[0];
wrongRestoreSlot.items.splice(wrongRestoreSlot.items.length - 1, 0, misplacedWorkspace);
wrongRestoreSlot.order = wrongRestoreSlot.items.map(item => String(item.id));
const wrongRestoreBefore = fullPanelDigest(wrongRestoreSlot);
let wrongRestoreRefused = false;
try {
    run(sources[3], wrongRestoreSlot, {capture: wrongRestoreCapture});
} catch (error) {
    wrongRestoreRefused = true;
}
assert(wrongRestoreRefused, "restore accepted a custom applet in a foreign slot");
assert(fullPanelDigest(wrongRestoreSlot) === wrongRestoreBefore,
    "foreign-slot restore refusal removed or rewrote an applet");
const unsafe = panel();
const unsafeCapture = capture(unsafe);
unsafe.items[4].type = "org.example.foreign";
let refused = false;
try {
    run(sources[1], unsafe, {capture: unsafeCapture});
} catch (error) {
    refused = true;
}
assert(refused, "unknown topology was accepted");
NODE

mkdir -p -- "$TARGET_HOME/.config" "$TARGET_HOME/.local/state" "$MOCK_BIN" \
    "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources"
printf 'baseline panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'old layout\n' > "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt"
for package in org.kde.minimalist.activewindowtitle org.kde.minimalist.workspaces org.kde.minimalist.resources; do
    printf 'old %s\n' "$package" > "$TARGET_HOME/.local/share/plasma/plasmoids/$package/old.txt"
done
printf 'source\n' > "$MOCK_STATE"
printf 'source\n' > "$MOCK_UI_STATE"
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
state=$(< "${MOCK_FONT_STATE:?}")
ui_state=$(< "${MOCK_UI_STATE:?}")
if [[ $script == *MINIMALIST_CHIMERA_CAPTURE=* ]]; then
    printf '%s\n' 'MINIMALIST_CHIMERA_CAPTURE={"schemaVersion":1,"panelId":29,"orderedIds":[1,2,3,4,5,6,7,8,9,10,11],"orderedTypes":["org.kde.plasma.kickoff","org.kde.minimalist.workspaces","org.kde.minimalist.activewindowtitle","org.kde.plasma.panelspacer","org.kde.plasma.icontasks","org.kde.plasma.panelspacer","org.kde.minimalist.resources","org.kde.plasma.marginsseparator","org.kde.plasma.kimpanel","org.kde.plasma.systemtray","org.kde.plasma.digitalclock"],"workspace":{"id":2,"type":"org.kde.minimalist.workspaces","geometry":{"x":33,"y":4,"width":103,"height":24},"userConfig":{},"presentUserConfigKeys":[]},"activeTitle":{"id":3,"type":"org.kde.minimalist.activewindowtitle","geometry":{"x":140,"y":0,"width":323,"height":32},"userConfig":{},"presentUserConfigKeys":[]},"resources":{"id":7,"type":"org.kde.minimalist.resources","geometry":{"x":1879,"y":4,"width":283,"height":24},"userConfig":{},"presentUserConfigKeys":[]}}'
elif [[ $script == *MINIMALIST_FONT_PREFLIGHT* ]]; then
    count=$(( $(< "${MOCK_PREFLIGHT_COUNT:?}") + 1 ))
    printf '%s\n' "$count" > "$MOCK_PREFLIGHT_COUNT"
    [[ ${MOCK_TOCTOU_FAIL:-false} != true || $count -le 1 ]] || state=unknown
    [[ ${MOCK_UI_TOCTOU_FAIL:-false} != true || $count -le 1 ]] || ui_state=unknown
    if [[ $state == source ]]; then revisions='1 1 1'; family=Noto_Sans_Mono; else revisions='2 2 2'; family=Noto_Sans; fi
    if [[ $ui_state == source ]]; then
        ui_revisions='0 0 0'; ui_revision=0
    elif [[ $ui_state == target ]]; then
        ui_revisions='2 2 2'; ui_revision=2
    else
        ui_revisions='9 9 9'; ui_revision=unknown
    fi
    read -r active workspace resource <<< "$revisions"
    read -r active_ui workspace_ui resource_ui <<< "$ui_revisions"
    printf 'MINIMALIST_FONT_PREFLIGHT panelCount=1 topologyOk=true geometryOk=true anchorsReady=true projectGeometryOk=true customTypesKnown=true fontState=%s uiState=%s uiRevision=%s activeRevision=1 workspaceRevision=2 resourceRevision=2 activeFontRevision=%s workspaceFontRevision=%s resourceFontRevision=%s activeUiRevision=%s workspaceUiRevision=%s resourceUiRevision=%s clockFontFamily=%s widgets=mock\n' \
        "$state" "$ui_state" "$ui_revision" "$active" "$workspace" "$resource" \
        "$active_ui" "$workspace_ui" "$resource_ui" "$family"
    [[ $state == source || $state == target ]] \
        && [[ $ui_state == source || $ui_state == target ]] \
        && printf '%s\n' ' MINIMALIST_FONT_PREFLIGHT_OK'
    true
elif [[ $script == *MINIMALIST_FONT_LAYOUT_OK* ]]; then
    shopt -s nullglob
    complete=("${MOCK_TARGET_HOME:?}/.local/state/kde-rice/snapshots/"*/complete)
    ((${#complete[@]} > 0)) || exit 70
    printf 'target\n' > "$MOCK_FONT_STATE"
    printf 'target\n' > "$MOCK_UI_STATE"
    printf 'font policy applied\n' > "${MOCK_APPLETSRC:?}"
    printf 'MINIMALIST_FONT_LAYOUT_OK transition=refresh-project-widgets panelId=29 workspaceId=100 activeTitleId=101 resourceId=102 clockId=61\n'
elif [[ $script == *MINIMALIST_FONT_POSTCHECK* ]]; then
    if [[ ${MOCK_POSTCHECK_FAIL:-false} == true ]]; then
        printf 'MINIMALIST_FONT_POSTCHECK topologyOk=true geometryOk=true projectWidgetsOk=false projectGeometryOk=false clockOk=true widgets=mock\n'
    else
        printf 'MINIMALIST_FONT_POSTCHECK topologyOk=true geometryOk=true projectWidgetsOk=true projectGeometryOk=true clockOk=true widgets=mock\n'
        printf '%s\n' ' MINIMALIST_FONT_POSTCHECK_OK'
    fi
elif [[ $script == *MINIMALIST_FONT_RESTORE_POSTCHECK* ]]; then
    printf '%s\n' 'MINIMALIST_FONT_RESTORE_POSTCHECK topologyOk=true geometryOk=true preservedIdsOk=true projectPolicyOk=true userConfigRestored=true sourceGeometryRestored=true clockOk=true'
    printf '%s\n' ' MINIMALIST_FONT_RESTORE_POSTCHECK_OK'
elif [[ $script == *MINIMALIST_FONT_RESTORE_OK* ]]; then
    printf 'source\n' > "$MOCK_FONT_STATE"
    printf 'source\n' > "$MOCK_UI_STATE"
    printf 'MINIMALIST_FONT_RESTORE_OK workspaceId=200 activeTitleId=201 resourceId=202 clockId=61\n'
else
    exit 2
fi
MOCK
cat > "$MOCK_BIN/verify" <<'MOCK'
#!/usr/bin/env bash
[[ $* == *'--panel-target minimalist-v04-workspaces'* ]] || exit 2
[[ $* == *"--expected-desktops ${MOCK_EXPECTED_DESKTOPS:-4}"* ]] || exit 2
printf '%s\n' '{"schema_version":1,"status":"mismatch","checks":[{"name":"panel_topology","ok":true},{"name":"display_configuration_unchanged","ok":false}]}'
exit 1
MOCK
chmod +x "$MOCK_BIN/doctor" "$MOCK_BIN/qdbus6" "$MOCK_BIN/verify"

run_policy() {
    HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    KDE_RICE_TEST_MODE=1 KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    KDE_RICE_VERIFY_COMMAND="$MOCK_BIN/verify" KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    KDE_RICE_FONT_MATCH='Noto Sans' MOCK_TARGET_HOME="$TARGET_HOME" \
    MOCK_APPLETSRC="$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
    MOCK_FONT_STATE="$MOCK_STATE" MOCK_UI_STATE="$MOCK_UI_STATE" \
    MOCK_PREFLIGHT_COUNT="$MOCK_PREFLIGHT_COUNT" \
    "$APPLY_SCRIPT" "$@"
}

run_policy --dry-run > "$TEMP_ROOT/dry-run.txt"
grep -Fq 'selected Fedora family: Noto Sans' "$TEMP_ROOT/dry-run.txt" || fail "plan omitted font"
grep -Fq 'applet removals: exactly one active-title, one Workspaces, and one resource' \
    "$TEMP_ROOT/dry-run.txt" || fail "plan omitted exact applet removals"
[[ $(< "$MOCK_STATE") == source ]] || fail "dry-run changed live state"
[[ $(< "$MOCK_UI_STATE") == source ]] || fail "dry-run changed Chimera UI state"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "dry-run created transaction state"

run_policy --stage-next-login --expected-desktops 3 --dry-run > "$TEMP_ROOT/stage-preview.txt"
grep -Fq 'activation: the staged QML is loaded only by the next normal Plasma login' \
    "$TEMP_ROOT/stage-preview.txt" || fail "staging preview described the wrong operation"
grep -Fq 'Dry run only' "$TEMP_ROOT/stage-preview.txt" || fail "staging preview applied changes"
[[ $(< "$MOCK_STATE") == source && $(< "$MOCK_UI_STATE") == source ]] \
    || fail "staging preview changed live state"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "staging preview created transaction state"

printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
set +e
MOCK_UI_TOCTOU_FAIL=true run_policy --apply > "$TEMP_ROOT/ui-toctou.txt" 2>&1
ui_toctou_status=$?
set -e
[[ $ui_toctou_status == 1 ]] || fail "concurrent Chimera UI state was accepted"
[[ $(< "$MOCK_STATE") == source && $(< "$MOCK_UI_STATE") == source ]] \
    || fail "UI TOCTOU refusal changed live policy state"
grep -Fq 'panel or font state changed before the guarded live write' \
    "$TEMP_ROOT/ui-toctou.txt" || fail "UI TOCTOU refusal reason was omitted"
if [[ -d $TARGET_HOME/.local/state/kde-rice ]]; then
    mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/ui-toctou-state"
fi
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"

run_policy --apply > "$TEMP_ROOT/apply.txt"
[[ $(< "$MOCK_STATE") == target ]] || fail "apply did not reach target"
[[ $(< "$MOCK_UI_STATE") == target ]] || fail "apply did not reach Chimera UI target"
for pair in \
    "plasmoids/org.kde.minimalist.activewindowtitle .local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle" \
    "plasmoids/org.kde.minimalist.workspaces .local/share/plasma/plasmoids/org.kde.minimalist.workspaces" \
    "plasmoids/org.kde.minimalist.resources .local/share/plasma/plasmoids/org.kde.minimalist.resources"; do
    read -r source target <<< "$pair"
    diff -qr -- "$REPO_ROOT/$source" "$TARGET_HOME/$target" >/dev/null || fail "installed package differs: $target"
done
grep -Fq 'MINIMALIST_FONT_POSTCHECK_OK' "$TEMP_ROOT/apply.txt" || fail "postcheck marker missing"
snapshot=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt" | tail -n 1)
[[ -f $snapshot/complete ]] || fail "complete snapshot missing"

if [[ -d $TARGET_HOME/.local/state/kde-rice ]]; then
    mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/success-state"
fi
for package in org.kde.minimalist.activewindowtitle org.kde.minimalist.workspaces org.kde.minimalist.resources; do
    rm -rf -- "$TARGET_HOME/.local/share/plasma/plasmoids/$package"
    mkdir -p -- "$TARGET_HOME/.local/share/plasma/plasmoids/$package"
    printf 'old %s\n' "$package" > "$TARGET_HOME/.local/share/plasma/plasmoids/$package/old.txt"
done
rm -rf -- "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04"
mkdir -p -- "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents"
printf 'old layout again\n' > "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt"
printf 'pre-failure panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'source\n' > "$MOCK_STATE"
printf 'source\n' > "$MOCK_UI_STATE"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
set +e
MOCK_POSTCHECK_FAIL=true run_policy --apply > "$TEMP_ROOT/failure.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "failed postcheck did not fail transaction"
[[ $(< "$MOCK_STATE") == source ]] || fail "failure did not reload source live"
[[ $(< "$MOCK_UI_STATE") == source ]] || fail "failure did not reload source Chimera UI"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'pre-failure panel config' ]] \
    || fail "failure did not restore panel config"
for package in org.kde.minimalist.activewindowtitle org.kde.minimalist.workspaces org.kde.minimalist.resources; do
    [[ -f $TARGET_HOME/.local/share/plasma/plasmoids/$package/old.txt ]] || fail "failure did not restore $package"
done
grep -Fq 'the three snapshotted project packages and prior clock family were reloaded and verified live' \
    "$TEMP_ROOT/failure.txt" || fail "failure omitted verified live reload confirmation"

printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
MOCK_EXPECTED_DESKTOPS=3 run_policy --stage-next-login --expected-desktops 3 > "$TEMP_ROOT/stage.txt"
[[ $(< "$MOCK_STATE") == source && $(< "$MOCK_UI_STATE") == source ]] \
    || fail "next-login staging changed live policy state"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'pre-failure panel config' ]] \
    || fail "next-login staging changed the live panel config"
for pair in \
    "plasmoids/org.kde.minimalist.activewindowtitle .local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle" \
    "plasmoids/org.kde.minimalist.workspaces .local/share/plasma/plasmoids/org.kde.minimalist.workspaces" \
    "plasmoids/org.kde.minimalist.resources .local/share/plasma/plasmoids/org.kde.minimalist.resources" \
    "layouts/plasma/org.kde.minimalist-v04 .local/share/plasma/layout-templates/org.kde.minimalist-v04"; do
    read -r source target <<< "$pair"
    diff -qr -- "$REPO_ROOT/$source" "$TARGET_HOME/$target" >/dev/null \
        || fail "next-login staging differs from source: $target"
done
grep -Fq 'expected virtual desktops: 3 (verification only; KWin count is preserved)' \
    "$TEMP_ROOT/stage.txt" || fail "staging plan omitted the accepted desktop count"
grep -Fq 'Minimalist panel font policy mode: STAGE NEXT LOGIN' \
    "$TEMP_ROOT/stage.txt" || fail "next-login staging mode was not reported"
grep -Fq 'applet removals/additions: none' "$TEMP_ROOT/stage.txt" \
    || fail "next-login staging plan did not preserve live applets"
grep -Fq 'live applet IDs, revisions, settings, geometry, and clock remain unchanged' \
    "$TEMP_ROOT/stage.txt" || fail "next-login staging result omitted its live boundary"
if grep -Fq 'MINIMALIST_FONT_LAYOUT_OK' "$TEMP_ROOT/stage.txt"; then
    fail "next-login staging invoked the live writer"
fi

printf 'PASS: guarded Noto Sans panel-font policy tests\n'
