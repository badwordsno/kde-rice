#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$TEST_DIR/lib/runtime.sh"
require_test_node
require_test_qmllint
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-minimalist-v02.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-minimalist-v02.*)
            rm -rf -- "$TEMP_ROOT"
            ;;
        *)
            printf 'refusing to clean unexpected test directory: %s\n' "$TEMP_ROOT" >&2
            ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v02"
SCRIPT="$LAYOUT/contents/layout.js"
PREFLIGHT_SCRIPT="$LAYOUT/contents/preflight.js"
POSTCHECK_SCRIPT="$LAYOUT/contents/postcheck.js"
APPLY_SCRIPT="$REPO_ROOT/scripts/apply-minimalist-v02"
TITLE_PLASMOID="$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle"
TITLE_QML="$TITLE_PLASMOID/contents/ui/main.qml"
TARGET_HOME="$TEMP_ROOT/home"
TARGET_RELATIVE=".local/share/plasma/layout-templates/org.kde.minimalist-v02"
TITLE_TARGET_RELATIVE=".local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle"

grep -Fq '"KPackageStructure": "Plasma/LayoutTemplate"' "$LAYOUT/metadata.json" || fail "layout package structure metadata is missing"
grep -Fq '"Id": "org.kde.minimalist-v02"' "$LAYOUT/metadata.json" || fail "layout package ID is wrong"
grep -Fq 'const baselineWidgets = [' "$SCRIPT" || fail "v0.1 topology guard is missing"
grep -Fq 'const targetWidgets = [' "$SCRIPT" || fail "v0.2 topology guard is missing"
grep -Fq 'const spacerRecoveryWidgets = [' "$SCRIPT" || fail "v0.2 spacer recovery guard is missing"
grep -Fq 'const titleRecoveryWidgets = [' "$SCRIPT" || fail "v0.2 title recovery guard is missing"
grep -Fq 'knownWidgetTypes.indexOf("org.kde.plasma.panelspacer")' "$SCRIPT" || fail "built-in spacer availability guard is missing"
grep -Fq 'pager.remove();' "$SCRIPT" || fail "pager transition is missing"
grep -Fq 'tasks.remove();' "$SCRIPT" || fail "icon-task transition is missing"
grep -Fq 'showDesktop.remove();' "$SCRIPT" || fail "show-desktop transition is missing"
grep -Fq '"org.kde.plasma.panelspacer",' "$SCRIPT" || fail "built-in flexible spacer is not added"
grep -Fq 'position.x,' "$SCRIPT" || fail "Plasma 6.7 position hint is missing"
grep -Fq 'orderedWidgetTypes(panel)' "$SCRIPT" || fail "AppletOrder topology check is missing"
grep -Fq 'if (orderIds.length !== widgets.length)' "$SCRIPT" "$PREFLIGHT_SCRIPT" || fail "strict AppletOrder validation is missing"
grep -Fq 'spacer.writeConfig("expanding", true);' "$SCRIPT" || fail "spacer is not flexible"
grep -Fq 'clock.writeConfig("showDate", false);' "$SCRIPT" || fail "clock date-hidden policy is missing"
grep -Fq 'clock.writeConfig("showSeconds", 2);' "$SCRIPT" || fail "clock seconds policy is missing"
grep -Fq 'clock.writeConfig("autoFontAndSize", true);' "$SCRIPT" || fail "clock automatic-font policy is missing"
if grep -Eq 'clock\.writeConfig\("(dateDisplayFormat|dateFormat|customDateFormat)"' "$SCRIPT"; then
    fail "hidden date preferences must remain user-owned"
