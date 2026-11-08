// Read-only guard for the one known post-reboot duplicate-tail state.
// expectedStablePanelState is injected from the trusted refresh receipt. Its
// old geometry is deliberately not used: the running shell is the geometry
// source of truth, while the receipt binds panel/applet identity and user data.

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const stableTypes = [
    "org.kde.plasma.kickoff", workspaceType, activeTitleType,
    "org.kde.plasma.panelspacer", "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer", resourceType,
    "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray", clockType
];
const stableIds = [30, 80, 81, 32, 56, 55, 82, 33, 34, 35, 61];
const staleActiveTitleId = 75;
const staleResourceId = 76;
const userConfigKeys = {};
userConfigKeys[activeTitleType] = [
    ["titleTemplate", "{title}"], ["showIcon", false], ["widthMode", 1],
    ["minimumWidthUnits", 8], ["preferredWidthUnits", 18],
    ["maximumWidthUnits", 20], ["maximizedOnly", false],
    ["wheelSwitch", false], ["doubleClickMaximize", true],
    ["middleClickClose", false], ["density", 0], ["surfaceStyle", 0],
    ["bevelDepth", 2], ["motionEnabled", true]
];
userConfigKeys[workspaceType] = [
    ["labelMode", 0], ["hideWhenSingle", false], ["wrapWheel", false],
    ["invertWheel", false], ["density", 0], ["surfaceStyle", 0],
    ["bevelDepth", 2], ["motionEnabled", true]
];
userConfigKeys[resourceType] = [
    ["metricOrder", "CPU,RAM,GPU,VOL"], ["showCpu", true],
    ["showMemory", true], ["showGpu", true], ["showVolume", true],
    ["updateRateMs", 2000], ["warningPercent", 70],
    ["criticalPercent", 90], ["showStateRails", true], ["density", 0],
    ["surfaceStyle", 0], ["bevelDepth", 2], ["motionEnabled", true]
];

