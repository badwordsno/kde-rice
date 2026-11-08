// Refresh the three project widgets and the built-in clock to Noto Sans.

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const userConfigKeys = {};
userConfigKeys[activeTitleType] = [
    ["titleTemplate", "{title}"], ["showIcon", false], ["widthMode", 1],
    ["minimumWidthUnits", 8], ["preferredWidthUnits", 18],
    ["maximumWidthUnits", 20], ["maximizedOnly", false],
    ["wheelSwitch", false], ["doubleClickMaximize", true],
    ["middleClickClose", false], ["density", 0], ["surfaceStyle", 0],
    ["bevelDepth", 2],
    ["motionEnabled", true]
];
userConfigKeys[workspaceType] = [
    ["labelMode", 0], ["hideWhenSingle", false], ["wrapWheel", false],
    ["invertWheel", false], ["density", 0], ["surfaceStyle", 0],
    ["bevelDepth", 2],
    ["motionEnabled", true]
];
userConfigKeys[resourceType] = [
    ["metricOrder", "CPU,RAM,GPU,VOL"], ["showCpu", true],
    ["showMemory", true], ["showGpu", true], ["showVolume", true],
    ["updateRateMs", 2000], ["warningPercent", 70],
    ["criticalPercent", 90], ["showStateRails", true], ["density", 0],
    ["surfaceStyle", 0], ["bevelDepth", 2], ["motionEnabled", true]
];
const expectedWidgets = [
    "org.kde.plasma.kickoff", workspaceType, activeTitleType,
    "org.kde.plasma.panelspacer", "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer", resourceType,
    "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray", clockType
];

function orderedPanelState(panel) {
    const widgets = panel.widgets();
    const byId = {};
    for (let index = 0; index < widgets.length; ++index) byId[String(widgets[index].id)] = widgets[index];
    const previousGroup = panel.currentConfigGroup;
    panel.currentConfigGroup = ["General"];
    const orderText = String(panel.readConfig("AppletOrder", ""));
    panel.currentConfigGroup = previousGroup;
    const orderIds = orderText === "" ? [] : orderText.split(";");
    if (orderIds.length !== widgets.length) return {types: [], widgets: []};
    const types = [];
    const orderedWidgets = [];
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!byId[id] || seen[id]) return {types: [], widgets: []};
        seen[id] = true;
        types.push(byId[id].type);
        orderedWidgets.push(byId[id]);
    }
    return {types: types, widgets: orderedWidgets};
}

function exactGeometry(panel) {
    return !!panel && panel.screen === 0 && panel.location === "top"
        && panel.formFactor === "horizontal" && Number(panel.height) === 32
        && panel.lengthMode === "fill" && panel.hiding === "none"
        && panel.floating === false && panel.opacity === "opaque";
}

function readGeneral(widget, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

function configure(widget, packageRevision, userConfig, presentUserConfigKeys) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    if (userConfig) {
        const keys = Array.isArray(presentUserConfigKeys)
            ? presentUserConfigKeys : [];
        for (let index = 0; index < keys.length; ++index) {
            widget.writeConfig(keys[index], userConfig[keys[index]]);
        }
    }
    widget.writeConfig("packageRevision", packageRevision);
    widget.writeConfig("fontPolicyRevision", 2);
    widget.writeConfig("chimeraUiRevision", 2);
    widget.reloadConfig();
    widget.currentConfigGroup = previousGroup;
}

function sameGeometry(widget, captured) {
    return !!widget.geometry && !!captured
        && Number(widget.geometry.x) === Number(captured.x)
        && Number(widget.geometry.y) === Number(captured.y)
        && Number(widget.geometry.width) === Number(captured.width)
        && Number(widget.geometry.height) === Number(captured.height);
}

function stringSequence(value) {
    if (!value || typeof value !== "object") return null;
    const length = Number(value.length);
    if (!Number.isFinite(length) || length < 0 || length !== Math.floor(length)
            || length > 256) return null;
    const result = [];
    for (let index = 0; index < length; ++index) {
        if (typeof value[index] === "undefined") return null;
        result.push(String(value[index]));
    }
    return result;
}

