// Read-only guard for replacing the stock Pager with Minimalist Workspaces.

const pagerType = "org.kde.plasma.pager";
const workspaceType = "org.kde.minimalist.workspaces";
const baseWidgets = [
    "org.kde.plasma.kickoff",
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
const pagerWidgets = baseWidgets.slice();
pagerWidgets.splice(1, 0, pagerType);
const workspaceWidgets = baseWidgets.slice();
workspaceWidgets.splice(1, 0, workspaceType);

function sameSequence(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
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
let topology = "unknown";
if (sameSequence(state.types, pagerWidgets)) {
    topology = "minimalist-v04-pager";
} else if (sameSequence(state.types, workspaceWidgets)) {
    topology = "minimalist-v04-workspaces";
}
const launcher = topology !== "unknown" ? state.widgets[0] : null;
const title = topology !== "unknown" ? state.widgets[2] : null;
const anchorReady = !!launcher && !!title && !!launcher.geometry && !!title.geometry
    && typeof launcher.geometry.x === "number"
    && typeof launcher.geometry.width === "number"
    && typeof launcher.geometry.height === "number"
    && typeof title.geometry.x === "number"
    && launcher.geometry.width > 0
    && launcher.geometry.height > 0
    && launcher.geometry.x + launcher.geometry.width < title.geometry.x;
const geometryOk = exactGeometry(panel);
const pagerKnown = knownWidgetTypes.indexOf(pagerType) !== -1;
const workspaceKnown = knownWidgetTypes.indexOf(workspaceType) !== -1;
let workspaceRevision = "none";
let workspaceId = "none";
if (topology === "minimalist-v04-workspaces") {
    const workspaceSwitcher = state.widgets[1];
    workspaceId = String(workspaceSwitcher.id);
    const previousGroup = workspaceSwitcher.currentConfigGroup;
    workspaceSwitcher.currentConfigGroup = ["General"];
    workspaceRevision = String(workspaceSwitcher.readConfig("packageRevision", 0));
    workspaceSwitcher.currentConfigGroup = previousGroup;
}

print(
    "MINIMALIST_WORKSPACES_PREFLIGHT"
    + " panelCount=" + panelIds.length
    + " topology=" + topology
    + " height=" + (panel ? Number(panel.height) : "none")
    + " geometryOk=" + geometryOk
    + " anchorReady=" + anchorReady
    + " pagerKnown=" + pagerKnown
    + " workspaceKnown=" + workspaceKnown
    + " workspaceRevision=" + workspaceRevision
    + " workspaceId=" + workspaceId
    + " widgets=" + (state.types.length ? state.types.join(";") : "none")
);
if (topology !== "unknown" && geometryOk && anchorReady && pagerKnown
        && (topology === "minimalist-v04-pager" || workspaceKnown)) {
    print(" MINIMALIST_WORKSPACES_PREFLIGHT_OK");
}
