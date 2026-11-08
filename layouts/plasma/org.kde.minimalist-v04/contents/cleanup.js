// Exact live rollback for v0.4.1 additions.  This script removes only the task
// manager and right spacer introduced by the v0.3 -> v0.4.1 migration.

// BEGIN GENERATED PANEL CONSTANTS
const spacerType = "org.kde.plasma.panelspacer";
const taskType = "org.kde.plasma.icontasks";
const resourceType = "org.kde.minimalist.resources";
const v03Widgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const v03WidgetsPositions = {
    "launcher": 0,
    "title": 1,
    "leftSpacer": 2,
    "resources": 3,
    "margin": 4,
    "input": 5,
    "tray": 6,
    "clock": 7
};
const stagedWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const stagedWidgetsPositions = {
    "launcher": 0,
    "title": 1,
    "leftSpacer": 2,
    "rightSpacer": 3,
    "resources": 4,
    "margin": 5,
    "input": 6,
    "tray": 7,
    "clock": 8
};
const taskFrontWidgets = [
    "org.kde.plasma.icontasks",
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const taskFrontWidgetsPositions = {
    "tasks": 0,
    "launcher": 1,
    "title": 2,
    "leftSpacer": 3,
    "rightSpacer": 4,
    "resources": 5,
    "margin": 6,
    "input": 7,
    "tray": 8,
    "clock": 9
};
const targetWidgets = [
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
const targetWidgetsPositions = {
    "launcher": 0,
    "title": 1,
    "leftSpacer": 2,
    "tasks": 3,
    "rightSpacer": 4,
    "resources": 5,
    "margin": 6,
    "input": 7,
    "tray": 8,
    "clock": 9
};
// END GENERATED PANEL CONSTANTS


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
    rightSpacer = before.widgets[stagedWidgetsPositions.rightSpacer];
} else if (sameSequence(before.types, taskFrontWidgets)) {
    transition = "remove-task-front-stage";
    task = before.widgets[taskFrontWidgetsPositions.tasks];
    rightSpacer = before.widgets[taskFrontWidgetsPositions.rightSpacer];
} else if (sameSequence(before.types, targetWidgets)) {
    transition = "remove-v0.4.1-target";
    task = before.widgets[targetWidgetsPositions.tasks];
    rightSpacer = before.widgets[targetWidgetsPositions.rightSpacer];
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