function validateCapturedWidget(captured, liveWidget, type) {
    if (!captured || Number(captured.id) !== Number(liveWidget.id)
            || captured.type !== type || !sameGeometry(liveWidget, captured.geometry)
            || !captured.userConfig || typeof captured.userConfig !== "object"
            || !Array.isArray(captured.presentUserConfigKeys)) {
        throw new Error("captured project-applet state no longer matches: " + type);
    }
    const entries = userConfigKeys[type] || [];
    const allowedKeys = entries.map(function (entry) { return entry[0]; });
    const capturedPresentKeys = captured.presentUserConfigKeys;
    const seenCapturedKeys = {};
    for (let index = 0; index < entries.length; ++index) {
        if (!Object.prototype.hasOwnProperty.call(
                captured.userConfig, entries[index][0])) {
            throw new Error("captured user configuration is incomplete: " + type);
        }
    }
    for (let index = 0; index < capturedPresentKeys.length; ++index) {
        const key = capturedPresentKeys[index];
        if (allowedKeys.indexOf(key) === -1 || seenCapturedKeys[key]) {
            throw new Error("captured user configuration has an unknown key: " + type);
        }
        seenCapturedKeys[key] = true;
    }

    const previousGroup = liveWidget.currentConfigGroup;
    liveWidget.currentConfigGroup = ["General"];
    const storedKeys = stringSequence(liveWidget.configKeys);
    if (storedKeys === null) {
        liveWidget.currentConfigGroup = previousGroup;
        throw new Error("live user configuration keys are unavailable: " + type);
    }
    const livePresentKeys = [];
    const liveValues = {};
    for (let index = 0; index < entries.length; ++index) {
        const key = entries[index][0];
        liveValues[key] = liveWidget.readConfig(key, entries[index][1]);
        if (storedKeys.indexOf(key) !== -1) livePresentKeys.push(key);
    }
    liveWidget.currentConfigGroup = previousGroup;
    if (JSON.stringify(livePresentKeys) !== JSON.stringify(capturedPresentKeys)) {
        throw new Error("live stored user configuration changed: " + type);
    }
    for (let index = 0; index < entries.length; ++index) {
        const key = entries[index][0];
        if (JSON.stringify(liveValues[key])
                !== JSON.stringify(captured.userConfig[key])) {
            throw new Error("live user configuration changed: " + type + "/" + key);
        }
    }
}

function configureClock(clock) {
    const previousGroup = clock.currentConfigGroup;
    clock.currentConfigGroup = ["Appearance"];
    clock.writeConfig("fontFamily", "Noto Sans");
    clock.reloadConfig();
    clock.currentConfigGroup = previousGroup;
}

if (panelIds.length !== 1) throw new Error("expected exactly one panel");
const panel = panelById(panelIds[0]);
const before = panel ? orderedPanelState(panel) : {types: [], widgets: []};
if (!panel || !exactGeometry(panel)
        || JSON.stringify(before.types) !== JSON.stringify(expectedWidgets)
        || knownWidgetTypes.indexOf(activeTitleType) === -1
        || knownWidgetTypes.indexOf(workspaceType) === -1
        || knownWidgetTypes.indexOf(resourceType) === -1) {
    throw new Error("panel is not the exact font-policy target");
}
let workspace = before.widgets[1];
let activeTitle = before.widgets[2];
let resources = before.widgets[6];
const clock = before.widgets[10];
if (typeof capturedRefreshState !== "object" || !capturedRefreshState
        || capturedRefreshState.schemaVersion !== 1
        || Number(capturedRefreshState.panelId) !== Number(panel.id)
        || JSON.stringify(capturedRefreshState.orderedTypes)
            !== JSON.stringify(before.types)
        || JSON.stringify(capturedRefreshState.orderedIds)
            !== JSON.stringify(before.widgets.map(function (widget) {
                return Number(widget.id);
            }))) {
    throw new Error("captured panel state is missing or stale");
}
validateCapturedWidget(capturedRefreshState.workspace, workspace, workspaceType);
validateCapturedWidget(capturedRefreshState.activeTitle, activeTitle, activeTitleType);
validateCapturedWidget(capturedRefreshState.resources, resources, resourceType);
const compactAnchor = capturedRefreshState.workspace.geometry;
if (Number(compactAnchor.y) !== 4 || Number(compactAnchor.height) !== 24
        || Number(capturedRefreshState.resources.geometry.y) !== 4
        || Number(capturedRefreshState.resources.geometry.height) !== 24) {
    throw new Error("captured compact applet geometry changed");
}
const revisionsOk = String(readGeneral(activeTitle, "packageRevision", 0)) === "1"
    && String(readGeneral(workspace, "packageRevision", 0)) === "2"
    && String(readGeneral(resources, "packageRevision", 0)) === "2";