fi
grep -Fq 'panel.height = 32;' "$SCRIPT" || fail "v0.2 strip height changed"
grep -Fq 'panel.lengthMode = "fill";' "$SCRIPT" || fail "v0.2 strip is not full width"
grep -Fq 'panel.opacity = "opaque";' "$SCRIPT" || fail "v0.2 strip is not opaque"
grep -Fq 'MINIMALIST_V02_STATUS_STRIP_OK' "$SCRIPT" || fail "layout success marker is missing"
grep -Fq 'MINIMALIST_V02_PREFLIGHT_OK' "$PREFLIGHT_SCRIPT" || fail "live preflight marker is missing"
grep -Fq 'MINIMALIST_V02_POSTCHECK_OK' "$POSTCHECK_SCRIPT" || fail "live post-check marker is missing"
grep -Fq 'AppletOrder' "$PREFLIGHT_SCRIPT" "$POSTCHECK_SCRIPT" || fail "live checks do not use the visible panel order"
grep -Fq '"KPackageStructure": "Plasma/Applet"' "$TITLE_PLASMOID/metadata.json" || fail "active-title package structure metadata is missing"
grep -Fq '"Id": "org.kde.minimalist.activewindowtitle"' "$TITLE_PLASMOID/metadata.json" || fail "active-title package ID is wrong"
grep -Fq 'TaskManager.TasksModel' "$TITLE_QML" || fail "active-title tasks model is missing"
grep -Fq 'tasksModel.activeTask' "$TITLE_QML" || fail "active-title model does not follow the active task"
grep -Fq 'tasksModel.data(activeIndex, 0)' "$TITLE_QML" || fail "active-title model does not read the window title"
grep -Fq 'preferredTitleWidth: Kirigami.Units.gridUnit * 18' "$TITLE_QML" || fail "active-title normal width changed"
grep -Fq 'elide: Text.ElideRight' "$TITLE_QML" || fail "active-title ellipsis policy is missing"
grep -Fq 'font.family: "Noto Sans"' "$TITLE_QML" || fail "active-title panel font changed"
grep -Fq 'activeTitle.writeConfig("packageRevision", activeTitleRevision);' "$SCRIPT" || fail "active-title package revision is not managed"

if grep -Eq 'new[[:space:]]+Panel|\.location[[:space:]]*=[[:space:]]*"(left|right|bottom)"' "$SCRIPT"; then
    fail "v0.2 layout may create a panel or move it away from the top edge"
fi
if grep -Eq 'kglobalshortcuts|globalShortcut|kwinoutputconfig|\.local/share/kscreen|plasma-apply-wallpaperimage|applywindowdecoration' "$SCRIPT" "$PREFLIGHT_SCRIPT" "$POSTCHECK_SCRIPT" "$APPLY_SCRIPT"; then
    fail "v0.2 apply path may change shortcuts, KWin, display, wallpaper, or decoration"
fi

expected_target_widgets=(
    org.kde.plasma.kickoff
    org.kde.minimalist.activewindowtitle
    org.kde.plasma.panelspacer
    org.kde.plasma.marginsseparator
    org.kde.plasma.kimpanel
    org.kde.plasma.systemtray
    org.kde.plasma.digitalclock
)
for widget in "${expected_target_widgets[@]}"; do
    grep -Fq "\"$widget\"" "$SCRIPT" || fail "v0.2 widget guard is missing: $widget"
done

grep -Fxq "$TARGET_RELATIVE" "$REPO_ROOT/config/managed-paths.txt" || fail "v0.2 layout package is outside the managed boundary"
grep -Fxq "$TITLE_TARGET_RELATIVE" "$REPO_ROOT/config/managed-paths.txt" || fail "active-title package is outside the managed boundary"
grep -Fxq '.config/plasma-org.kde.plasma.desktop-appletsrc' "$REPO_ROOT/config/managed-paths.txt" || fail "panel topology is outside the snapshot boundary"
grep -Fxq '.config/plasmashellrc' "$REPO_ROOT/config/managed-paths.txt" || fail "panel view is outside the snapshot boundary"

"$QMLLINT_BIN" -I "$QML_IMPORT_ROOT" "$TITLE_QML" \
    || fail "active-title QML validation failed"
