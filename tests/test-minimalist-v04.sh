#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$SCRIPT_DIR/lib/runtime.sh"
require_test_node
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-minimalist-v04.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-minimalist-v04.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing unsafe cleanup: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v04"
ACTIVE="$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle"
RESOURCE="$REPO_ROOT/plasmoids/org.kde.minimalist.resources"
WORKSPACE="$REPO_ROOT/plasmoids/org.kde.minimalist.workspaces"
APPLY_SCRIPT="$REPO_ROOT/scripts/apply-minimalist-v04"
TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
mkdir -p -- "$TARGET_HOME/.config" "$TARGET_HOME/.local/share" \
    "$TARGET_HOME/.local/state" "$MOCK_BIN"

for script in preflight.js stage-spacer.js layout.js cleanup.js postcheck.js; do
    "$NODE_BIN" --check "$LAYOUT/contents/$script" >/dev/null
done
bash -n "$APPLY_SCRIPT"

grep -Fq '"Id": "org.kde.minimalist-v04"' "$LAYOUT/metadata.json" \
    || fail "v0.4.1 layout package ID is wrong"
grep -Fq 'const taskType = "org.kde.plasma.icontasks";' \
    "$LAYOUT/contents/layout.js" || fail "native Icons-only Task Manager ID is missing"
grep -Fq 'writeGeneralConfig(widget, "fill", false);' \
    "$LAYOUT/contents/layout.js" || fail "compact task fill policy is missing"
grep -Fq 'writeGeneralConfig(widget, "maxStripes", 1);' \
    "$LAYOUT/contents/layout.js" || fail "single-row task policy is missing"
grep -Fq 'writeGeneralConfig(widget, "iconSpacing", 0);' \
    "$LAYOUT/contents/layout.js" || fail "small icon-spacing policy is missing"
grep -Fq 'writeGeneralConfig(widget, "expanding", true);' \
    "$LAYOUT/contents/layout.js" || fail "expanding spacer policy is missing"
grep -Fq 'widget.writeConfig("showDate", false);' \
    "$LAYOUT/contents/layout.js" || fail "clock date-hidden policy is missing"
grep -Fq 'widget.writeConfig("showSeconds", 2);' \
    "$LAYOUT/contents/layout.js" || fail "clock seconds policy is missing"
grep -Fq 'widget.writeConfig("use24hFormat", 2);' \
    "$LAYOUT/contents/layout.js" || fail "clock 24-hour policy is missing"
if grep -Eq 'widget\.writeConfig\("(dateDisplayFormat|dateFormat|customDateFormat)"' \
    "$LAYOUT/contents/layout.js"; then
    fail "hidden date preferences must remain user-owned"
fi
grep -Fq 'widget.writeConfig("autoFontAndSize", false);' \
    "$LAYOUT/contents/layout.js" || fail "clock custom-font policy is missing"
grep -Fq 'widget.writeConfig("fontFamily", "Noto Sans");' \
    "$LAYOUT/contents/layout.js" || fail "clock font-family policy is missing"
grep -Fq 'widget.writeConfig("fontSize", 11);' \
    "$LAYOUT/contents/layout.js" || fail "clock font-size policy is missing"
grep -Fq 'widget.writeConfig("fontStyleName", "Regular");' \
    "$LAYOUT/contents/layout.js" || fail "clock font-style policy is missing"
grep -Fq 'widget.writeConfig("fontWeight", 400);' \
    "$LAYOUT/contents/layout.js" || fail "clock font-weight policy is missing"
if rg -n 'writeConfig\("AppletOrder"|\.index[[:space:]]*=' \
    "$LAYOUT/contents" >/dev/null; then
    fail "v0.4.1 package relies on an ineffective live AppletOrder/index reorder"
fi
grep -Fq 'MINIMALIST_V04_POSTCHECK_OK' "$LAYOUT/contents/postcheck.js" \
    || fail "v0.4.1 postcheck marker is missing"
grep -Fq 'require_component_diagnosis "$DOCTOR_COMMAND" minimalist-v04' "$APPLY_SCRIPT" \
    || fail "v0.4.1 apply does not request the v0.4.1 doctor target"
grep -Fq 'capture_or_reuse_snapshot' "$APPLY_SCRIPT" \
    || fail "v0.4.1 apply no longer preserves transaction snapshot reuse"
grep -Fxq '.local/share/plasma/layout-templates/org.kde.minimalist-v04' \
    "$REPO_ROOT/config/managed-paths.txt" || fail "v0.4.1 layout target is unmanaged"
grep -Fxq '.local/share/plasma/plasmoids/org.kde.minimalist.resources' \
    "$REPO_ROOT/config/managed-paths.txt" || fail "resource Plasmoid target is unmanaged"
grep -Fxq '.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle' \
    "$REPO_ROOT/config/managed-paths.txt" || fail "active-title Plasmoid target is unmanaged"
grep -Fxq '.local/share/plasma/plasmoids/org.kde.minimalist.workspaces' \
    "$REPO_ROOT/config/managed-paths.txt" || fail "Workspaces Plasmoid target is unmanaged"

if rg -n '(readConfig|writeConfig)\("launchers"' "$LAYOUT" >/dev/null; then
    fail "v0.4.1 package reads or writes the user-owned pinned application list"
fi
if rg -n 'new Panel|removePanel|globalShortcut|kwinoutputconfig|share/kscreen' \
    "$LAYOUT" "$APPLY_SCRIPT" >/dev/null; then
    fail "v0.4.1 implementation crosses its panel, shortcut, or display boundary"
