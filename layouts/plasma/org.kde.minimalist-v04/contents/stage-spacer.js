// Minimalist v0.4.1 phase one: add only the second flexible spacer.  The task
// manager is deliberately created by a later Plasma script invocation, after
// this new spacer has a stable live geometry.

// BEGIN GENERATED PANEL CONSTANTS
const spacerType = "org.kde.plasma.panelspacer";
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

function validAnchor(widget) {
    return !!widget
        && !!widget.geometry
        && typeof widget.geometry.x === "number"
        && typeof widget.geometry.y === "number"
        && typeof widget.geometry.height === "number"
        && widget.geometry.x > 0
        && widget.geometry.height > 0;
}

function configureSpacer(widget) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    widget.writeConfig("expanding", true);
    widget.currentConfigGroup = previousGroup;
    widget.reloadConfig();
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

const before = orderedPanelState(panel);
let transition = "already-staged";
let leftSpacer = null;
let rightSpacer = null;
let addedSpacer = false;
if (sameSequence(before.types, v03Widgets)) {
    transition = "stage-v0.4.1-spacer";
    leftSpacer = before.widgets[v03WidgetsPositions.leftSpacer];
    const resource = before.widgets[v03WidgetsPositions.resources];
    if (!validAnchor(resource)) {
        throw new Error("could not resolve the resource placement anchor");
    }
    rightSpacer = panel.addWidget(
        spacerType,
        Math.max(0, resource.geometry.x - 1),
        resource.geometry.y,
        1,
        resource.geometry.height
    );
    if (!rightSpacer) {
        throw new Error("could not add the positioned right flexible spacer");
    }
    addedSpacer = true;
} else if (sameSequence(before.types, stagedWidgets)) {
    leftSpacer = before.widgets[stagedWidgetsPositions.leftSpacer];
    rightSpacer = before.widgets[stagedWidgetsPositions.rightSpacer];
} else {
    throw new Error(
        "panel topology differs from the exact Minimalist v0.3/spacer-staged states: "
        + before.types.join(";")
    );
}
configureSpacer(leftSpacer);
configureSpacer(rightSpacer);

print(
    "MINIMALIST_V04_STAGE_SPACER_OK"
    + " transition=" + transition
    + " id=" + panel.id
    + " addedSpacer=" + addedSpacer
    + " widgets=" + stagedWidgets.join(";")
);
