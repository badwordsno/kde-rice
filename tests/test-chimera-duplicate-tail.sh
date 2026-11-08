#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$SCRIPT_DIR/lib/runtime.sh"
require_test_node

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v04/contents"
PREFLIGHT="$LAYOUT/duplicate-tail-preflight.js"
CLEANUP="$LAYOUT/duplicate-tail-cleanup.js"
POSTCHECK="$LAYOUT/duplicate-tail-postcheck.js"
RECOVERY="$REPO_ROOT/scripts/recover-chimera-duplicate-tail"

for script in "$PREFLIGHT" "$CLEANUP" "$POSTCHECK"; do
    [[ -f $script && ! -L $script ]] \
        || fail "duplicate-tail recovery source is missing or unsafe: $script"
    "$NODE_BIN" --check "$script" >/dev/null
done
[[ -x $RECOVERY && ! -L $RECOVERY ]] \
    || fail "duplicate-tail recovery entry point is missing or unsafe"
bash -n "$RECOVERY"
for required_text in \
    'capture_or_reuse_snapshot' \
    'source snapshot direct applet map' \
    'persistent_state_matches' \
    'wait_for_persistent_target' \
    'MINIMALIST_V04_DUPLICATE_TAIL_CLEANUP_OK' \
    'MINIMALIST_V04_DUPLICATE_TAIL_POSTCHECK_OK' \
    'rollback apply (only while logged out of Plasma)' \
    '--allow-degraded'; do
    grep -Fq -- "$required_text" "$RECOVERY" \
        || fail "duplicate-tail transaction omits required guard: $required_text"
done
if rg -n 'writeConfig\("AppletOrder"|addWidget\(' "$RECOVERY" >/dev/null; then
    fail "duplicate-tail transaction contains a manual order or applet-add path"
fi

if rg -n '\.remove\(|addWidget\(|writeConfig\(' "$PREFLIGHT" "$POSTCHECK" >/dev/null; then
    fail "duplicate-tail read-only guards contain a live mutation"
fi
if rg -n 'addWidget\(|writeConfig\("AppletOrder"|\.index[[:space:]]*=' "$CLEANUP" >/dev/null; then
    fail "duplicate-tail cleanup adds, configures, or manually reorders a widget"
fi

"$NODE_BIN" - "$PREFLIGHT" "$CLEANUP" "$POSTCHECK" <<'NODE'
const fs = require("fs");
const vm = require("vm");

const [preflightSource, cleanupSource, postcheckSource] = process.argv.slice(2)
    .map(file => fs.readFileSync(file, "utf8"));

const activeType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const spacerType = "org.kde.plasma.panelspacer";
const taskType = "org.kde.plasma.icontasks";
const stableIds = [30, 80, 81, 32, 56, 55, 82, 33, 34, 35, 61];
const stableTypes = [
    "org.kde.plasma.kickoff", workspaceType, activeType, spacerType,
    taskType, spacerType, resourceType, "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel", "org.kde.plasma.systemtray", clockType
];
const sourceIds = stableIds.concat([75, 76]);
const sourceTypes = stableTypes.concat([activeType, resourceType]);
const partialIds = stableIds.concat([75]);
const partialTypes = stableTypes.concat([activeType]);
const knownTypes = Array.from(new Set(sourceTypes));