fi
if rg -n '\.remove\(' "$LAYOUT/contents/preflight.js" \
    "$LAYOUT/contents/stage-spacer.js" "$LAYOUT/contents/layout.js" \
    "$LAYOUT/contents/postcheck.js" >/dev/null; then
    fail "v0.4.1 removes a widget outside its exact rollback script"
fi
if rg -n '(^|[[:space:]])(sudo|pkexec|pacman|dnf|apt-get|killall|pkill|systemctl)[[:space:]]' \
    "$APPLY_SCRIPT" >/dev/null; then
    fail "v0.4.1 apply contains a privileged, package, or restart command"
fi

# Move the clock near the front in a disposable contract to exercise every
# generated role index without changing the checked-in desktop topology.
python3 - "$REPO_ROOT" "$TEMP_ROOT/reordered" <<'PY'
import json
import shutil
import subprocess
import sys
from pathlib import Path
repo, target = map(Path, sys.argv[1:])
for relative in ("design/panel", "layouts/plasma/org.kde.minimalist-v04/contents"):
    shutil.copytree(repo / relative, target / relative)
contract_path = target / "design/panel/v04.json"
contract = json.loads(contract_path.read_text())
for sequence in contract["sequences"].values():
    sequence.remove("clock")
    sequence.insert(sequence.index("launcher") + 1, "clock")
contract_path.write_text(json.dumps(contract))
subprocess.run([str(repo / "scripts/sync-panel-contract"), "--write", "--source", str(target)], check=True)
subprocess.run([str(repo / "scripts/sync-panel-contract"), "--check", "--source", str(target)], check=True)
PY

