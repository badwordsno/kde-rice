// Read-only exact postcheck for Minimalist Workspaces.

const workspaceType = "org.kde.minimalist.workspaces";
const expectedWidgets = [
    "org.kde.plasma.kickoff",
    workspaceType,
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
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

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: []};
const topologyOk = JSON.stringify(state.types) === JSON.stringify(expectedWidgets);
const workspaceSwitcher = topologyOk ? state.widgets[1] : null;
let workspaceSwitcherOk = false;
if (workspaceSwitcher && workspaceSwitcher.type === workspaceType) {
    const previousGroup = workspaceSwitcher.currentConfigGroup;
    workspaceSwitcher.currentConfigGroup = ["General"];
    const packageRevision = workspaceSwitcher.readConfig("packageRevision", 0);
    workspaceSwitcher.currentConfigGroup = previousGroup;
    workspaceSwitcherOk = String(packageRevision) === "2";
}
const geometryOk = exactGeometry(panel);

print(
    "MINIMALIST_WORKSPACES_POSTCHECK"
    + " panelCount=" + panelIds.length
    + " topologyOk=" + topologyOk
    + " geometryOk=" + geometryOk
    + " workspaceSwitcherOk=" + workspaceSwitcherOk
    + " widgets=" + (state.types.length ? state.types.join(";") : "none")
);
if (topologyOk && geometryOk && workspaceSwitcherOk) {
    print(" MINIMALIST_WORKSPACES_POSTCHECK_OK");
}