const userConfig = {};
userConfig[workspaceType] = {
    labelMode: 1,
    hideWhenSingle: true,
    wrapWheel: true,
    invertWheel: false,
    density: 1,
    surfaceStyle: 2,
    bevelDepth: 1,
    motionEnabled: false
};
userConfig[activeType] = {
    titleTemplate: "{app} :: {title}",
    showIcon: true,
    widthMode: 2,
    minimumWidthUnits: 7,
    preferredWidthUnits: 23,
    maximumWidthUnits: 31,
    maximizedOnly: true,
    wheelSwitch: true,
    doubleClickMaximize: false,
    middleClickClose: true,
    density: 1,
    surfaceStyle: 2,
    bevelDepth: 1,
    motionEnabled: false
};
userConfig[resourceType] = {
    metricOrder: "VOL,GPU,RAM,CPU",
    showCpu: false,
    showMemory: true,
    showGpu: false,
    showVolume: true,
    updateRateMs: 750,
    warningPercent: 61,
    criticalPercent: 83,
    showStateRails: false,
    density: 1,
    surfaceStyle: 2,
    bevelDepth: 1,
    motionEnabled: false
};
const presentKeys = {};
presentKeys[workspaceType] = [
    "labelMode", "hideWhenSingle", "wrapWheel", "invertWheel",
    "density", "surfaceStyle", "bevelDepth", "motionEnabled"
];
presentKeys[activeType] = [
    "titleTemplate", "showIcon", "widthMode", "minimumWidthUnits",
    "preferredWidthUnits", "maximumWidthUnits", "maximizedOnly",
    "wheelSwitch", "doubleClickMaximize", "middleClickClose", "density",
    "surfaceStyle", "bevelDepth", "motionEnabled"
];
presentKeys[resourceType] = [
    "metricOrder", "showCpu", "showMemory", "showGpu", "showVolume",
    "updateRateMs", "warningPercent", "criticalPercent", "showStateRails",
    "density", "surfaceStyle", "bevelDepth", "motionEnabled"
];

function assert(condition, message) {
    if (!condition) throw new Error(message);
}

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function customGeometry(type, id) {
    if (type === workspaceType) {
        return {x: id === 80 ? 33 : 2200, y: 4, width: 103, height: 24};
    }
    if (type === activeType) {
        return {x: id === 81 ? 140 : 2300, y: 4, width: 323, height: 24};
    }
    if (type === resourceType) {
        return {x: id === 82 ? 1879 : 2400, y: 4, width: 283, height: 24};
    }
    return null;
}

function makeConfig(type, id) {
    const config = {"General:unmanagedSentinel": "preserve-" + id};
    if (type === activeType) {
        config["General:packageRevision"] = 1;
        config["General:fontPolicyRevision"] = 2;
        config["General:chimeraUiRevision"] = 1;
    } else if (type === workspaceType || type === resourceType) {
        config["General:packageRevision"] = 2;
        config["General:fontPolicyRevision"] = 2;
        config["General:chimeraUiRevision"] = 1;
    }
    for (const key of presentKeys[type] || []) {
        config["General:" + key] = clone(userConfig[type][key]);
    }
    if (type === spacerType) config["General:expanding"] = true;
    if (type === taskType) Object.assign(config, {
        "General:fill": false,
        "General:maxStripes": 1,
        "General:iconSpacing": 0,
        "General:launchers": ["applications:org.example.user-owned.desktop"],
        "General:userBehavior": "keep-task-setting"
    });
    if (type === clockType) Object.assign(config, {
        "Appearance:showDate": false,
        "Appearance:showSeconds": 2,
        "Appearance:use24hFormat": 2,
        "Appearance:autoFontAndSize": false,
        "Appearance:fontFamily": "Noto Sans",
        "Appearance:fontSize": 11,
        "Appearance:fontStyleName": "Regular",
        "Appearance:fontWeight": 400,
        "Appearance:customDateFormat": "MM.dd ddd ·"
    });
    return config;
}