"$NODE_BIN" - "$LAYOUT" "$TEMP_ROOT/reordered/layouts/plasma/org.kde.minimalist-v04" <<'NODE'
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const layoutRoot = process.argv[2];
const reorderedRoot = process.argv[3];
const spacerType = "org.kde.plasma.panelspacer";
const taskType = "org.kde.plasma.icontasks";
const resourceType = "org.kde.minimalist.resources";
const pagerType = "org.kde.plasma.pager";
const workspaceType = "org.kde.minimalist.workspaces";
const v03Types = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const stagedTypes = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const taskFrontStagedTypes = [
    taskType,
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const v04Types = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    taskType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const pagerTypes = [
    "org.kde.plasma.kickoff",
    pagerType,
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    taskType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const workspacesTypes = [
    "org.kde.plasma.kickoff",
    workspaceType,
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    taskType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const pinnedSentinel = ["applications:org.example.user-owned.desktop"];

function assert(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

function makeWidget(type, id, geometry, initialConfig = {}) {
    const config = Object.assign({}, initialConfig);
    if (type === taskType && !("General:launchers" in config)) {
        config["General:launchers"] = pinnedSentinel.slice();
    }
    return {
        id,
        type,
        geometry,
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
            return Object.prototype.hasOwnProperty.call(this.config, composite)
                ? this.config[composite]
                : fallback;
        },
        reloadConfig() {}
    };
}

function createPanel(types, options = {}) {
    let nextId = 1;
    const widgets = [];
    const byId = {};
    for (let index = 0; index < types.length; ++index) {
        const type = types[index];
        const config = {};
        if (type === spacerType) {
            config["General:expanding"] = options.spacersExpanding ?? false;
        }
        if (type === resourceType) {
            config["General:packageRevision"] = options.resourceRevision ?? 0;
        }
        if (type === pagerType) {
            config["General:displayedText"] = options.pagerDisplayedText ?? 3;
            config["General:showWindowOutlines"] = options.pagerShowWindowOutlines ?? true;
            config["General:showWindowIcons"] = options.pagerShowWindowIcons ?? true;
        }
        if (type === workspaceType) {
            config["General:packageRevision"] = options.workspaceRevision ?? 0;
        }
        if (type === taskType) {
            config["General:fill"] = options.taskFill ?? true;
            config["General:maxStripes"] = options.taskMaxStripes ?? 3;
            config["General:iconSpacing"] = options.taskIconSpacing ?? 3;
            config["General:launchers"] = (options.pinned || pinnedSentinel).slice();
            config["General:userBehavior"] = options.userBehavior ?? "preserve-me";
        }
        if (type === "org.kde.plasma.digitalclock") {
            config["Appearance:showDate"] = options.clockShowDate ?? false;
            config["Appearance:showSeconds"] = options.clockShowSeconds ?? 0;
            config["Appearance:use24hFormat"] = options.clockUse24hFormat ?? 0;
            config["Appearance:dateDisplayFormat"] = options.clockDateDisplayFormat ?? 2;
            config["Appearance:dateFormat"] = options.clockDateFormat ?? "shortDate";
            config["Appearance:customDateFormat"] = options.clockCustomDateFormat ?? "yyyy-MM-dd";
            config["Appearance:autoFontAndSize"] = options.clockAutoFontAndSize ?? false;
            config["Appearance:fontFamily"] = options.clockFontFamily ?? "User Fixed Font";
            config["Appearance:fontSize"] = options.clockFontSize ?? 17;
        }
        const widget = makeWidget(
            type,
            nextId++,
            {x: index * 100, y: 0, width: 80, height: 28},
            config
        );
        widgets.push(widget);
        byId[String(widget.id)] = widget;
        widget.remove = () => {
            const widgetIndex = widgets.indexOf(widget);
            if (widgetIndex !== -1) {
                widgets.splice(widgetIndex, 1);
            }
            const orderIndex = panel.order.indexOf(String(widget.id));
            if (orderIndex !== -1) {
                panel.order.splice(orderIndex, 1);
            }
            delete byId[String(widget.id)];
        };
    }
    const panel = {
        id: 17,
        screen: 0,
        location: "top",
        formFactor: "horizontal",
        height: 28,
        lengthMode: "fill",
        hiding: "none",
        floating: false,
        opacity: "opaque",
        group: [],
        order: widgets.map(widget => String(widget.id)),
        addedTypes: [],
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            return this.group.join("/") === "General" && key === "AppletOrder"
                ? this.order.join(";")
                : fallback;
        },
        writeConfig(key, value) {
            if (this.group.join("/") === "General" && key === "AppletOrder") {
                this.order = String(value).split(";");
            }
        },
        reloadConfig() {},
        widgets(type) {
            return type ? widgets.filter(widget => widget.type === type) : widgets.slice();
        },
        addWidget(type, x, y, width, height) {
            const config = {};
            if (type === taskType) {
                config["General:launchers"] = pinnedSentinel.slice();
                config["General:userBehavior"] = "new-default-preserved";
            }
            const widget = makeWidget(type, nextId++, {x, y, width, height}, config);
            widgets.push(widget);
            byId[String(widget.id)] = widget;
            widget.remove = () => {
                const widgetIndex = widgets.indexOf(widget);
                if (widgetIndex !== -1) {
                    widgets.splice(widgetIndex, 1);
                }
                const orderIndex = this.order.indexOf(String(widget.id));
                if (orderIndex !== -1) {
                    this.order.splice(orderIndex, 1);
                }
                delete byId[String(widget.id)];
            };
            let insertion = this.order.findIndex(id => byId[id].geometry.x > x);
            if (insertion === -1) {
                insertion = this.order.length;
            }
            this.order.splice(insertion, 0, String(widget.id));
            this.addedTypes.push(type);
            return widget;
        },
        orderedWidgets() {
            return this.order.map(id => byId[id]);
        }
    };
    if (options.geometry) {
        Object.assign(panel, options.geometry);
    }
    return panel;
}

function digest(panel) {
    return JSON.stringify({
        order: panel.order,
        addedTypes: panel.addedTypes,
        widgets: panel.widgets().map(widget => ({
            id: widget.id,
            type: widget.type,
            geometry: widget.geometry,
            config: widget.config,
            writes: widget.writes
        }))
    });
}

function run(name, panel, options = {}) {
    const output = [];
    let known = Array.from(new Set(v04Types.concat(pagerTypes, workspacesTypes, [
        "org.kde.plasma.networkmanagement",
        "org.kde.plasma.volume",
        "org.kde.plasma.notifications"
    ])));
    if (options.withoutTaskCapability) {
        known = known.filter(type => type !== taskType);
    }
    const context = {
        panelIds: options.panelIds || [panel.id],
        panelById: id => id === panel.id ? panel : null,
        knownWidgetTypes: known,
        print: value => output.push(String(value)),
        JSON, String, Number, Math, Array, Object, Error
    };
    vm.runInNewContext(
        fs.readFileSync(path.join(options.layoutRoot || layoutRoot, "contents", name), "utf8"),
        context,
        {filename: name}
    );
    if (name === "stage-spacer.js") {
        for (const spacer of panel.widgets(spacerType)) {
            if (spacer.geometry.width <= 1) {
                spacer.geometry.width = 80;
            }
        }
    }
    return output.join("\n");
}

function orderedTypes(panel) {
    return panel.orderedWidgets().map(widget => widget.type);
}

function read(widget, key) {
    return widget.config["General:" + key];
}

function readAppearance(widget, key) {
    return widget.config["Appearance:" + key];
}

function assertClockPolicy(widget, label) {
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
        assert(readAppearance(widget, key) === value,
            label + ": clock " + key + " policy differs");
    }
}

function assertTargetPolicy(panel, label, expectedTypes = v04Types) {
    assert(JSON.stringify(orderedTypes(panel)) === JSON.stringify(expectedTypes),
        label + ": target order differs");
    const spacers = panel.orderedWidgets().filter(widget => widget.type === spacerType);
    const tasks = panel.widgets(taskType);
    const resources = panel.widgets(resourceType);
    assert(spacers.length === 2 && spacers.every(widget => read(widget, "expanding") === true),
        label + ": both spacers are not expanding");
    assert(tasks.length === 1, label + ": task instance count differs");
    assert(read(tasks[0], "fill") === false, label + ": task fill policy differs");
    assert(String(read(tasks[0], "maxStripes")) === "1", label + ": task rows differ");
    assert(String(read(tasks[0], "iconSpacing")) === "0", label + ": icon spacing differs");
    assert(resources.length === 1 && String(read(resources[0], "packageRevision")) === "2",
        label + ": resource revision differs");
    if (expectedTypes === pagerTypes) {
        const pager = panel.widgets(pagerType)[0];
        assert(String(read(pager, "displayedText")) === "0"
            && read(pager, "showWindowOutlines") === false
            && read(pager, "showWindowIcons") === false,
        label + ": Pager policy differs");
    }
    if (expectedTypes === workspacesTypes) {
        const workspaces = panel.widgets(workspaceType)[0];
        assert(String(read(workspaces, "packageRevision")) === "2",
            label + ": Workspaces revision differs");
    }
    assert(JSON.stringify(read(tasks[0], "launchers")) === JSON.stringify(pinnedSentinel),
        label + ": user-owned pinned applications changed");
    const clocks = panel.widgets("org.kde.plasma.digitalclock");
    assert(clocks.length === 1, label + ": clock instance count differs");
    assertClockPolicy(clocks[0], label);
    assert(panel.height === 32, label + ": panel height was not migrated to 32px");
}

const migrating = createPanel(v03Types);
assert(run("preflight.js", migrating).includes("topology=minimalist-v03"),
    "exact v0.3 preflight topology was not reported");
assert(run("preflight.js", migrating).includes("MINIMALIST_V04_PREFLIGHT_OK"),
    "exact v0.3 preflight was not accepted");
const spacerStageOutput = run("stage-spacer.js", migrating);
assert(spacerStageOutput.includes("transition=stage-v0.4.1-spacer"),
    "v0.3 spacer stage did not run");
assert(JSON.stringify(migrating.addedTypes) === JSON.stringify([spacerType]),
    "v0.3 spacer phase added anything except one spacer");
assert(run("preflight.js", migrating).includes("topology=minimalist-v04-spacer-staged"),
    "v0.3 spacer phase did not reach the exact staged topology");
assert(run("preflight.js", migrating).includes("stageAnchorReady=true"),
    "staged spacer did not expose a settled placement anchor");
const migrationOutput = run("layout.js", migrating);
assert(migrationOutput.includes("transition=complete-v04-staged"),
    "settled v0.3 migration did not run its task phase");
assert(JSON.stringify(migrating.addedTypes) === JSON.stringify([spacerType, taskType]),
    "v0.3 migration did not isolate spacer and task additions");
assertTargetPolicy(migrating, "v0.3 migration");
assert(run("postcheck.js", migrating).includes("MINIMALIST_V04_POSTCHECK_OK"),
    "migrated v0.4.1 target failed postcheck");

const staged = createPanel(stagedTypes);
assert(run("preflight.js", staged).includes("topology=minimalist-v04-spacer-staged"),
    "staged topology was not reported");
const stagedOutput = run("layout.js", staged);
assert(stagedOutput.includes("transition=complete-v04-staged"),
    "staged migration did not complete");
assert(JSON.stringify(staged.addedTypes) === JSON.stringify([taskType]),
    "staged migration added anything except the missing task manager");
assertTargetPolicy(staged, "staged migration");

const taskFrontStaged = createPanel(taskFrontStagedTypes, {
    spacersExpanding: true,
    resourceRevision: 2,
    taskFill: false,
    taskMaxStripes: 1,
    taskIconSpacing: 0
});
assert(run("preflight.js", taskFrontStaged)
    .includes("topology=minimalist-v04-task-front-staged"),
"task-front staged topology was not reported");
const taskFrontOutput = run("cleanup.js", taskFrontStaged);
assert(taskFrontOutput.includes("transition=remove-task-front-stage"),
    "task-front staged topology did not use exact live cleanup");
assert(JSON.stringify(orderedTypes(taskFrontStaged)) === JSON.stringify(v03Types),
    "task-front cleanup did not restore the v0.3 topology");
assert(taskFrontStaged.widgets(taskType).length === 0
    && taskFrontStaged.widgets(spacerType).length === 1,
"task-front cleanup removed anything other than the v0.4.1 additions");

const cleanupTarget = createPanel(v04Types, {
    spacersExpanding: true,
    resourceRevision: 2,
    taskFill: false,
    taskMaxStripes: 1,
    taskIconSpacing: 0
});
assert(run("cleanup.js", cleanupTarget).includes("transition=remove-v0.4.1-target"),
    "target cleanup did not report its exact transition");
assert(JSON.stringify(orderedTypes(cleanupTarget)) === JSON.stringify(v03Types),
    "target cleanup did not restore the v0.3 topology");

const pinned = ["applications:user-one.desktop", "applications:user-two.desktop"];
const target = createPanel(v04Types, {
    taskFill: true,
    taskMaxStripes: 4,
    taskIconSpacing: 3,
    pinned,
    userBehavior: "keep-this-setting",
    spacersExpanding: false,
    resourceRevision: 0
});
const targetTasks = target.widgets(taskType)[0];
const targetClock = target.widgets("org.kde.plasma.digitalclock")[0];
const taskId = targetTasks.id;
const clockId = targetClock.id;
const reapplyOutput = run("layout.js", target);
assert(reapplyOutput.includes("transition=already-target"), "v0.4.1 reapply was not idempotent");
assert(target.addedTypes.length === 0, "v0.4.1 reapply added a widget");
assert(target.widgets(taskType)[0].id === taskId, "v0.4.1 reapply replaced the task instance");
assert(target.widgets("org.kde.plasma.digitalclock")[0].id === clockId,
    "v0.4.1 reapply replaced the clock instance");
assert(JSON.stringify(read(targetTasks, "launchers")) === JSON.stringify(pinned),
    "v0.4.1 reapply changed the user's pinned applications");
assert(read(targetTasks, "userBehavior") === "keep-this-setting",
    "v0.4.1 reapply changed unrelated task configuration");
assert(read(targetTasks, "fill") === false
    && String(read(targetTasks, "maxStripes")) === "1"
    && String(read(targetTasks, "iconSpacing")) === "0",
    "v0.4.1 reapply did not reassert only the managed presentation policy");
assertClockPolicy(targetClock, "v0.4.1 reapply");
assert(readAppearance(targetClock, "fontFamily") === "Noto Sans"
    && readAppearance(targetClock, "fontSize") === 11,
    "v0.4.1 reapply did not retain the managed minimalist font");
assert(run("postcheck.js", target).includes("MINIMALIST_V04_POSTCHECK_OK"),
    "idempotent v0.4.1 target failed postcheck");
targetClock.config["Appearance:showSeconds"] = "Always";
assert(run("postcheck.js", target).includes("MINIMALIST_V04_POSTCHECK_OK"),
    "v0.4.1 postcheck rejected Plasma's canonical showSeconds enum name");
run("layout.js", target);
assertClockPolicy(targetClock, "v0.4.1 enum normalization");

for (const [label, types, topology, transition] of [
    ["Pager", pagerTypes, "minimalist-v04-pager", "already-pager-target"],
    ["Workspaces", workspacesTypes, "minimalist-v04-workspaces", "already-workspaces-target"]
]) {
    const variant = createPanel(types, {
        taskFill: true,
        taskMaxStripes: 4,
        taskIconSpacing: 3,
        spacersExpanding: false,
        resourceRevision: 0
    });
    const beforeIds = variant.orderedWidgets().map(widget => widget.id);
    assert(run("preflight.js", variant).includes("topology=" + topology),
        label + " target topology was not reported");
    assert(run("preflight.js", variant).includes("MINIMALIST_V04_PREFLIGHT_OK"),
        label + " target was not accepted");
    const output = run("layout.js", variant);
    assert(output.includes("transition=" + transition),
        label + " target did not use its idempotent transition");
    assert(JSON.stringify(variant.orderedWidgets().map(widget => widget.id))
        === JSON.stringify(beforeIds), label + " target replaced a widget");
    assertTargetPolicy(variant, label + " target", types);
    assert(run("postcheck.js", variant).includes("MINIMALIST_V04_POSTCHECK_OK"),
        label + " target failed the common v0.4.1 postcheck");
}

const badClock = createPanel(v04Types);
run("layout.js", badClock);
const badClockWidget = badClock.widgets("org.kde.plasma.digitalclock")[0];
badClockWidget.config["Appearance:showDate"] = true;
const badClockBefore = digest(badClock);
assert(!run("postcheck.js", badClock).includes("MINIMALIST_V04_POSTCHECK_OK"),
    "postcheck accepted a clock with a visible date");
assert(digest(badClock) === badClockBefore, "read-only postcheck changed clock configuration");
run("layout.js", badClock);
assertTargetPolicy(badClock, "v0.4.1 clock repair");
assert(run("postcheck.js", badClock).includes("MINIMALIST_V04_POSTCHECK_OK"),
    "repaired v0.4.1 clock failed postcheck");

const badPolicy = createPanel(v04Types, {
    taskFill: true,
    taskMaxStripes: 1,
    taskIconSpacing: 0,
    spacersExpanding: true,
    resourceRevision: 2
});
const badPolicyBefore = digest(badPolicy);
assert(!run("postcheck.js", badPolicy).includes("MINIMALIST_V04_POSTCHECK_OK"),
    "postcheck accepted an expanding task manager");
assert(digest(badPolicy) === badPolicyBefore, "read-only postcheck changed task configuration");

for (const [label, panel] of [
    ["foreign widget", createPanel(v03Types.concat(["org.example.foreign"]))],
    ["duplicate task", createPanel(v04Types.concat([taskType]))]
]) {
    const before = digest(panel);
    assert(!run("preflight.js", panel).includes("MINIMALIST_V04_PREFLIGHT_OK"),
        label + " passed preflight");
    let refused = false;
    try {
        run("layout.js", panel);
    } catch (error) {
        refused = String(error).includes("panel topology differs");
    }
    assert(refused, label + " was not refused by the layout");
    assert(digest(panel) === before, label + " was mutated before refusal");
}

const malformed = createPanel(v03Types);
malformed.order[1] = malformed.order[0];
const malformedBefore = digest(malformed);
assert(!run("preflight.js", malformed).includes("MINIMALIST_V04_PREFLIGHT_OK"),
    "malformed AppletOrder passed preflight");
let malformedRefused = false;
try {
    run("layout.js", malformed);
} catch (error) {
    malformedRefused = true;
}
assert(malformedRefused && digest(malformed) === malformedBefore,
    "malformed AppletOrder was not refused without mutation");

const wrongGeometry = createPanel(v03Types, {geometry: {location: "bottom"}});
const wrongGeometryBefore = digest(wrongGeometry);
assert(!run("preflight.js", wrongGeometry).includes("MINIMALIST_V04_PREFLIGHT_OK"),
    "wrong panel geometry passed preflight");
let geometryRefused = false;
try {
    run("layout.js", wrongGeometry);
} catch (error) {
    geometryRefused = String(error).includes("approved Minimalist v0.3/v0.4.1 migration geometry");
}
assert(geometryRefused && digest(wrongGeometry) === wrongGeometryBefore,
    "wrong geometry was not refused before mutation");

const missingCapability = createPanel(v03Types);
const missingCapabilityBefore = digest(missingCapability);
assert(!run("preflight.js", missingCapability, {withoutTaskCapability: true})
    .includes("MINIMALIST_V04_PREFLIGHT_OK"), "missing task capability passed preflight");
let capabilityRefused = false;
try {
    run("layout.js", missingCapability, {withoutTaskCapability: true});
} catch (error) {
    capabilityRefused = String(error).includes("Icons-only Task Manager is unavailable");
}
assert(capabilityRefused && digest(missingCapability) === missingCapabilityBefore,
    "missing task capability was not refused before mutation");

// Independent fixtures move the clock after the launcher, shifting policy and
// placement roles. These expectations do not read the generated contract.
function moveClock(types) {
    const result = types.filter(type => type !== "org.kde.plasma.digitalclock");
    result.splice(result.indexOf("org.kde.plasma.kickoff") + 1, 0, "org.kde.plasma.digitalclock");
    return result;
}
function runReordered(name, panel) {
    return run(name, panel, {layoutRoot: reorderedRoot});
}
const reorderedV03 = moveClock(v03Types);
const reorderedV04 = moveClock(v04Types);
const reordered = createPanel(reorderedV03);
const retainedSpacer = reordered.widgets(spacerType)[0];
assert(runReordered("preflight.js", reordered).includes("topology=minimalist-v03"),
    "reordered source was not recognized by preflight");
runReordered("stage-spacer.js", reordered);
assert(JSON.stringify(orderedTypes(reordered)) === JSON.stringify(moveClock(stagedTypes)),
    "reordered spacer phase used the wrong placement anchor");
runReordered("layout.js", reordered);
assertTargetPolicy(reordered, "reordered migration", reorderedV04);
assert(runReordered("postcheck.js", reordered).includes("MINIMALIST_V04_POSTCHECK_OK"),
    "reordered postcheck inspected a stale policy position");
for (const [type, key, value, result] of [
    [taskType, "General:fill", true, "taskPolicyOk=false"],
    [resourceType, "General:packageRevision", 0, "resourceOk=false"],
    ["org.kde.plasma.digitalclock", "Appearance:showDate", true, "clockOk=false"]
]) {
    const widget = reordered.widgets(type)[0];
    const saved = widget.config[key];
    widget.config[key] = value;
    const before = digest(reordered);
    const output = runReordered("postcheck.js", reordered);
    assert(output.includes(result) && !output.includes("MINIMALIST_V04_POSTCHECK_OK"),
        "reordered postcheck missed policy drift for " + type);
    assert(digest(reordered) === before, "reordered postcheck mutated policy");
    widget.config[key] = saved;
}
runReordered("cleanup.js", reordered);
assert(JSON.stringify(orderedTypes(reordered)) === JSON.stringify(reorderedV03)
    && reordered.widgets(spacerType)[0] === retainedSpacer,
    "reordered cleanup did not preserve the original spacer and widgets");
for (const types of [stagedTypes, taskFrontStagedTypes]) {
    const intermediate = createPanel(moveClock(types));
    runReordered("cleanup.js", intermediate);
    assert(JSON.stringify(orderedTypes(intermediate)) === JSON.stringify(reorderedV03),
        "reordered intermediate cleanup used a stale removal position");
}
for (const types of [pagerTypes, workspacesTypes]) {
    const shifted = moveClock(types);
    const panel = createPanel(shifted);
    runReordered("layout.js", panel);
    assertTargetPolicy(panel, "reordered optional variant", shifted);
    assert(runReordered("postcheck.js", panel).includes("MINIMALIST_V04_POSTCHECK_OK"),
        "reordered optional widget was checked at a stale position");
}
NODE

cat > "$MOCK_BIN/doctor" <<'MOCK'
#!/usr/bin/env bash
[[ $# == 2 && $1 == --target && $2 == minimalist-v04 ]] || exit 64
printf 'mock doctor: supported\n'
exit "${MOCK_DOCTOR_STATUS:-0}"
MOCK
cat > "$MOCK_BIN/qdbus6" <<'MOCK'
#!/usr/bin/env bash
script=${4:-}
state_file=${MOCK_PLASMA_STATE:?}
topology=$(< "$state_file")
if [[ $script == *MINIMALIST_V04_PREFLIGHT* ]]; then
    task_known=${MOCK_TASK_KNOWN:-true}
    printf 'MINIMALIST_V04_PREFLIGHT panelCount=1 topology=%s height=28 geometryOk=true spacerKnown=true taskKnown=%s stageAnchorReady=true resourceKnown=true widgets=mock\n' \
        "$topology" "$task_known"
    if [[ $topology != unknown && $task_known == true ]]; then
        printf '%s\n' ' MINIMALIST_V04_PREFLIGHT_OK'
    fi
elif [[ $script == *MINIMALIST_V04_STAGE_SPACER_OK* ]]; then
    case "$topology" in
        minimalist-v03)
            transition=stage-v0.4.1-spacer
            printf '%s\n' minimalist-v04-spacer-staged > "$state_file"
            ;;
        minimalist-v04-spacer-staged) transition=already-staged ;;
        *) exit 2 ;;
    esac
    printf 'MINIMALIST_V04_STAGE_SPACER_OK transition=%s id=17 addedSpacer=true widgets=mock\n' \
        "$transition"