"$NODE_BIN" - "$SCRIPT" "$PREFLIGHT_SCRIPT" "$POSTCHECK_SCRIPT" <<'NODE'
const fs = require("fs");
const vm = require("vm");

const script = fs.readFileSync(process.argv[2], "utf8");
const preflightScript = fs.readFileSync(process.argv[3], "utf8");
const postcheckScript = fs.readFileSync(process.argv[4], "utf8");
const baseline = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const legacyTarget = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const preTitleTarget = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const target = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const spacerRecovery = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop",
    "org.kde.plasma.panelspacer"
];
const titleRecovery = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.minimalist.activewindowtitle"
];
const creationTarget = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.activewindowtitle"
];

function assert(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

function assertClockPolicy(widget, label) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["Appearance"];
    const expected = {
        showDate: false,
        showSeconds: 2,
        use24hFormat: 2,
        autoFontAndSize: true
    };
    for (const [key, value] of Object.entries(expected)) {
        assert(widget.readConfig(key, null) === value, label + ": clock " + key + " policy differs");
    }
    widget.currentConfigGroup = previousGroup;
}

function makePanel(types) {
    let panelConfigGroup = [];
    const panelConfig = new Map();
    const panel = {
        id: 2,
        screen: 0,
        formFactor: "horizontal",
        location: "top",
        height: 28,
        lengthMode: "fill",
        alignment: "center",
        offset: 0,
        hiding: "none",
        floating: false,
        opacity: "opaque",
        _widgets: [],
        _order: []
    };

    let nextId = 100;
    function makeWidget(type) {
        let configGroup = [];
        const config = new Map();
        return {
            id: nextId++,
            type,
            get geometry() {
                const visualIndex = panel._order.indexOf(this.id);
                return {
                    x: 3 + Math.max(visualIndex, 0) * 30,
                    y: 3,
                    width: 22,
                    height: 22
                };
            },
            get index() {
                return -1;
            },
            set index(value) {},
            set currentConfigGroup(value) {
                configGroup = value.slice();
            },
            get currentConfigGroup() {
                return configGroup.slice();
            },
            writeConfig(key, value) {
                config.set(configGroup.join("/") + "/" + key, value);
            },
            readConfig(key, fallback) {
                const fullKey = configGroup.join("/") + "/" + key;
                return config.has(fullKey) ? config.get(fullKey) : fallback;
            },
            reloadConfig() {},
            remove() {
                const index = panel._widgets.indexOf(this);
                if (index !== -1) {
                    panel._widgets.splice(index, 1);
                }
                const orderIndex = panel._order.indexOf(this.id);
                if (orderIndex !== -1) {
                    panel._order.splice(orderIndex, 1);
                }
            }
        };
    }

    panel._widgets = types.map(makeWidget);
    panel._order = panel._widgets.map((widget) => widget.id);
    Object.defineProperty(panel, "currentConfigGroup", {
        get() {
            return panelConfigGroup.slice();
        },
        set(value) {
            panelConfigGroup = value.slice();
        }
    });
    panel.readConfig = function (key, fallback) {
        if (panelConfigGroup.join("/") === "General" && key === "AppletOrder") {
            return this._order.join(";");
        }
        const fullKey = panelConfigGroup.join("/") + "/" + key;
        return panelConfig.has(fullKey) ? panelConfig.get(fullKey) : fallback;
    };
    panel.writeConfig = function (key, value) {
        panelConfig.set(panelConfigGroup.join("/") + "/" + key, value);
    };
    panel.reloadConfig = function () {};
    panel.widgets = function (type) {
        return type ? this._widgets.filter((widget) => widget.type === type) : this._widgets.slice();
    };
    panel.widgetById = function (id) {
        return this._widgets.find((widget) => widget.id === Number(id)) || null;
    };
    panel.orderedWidgets = function () {
        return this._order.map((id) => this.widgetById(id)).filter(Boolean);
    };
    panel.addWidget = function (type, x) {
        const widget = makeWidget(type);
        this._widgets.push(widget);
        let orderIndex = this._order.length;
        if (typeof x === "number") {
            const launcher = this._widgets.find((candidate) => candidate.type === "org.kde.plasma.kickoff");
            if (launcher && x <= launcher.geometry.x + launcher.geometry.width + 1) {
                orderIndex = this._order.indexOf(launcher.id) + 1;
            }
        }
        this._order.splice(orderIndex, 0, widget.id);
        return widget;
    };
    return panel;
}