if (!revisionsOk) throw new Error("project widget package revisions changed");
const fontRevisions = [activeTitle, workspace, resources].map(function (widget) {
    return String(readGeneral(widget, "fontPolicyRevision", 0));
});
const sourceState = fontRevisions.every(function (value) { return value === "1"; });
const targetState = fontRevisions.every(function (value) { return value === "2"; });
if (!sourceState && !targetState) throw new Error("mixed font-policy revision state");
const uiRevisions = [activeTitle, workspace, resources].map(function (widget) {
    return String(readGeneral(widget, "chimeraUiRevision", 0));
});
const uiSourceState = uiRevisions.every(function (value) {
    return value === "0";
}) || uiRevisions.every(function (value) { return value === "1"; });
const uiTargetState = uiRevisions.every(function (value) { return value === "2"; });
if (!uiSourceState && !uiTargetState) throw new Error("mixed Chimera UI revision state");

let transition = "already-target";
if (sourceState || uiSourceState) {
    resources.remove();
    activeTitle.remove();
    workspace.remove();
    workspace = panel.addWidget(workspaceType,
        capturedRefreshState.workspace.geometry.x, compactAnchor.y,
        1, compactAnchor.height);
    if (!workspace || workspace.type !== workspaceType) {
        throw new Error("Plasma did not recreate Workspaces");
    }
    configure(workspace, 2, capturedRefreshState.workspace.userConfig,
        capturedRefreshState.workspace.presentUserConfigKeys);
    activeTitle = panel.addWidget(activeTitleType,
        capturedRefreshState.activeTitle.geometry.x, compactAnchor.y,
        1, compactAnchor.height);
    if (!activeTitle || activeTitle.type !== activeTitleType) {
        throw new Error("Plasma did not recreate the active title");
    }
    configure(activeTitle, 1, capturedRefreshState.activeTitle.userConfig,
        capturedRefreshState.activeTitle.presentUserConfigKeys);
    resources = panel.addWidget(resourceType,
        capturedRefreshState.resources.geometry.x,
        capturedRefreshState.resources.geometry.y, 1,
        capturedRefreshState.resources.geometry.height);
    if (!resources || resources.type !== resourceType) {
        throw new Error("Plasma did not recreate resources");
    }
    configure(resources, 2, capturedRefreshState.resources.userConfig,
        capturedRefreshState.resources.presentUserConfigKeys);
    transition = "refresh-project-widgets";
} else {
    configure(activeTitle, 1, null, null);
    configure(workspace, 2, null, null);
    configure(resources, 2, null, null);
}

configureClock(clock);
print(
    "MINIMALIST_FONT_LAYOUT_OK"
    + " transition=" + transition
    + " fontState=" + (sourceState ? "source" : "target")
    + " uiState=" + (uiSourceState ? "source" : "target")
    + " panelId=" + panel.id
    + " workspaceId=" + workspace.id
    + " activeTitleId=" + activeTitle.id
    + " resourceId=" + resources.id
    + " clockId=" + clock.id
);
