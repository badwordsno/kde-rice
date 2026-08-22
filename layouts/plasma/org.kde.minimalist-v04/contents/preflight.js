// Read-only preflight for the Minimalist v0.4.1 centered task strip.

const spacerType = "org.kde.plasma.panelspacer";
const taskType = "org.kde.plasma.icontasks";
const resourceType = "org.kde.minimalist.resources";
const pagerType = "org.kde.plasma.pager";
const workspaceType = "org.kde.minimalist.workspaces";
const v03Widgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const stagedWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const taskFrontStagedWidgets = [
    taskType,
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const v04Widgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    taskType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const v04PagerWidgets = [
    "org.kde.plasma.kickoff",
    pagerType,
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    taskType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const v04WorkspacesWidgets = [
    "org.kde.plasma.kickoff",
    workspaceType,
    "org.kde.minimalist.activewindowtitle",
    spacerType,
    taskType,
    spacerType,
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];

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
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!widgetsById[id] || seen[id]) {
            return {types: [], widgets: []};
        }
        seen[id] = true;
        types.push(widgetsById[id].type);
    }
    return {types: types, widgets: orderIds.map(id => widgetsById[id])};
}

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: []};
const types = state.types;
let topology = "unknown";
if (sameSequence(types, v03Widgets)) {
    topology = "minimalist-v03";
} else if (sameSequence(types, stagedWidgets)) {
    topology = "minimalist-v04-spacer-staged";
} else if (sameSequence(types, taskFrontStagedWidgets)) {
    topology = "minimalist-v04-task-front-staged";
} else if (sameSequence(types, v04Widgets)) {
    topology = "minimalist-v04";
} else if (sameSequence(types, v04PagerWidgets)) {
    topology = "minimalist-v04-pager";
} else if (sameSequence(types, v04WorkspacesWidgets)) {
    topology = "minimalist-v04-workspaces";
}
let rightSpacer = null;
if (topology === "minimalist-v04-spacer-staged") {
    rightSpacer = state.widgets[3];
} else if (topology === "minimalist-v04-task-front-staged") {
    rightSpacer = state.widgets[4];
} else if (topology === "minimalist-v04") {
    rightSpacer = state.widgets[4];
} else if (topology === "minimalist-v04-pager"
    || topology === "minimalist-v04-workspaces") {
    rightSpacer = state.widgets[5];
}
const stageAnchorReady = !rightSpacer || (!!rightSpacer.geometry
    && typeof rightSpacer.geometry.x === "number"
    && typeof rightSpacer.geometry.width === "number"
    && typeof rightSpacer.geometry.height === "number"
    && rightSpacer.geometry.x > 0
    && rightSpacer.geometry.width > 1
    && rightSpacer.geometry.height > 0);
const geometryOk = !!panel
    && panel.screen === 0
    && panel.location === "top"
    && panel.formFactor === "horizontal"
    && (Number(panel.height) === 28 || Number(panel.height) === 32)
    && panel.lengthMode === "fill"
    && panel.hiding === "none"
    && panel.floating === false
    && panel.opacity === "opaque";
const spacerKnown = knownWidgetTypes.indexOf(spacerType) !== -1;
const taskKnown = knownWidgetTypes.indexOf(taskType) !== -1;
const pagerKnown = knownWidgetTypes.indexOf(pagerType) !== -1;
const workspaceKnown = knownWidgetTypes.indexOf(workspaceType) !== -1;
const optionalWidgetKnown = topology !== "minimalist-v04-pager" || pagerKnown;
const optionalWorkspaceKnown = topology !== "minimalist-v04-workspaces" || workspaceKnown;

print(
    "MINIMALIST_V04_PREFLIGHT"
    + " panelCount=" + panelIds.length
    + " topology=" + topology
    + " height=" + (panel ? Number(panel.height) : "none")
    + " geometryOk=" + geometryOk
    + " spacerKnown=" + spacerKnown
    + " taskKnown=" + taskKnown
    + " pagerKnown=" + pagerKnown
    + " workspaceKnown=" + workspaceKnown
    + " stageAnchorReady=" + stageAnchorReady
    + " resourceKnown=" + (knownWidgetTypes.indexOf(resourceType) !== -1)
    + " widgets=" + (types.length ? types.join(";") : "none")
);
if (topology !== "unknown" && geometryOk && spacerKnown && taskKnown
    && optionalWidgetKnown && optionalWorkspaceKnown) {
    print(" MINIMALIST_V04_PREFLIGHT_OK");
}
