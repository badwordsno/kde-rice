// Exact live rollback for v0.4.1 additions.  This script removes only the task
// manager and right spacer introduced by the v0.3 -> v0.4.1 migration.

const spacerType = "org.kde.plasma.panelspacer";
const taskType = "org.kde.plasma.icontasks";
const resourceType = "org.kde.minimalist.resources";
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
const taskFrontWidgets = [
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
const targetWidgets = [
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
        return {types: [], widgets: widgets};
    }
    const types = [];
    const orderedWidgets = [];
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!widgetsById[id] || seen[id]) {
            return {types: [], widgets: widgets};
        }
        seen[id] = true;
        types.push(widgetsById[id].type);
        orderedWidgets.push(widgetsById[id]);
    }
    return {types: types, widgets: orderedWidgets};
}

if (panelIds.length !== 1) {
    throw new Error("expected exactly one panel for v0.4.1 cleanup");
}
const panel = panelById(panelIds[0]);
const before = orderedPanelState(panel);
let transition = "already-v0.3";
let task = null;
let rightSpacer = null;

if (sameSequence(before.types, v03Widgets)) {
    // Nothing from v0.4.1 remains live.
} else if (sameSequence(before.types, stagedWidgets)) {
    transition = "remove-staged-spacer";
    rightSpacer = before.widgets[3];
} else if (sameSequence(before.types, taskFrontWidgets)) {
    transition = "remove-task-front-stage";
    task = before.widgets[0];
    rightSpacer = before.widgets[4];
} else if (sameSequence(before.types, targetWidgets)) {
    transition = "remove-v0.4.1-target";
    task = before.widgets[3];
    rightSpacer = before.widgets[4];
} else {
    throw new Error(
        "refusing cleanup for an unknown panel topology: " + before.types.join(";")
    );
}

if (task) {
    task.remove();
}
if (rightSpacer) {
    rightSpacer.remove();
}

print(
    "MINIMALIST_V04_CLEANUP_OK"
    + " transition=" + transition
    + " removedTask=" + (!!task)
    + " removedSpacer=" + (!!rightSpacer)
);