function runSource(source, panel) {
    const output = [];
    const context = {
        panelIds: [panel.id],
        panelById: (id) => id === panel.id ? panel : null,
        knownWidgetTypes: target.concat([
            "org.kde.plasma.pager",
            "org.kde.plasma.icontasks",
            "org.kde.plasma.showdesktop"
        ]),
        screenGeometry: () => ({width: 2400, height: 1350}),
        print: (value) => output.push(String(value))
    };
    vm.runInNewContext(source, context);
    return output.join("\n");
}

function run(panel) {
    return runSource(script, panel);
}

const panel = makePanel(baseline);
const first = run(panel);
assert(first.includes("transition=v0.1-to-v0.2"), "baseline transition was not reported");
assert(JSON.stringify(panel.orderedWidgets().map((widget) => widget.type)) === JSON.stringify(target), "target visible widget order is wrong");
assert(JSON.stringify(panel.widgets().map((widget) => widget.type)) === JSON.stringify(creationTarget), "harness no longer models Plasma 6.7 creation order");
assert(panel.widgets("org.kde.plasma.showdesktop").length === 0, "baseline transition left show-desktop on the panel");
const activeTitle = panel.widgets("org.kde.minimalist.activewindowtitle")[0];
activeTitle.currentConfigGroup = ["General"];
assert(activeTitle.readConfig("packageRevision", 0) === 1, "active-title package revision was not written");
const spacer = panel.widgets("org.kde.plasma.panelspacer")[0];
spacer.currentConfigGroup = ["General"];
assert(spacer.readConfig("expanding", false) === true, "spacer is not expanding");
assertClockPolicy(panel.widgets("org.kde.plasma.digitalclock")[0], "v0.2 transition");
assert(panel.height === 32 && panel.lengthMode === "fill" && panel.opacity === "opaque", "panel target geometry is wrong");
const second = run(panel);
assert(second.includes("transition=already-target"), "v0.2 apply is not idempotent");
assert(JSON.stringify(panel.orderedWidgets().map((widget) => widget.type)) === JSON.stringify(target), "idempotent apply changed widget order");

const preflight = runSource(preflightScript, panel);
assert(preflight.includes("topology=v0.2"), "preflight did not read AppletOrder");
assert(preflight.includes("MINIMALIST_V02_PREFLIGHT_OK"), "target preflight failed");
const postcheck = runSource(postcheckScript, panel);
assert(postcheck.includes("MINIMALIST_V02_POSTCHECK_OK"), "target post-check failed");
const clock = panel.widgets("org.kde.plasma.digitalclock")[0];
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showSeconds", 1);
clock.currentConfigGroup = [];
assert(!runSource(postcheckScript, panel).includes("MINIMALIST_V02_POSTCHECK_OK"),
    "postcheck accepted clock seconds that are not always visible");
run(panel);
assertClockPolicy(clock, "v0.2 clock repair");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showSeconds", "Always");
clock.currentConfigGroup = [];
assert(runSource(postcheckScript, panel).includes("MINIMALIST_V02_POSTCHECK_OK"),
    "postcheck rejected Plasma's canonical showSeconds enum name");