elif [[ $script == *MINIMALIST_V04_CENTER_TASKS_OK* ]]; then
    case "$topology" in
        minimalist-v04-spacer-staged)
            transition=complete-v04-staged
            printf '%s\n' minimalist-v04 > "$state_file"
            ;;
        minimalist-v04) transition=already-target ;;
        minimalist-v04-pager) transition=already-pager-target ;;
        minimalist-v04-workspaces) transition=already-workspaces-target ;;
        *) exit 2 ;;
    esac
    printf 'MINIMALIST_V04_CENTER_TASKS_OK transition=%s id=17 addedTasks=true widgets=mock\n' "$transition"
elif [[ $script == *MINIMALIST_V04_CLEANUP_OK* ]]; then
    case "$topology" in
        minimalist-v03) transition=already-v0.3 ;;
        minimalist-v04-spacer-staged) transition=remove-staged-spacer ;;
        minimalist-v04-task-front-staged) transition=remove-task-front-stage ;;
        minimalist-v04) transition=remove-v0.4.1-target ;;
        *) exit 2 ;;
    esac
    printf '%s\n' minimalist-v03 > "$state_file"
    printf 'MINIMALIST_V04_CLEANUP_OK transition=%s removedTask=true removedSpacer=true\n' "$transition"
elif [[ $script == *MINIMALIST_V04_POSTCHECK* ]]; then
    if [[ ( $topology == minimalist-v04 || $topology == minimalist-v04-pager \
        || $topology == minimalist-v04-workspaces ) \
        && ${MOCK_POSTCHECK_FAIL:-false} != true ]]; then
        printf '%s\n' 'MINIMALIST_V04_POSTCHECK geometryOk=true topologyOk=true leftSpacerOk=true rightSpacerOk=true taskPolicyOk=true resourceOk=true clockOk=true widgets=mock'
        printf '%s\n' ' MINIMALIST_V04_POSTCHECK_OK'
    else
        printf '%s\n' 'MINIMALIST_V04_POSTCHECK geometryOk=true topologyOk=false widgets=mock'
    fi
