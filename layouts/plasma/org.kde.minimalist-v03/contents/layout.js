// Minimalist v0.3: add one compact resource Plasmoid to the v0.2 strip.

const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const resourceRevision = 2;
const v02Widgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const targetWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
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

function configureResource(widget) {
    widget.currentConfigGroup = ["General"];
    widget.writeConfig("packageRevision", resourceRevision);
    widget.reloadConfig();
    widget.currentConfigGroup = [];
}

function configureClock(widget) {
    widget.currentConfigGroup = ["Appearance"];
    widget.writeConfig("showDate", false);
    widget.writeConfig("showSeconds", 2);
    widget.writeConfig("use24hFormat", 2);
    widget.writeConfig("autoFontAndSize", true);
    widget.reloadConfig();
    widget.currentConfigGroup = [];
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
    throw new Error("the panel is not an approved Minimalist v0.2/v0.3 migration geometry");
}
if (knownWidgetTypes.indexOf(resourceType) === -1) {
    throw new Error("the Minimalist resource widget is unavailable");
}

const before = orderedPanelState(panel);
let transition = "already-target";
let resource = null;
const clock = findSingleWidget(before.widgets, clockType);
if (!clock) {
    throw new Error("could not resolve the built-in digital clock widget");
}
if (sameSequence(before.types, v02Widgets)) {
    transition = "v0.2-to-v0.3";
    const margin = findSingleWidget(before.widgets, "org.kde.plasma.marginsseparator");
    if (!margin || !margin.geometry) {
        throw new Error("could not resolve the margin separator placement anchor");
    }
    resource = panel.addWidget(
        resourceType,
        Math.max(0, margin.geometry.x - 1),
        margin.geometry.y,
        1,
        margin.geometry.height
    );
    if (!resource) {
        throw new Error("could not add the Minimalist resource widget");
    }
} else if (sameSequence(before.types, targetWidgets)) {
    resource = findSingleWidget(before.widgets, resourceType);
} else {
    throw new Error("panel topology differs from the exact Minimalist v0.2/v0.3 states: " + before.types.join(";"));
}
if (!resource) {
    throw new Error("could not resolve the Minimalist resource widget");
}
configureResource(resource);
configureClock(clock);
panel.height = 32;

print(
    "MINIMALIST_V03_RESOURCE_STRIP_OK"
    + " transition=" + transition
    + " id=" + panel.id
    + " added=" + (transition === "v0.2-to-v0.3")
    + " widgets=" + targetWidgets.join(";")
);