const legacy = makePanel(legacyTarget);
const legacyPreflight = runSource(preflightScript, legacy);
assert(legacyPreflight.includes("topology=v0.2-show-desktop"), "legacy v0.2 preflight topology was not reported");
assert(legacyPreflight.includes("MINIMALIST_V02_PREFLIGHT_OK"), "legacy v0.2 preflight failed");
const migrated = run(legacy);
assert(migrated.includes("transition=remove-show-desktop"), "legacy v0.2 transition was not reported");
assert(JSON.stringify(legacy.orderedWidgets().map((widget) => widget.type)) === JSON.stringify(target), "legacy v0.2 transition changed the target order");
assert(legacy.widgets("org.kde.plasma.showdesktop").length === 0, "legacy v0.2 transition left show-desktop on the panel");

const preTitle = makePanel(preTitleTarget);
const titleAdded = run(preTitle);
assert(titleAdded.includes("transition=add-active-window-title"), "active-title transition was not reported");
assert(JSON.stringify(preTitle.orderedWidgets().map((widget) => widget.type)) === JSON.stringify(target), "active title was not inserted after the launcher");

const interruptedSpacer = makePanel(spacerRecovery);
const repairedSpacer = run(interruptedSpacer);
assert(repairedSpacer.includes("transition=repair-v0.2-spacer-order"), "interrupted spacer transition was not repaired");
assert(JSON.stringify(interruptedSpacer.orderedWidgets().map((widget) => widget.type)) === JSON.stringify(target), "spacer recovery did not reach the target");
assert(interruptedSpacer.widgets("org.kde.plasma.panelspacer").length === 1, "spacer recovery left duplicate spacers");
assert(interruptedSpacer.widgets("org.kde.plasma.showdesktop").length === 0, "spacer recovery left show-desktop on the panel");

const interruptedTitle = makePanel(titleRecovery);
const repairedTitle = run(interruptedTitle);
assert(repairedTitle.includes("transition=repair-v0.2-title-order"), "interrupted title transition was not repaired");
assert(JSON.stringify(interruptedTitle.orderedWidgets().map((widget) => widget.type)) === JSON.stringify(target), "title recovery did not reach the target");
assert(interruptedTitle.widgets("org.kde.minimalist.activewindowtitle").length === 1, "title recovery left duplicate title widgets");

const foreign = makePanel(baseline.concat(["org.example.foreign"]));
let refused = false;
try {
    run(foreign);
} catch (error) {
    refused = String(error).includes("panel topology differs");
}
assert(refused, "unapproved topology was not refused");
assert(JSON.stringify(foreign.widgets().map((widget) => widget.type)) === JSON.stringify(baseline.concat(["org.example.foreign"])), "refused topology was mutated");

const malformed = makePanel(baseline);
malformed._order = [];
const malformedBefore = JSON.stringify(malformed.widgets().map((widget) => widget.type));
const malformedPreflight = runSource(preflightScript, malformed);
assert(!malformedPreflight.includes("MINIMALIST_V02_PREFLIGHT_OK"), "malformed AppletOrder passed preflight");
let malformedRefused = false;
try {
    run(malformed);
} catch (error) {
    malformedRefused = String(error).includes("panel topology differs");
}
assert(malformedRefused, "malformed AppletOrder was not refused");
assert(JSON.stringify(malformed.widgets().map((widget) => widget.type)) === malformedBefore, "malformed AppletOrder was mutated");
NODE

mkdir -p -- "$TARGET_HOME/.config"
printf 'baseline-kdeglobals\n' > "$TARGET_HOME/.config/kdeglobals"
printf 'baseline-panel\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'baseline-shell-view\n' > "$TARGET_HOME/.config/plasmashellrc"
printf 'baseline-kwin\n' > "$TARGET_HOME/.config/kwinrc"
printf 'baseline-shortcuts\n' > "$TARGET_HOME/.config/kglobalshortcutsrc"
printf 'baseline-output\n' > "$TARGET_HOME/.config/kwinoutputconfig.json"

