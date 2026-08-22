// Read-only guard for the exact v0.4.1 Workspaces panel font migration.

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const expectedWidgets = [
    "org.kde.plasma.kickoff",
    workspaceType,
    activeTitleType,
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer",
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    clockType
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
    if (orderIds.length !== widgets.length) {
        return {types: [], widgets: []};
    }
    const types = [];
    const orderedWidgets = [];
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!byId[id] || seen[id]) {
            return {types: [], widgets: []};
        }
        seen[id] = true;
        types.push(byId[id].type);
        orderedWidgets.push(byId[id]);
    }
    return {types: types, widgets: orderedWidgets};
}

function exactGeometry(panel) {
    return !!panel
        && panel.screen === 0
        && panel.location === "top"
        && panel.formFactor === "horizontal"
        && Number(panel.height) === 32
        && panel.lengthMode === "fill"
        && panel.hiding === "none"
        && panel.floating === false
        && panel.opacity === "opaque";
}

function readGeneral(widget, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

function readAppearance(widget, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["Appearance"];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: []};
const topologyOk = JSON.stringify(state.types) === JSON.stringify(expectedWidgets);
const geometryOk = exactGeometry(panel);
const workspace = topologyOk ? state.widgets[1] : null;
const activeTitle = topologyOk ? state.widgets[2] : null;
const resources = topologyOk ? state.widgets[6] : null;
const clock = topologyOk ? state.widgets[10] : null;
const activeRevision = activeTitle ? String(readGeneral(activeTitle, "packageRevision", 0)) : "none";
const workspaceRevision = workspace ? String(readGeneral(workspace, "packageRevision", 0)) : "none";
const resourceRevision = resources ? String(readGeneral(resources, "packageRevision", 0)) : "none";
const activeFontRevision = activeTitle ? String(readGeneral(activeTitle, "fontPolicyRevision", 0)) : "none";
const workspaceFontRevision = workspace ? String(readGeneral(workspace, "fontPolicyRevision", 0)) : "none";
const resourceFontRevision = resources ? String(readGeneral(resources, "fontPolicyRevision", 0)) : "none";
const clockFontFamily = clock ? String(readAppearance(clock, "fontFamily", "missing")) : "none";
const clockAuto = clock ? String(readAppearance(clock, "autoFontAndSize", "missing")) : "none";
const clockSize = clock ? String(readAppearance(clock, "fontSize", "missing")) : "none";
const clockStyle = clock ? String(readAppearance(clock, "fontStyleName", "missing")) : "none";
const clockWeight = clock ? String(readAppearance(clock, "fontWeight", "missing")) : "none";
const packageRevisionsOk = activeRevision === "1"
    && workspaceRevision === "2"
    && resourceRevision === "2";
const clockShapeOk = (clockAuto === "false" || clockAuto === "0")
    && clockSize === "11" && clockStyle === "Regular" && clockWeight === "400";
let fontState = "unknown";
if (packageRevisionsOk && clockShapeOk
        && activeFontRevision === "1" && workspaceFontRevision === "1"
        && resourceFontRevision === "1" && clockFontFamily === "Noto Sans Mono") {
    fontState = "source";
} else if (packageRevisionsOk && clockShapeOk
        && activeFontRevision === "2" && workspaceFontRevision === "2"
        && resourceFontRevision === "2" && clockFontFamily === "Noto Sans") {
    fontState = "target";
}
let anchorsReady = topologyOk;
for (const widget of [workspace, activeTitle, resources]) {
    anchorsReady = anchorsReady && !!widget.geometry
        && typeof widget.geometry.x === "number"
        && typeof widget.geometry.y === "number"
        && typeof widget.geometry.height === "number"
        && widget.geometry.height > 0;
}
const customTypesKnown = knownWidgetTypes.indexOf(activeTitleType) !== -1
    && knownWidgetTypes.indexOf(workspaceType) !== -1
    && knownWidgetTypes.indexOf(resourceType) !== -1;

print(
    "MINIMALIST_FONT_PREFLIGHT"
    + " panelCount=" + panelIds.length
    + " topologyOk=" + topologyOk
    + " geometryOk=" + geometryOk
    + " anchorsReady=" + anchorsReady
    + " customTypesKnown=" + customTypesKnown
    + " fontState=" + fontState
    + " activeRevision=" + activeRevision
    + " workspaceRevision=" + workspaceRevision
    + " resourceRevision=" + resourceRevision
    + " activeFontRevision=" + activeFontRevision
    + " workspaceFontRevision=" + workspaceFontRevision
    + " resourceFontRevision=" + resourceFontRevision
    + " clockFontFamily=" + clockFontFamily.split(" ").join("_")
    + " widgets=" + (state.types.length ? state.types.join(";") : "none")
);
if (topologyOk && geometryOk && anchorsReady && customTypesKnown
        && fontState !== "unknown") {
    print(" MINIMALIST_FONT_PREFLIGHT_OK");
}