else
    printf 'unexpected Plasma script\n' >&2
    exit 2
fi
MOCK
chmod +x "$MOCK_BIN/doctor" "$MOCK_BIN/qdbus6"

printf 'baseline panel configuration\n' \
    > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

run_v04() {
    printf '%s\n' "${MOCK_PREFLIGHT_TOPOLOGY:-minimalist-v03}" > "$TEMP_ROOT/plasma-state"
    HOME="$TARGET_HOME" \
    XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" \
    XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_PLASMA_STATE="$TEMP_ROOT/plasma-state" \
    "$APPLY_SCRIPT" "$@"
}

run_v04 --dry-run > "$TEMP_ROOT/dry-run-v03.txt"
grep -Fq 'current accepted topology: minimalist-v03' "$TEMP_ROOT/dry-run-v03.txt" \
    || fail "v0.3 dry-run omitted the source topology"
grep -Fq 'panel removals: none' "$TEMP_ROOT/dry-run-v03.txt" \
    || fail "v0.4.1 dry-run omitted zero removals"
grep -Fq 'one right org.kde.plasma.panelspacer and one org.kde.plasma.icontasks' \
    "$TEMP_ROOT/dry-run-v03.txt" || fail "v0.3 dry-run omitted exact additions"
grep -Fq 'panel height: 28 -> 32 logical px; preserve the existing panel instance' \
    "$TEMP_ROOT/dry-run-v03.txt" || fail "v0.4.1 dry-run omitted the panel-height migration"