function makeWidget(type, id, index, removalLog) {
    const projectGeometry = customGeometry(type, id);
    const widget = {
        id,
        type,
        geometry: projectGeometry || {
            x: 5 + index * 165,
            y: 0,
            width: type === "org.kde.plasma.kickoff" ? 32 : 120,
            height: 32
        },
        config: makeConfig(type, id),
        group: [],
        writes: [],
        removeCalls: 0,
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = Array.from(value || []); },
        get configKeys() {
            const prefix = this.group.join("/") + ":";
            const keys = Object.keys(this.config)
                .filter(key => key.startsWith(prefix))
                .map(key => key.slice(prefix.length));
            const result = {length: keys.length};
            keys.forEach((key, keyIndex) => { result[keyIndex] = key; });
            return result;
        },
        readConfig(key, fallback) {
            const composite = this.group.join("/") + ":" + key;
            return Object.prototype.hasOwnProperty.call(this.config, composite)
                ? this.config[composite] : fallback;
        },
        writeConfig() {
            throw new Error("duplicate-tail recovery must not write widget config");
        },
        reloadConfig() {
            throw new Error("duplicate-tail recovery must not reload keeper config");
        },
        remove() {
            this.removeCalls += 1;
            removalLog.push(this.id);
            if (this.removeBehavior === "throw") {
                throw new Error("injected remove failure for " + this.id);
            }
            if (this.removeBehavior === "noop") return;
            this.panel.items = this.panel.items.filter(item => item !== this);
            this.panel.order = this.panel.order.filter(idValue => idValue !== String(this.id));
            if (typeof this.afterRemove === "function") this.afterRemove();
        }
    };
    return widget;
}

function makePanel(state = "source13") {
    let ids;
    let types;
    if (state === "source13") {
        ids = sourceIds.slice();
        types = sourceTypes.slice();
    } else if (state === "partial12") {
        ids = partialIds.slice();
        types = partialTypes.slice();
    } else if (state === "target11") {
        ids = stableIds.slice();
        types = stableTypes.slice();
    } else {
        throw new Error("unknown mock state: " + state);
    }
    const removalLog = [];
    const items = types.map((type, index) => makeWidget(type, ids[index], index, removalLog));
    const panel = {
        id: 29,
        screen: 0,
        location: "top",
        formFactor: "horizontal",
        height: 32,
        lengthMode: "fill",
        hiding: "none",
        floating: false,
        opacity: "opaque",
        alignment: "center",
        offset: 0,
        minimumLength: 1920,
        maximumLength: 1920,
        length: 1920,
        group: [],
        items,
        order: ids.map(String),
        removalLog,
        addCalls: [],
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = Array.from(value || []); },
        readConfig(key, fallback) {
            return this.group.join("/") === "General" && key === "AppletOrder"
                ? this.order.join(";") : fallback;
        },
        writeConfig() {
            throw new Error("duplicate-tail recovery must not write AppletOrder");
        },
        widgets(type) {
            return type ? this.items.filter(widget => widget.type === type) : this.items.slice();
        },
        widgetById(id) {
            return this.items.find(widget => Number(widget.id) === Number(id)) || null;
        },
        addWidget(...args) {
            this.addCalls.push(args);
            throw new Error("duplicate-tail recovery must not add a widget");
        }
    };
    items.forEach(widget => { widget.panel = panel; });
    return panel;
}

function capturedWidget(panel, id) {
    const widget = panel.items.find(item => item.id === id);
    return {
        id: Number(widget.id),
        type: widget.type,
        geometry: clone(widget.geometry),
        userConfig: clone(userConfig[widget.type]),
        presentUserConfigKeys: (presentKeys[widget.type] || []).slice()
    };
}

const receiptPanel = makePanel("target11");
const expectedStablePanelState = {
    schemaVersion: 1,
    panelId: receiptPanel.id,
    orderedIds: stableIds.slice(),
    orderedTypes: stableTypes.slice(),
    workspace: capturedWidget(receiptPanel, 80),
    activeTitle: capturedWidget(receiptPanel, 81),
    resources: capturedWidget(receiptPanel, 82)
};

function panelDigest(panel) {
    return JSON.stringify({
        panel: {
            id: panel.id,
            screen: panel.screen,
            location: panel.location,
            formFactor: panel.formFactor,
            height: panel.height,
            lengthMode: panel.lengthMode,
            hiding: panel.hiding,
            floating: panel.floating,
            opacity: panel.opacity,
            alignment: panel.alignment,
            offset: panel.offset,
            minimumLength: panel.minimumLength,
            maximumLength: panel.maximumLength,
            length: panel.length
        },
        order: panel.order,
        items: panel.items.map(widget => ({
            id: widget.id,
            type: widget.type,
            geometry: widget.geometry,
            config: widget.config,
            writes: widget.writes,
            removeCalls: widget.removeCalls
        })),
        addCalls: panel.addCalls
    });
}

