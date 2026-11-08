// Minimalist v0.4.1 phase two: add one compact native task surface only after
// the second spacer has settled in Plasma's live panel layout.

// BEGIN GENERATED PANEL CONSTANTS
const spacerType = "org.kde.plasma.panelspacer";
const taskType = "org.kde.plasma.icontasks";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const pagerType = "org.kde.plasma.pager";
const workspaceType = "org.kde.minimalist.workspaces";
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
const pagerTargetWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
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
const pagerTargetWidgetsPositions = {
    "launcher": 0,
    "pager": 1,
    "title": 2,
    "leftSpacer": 3,
    "tasks": 4,
    "rightSpacer": 5,
    "resources": 6,
    "margin": 7,
    "input": 8,
    "tray": 9,
    "clock": 10
};
const workspacesTargetWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.workspaces",
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
const workspacesTargetWidgetsPositions = {
    "launcher": 0,
    "workspaces": 1,
    "title": 2,
    "leftSpacer": 3,
    "tasks": 4,
    "rightSpacer": 5,
    "resources": 6,
    "margin": 7,
    "input": 8,
    "tray": 9,
    "clock": 10
};
// END GENERATED PANEL CONSTANTS
const resourceRevision = 2;


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

function validSettledAnchor(widget) {
    return !!widget
        && !!widget.geometry
        && typeof widget.geometry.x === "number"
        && typeof widget.geometry.y === "number"
        && typeof widget.geometry.width === "number"
        && typeof widget.geometry.height === "number"
        && widget.geometry.x > 0
        && widget.geometry.width > 1
        && widget.geometry.height > 0;
}

function findSingleWidget(widgets, type) {
    let match = null;
    for (let index = 0; index < widgets.length; ++index) {
        if (widgets[index].type === type) {
            if (match) {
                return null;
            }
            match = widgets[index];
        }
    }
    return match;
}

function writeGeneralConfig(widget, key, value) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    widget.writeConfig(key, value);
    widget.currentConfigGroup = previousGroup;
}

function configureSpacer(widget) {
    writeGeneralConfig(widget, "expanding", true);
    widget.reloadConfig();
}

function configureTask(widget) {
    writeGeneralConfig(widget, "fill", false);
    writeGeneralConfig(widget, "maxStripes", 1);
    writeGeneralConfig(widget, "iconSpacing", 0);
    widget.reloadConfig();
}

function configureResource(widget) {
    writeGeneralConfig(widget, "packageRevision", resourceRevision);
    widget.reloadConfig();
}

function configurePager(widget) {
    writeGeneralConfig(widget, "displayedText", 0);
    writeGeneralConfig(widget, "showWindowOutlines", false);
    writeGeneralConfig(widget, "showWindowIcons", false);
    widget.reloadConfig();
}

function configureWorkspaces(widget) {
    writeGeneralConfig(widget, "packageRevision", 2);
    widget.reloadConfig();
}

function configureClock(widget) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["Appearance"];
    widget.writeConfig("showDate", false);
    widget.writeConfig("showSeconds", 2);
    widget.writeConfig("use24hFormat", 2);
    widget.writeConfig("autoFontAndSize", false);
    widget.writeConfig("fontFamily", "Noto Sans");
    widget.writeConfig("fontSize", 11);
    widget.writeConfig("fontStyleName", "Regular");
    widget.writeConfig("fontWeight", 400);
    widget.reloadConfig();
    widget.currentConfigGroup = previousGroup;
}

if (panelIds.length !== 1) {
    throw new Error("expected exactly one panel; found " + panelIds.length);
}
const panel = panelById(panelIds[0]);
if (!panel
    || panel.screen !== 0
    || panel.location !== "top"
    || panel.formFactor !== "horizontal"
    || (Number(panel.height) !== 28 && Number(panel.height) !== 32)
    || panel.lengthMode !== "fill"
    || panel.hiding !== "none"
    || panel.floating !== false
    || panel.opacity !== "opaque") {
    throw new Error("the panel is not an approved Minimalist v0.3/v0.4.1 migration geometry");
}
if (knownWidgetTypes.indexOf(spacerType) === -1) {
    throw new Error("the built-in Plasma panel spacer is unavailable");
}
if (knownWidgetTypes.indexOf(taskType) === -1) {
    throw new Error("the built-in Plasma Icons-only Task Manager is unavailable");
}
if (knownWidgetTypes.indexOf(resourceType) === -1) {
    throw new Error("the Minimalist resource widget is unavailable");
}

