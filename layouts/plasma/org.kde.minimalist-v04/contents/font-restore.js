// Reload the snapshotted project packages after a failed font/UI refresh.

if (typeof restoreFontRevision !== "number"
        || (restoreFontRevision !== 1 && restoreFontRevision !== 2)
        || typeof restoreUiRevision !== "number"
        || (restoreUiRevision !== 0 && restoreUiRevision !== 1
            && restoreUiRevision !== 2)
        || typeof restoreClockFamily !== "string"
        || (restoreClockFamily !== "Noto Sans"
            && restoreClockFamily !== "Noto Sans Mono")) {
    throw new Error("font restore policy was not supplied");
}

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const customTypes = [workspaceType, activeTitleType, resourceType];
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
const preservedTypesExpected = [
    "org.kde.plasma.kickoff", "org.kde.plasma.panelspacer",
    "org.kde.plasma.icontasks", "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray", "org.kde.plasma.digitalclock"
];

function refreshSlotToken(type, id) {
    return customTypes.indexOf(type) === -1
        ? "preserved:" + Number(id) + ":" + type
        : "custom:" + type;
}

function exactPartialRefreshOrder(state, captured) {
    const currentCustomTypes = state.widgets.filter(function (widget) {
        return customTypes.indexOf(widget.type) !== -1;
    }).map(function (widget) { return widget.type; });
    const expectedTokens = [];
    for (let index = 0; index < captured.orderedTypes.length; ++index) {
        const type = captured.orderedTypes[index];
        if (customTypes.indexOf(type) === -1
                || currentCustomTypes.indexOf(type) !== -1) {
            expectedTokens.push(refreshSlotToken(type, captured.orderedIds[index]));
        }
    }
    const currentTokens = state.widgets.map(function (widget) {
        return refreshSlotToken(widget.type, widget.id);
    });
    return JSON.stringify(currentTokens) === JSON.stringify(expectedTokens);
}