function keeperDigest(panel) {
    return JSON.stringify(panel.items
        .filter(widget => stableIds.includes(Number(widget.id)))
        .map(widget => ({
            id: widget.id,
            type: widget.type,
            geometry: widget.geometry,
            config: widget.config,
            writes: widget.writes,
            removeCalls: widget.removeCalls
        })));
}

function keeperProtectedDigest(panel) {
    return JSON.stringify(panel.items
        .filter(widget => stableIds.includes(Number(widget.id)))
        .map(widget => ({
            id: widget.id,
            type: widget.type,
            y: widget.geometry.y,
            height: widget.geometry.height,
            config: widget.config,
            writes: widget.writes,
            removeCalls: widget.removeCalls
        })));
}

function run(source, panel, options = {}) {
    const output = [];
    const context = {
        panelIds: options.panelIds || [panel.id],
        panelById: id => Number(id) === Number(panel.id) ? panel : null,
        knownWidgetTypes: knownTypes.slice(),
        expectedStablePanelState: options.expected || clone(expectedStablePanelState),
        capturedDuplicateTailState: options.capture,
        duplicateTailTestFailAfterFirstRemoval: options.failAfterFirst === true,
        screenGeometry: () => ({width: 1920, height: 1080}),
        print: value => output.push(String(value)),
        JSON,
        String,
        Number,
        Boolean,
        Array,
        Object,
        Math,
        Error
    };
    vm.runInNewContext(source, context);
    return output.join("\n");
}

function preflight(panel, options = {}) {
    const before = panelDigest(panel);
    const output = run(preflightSource, panel, options);
    assert(panelDigest(panel) === before, "preflight mutated the panel");
    return output;
}

function captureFrom(output) {
    const prefix = "MINIMALIST_V04_DUPLICATE_TAIL_CAPTURE=";
    const line = output.split("\n").find(value => value.startsWith(prefix));
    assert(line, "duplicate-tail preflight omitted its JSON capture");
    return JSON.parse(line.slice(prefix.length));
}

function acceptedCapture(panel, expectedState) {
    const output = preflight(panel, {expected: expectedState});
    assert(output.includes("MINIMALIST_V04_DUPLICATE_TAIL_PREFLIGHT_OK"),
        "exact duplicate-tail state failed preflight");
    return {output, capture: captureFrom(output)};
}

function cleanup(panel, capture, options = {}) {
    return run(cleanupSource, panel, Object.assign({}, options, {capture}));
}

function postcheck(panel, capture, options = {}) {
    const before = panelDigest(panel);
    const output = run(postcheckSource, panel, Object.assign({}, options, {capture}));
    assert(panelDigest(panel) === before, "postcheck mutated the panel");
    return output;
}

function expectRefusal(label, mutate, options = {}) {
    const panel = makePanel("source13");
    const validCapture = acceptedCapture(panel).capture;
    mutate(panel, validCapture);
    const before = panelDigest(panel);
    let preflightAccepted = false;
    try {
        preflightAccepted = preflight(panel, {expected: options.expected})
            .includes("MINIMALIST_V04_DUPLICATE_TAIL_PREFLIGHT_OK");
    } catch (error) {
        preflightAccepted = false;
    }
    assert(!preflightAccepted, label + ": invalid state passed preflight");
    assert(panelDigest(panel) === before, label + ": preflight refusal mutated state");
    let cleanupRefused = false;
    try {
        cleanup(panel, options.capture || validCapture, {expected: options.expected});
    } catch (error) {
        cleanupRefused = true;
    }
    assert(cleanupRefused, label + ": invalid state passed cleanup");
    assert(panelDigest(panel) === before, label + ": cleanup refusal mutated state");
}