display_before=$(sha256sum "$TARGET_HOME/.config/kwinoutputconfig.json")
kwin_before=$(sha256sum "$TARGET_HOME/.config/kwinrc")
shortcuts_before=$(sha256sum "$TARGET_HOME/.config/kglobalshortcutsrc")
panel_before=$(sha256sum "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc")
shell_before=$(sha256sum "$TARGET_HOME/.config/plasmashellrc")

bash "$APPLY_SCRIPT" --home "$TARGET_HOME" --install-only --dry-run > "$TEMP_ROOT/dry-run.txt"
[[ ! -e $TARGET_HOME/.local ]] || fail "v0.2 dry run wrote to the target home"

if bash "$APPLY_SCRIPT" --home "$TARGET_HOME" --dry-run > "$TEMP_ROOT/foreign-live.txt" 2>&1; then
    fail "v0.2 allowed live activation for a foreign home"
fi

bash "$APPLY_SCRIPT" --home "$TARGET_HOME" --install-only --apply > "$TEMP_ROOT/apply.txt"
snapshot_path=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt")
installed="$TARGET_HOME/$TARGET_RELATIVE"
installed_title="$TARGET_HOME/$TITLE_TARGET_RELATIVE"

[[ -n $snapshot_path && -f $snapshot_path/complete ]] || fail "v0.2 did not record a complete pre-apply snapshot"
[[ -f $snapshot_path/payload/.config/plasma-org.kde.plasma.desktop-appletsrc ]] || fail "v0.2 snapshot omitted panel topology"
[[ ! -e $snapshot_path/payload/.config/kwinoutputconfig.json ]] || fail "v0.2 snapshot captured display configuration"
diff -qr -- "$LAYOUT" "$installed" >/dev/null || fail "installed v0.2 layout differs from source"
diff -qr -- "$TITLE_PLASMOID" "$installed_title" >/dev/null || fail "installed active-title package differs from source"
[[ $(sha256sum "$TARGET_HOME/.config/kwinoutputconfig.json") == "$display_before" ]] || fail "v0.2 changed display configuration"
[[ $(sha256sum "$TARGET_HOME/.config/kwinrc") == "$kwin_before" ]] || fail "v0.2 changed KWin configuration"
[[ $(sha256sum "$TARGET_HOME/.config/kglobalshortcutsrc") == "$shortcuts_before" ]] || fail "v0.2 changed global shortcuts"
[[ $(sha256sum "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == "$panel_before" ]] || fail "install-only changed panel topology"
[[ $(sha256sum "$TARGET_HOME/.config/plasmashellrc") == "$shell_before" ]] || fail "install-only changed panel view geometry"

bash "$REPO_ROOT/scripts/restore" --backup "$snapshot_path" --home "$TARGET_HOME" --state-root "$TARGET_HOME/.local/state/kde-rice/test-restore" --apply > "$TEMP_ROOT/restore.txt"
[[ ! -e $installed ]] || fail "restore left the v0.2 layout package installed"
[[ ! -e $installed_title ]] || fail "restore left the active-title package installed"
[[ $(sha256sum "$TARGET_HOME/.config/kwinoutputconfig.json") == "$display_before" ]] || fail "restore changed display configuration"
[[ $(sha256sum "$TARGET_HOME/.config/kwinrc") == "$kwin_before" ]] || fail "restore changed KWin baseline"
[[ $(sha256sum "$TARGET_HOME/.config/kglobalshortcutsrc") == "$shortcuts_before" ]] || fail "restore changed shortcut baseline"
[[ $(sha256sum "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == "$panel_before" ]] || fail "restore changed panel baseline"
[[ $(sha256sum "$TARGET_HOME/.config/plasmashellrc") == "$shell_before" ]] || fail "restore changed panel-view baseline"

printf 'PASS: Minimalist v0.2 status-strip tests\n'
