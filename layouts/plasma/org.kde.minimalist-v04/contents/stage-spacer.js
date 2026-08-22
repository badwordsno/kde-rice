// Minimalist v0.4.1 phase one: add only the second flexible spacer.  The task
// manager is deliberately created by a later Plasma script invocation, after
// this new spacer has a stable live geometry.

const spacerType = "org.kde.plasma.panelspacer";
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
let rightSpacer = null;
let addedSpacer = false;
if (sameSequence(before.types, v03Widgets)) {
    transition = "stage-v0.4.1-spacer";
    const resource = before.widgets[3];
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
    rightSpacer = before.widgets[3];
} else {
    throw new Error(
        "panel topology differs from the exact Minimalist v0.3/spacer-staged states: "
        + before.types.join(";")
    );
}
configureSpacer(before.widgets[2]);
configureSpacer(rightSpacer);

print(
    "MINIMALIST_V04_STAGE_SPACER_OK"
    + " transition=" + transition
    + " id=" + panel.id
    + " addedSpacer=" + addedSpacer
    + " widgets=" + stagedWidgets.join(";")
);
