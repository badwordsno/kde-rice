// Read-only exact postcheck for the Noto Sans panel font policy.

const expectedWidgets = [
    "org.kde.plasma.kickoff", "org.kde.minimalist.workspaces",
    "org.kde.minimalist.activewindowtitle", "org.kde.plasma.panelspacer",
    "org.kde.plasma.icontasks", "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources", "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel", "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
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

function readConfig(widget, group, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = [group];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

function exactGeometry(panel) {
    return !!panel && panel.screen === 0 && panel.location === "top"
        && panel.formFactor === "horizontal" && Number(panel.height) === 32
        && panel.lengthMode === "fill" && panel.hiding === "none"
        && panel.floating === false && panel.opacity === "opaque";
}

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: []};
const topologyOk = JSON.stringify(state.types) === JSON.stringify(expectedWidgets);
const geometryOk = exactGeometry(panel);
const workspace = topologyOk ? state.widgets[1] : null;
const activeTitle = topologyOk ? state.widgets[2] : null;
const resources = topologyOk ? state.widgets[6] : null;
const clock = topologyOk ? state.widgets[10] : null;
const projectWidgetsOk = !!workspace && !!activeTitle && !!resources
    && String(readConfig(activeTitle, "General", "packageRevision", 0)) === "1"
    && String(readConfig(workspace, "General", "packageRevision", 0)) === "2"
    && String(readConfig(resources, "General", "packageRevision", 0)) === "2"
    && String(readConfig(activeTitle, "General", "fontPolicyRevision", 0)) === "2"
    && String(readConfig(workspace, "General", "fontPolicyRevision", 0)) === "2"
    && String(readConfig(resources, "General", "fontPolicyRevision", 0)) === "2"
    && String(readConfig(activeTitle, "General", "chimeraUiRevision", 0)) === "2"
    && String(readConfig(workspace, "General", "chimeraUiRevision", 0)) === "2"
    && String(readConfig(resources, "General", "chimeraUiRevision", 0)) === "2";
const projectGeometryOk = !!workspace && !!activeTitle && !!resources
    && workspace.geometry.y === 4 && workspace.geometry.height === 24
    && activeTitle.geometry.y === 4 && activeTitle.geometry.height === 24
    && resources.geometry.y === 4 && resources.geometry.height === 24;
const clockOk = !!clock
    && String(readConfig(clock, "Appearance", "fontFamily", "missing")) === "Noto Sans"
    && ["false", "0"].indexOf(String(readConfig(clock, "Appearance", "autoFontAndSize", "missing"))) !== -1
    && String(readConfig(clock, "Appearance", "fontSize", "missing")) === "11"
    && String(readConfig(clock, "Appearance", "fontStyleName", "missing")) === "Regular"
    && String(readConfig(clock, "Appearance", "fontWeight", "missing")) === "400";

print(
    "MINIMALIST_FONT_POSTCHECK"
    + " panelCount=" + panelIds.length
    + " topologyOk=" + topologyOk
    + " geometryOk=" + geometryOk
    + " projectWidgetsOk=" + projectWidgetsOk
    + " projectGeometryOk=" + projectGeometryOk
    + " clockOk=" + clockOk
    + " widgets=" + (state.types.length ? state.types.join(";") : "none")
);
if (topologyOk && geometryOk && projectWidgetsOk && projectGeometryOk && clockOk) {
    print(" MINIMALIST_FONT_POSTCHECK_OK");
}
