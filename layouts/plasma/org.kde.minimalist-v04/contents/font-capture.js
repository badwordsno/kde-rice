// Capture the exact project-applet settings and geometry before a guarded
// font/Chimera refresh. The shell persists this JSON only after its snapshot.

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
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

function validProjectGeometry(workspace, activeTitle, resources) {
    const commonReady = [workspace, activeTitle, resources].every(function (widget) {
        return !!widget && !!widget.geometry
            && typeof widget.geometry.x === "number"
            && typeof widget.geometry.y === "number"
            && typeof widget.geometry.width === "number"
            && typeof widget.geometry.height === "number";
    });
    if (!commonReady) return false;
    const compactPair = workspace.geometry.y === 4 && workspace.geometry.height === 24
        && resources.geometry.y === 4 && resources.geometry.height === 24;
    const recognizedTitle = (activeTitle.geometry.y === 0
            && activeTitle.geometry.height === 32)
        || (activeTitle.geometry.y === 4 && activeTitle.geometry.height === 24);
    return compactPair && recognizedTitle;
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

function captureUserConfig(widget) {
    const values = {};
    const presentKeys = [];
    const entries = userConfigKeys[widget.type] || [];
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    const storedKeys = stringSequence(widget.configKeys);
    if (storedKeys === null) {
        widget.currentConfigGroup = previousGroup;
        throw new Error("project-applet stored keys are unavailable: " + widget.type);
    }
    for (let index = 0; index < entries.length; ++index) {
        values[entries[index][0]] = widget.readConfig(
            entries[index][0], entries[index][1]);
        if (storedKeys.indexOf(entries[index][0]) !== -1) {
            presentKeys.push(entries[index][0]);
        }
    }
    widget.currentConfigGroup = previousGroup;
    return {values: values, presentKeys: presentKeys};
}

function captureWidget(widget) {
    const userConfig = captureUserConfig(widget);
    return {
        id: Number(widget.id),
        type: widget.type,
        geometry: {
            x: Number(widget.geometry.x), y: Number(widget.geometry.y),
            width: Number(widget.geometry.width), height: Number(widget.geometry.height)
        },
        userConfig: userConfig.values,
        presentUserConfigKeys: userConfig.presentKeys
    };
}

if (panelIds.length !== 1) throw new Error("capture expected exactly one panel");
const panel = panelById(panelIds[0]);
const state = panel ? orderedPanelState(panel) : {types: [], widgets: []};
if (!panel || !exactPanelGeometry(panel)
        || JSON.stringify(state.types) !== JSON.stringify(expectedWidgets)
        || !validProjectGeometry(state.widgets[1], state.widgets[2], state.widgets[6])) {
    throw new Error("capture target is not the exact recognized Workspaces panel");
}

const captured = {
    schemaVersion: 1,
    panelId: Number(panel.id),
    orderedIds: state.widgets.map(function (widget) { return Number(widget.id); }),
    orderedTypes: state.types,
    workspace: captureWidget(state.widgets[1]),
    activeTitle: captureWidget(state.widgets[2]),
    resources: captureWidget(state.widgets[6])
};
print("MINIMALIST_CHIMERA_CAPTURE=" + JSON.stringify(captured));