// Exact source13 -> target11 convergence removes only the two stale tail IDs.
const source = makePanel("source13");
const sourceKeepers = keeperDigest(source);
const sourceAccepted = acceptedCapture(source);
assert(sourceAccepted.output.includes("topologyState=source13"),
    "source13 preflight state was not reported");
assert(JSON.stringify(sourceAccepted.capture.orderedIds) === JSON.stringify(sourceIds)
    && JSON.stringify(sourceAccepted.capture.orderedTypes) === JSON.stringify(sourceTypes),
"source13 capture did not bind the exact applet order");
assert(sourceAccepted.capture.staleActiveTitle.id === 75
    && sourceAccepted.capture.staleResources.id === 76,
"source13 capture did not bind both stale tail applets");
const sourceOutput = cleanup(source, sourceAccepted.capture);
assert(sourceOutput.includes("MINIMALIST_V04_DUPLICATE_TAIL_CLEANUP_OK")
    && sourceOutput.includes("transition=remove-both"),
"source13 cleanup did not report the exact transition");
assert(JSON.stringify(source.removalLog) === JSON.stringify([76, 75]),
    "source13 cleanup did not remove resources before active title");
assert(JSON.stringify(source.order.map(Number)) === JSON.stringify(stableIds),
    "source13 cleanup did not converge to stable target IDs");
assert(JSON.stringify(source.items.map(widget => widget.type)) === JSON.stringify(stableTypes),
    "source13 cleanup did not converge to stable target types");
assert(keeperDigest(source) === sourceKeepers,
    "source13 cleanup changed a keeper ID, geometry, or setting");
assert(source.addCalls.length === 0, "source13 cleanup added a widget");
assert(postcheck(source, sourceAccepted.capture)
    .includes("MINIMALIST_V04_DUPLICATE_TAIL_POSTCHECK_OK"),
"source13 cleanup failed exact postcheck");

// Plasma may automatically reflow x/width as applets disappear. That must not
// be mistaken for a script write, while IDs, y/height, and all settings remain
// exactly protected.
{
    const panel = makePanel("source13");
    const capture = acceptedCapture(panel).capture;
    const protectedBefore = keeperProtectedDigest(panel);
    const xBefore = panel.items.find(widget => widget.id === 81).geometry.x;
    panel.items.find(widget => widget.id === 76).afterRemove = () => {
        for (const widget of panel.items.filter(item => stableIds.includes(item.id))) {
            widget.geometry.x += 9;
            widget.geometry.width += 3;
        }
    };
    const output = cleanup(panel, capture);
    assert(output.includes("transition=remove-both"),
        "automatic keeper reflow prevented exact convergence");
    assert(panel.items.find(widget => widget.id === 81).geometry.x !== xBefore,
        "automatic keeper reflow was not exercised");
    assert(keeperProtectedDigest(panel) === protectedBefore,
        "automatic reflow changed a protected keeper field");
    assert(postcheck(panel, capture)
        .includes("MINIMALIST_V04_DUPLICATE_TAIL_POSTCHECK_OK"),
        "automatic keeper reflow failed postcheck");
}

// The explicitly injected failure leaves the documented partial12 state, and
// a fresh receipt-bound capture safely converges that state to target11.
const interrupted = makePanel("source13");
const interruptedKeepers = keeperDigest(interrupted);
const interruptedCapture = acceptedCapture(interrupted).capture;
let injectedFailure = false;
try {
    cleanup(interrupted, interruptedCapture, {failAfterFirst: true});
} catch (error) {
    injectedFailure = true;
}
assert(injectedFailure, "failure after first removal was not injected");
assert(JSON.stringify(interrupted.removalLog) === JSON.stringify([76]),
    "injected failure removed anything except stale resources");
assert(JSON.stringify(interrupted.order.map(Number)) === JSON.stringify(partialIds),
    "injected failure did not leave exact partial12 IDs");