grep -Fq 'clock policy: date hidden; 24-hour time with seconds; fixed Noto Sans 11 pt' \
    "$TEMP_ROOT/dry-run-v03.txt" || fail "v0.4.1 dry-run omitted the exact clock policy"
grep -Fq 'no pinned application list is inspected, seeded, rewritten, or verified' \
    "$TEMP_ROOT/dry-run-v03.txt" || fail "dry-run omitted user-owned application policy"
grep -Fq 'rollback apply:' "$TEMP_ROOT/dry-run-v03.txt" \
    || fail "v0.4.1 dry-run omitted rollback"
[[ ! -e $TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04 ]] \
    || fail "dry-run installed the v0.4.1 layout"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources ]] \
    || fail "dry-run installed the resource Plasmoid"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle ]] \
    || fail "dry-run installed the active-title Plasmoid"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces ]] \
    || fail "dry-run installed the Workspaces Plasmoid"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] \
    || fail "dry-run created transaction state"

MOCK_PREFLIGHT_TOPOLOGY=minimalist-v04-spacer-staged \
    run_v04 --dry-run > "$TEMP_ROOT/dry-run-staged.txt"
grep -Fq 'current accepted topology: minimalist-v04-spacer-staged' \
    "$TEMP_ROOT/dry-run-staged.txt" || fail "staged dry-run omitted its topology"