const before = orderedPanelState(panel);
let transition = "already-target";
let leftSpacer = null;
let rightSpacer = null;
let tasks = null;
let resource = null;
let optionalWidget = null;
let addedTasks = false;
const clock = findSingleWidget(before.widgets, clockType);
if (!clock) {
    throw new Error("could not resolve the built-in digital clock widget");
}

if (sameSequence(before.types, stagedWidgets)) {
    transition = "complete-v04-staged";
    leftSpacer = before.widgets[stagedWidgetsPositions.leftSpacer];
    rightSpacer = before.widgets[stagedWidgetsPositions.rightSpacer];
    resource = before.widgets[stagedWidgetsPositions.resources];
    if (!validSettledAnchor(rightSpacer)) {
        throw new Error("the staged right-spacer placement anchor has not settled");
    }
    tasks = panel.addWidget(
        taskType,
        Math.max(0, rightSpacer.geometry.x - 1),
        rightSpacer.geometry.y,
        1,
        rightSpacer.geometry.height
    );
    if (!tasks) {
        throw new Error("could not add the positioned centered Icons-only Task Manager");
    }
    addedTasks = true;
} else if (sameSequence(before.types, targetWidgets)) {
    leftSpacer = before.widgets[targetWidgetsPositions.leftSpacer];
    tasks = before.widgets[targetWidgetsPositions.tasks];
    rightSpacer = before.widgets[targetWidgetsPositions.rightSpacer];
    resource = before.widgets[targetWidgetsPositions.resources];
} else if (sameSequence(before.types, pagerTargetWidgets)) {
    transition = "already-pager-target";
    optionalWidget = before.widgets[pagerTargetWidgetsPositions.pager];
    leftSpacer = before.widgets[pagerTargetWidgetsPositions.leftSpacer];
    tasks = before.widgets[pagerTargetWidgetsPositions.tasks];
    rightSpacer = before.widgets[pagerTargetWidgetsPositions.rightSpacer];
    resource = before.widgets[pagerTargetWidgetsPositions.resources];
} else if (sameSequence(before.types, workspacesTargetWidgets)) {
    transition = "already-workspaces-target";
    optionalWidget = before.widgets[workspacesTargetWidgetsPositions.workspaces];
    leftSpacer = before.widgets[workspacesTargetWidgetsPositions.leftSpacer];
    tasks = before.widgets[workspacesTargetWidgetsPositions.tasks];
    rightSpacer = before.widgets[workspacesTargetWidgetsPositions.rightSpacer];
    resource = before.widgets[workspacesTargetWidgetsPositions.resources];
} else {
    throw new Error(
        "panel topology differs from the exact settled-v0.4.1-stage/v0.4.1 states: "
        + before.types.join(";")
    );
}

if (!leftSpacer || !rightSpacer || !tasks || !resource) {
    throw new Error("could not resolve every Minimalist v0.4.1 target widget");
}
configureSpacer(leftSpacer);
configureSpacer(rightSpacer);
configureTask(tasks);
configureResource(resource);
if (optionalWidget && optionalWidget.type === pagerType) {
    configurePager(optionalWidget);
} else if (optionalWidget && optionalWidget.type === workspaceType) {
    configureWorkspaces(optionalWidget);
}
configureClock(clock);
panel.height = 32;

print(
    "MINIMALIST_V04_CENTER_TASKS_OK"
    + " transition=" + transition
    + " id=" + panel.id
    + " addedTasks=" + addedTasks
    + " widgets=" + before.types.join(";")
);