function orderedPanelState(panel) {
    const widgets = panel.widgets();
    const byId = {};
    for (let index = 0; index < widgets.length; ++index) {
        byId[String(widgets[index].id)] = widgets[index];
    }
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

function validateCapturedWidget(captured, type) {
    if (!captured || captured.type !== type || !captured.geometry
            || !captured.userConfig || typeof captured.userConfig !== "object") {
        throw new Error("font restore capture is incomplete: " + type);
    }
    const entries = userConfigKeys[type] || [];
    if (!Array.isArray(captured.presentUserConfigKeys)) {
        throw new Error("font restore stored-key list is incomplete: " + type);
    }
    const allowedKeys = entries.map(function (entry) { return entry[0]; });
    for (let index = 0; index < entries.length; ++index) {
        if (!Object.prototype.hasOwnProperty.call(
                captured.userConfig, entries[index][0])) {
            throw new Error("font restore user configuration is incomplete: " + type);
        }
    }
    for (let index = 0; index < captured.presentUserConfigKeys.length; ++index) {
        if (allowedKeys.indexOf(captured.presentUserConfigKeys[index]) === -1) {
            throw new Error("font restore capture has an unknown key: " + type);
        }
    }
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
    widget.writeConfig("fontPolicyRevision", restoreFontRevision);
    widget.writeConfig("chimeraUiRevision", restoreUiRevision);
    widget.reloadConfig();
    widget.currentConfigGroup = previousGroup;
}

if (panelIds.length !== 1 || customTypes.some(function (type) {
    return knownWidgetTypes.indexOf(type) === -1;
})) {
    throw new Error("font restore refused: exact panel or restored packages are unavailable");
}
const panel = panelById(panelIds[0]);
const state = panel ? orderedPanelState(panel) : {types: [], widgets: []};
const widgets = state.widgets;
const customWidgets = widgets.filter(function (widget) {
    return customTypes.indexOf(widget.type) !== -1;
});
const preservedWidgets = widgets.filter(function (widget) {
    return customTypes.indexOf(widget.type) === -1;
});
const capturedPreservedIds = [];
if (!panel || typeof capturedRefreshState !== "object" || !capturedRefreshState
        || capturedRefreshState.schemaVersion !== 1
        || Number(capturedRefreshState.panelId) !== Number(panel.id)
        || !Array.isArray(capturedRefreshState.orderedIds)
        || !Array.isArray(capturedRefreshState.orderedTypes)) {
    throw new Error("font restore capture is missing or stale");
}
for (let index = 0; index < capturedRefreshState.orderedTypes.length; ++index) {
    if (customTypes.indexOf(capturedRefreshState.orderedTypes[index]) === -1) {
        capturedPreservedIds.push(Number(capturedRefreshState.orderedIds[index]));
    }
}
validateCapturedWidget(capturedRefreshState.workspace, workspaceType);
validateCapturedWidget(capturedRefreshState.activeTitle, activeTitleType);
validateCapturedWidget(capturedRefreshState.resources, resourceType);
if (!exactGeometry(panel)
        || JSON.stringify(preservedWidgets.map(function (widget) {
            return widget.type;
        })) !== JSON.stringify(preservedTypesExpected)
        || JSON.stringify(preservedWidgets.map(function (widget) {
            return Number(widget.id);
        })) !== JSON.stringify(capturedPreservedIds)
        || customWidgets.filter(function (widget) { return widget.type === workspaceType; }).length > 1
        || customWidgets.filter(function (widget) { return widget.type === activeTitleType; }).length > 1
        || customWidgets.filter(function (widget) { return widget.type === resourceType; }).length > 1
        || !exactPartialRefreshOrder(state, capturedRefreshState)) {
    throw new Error("font restore refused: live widgets are not an exact refresh state");
}
const clock = preservedWidgets.find(function (widget) { return widget.type === "org.kde.plasma.digitalclock"; });
if (!clock) throw new Error("font restore refused: clock is unavailable");
for (const widget of customWidgets) widget.remove();
const workspace = panel.addWidget(workspaceType,
    capturedRefreshState.workspace.geometry.x,
    capturedRefreshState.workspace.geometry.y, 1,
    capturedRefreshState.workspace.geometry.height);
if (!workspace || workspace.type !== workspaceType) {
    throw new Error("font restore could not recreate Workspaces");
}
configure(workspace, 2, capturedRefreshState.workspace.userConfig,
    capturedRefreshState.workspace.presentUserConfigKeys);
const activeTitle = panel.addWidget(activeTitleType,
    capturedRefreshState.activeTitle.geometry.x,
    capturedRefreshState.activeTitle.geometry.y, 1,
    capturedRefreshState.activeTitle.geometry.height);
if (!activeTitle || activeTitle.type !== activeTitleType) {
    throw new Error("font restore could not recreate the active title");
}
configure(activeTitle, 1, capturedRefreshState.activeTitle.userConfig,
    capturedRefreshState.activeTitle.presentUserConfigKeys);
const resources = panel.addWidget(resourceType,
    capturedRefreshState.resources.geometry.x,
    capturedRefreshState.resources.geometry.y, 1,
    capturedRefreshState.resources.geometry.height);
if (!resources || resources.type !== resourceType) {
    throw new Error("font restore could not recreate resources");
}
configure(resources, 2, capturedRefreshState.resources.userConfig,
    capturedRefreshState.resources.presentUserConfigKeys);
const previousGroup = clock.currentConfigGroup;
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("fontFamily", restoreClockFamily);
clock.reloadConfig();
clock.currentConfigGroup = previousGroup;
print(
    "MINIMALIST_FONT_RESTORE_OK"
    + " workspaceId=" + workspace.id
    + " activeTitleId=" + activeTitle.id
    + " resourceId=" + resources.id
    + " clockId=" + clock.id
    + " fontRevision=" + restoreFontRevision
    + " uiRevision=" + restoreUiRevision
);