grep -Fq 'panel additions: one org.kde.plasma.icontasks; preserve both existing spacers' \
    "$TEMP_ROOT/dry-run-staged.txt" || fail "staged dry-run plan is inaccurate"

MOCK_PREFLIGHT_TOPOLOGY=minimalist-v04-task-front-staged \
    run_v04 --dry-run > "$TEMP_ROOT/dry-run-task-front.txt"
grep -Fq 'place the existing task manager at the authoritative AppletOrder position' \
    "$TEMP_ROOT/dry-run-task-front.txt" && fail "task-front plan still relies on AppletOrder"
grep -Fq 'recovery removals: the misplaced v0.4.1 task and right spacer; then rebuild both in two settled phases' \
    "$TEMP_ROOT/dry-run-task-front.txt" || fail "task-front recovery plan is inaccurate"

MOCK_PREFLIGHT_TOPOLOGY=minimalist-v04 \
    run_v04 --dry-run > "$TEMP_ROOT/dry-run-v04.txt"
grep -Fq 'panel additions: none; preserve the existing task and spacer instances' \
    "$TEMP_ROOT/dry-run-v04.txt" || fail "v0.4.1 reapply plan reports an addition"

MOCK_PREFLIGHT_TOPOLOGY=minimalist-v04-pager \
    run_v04 --dry-run > "$TEMP_ROOT/dry-run-v04-pager.txt"
