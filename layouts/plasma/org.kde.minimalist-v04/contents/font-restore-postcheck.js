// Read-only proof that failure recovery restored the captured project policy.

if (typeof capturedRefreshState !== "object" || !capturedRefreshState
        || typeof restoreFontRevision !== "number"
        || typeof restoreUiRevision !== "number"
        || typeof restoreClockFamily !== "string") {
    throw new Error("font restore postcheck policy was not supplied");
}

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const customTypes = [workspaceType, activeTitleType, resourceType];
const userConfigKeys = {};
userConfigKeys[activeTitleType] = [
    "titleTemplate", "showIcon", "widthMode", "minimumWidthUnits",
    "preferredWidthUnits", "maximumWidthUnits", "maximizedOnly",
    "wheelSwitch", "doubleClickMaximize", "middleClickClose", "density",
    "surfaceStyle", "bevelDepth", "motionEnabled"
];
userConfigKeys[workspaceType] = [
    "labelMode", "hideWhenSingle", "wrapWheel", "invertWheel", "density",
    "surfaceStyle", "bevelDepth", "motionEnabled"
];
userConfigKeys[resourceType] = [
    "metricOrder", "showCpu", "showMemory", "showGpu", "showVolume",
    "updateRateMs", "warningPercent", "criticalPercent", "showStateRails",
    "density", "surfaceStyle", "bevelDepth", "motionEnabled"
];
const expectedWidgets = [
    "org.kde.plasma.kickoff", workspaceType, activeTitleType,
    "org.kde.plasma.panelspacer", "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer", resourceType,
    "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray", "org.kde.plasma.digitalclock"
];

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

function exactPanelGeometry(panel) {
    return !!panel && panel.screen === 0 && panel.location === "top"
        && panel.formFactor === "horizontal" && Number(panel.height) === 32
        && panel.lengthMode === "fill" && panel.hiding === "none"
        && panel.floating === false && panel.opacity === "opaque";
}

function readConfig(widget, group, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = [group];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
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

function userConfigOk(widget, captured, type) {
    if (!widget || !captured || !captured.userConfig
            || !Array.isArray(captured.presentUserConfigKeys)) return false;
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    const allowedKeys = userConfigKeys[type] || [];
    const storedKeys = stringSequence(widget.configKeys);
    const livePresentKeys = (storedKeys || []).filter(function (key) {
            return allowedKeys.indexOf(key) !== -1;
        }).sort();
    widget.currentConfigGroup = previousGroup;
    if (storedKeys === null) return false;
    const capturedPresentKeys = captured.presentUserConfigKeys.slice().sort();
    if (JSON.stringify(livePresentKeys) !== JSON.stringify(capturedPresentKeys)) {
        return false;
    }
    for (let index = 0; index < captured.presentUserConfigKeys.length; ++index) {
        const key = captured.presentUserConfigKeys[index];
        if (allowedKeys.indexOf(key) === -1) return false;
        if (JSON.stringify(readConfig(widget, "General", key, null))
                !== JSON.stringify(captured.userConfig[key])) return false;
    }
    return true;
}

function sourceGeometryOk(widget, captured) {
    return !!widget && !!widget.geometry && !!captured && !!captured.geometry
        && Number(widget.geometry.y) === Number(captured.geometry.y)
        && Number(widget.geometry.height) === Number(captured.geometry.height);
}

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: []};
const topologyOk = JSON.stringify(state.types) === JSON.stringify(expectedWidgets);
const geometryOk = exactPanelGeometry(panel);
const workspace = topologyOk ? state.widgets[1] : null;
const activeTitle = topologyOk ? state.widgets[2] : null;
const resources = topologyOk ? state.widgets[6] : null;
const clock = topologyOk ? state.widgets[10] : null;
const capturedPreservedIds = [];
const livePreservedIds = [];
if (topologyOk) {
    for (let index = 0; index < expectedWidgets.length; ++index) {
        if (customTypes.indexOf(expectedWidgets[index]) === -1) {
            capturedPreservedIds.push(Number(capturedRefreshState.orderedIds[index]));
            livePreservedIds.push(Number(state.widgets[index].id));
        }
    }
}
const preservedIdsOk = topologyOk
    && JSON.stringify(livePreservedIds) === JSON.stringify(capturedPreservedIds);
const projectPolicyOk = topologyOk
    && String(readConfig(activeTitle, "General", "packageRevision", 0)) === "1"
    && String(readConfig(workspace, "General", "packageRevision", 0)) === "2"
    && String(readConfig(resources, "General", "packageRevision", 0)) === "2"
    && [activeTitle, workspace, resources].every(function (widget) {
        return String(readConfig(widget, "General", "fontPolicyRevision", 0))
                === String(restoreFontRevision)
            && String(readConfig(widget, "General", "chimeraUiRevision", -1))
                === String(restoreUiRevision);
    });
const userConfigRestored = topologyOk
    && userConfigOk(workspace, capturedRefreshState.workspace, workspaceType)
    && userConfigOk(activeTitle, capturedRefreshState.activeTitle, activeTitleType)
    && userConfigOk(resources, capturedRefreshState.resources, resourceType);
const sourceGeometryRestored = topologyOk
    && sourceGeometryOk(workspace, capturedRefreshState.workspace)
    && sourceGeometryOk(activeTitle, capturedRefreshState.activeTitle)
    && sourceGeometryOk(resources, capturedRefreshState.resources);
const clockOk = !!clock
    && String(readConfig(clock, "Appearance", "fontFamily", "missing"))
        === restoreClockFamily;

print(
    "MINIMALIST_FONT_RESTORE_POSTCHECK"
    + " topologyOk=" + topologyOk
    + " geometryOk=" + geometryOk
    + " preservedIdsOk=" + preservedIdsOk
    + " projectPolicyOk=" + projectPolicyOk
    + " userConfigRestored=" + userConfigRestored
    + " sourceGeometryRestored=" + sourceGeometryRestored
    + " clockOk=" + clockOk
);
if (topologyOk && geometryOk && preservedIdsOk && projectPolicyOk
        && userConfigRestored && sourceGeometryRestored && clockOk) {
    print(" MINIMALIST_FONT_RESTORE_POSTCHECK_OK");
}
