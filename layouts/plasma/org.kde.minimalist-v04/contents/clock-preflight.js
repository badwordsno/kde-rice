// Read-only guard for the Minimalist v0.4.1 built-in Digital Clock policy.

const clockType = "org.kde.plasma.digitalclock";
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
    clockType
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
    const widgetsById = {};
    for (let index = 0; index < widgets.length; ++index) {
        widgetsById[String(widgets[index].id)] = widgets[index];
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
        if (!widgetsById[id] || seen[id]) {
            return {types: [], widgets: []};
        }
        seen[id] = true;
        types.push(widgetsById[id].type);
        orderedWidgets.push(widgetsById[id]);
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
if (sameSequence(state.types, baseWidgets)) {
    topology = "minimalist-v04";
} else if (sameSequence(state.types, pagerWidgets)) {
    topology = "minimalist-v04-pager";
} else if (sameSequence(state.types, workspaceWidgets)) {
    topology = "minimalist-v04-workspaces";
}
const geometryOk = exactGeometry(panel);
const clockKnown = knownWidgetTypes.indexOf(clockType) !== -1;
let workspaceRevision = "none";
if (topology === "minimalist-v04-workspaces") {
    const workspaceSwitcher = state.widgets[1];
    const previousGroup = workspaceSwitcher.currentConfigGroup;
    workspaceSwitcher.currentConfigGroup = ["General"];
    workspaceRevision = String(workspaceSwitcher.readConfig("packageRevision", 0));
    workspaceSwitcher.currentConfigGroup = previousGroup;
}

print(
    "MINIMALIST_CLOCK_PREFLIGHT"
    + " panelCount=" + panelIds.length
    + " topology=" + topology
    + " height=" + (panel ? Number(panel.height) : "none")
    + " geometryOk=" + geometryOk
    + " clockKnown=" + clockKnown
    + " workspaceRevision=" + workspaceRevision
    + " widgets=" + (state.types.length ? state.types.join(";") : "none")
);
if (topology !== "unknown" && geometryOk && clockKnown) {
    print(" MINIMALIST_CLOCK_PREFLIGHT_OK");
}