assert(keeperDigest(interrupted) === interruptedKeepers,
    "injected failure changed a keeper");
const partialAccepted = acceptedCapture(interrupted);
assert(partialAccepted.output.includes("topologyState=partial12"),
    "partial12 preflight state was not reported");
assert(JSON.stringify(partialAccepted.capture.orderedIds) === JSON.stringify(partialIds)
    && partialAccepted.capture.staleActiveTitle.id === 75
    && partialAccepted.capture.staleResources === null,
"partial12 capture did not bind its exact convergent state");
const partialOutput = cleanup(interrupted, partialAccepted.capture);
assert(partialOutput.includes("transition=remove-active-title"),
    "partial12 cleanup did not report active-title-only convergence");
assert(JSON.stringify(interrupted.removalLog) === JSON.stringify([76, 75]),
    "partial12 convergence removed the wrong ID");
assert(JSON.stringify(interrupted.order.map(Number)) === JSON.stringify(stableIds),
    "partial12 cleanup did not converge to target11");
assert(keeperDigest(interrupted) === interruptedKeepers,
    "partial12 cleanup changed a keeper");
assert(postcheck(interrupted, partialAccepted.capture)
    .includes("MINIMALIST_V04_DUPLICATE_TAIL_POSTCHECK_OK"),
"partial12 cleanup failed exact postcheck");

// target11 is idempotent and performs no removal or write.
const target = makePanel("target11");
const targetBefore = panelDigest(target);
const targetAccepted = acceptedCapture(target);
assert(targetAccepted.output.includes("topologyState=target11"),
    "target11 preflight state was not reported");
assert(JSON.stringify(targetAccepted.capture.orderedIds) === JSON.stringify(stableIds)
    && targetAccepted.capture.staleActiveTitle === null
    && targetAccepted.capture.staleResources === null,
"target11 capture did not bind the exact stable state");
const targetOutput = cleanup(target, targetAccepted.capture);
assert(targetOutput.includes("transition=already-target"),
    "target11 cleanup did not report its no-op transition");
assert(panelDigest(target) === targetBefore, "target11 cleanup was not idempotent");
assert(target.removalLog.length === 0 && target.addCalls.length === 0,
    "target11 cleanup attempted a widget mutation");
assert(postcheck(target, targetAccepted.capture)
    .includes("MINIMALIST_V04_DUPLICATE_TAIL_POSTCHECK_OK"),
"target11 failed exact postcheck");

// Every near miss is refused before the first mutation.
expectRefusal("reversed stale tail", panel => {
    const activeIndex = panel.order.indexOf("75");
    const resourceIndex = panel.order.indexOf("76");
    [panel.order[activeIndex], panel.order[resourceIndex]] =
        [panel.order[resourceIndex], panel.order[activeIndex]];
});
expectRefusal("wrong stale resource type", panel => {
    panel.items.find(widget => widget.id === 76).type = activeType;
});
expectRefusal("stale tail inserted in target", panel => {
    panel.order.splice(panel.order.indexOf("75"), 1);
    panel.order.splice(3, 0, "75");
});
expectRefusal("wrong stale IDs", panel => {
    const active = panel.items.find(widget => widget.id === 75);
    const resources = panel.items.find(widget => widget.id === 76);
    active.id = 175;
    resources.id = 176;
    panel.order.splice(-2, 2, "175", "176");
});
expectRefusal("wrong stable order", panel => {
    [panel.order[1], panel.order[2]] = [panel.order[2], panel.order[1]];
});
expectRefusal("wrong stable active-title ID", panel => {
    const active = panel.items.find(widget => widget.id === 81);
    active.id = 181;
    panel.order[2] = "181";
});
expectRefusal("malformed duplicate AppletOrder", panel => {
    panel.order[2] = panel.order[1];
});
expectRefusal("wrong panel geometry", panel => {
    panel.location = "bottom";
});
expectRefusal("wrong stable project geometry", panel => {
    panel.items.find(widget => widget.id === 81).geometry.y = 0;
});
expectRefusal("invalid stale geometry", panel => {
    panel.items.find(widget => widget.id === 76).geometry.width = 0;
});
expectRefusal("changed stable user config", panel => {
    panel.items.find(widget => widget.id === 81)
        .config["General:titleTemplate"] = "changed after receipt";
});
expectRefusal("changed stale user config", panel => {
    panel.items.find(widget => widget.id === 75)
        .config["General:titleTemplate"] = "different stale setting";
});
expectRefusal("changed stable policy revision", panel => {
    panel.items.find(widget => widget.id === 82)
        .config["General:chimeraUiRevision"] = 2;
});
expectRefusal("changed clock appearance", panel => {
    panel.items.find(widget => widget.id === 61)
        .config["Appearance:fontFamily"] = "Noto Sans Mono";
});
{
    const wrongReceipt = clone(expectedStablePanelState);
    wrongReceipt.activeTitle.userConfig.titleTemplate = "wrong receipt setting";
    expectRefusal("mismatched trusted receipt config", () => {}, {
        expected: wrongReceipt
    });
}