function same(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

function orderedPanelState(panel) {
    const widgets = panel.widgets();
    const byId = {};
    for (let position = 0; position < widgets.length; ++position) {
        byId[String(widgets[position].id)] = widgets[position];
    }
    const previousGroup = panel.currentConfigGroup;
    panel.currentConfigGroup = ["General"];
    const orderText = String(panel.readConfig("AppletOrder", ""));
    panel.currentConfigGroup = previousGroup;
    const orderIds = orderText === "" ? [] : orderText.split(";");
    if (orderIds.length !== widgets.length) return {ids: [], types: [], widgets: []};
    const ids = [];
    const types = [];
    const orderedWidgets = [];
    const seen = {};
    for (let position = 0; position < orderIds.length; ++position) {
        const idText = orderIds[position];
        if (!byId[idText] || seen[idText]) return {ids: [], types: [], widgets: []};
        seen[idText] = true;
        ids.push(Number(byId[idText].id));
        types.push(byId[idText].type);
        orderedWidgets.push(byId[idText]);
    }
    return {ids: ids, types: types, widgets: orderedWidgets};
}

function exactPanelGeometry(panel) {
    return !!panel && panel.screen === 0 && panel.location === "top"
        && panel.formFactor === "horizontal" && Number(panel.height) === 32
        && panel.lengthMode === "fill" && panel.hiding === "none"
        && panel.floating === false && panel.opacity === "opaque";
}

function finiteGeometry(widget) {
    if (!widget || !widget.geometry) return false;
    const geometry = widget.geometry;
    return Number.isFinite(Number(geometry.x))
        && Number.isFinite(Number(geometry.y))
        && Number.isFinite(Number(geometry.width))
        && Number.isFinite(Number(geometry.height))
        && Number(geometry.width) > 0 && Number(geometry.height) > 0;
}

function compactGeometry(widget) {
    return finiteGeometry(widget)
        && Number(widget.geometry.y) === 4
        && Number(widget.geometry.height) === 24;
}

function stringSequence(value) {
    if (!value || typeof value !== "object") return null;
    const length = Number(value.length);
    if (!Number.isFinite(length) || length < 0 || length !== Math.floor(length)
            || length > 256) return null;
    const result = [];
    for (let position = 0; position < length; ++position) {
        if (typeof value[position] === "undefined") return null;
        result.push(String(value[position]));
    }
    return result;
}

function readConfig(widget, group, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = [group];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

function captureUserConfig(widget) {
    const entries = userConfigKeys[widget.type] || [];
    const values = {};
    const presentKeys = [];
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    const storedKeys = stringSequence(widget.configKeys);
    if (storedKeys === null) {
        widget.currentConfigGroup = previousGroup;
        throw new Error("duplicate-tail preflight cannot read stored keys: " + widget.type);
    }
    for (let position = 0; position < entries.length; ++position) {
        const key = entries[position][0];
        values[key] = widget.readConfig(key, entries[position][1]);
        if (storedKeys.indexOf(key) !== -1) presentKeys.push(key);
    }
    widget.currentConfigGroup = previousGroup;
    return {values: values, presentKeys: presentKeys};
}

function expectedUserConfigValid(captured, type) {
    if (!captured || captured.type !== type || !captured.userConfig
            || typeof captured.userConfig !== "object"
            || !Array.isArray(captured.presentUserConfigKeys)) return false;
    const entries = userConfigKeys[type] || [];
    const allowed = [];
    for (let position = 0; position < entries.length; ++position) {
        const key = entries[position][0];
        allowed.push(key);
        if (!Object.prototype.hasOwnProperty.call(captured.userConfig, key)) return false;
    }
    const seen = {};
    for (let position = 0; position < captured.presentUserConfigKeys.length; ++position) {
        const key = captured.presentUserConfigKeys[position];
        if (allowed.indexOf(key) === -1 || seen[key]) return false;
        seen[key] = true;
    }
    return true;
}

function validateExpectedStableState() {
    if (typeof expectedStablePanelState !== "object" || !expectedStablePanelState
            || expectedStablePanelState.schemaVersion !== 1
            || !same(expectedStablePanelState.orderedIds, stableIds)
            || !same(expectedStablePanelState.orderedTypes, stableTypes)
            || Number(expectedStablePanelState.panelId) <= 0
            || !expectedUserConfigValid(expectedStablePanelState.workspace, workspaceType)
            || !expectedUserConfigValid(expectedStablePanelState.activeTitle, activeTitleType)
            || !expectedUserConfigValid(expectedStablePanelState.resources, resourceType)
            || Number(expectedStablePanelState.workspace.id) !== stableIds[1]
            || Number(expectedStablePanelState.activeTitle.id) !== stableIds[2]
            || Number(expectedStablePanelState.resources.id) !== stableIds[6]) {
        throw new Error("trusted stable-panel receipt is missing or not the exact recovery anchor");
    }
}

function expectedCaptureFor(type) {
    if (type === workspaceType) return expectedStablePanelState.workspace;
    if (type === activeTitleType) return expectedStablePanelState.activeTitle;
    if (type === resourceType) return expectedStablePanelState.resources;
    return null;
}

function expectedPackageRevision(type) {
    return type === activeTitleType ? "1" : "2";
}

function captureProjectWidget(widget, expected, requireCompactGeometry) {
    if ((requireCompactGeometry && !compactGeometry(widget))
            || (!requireCompactGeometry && !finiteGeometry(widget))) {
        throw new Error("project widget is not on the exact compact geometry: " + widget.type);
    }
    const packageRevision = String(readConfig(widget, "General", "packageRevision", 0));
    const fontPolicyRevision = String(readConfig(widget, "General", "fontPolicyRevision", 0));
    const chimeraUiRevision = String(readConfig(widget, "General", "chimeraUiRevision", -1));
    if (packageRevision !== expectedPackageRevision(widget.type)
            || fontPolicyRevision !== "2" || chimeraUiRevision !== "1") {
        throw new Error("project widget policy is not the exact duplicate-tail source: " + widget.type);
    }
    const userConfig = captureUserConfig(widget);
    if (!same(userConfig.values, expected.userConfig)
            || !same(userConfig.presentKeys, expected.presentUserConfigKeys)) {
        throw new Error("project widget user data differs from the trusted receipt: " + widget.type);
    }
    return {
        id: Number(widget.id), type: widget.type,
        geometry: {
            x: Number(widget.geometry.x), y: Number(widget.geometry.y),
            width: Number(widget.geometry.width), height: Number(widget.geometry.height)
        },
        generalPolicy: {
            packageRevision: packageRevision,
            fontPolicyRevision: fontPolicyRevision,
            chimeraUiRevision: chimeraUiRevision
        },
        userConfig: userConfig.values,
        presentUserConfigKeys: userConfig.presentKeys
    };
}

function captureClock(widget) {
    if (!finiteGeometry(widget)) throw new Error("clock geometry is unavailable");
    const appearancePolicy = {
        fontFamily: String(readConfig(widget, "Appearance", "fontFamily", "missing")),
        autoFontAndSize: String(readConfig(widget, "Appearance", "autoFontAndSize", "missing")),
        fontSize: String(readConfig(widget, "Appearance", "fontSize", "missing")),
        fontStyleName: String(readConfig(widget, "Appearance", "fontStyleName", "missing")),
        fontWeight: String(readConfig(widget, "Appearance", "fontWeight", "missing"))
    };
    if (appearancePolicy.fontFamily !== "Noto Sans"
            || ["false", "0"].indexOf(appearancePolicy.autoFontAndSize) === -1
            || appearancePolicy.fontSize !== "11"
            || appearancePolicy.fontStyleName !== "Regular"
            || appearancePolicy.fontWeight !== "400") {
        throw new Error("clock is not on the exact Noto Sans policy");
    }
    return {
        id: Number(widget.id), type: widget.type,
        geometry: {
            x: Number(widget.geometry.x), y: Number(widget.geometry.y),
            width: Number(widget.geometry.width), height: Number(widget.geometry.height)
        },
        appearancePolicy: appearancePolicy
    };
}

function captureStableWidget(widget, position) {
    if (!finiteGeometry(widget)) {
        throw new Error("stable widget geometry is unavailable: " + widget.type);
    }
    if (position === 1 || position === 2 || position === 6) {
        return captureProjectWidget(widget, expectedCaptureFor(widget.type), true);
    }
    if (position === 10) return captureClock(widget);
    return {
        id: Number(widget.id), type: widget.type,
        geometry: {
            x: Number(widget.geometry.x), y: Number(widget.geometry.y),
            width: Number(widget.geometry.width), height: Number(widget.geometry.height)
        }
    };
}

validateExpectedStableState();
if (panelIds.length !== 1) throw new Error("duplicate-tail preflight expected exactly one panel");
const panel = panelById(panelIds[0]);
if (!panel || Number(panel.id) !== Number(expectedStablePanelState.panelId)
        || !exactPanelGeometry(panel)) {
    throw new Error("live panel is not the exact receipt-bound recovery target");
}
const state = orderedPanelState(panel);
const sourceIds = stableIds.concat([staleActiveTitleId, staleResourceId]);
const sourceTypes = stableTypes.concat([activeTitleType, resourceType]);
const partialIds = stableIds.concat([staleActiveTitleId]);
const partialTypes = stableTypes.concat([activeTitleType]);
let topologyState = "unknown";
if (same(state.ids, sourceIds) && same(state.types, sourceTypes)) {
    topologyState = "source13";
} else if (same(state.ids, partialIds) && same(state.types, partialTypes)) {
    topologyState = "partial12";
} else if (same(state.ids, stableIds) && same(state.types, stableTypes)) {
    topologyState = "target11";
} else {
    throw new Error("live applet order is not a recognized duplicate-tail recovery state");
}
if (knownWidgetTypes.indexOf(workspaceType) === -1
        || knownWidgetTypes.indexOf(activeTitleType) === -1
        || knownWidgetTypes.indexOf(resourceType) === -1) {
    throw new Error("required project widget types are unavailable");
}

const stableWidgets = [];
for (let position = 0; position < stableTypes.length; ++position) {
    stableWidgets.push(captureStableWidget(state.widgets[position], position));
}
let staleActiveTitle = null;
let staleResources = null;
if (topologyState === "source13" || topologyState === "partial12") {
    staleActiveTitle = captureProjectWidget(
        state.widgets[11], expectedStablePanelState.activeTitle, false);
}
if (topologyState === "source13") {
    staleResources = captureProjectWidget(
        state.widgets[12], expectedStablePanelState.resources, false);
}
const capture = {
    schemaVersion: 1,
    topologyState: topologyState,
    panel: {
        id: Number(panel.id), screen: Number(panel.screen),
        location: String(panel.location), formFactor: String(panel.formFactor),
        height: Number(panel.height), lengthMode: String(panel.lengthMode),
        hiding: String(panel.hiding), floating: panel.floating === true,
        opacity: String(panel.opacity)
    },
    orderedIds: state.ids,
    orderedTypes: state.types,
    stableWidgets: stableWidgets,
    staleActiveTitle: staleActiveTitle,
    staleResources: staleResources
};
print("MINIMALIST_V04_DUPLICATE_TAIL_CAPTURE=" + JSON.stringify(capture));
print(
    "MINIMALIST_V04_DUPLICATE_TAIL_PREFLIGHT"
    + " topologyState=" + topologyState
    + " panelId=" + panel.id
    + " stableIds=" + stableIds.join(";")
    + " staleActiveTitleId=" + (staleActiveTitle ? staleActiveTitle.id : "none")
    + " staleResourceId=" + (staleResources ? staleResources.id : "none")
    + " MINIMALIST_V04_DUPLICATE_TAIL_PREFLIGHT_OK"
);