grep -Fq 'target order: launcher | Pager | active title' \
    "$TEMP_ROOT/dry-run-v04-pager.txt" || fail "Pager reapply plan omits the preserved switcher"

MOCK_PREFLIGHT_TOPOLOGY=minimalist-v04-workspaces \
    run_v04 --dry-run > "$TEMP_ROOT/dry-run-v04-workspaces.txt"
grep -Fq 'target order: launcher | Workspaces | active title' \
    "$TEMP_ROOT/dry-run-v04-workspaces.txt" || fail "Workspaces reapply plan omits the preserved switcher"

set +e
MOCK_PREFLIGHT_TOPOLOGY=unknown run_v04 --apply > "$TEMP_ROOT/unknown.txt" 2>&1
unknown_status=$?
set -e
[[ $unknown_status == 1 ]] || fail "unknown topology was not refused"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] \
    || fail "unknown topology wrote a snapshot"
[[ ! -e $TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04 ]] \
    || fail "unknown topology installed the layout"

set +e
MOCK_TASK_KNOWN=false run_v04 --apply > "$TEMP_ROOT/missing-task.txt" 2>&1
missing_task_status=$?
set -e
[[ $missing_task_status == 1 ]] || fail "missing task capability was not refused"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] \
    || fail "missing task capability wrote a snapshot"

set +e
MOCK_POSTCHECK_FAIL=true run_v04 --apply > "$TEMP_ROOT/rollback.txt" 2>&1
rollback_status=$?
set -e
[[ $rollback_status == 1 ]] || fail "postcheck failure did not fail the apply"
grep -Fq 'MINIMALIST_V04_CLEANUP_OK' "$TEMP_ROOT/rollback.txt" \
    || fail "postcheck failure did not invoke exact live cleanup"
grep -Fq 'pre-apply snapshot restored automatically' "$TEMP_ROOT/rollback.txt" \
    || fail "postcheck failure did not restore its snapshot"
[[ $(< "$TEMP_ROOT/plasma-state") == minimalist-v03 ]] \
    || fail "postcheck failure did not return the live mock to v0.3"
[[ ! -e $TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04 ]] \
    || fail "rollback left the v0.4.1 layout installed"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources ]] \
    || fail "rollback left the resource package installed"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle ]] \
    || fail "rollback left the active-title package installed"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces ]] \
    || fail "rollback left the Workspaces package installed"
grep -Fxq 'baseline panel configuration' \
    "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
    || fail "rollback did not restore the panel configuration"

run_v04 --apply > "$TEMP_ROOT/apply.txt"
resource_target="$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources"
active_target="$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle"
workspace_target="$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces"
layout_target="$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04"
diff -qr -- "$ACTIVE" "$active_target" >/dev/null \
    || fail "installed active-title Plasmoid differs from source"
diff -qr -- "$RESOURCE" "$resource_target" >/dev/null \
    || fail "installed resource Plasmoid differs from source"
diff -qr -- "$WORKSPACE" "$workspace_target" >/dev/null \
    || fail "installed Workspaces Plasmoid differs from source"
diff -qr -- "$LAYOUT" "$layout_target" >/dev/null \
    || fail "installed v0.4.1 layout differs from source"
snapshot=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt" | tail -n 1)
[[ -d $snapshot && -f $snapshot/complete ]] \
    || fail "v0.4.1 apply did not create a complete snapshot"
grep -Fq $'file\t.config/plasma-org.kde.plasma.desktop-appletsrc' "$snapshot/state.tsv" \
    || fail "snapshot omitted the complete panel configuration path"
grep -Fq $'absent\t.local/share/plasma/layout-templates/org.kde.minimalist-v04' \
    "$snapshot/state.tsv" || fail "snapshot did not record the absent v0.4.1 layout"
grep -Fq $'absent\t.local/share/plasma/plasmoids/org.kde.minimalist.resources' \
    "$snapshot/state.tsv" || fail "snapshot did not record the absent resource package"
grep -Fq $'absent\t.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle' \
    "$snapshot/state.tsv" || fail "snapshot did not record the absent active-title package"
grep -Fq $'absent\t.local/share/plasma/plasmoids/org.kde.minimalist.workspaces' \
    "$snapshot/state.tsv" || fail "snapshot did not record the absent Workspaces package"
cmp -- "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
    "$snapshot/payload/.config/plasma-org.kde.plasma.desktop-appletsrc" >/dev/null \
    || fail "snapshot panel payload differs from the pre-apply file"
grep -Fq 'MINIMALIST_V04_POSTCHECK_OK' "$TEMP_ROOT/apply.txt" \
    || fail "v0.4.1 apply did not report postcheck success"
grep -Fq 'Restore preview:' "$TEMP_ROOT/apply.txt" \
    || fail "v0.4.1 completion omitted restore preview"
grep -Fq 'Restore apply:' "$TEMP_ROOT/apply.txt" \
    || fail "v0.4.1 completion omitted restore apply"

MOCK_PREFLIGHT_TOPOLOGY=minimalist-v04 run_v04 --apply \
    > "$TEMP_ROOT/reapply-v04.txt"
grep -Fq 'No panel or existing widget instance was removed.' "$TEMP_ROOT/reapply-v04.txt" \
    || fail "v0.4.1 reapply omitted its instance-preservation boundary"

printf 'PASS: Minimalist v0.4.1 centered-task-strip tests\n'