// Capture tampering is independently rejected even when live state is valid.
{
    const panel = makePanel("source13");
    const capture = acceptedCapture(panel).capture;
    capture.stableWidgets[2].id = 999;
    const before = panelDigest(panel);
    let refused = false;
    try { cleanup(panel, capture); } catch (error) { refused = true; }
    assert(refused && panelDigest(panel) === before,
        "tampered duplicate-tail capture was accepted or mutated state");
}

// A failed first remove and a no-op first remove must never progress to ID 75.
for (const behavior of ["throw", "noop"]) {
    const panel = makePanel("source13");
    const capture = acceptedCapture(panel).capture;
    panel.items.find(widget => widget.id === 76).removeBehavior = behavior;
    const keepers = keeperDigest(panel);
    let refused = false;
    try { cleanup(panel, capture); } catch (error) { refused = true; }
    assert(refused, behavior + " resource removal was accepted");
    assert(JSON.stringify(panel.removalLog) === JSON.stringify([76]),
        behavior + " resource removal progressed to active title");
    assert(keeperDigest(panel) === keepers,
        behavior + " resource removal changed a keeper");
}

// If the second removal fails, only the exact partial12 state may remain.
for (const behavior of ["throw", "noop"]) {
    const panel = makePanel("source13");
    const capture = acceptedCapture(panel).capture;
    panel.items.find(widget => widget.id === 75).removeBehavior = behavior;
    const keepers = keeperDigest(panel);
    let refused = false;
    try { cleanup(panel, capture); } catch (error) { refused = true; }
    assert(refused, behavior + " active-title removal was accepted");
    assert(JSON.stringify(panel.removalLog) === JSON.stringify([76, 75]),
        behavior + " active-title failure used an unexpected removal order");
    assert(JSON.stringify(panel.order.map(Number)) === JSON.stringify(partialIds),
        behavior + " active-title failure left a non-partial topology");
    assert(keeperDigest(panel) === keepers,
        behavior + " active-title failure changed a keeper");
}

// A concurrent keeper mutation after ID 76 is removed is detected before ID 75.
{
    const panel = makePanel("source13");
    const capture = acceptedCapture(panel).capture;
    panel.items.find(widget => widget.id === 76).afterRemove = () => {
        panel.items.find(widget => widget.id === 81)
            .config["General:titleTemplate"] = "concurrent mutation";
    };
    let refused = false;
    try { cleanup(panel, capture); } catch (error) { refused = true; }
    assert(refused, "concurrent keeper mutation was accepted");
    assert(JSON.stringify(panel.removalLog) === JSON.stringify([76]),
        "concurrent keeper mutation progressed to the second removal");
}

process.stdout.write("PASS: exact Chimera duplicate-tail recovery tests\n");
NODE
