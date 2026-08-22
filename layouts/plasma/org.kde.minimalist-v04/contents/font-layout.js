// Refresh the three project widgets and the built-in clock to Noto Sans.

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const expectedWidgets = [
    "org.kde.plasma.kickoff", workspaceType, activeTitleType,
    "org.kde.plasma.panelspacer", "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer", resourceType,
    "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray", clockType
];

function orderedPanelState(panel) {
    const widgets = panel.widgets();
    const byId = {};
    for (let index = 0; index < widgets.length; ++index) byId[String(widgets[index].id)] = widgets[index];
    const previousGroup = panel.currentConfigGroup;
    panel.currentConfigGroup = ["General"];
    const orderText = String(panel.readConfig("AppletOrder", ""));
    panel.currentConfigGroup = previousGroup;
    const orderIds = orderText === "" ? [] : orderText.split(";");
    if (orderIds.length !== widgets.length) return {types: [], widgets: []};
    const types = [];
    const orderedWidgets = [];
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!byId[id] || seen[id]) return {types: [], widgets: []};
        seen[id] = true;
        types.push(byId[id].type);
        orderedWidgets.push(byId[id]);
    }
    return {types: types, widgets: orderedWidgets};
}

function exactGeometry(panel) {
    return !!panel && panel.screen === 0 && panel.location === "top"
        && panel.formFactor === "horizontal" && Number(panel.height) === 32
        && panel.lengthMode === "fill" && panel.hiding === "none"
        && panel.floating === false && panel.opacity === "opaque";
}

function readGeneral(widget, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

function configure(widget, packageRevision) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    widget.writeConfig("packageRevision", packageRevision);
    widget.writeConfig("fontPolicyRevision", 2);
    widget.reloadConfig();
    widget.currentConfigGroup = previousGroup;
}

function configureClock(clock) {
    const previousGroup = clock.currentConfigGroup;
    clock.currentConfigGroup = ["Appearance"];
    clock.writeConfig("fontFamily", "Noto Sans");
    clock.reloadConfig();
    clock.currentConfigGroup = previousGroup;
}

if (panelIds.length !== 1) throw new Error("expected exactly one panel");
const panel = panelById(panelIds[0]);
const before = panel ? orderedPanelState(panel) : {types: [], widgets: []};
if (!panel || !exactGeometry(panel)
        || JSON.stringify(before.types) !== JSON.stringify(expectedWidgets)
        || knownWidgetTypes.indexOf(activeTitleType) === -1
        || knownWidgetTypes.indexOf(workspaceType) === -1
        || knownWidgetTypes.indexOf(resourceType) === -1) {
    throw new Error("panel is not the exact font-policy target");
}
let workspace = before.widgets[1];
let activeTitle = before.widgets[2];
let resources = before.widgets[6];
const clock = before.widgets[10];
const revisionsOk = String(readGeneral(activeTitle, "packageRevision", 0)) === "1"
    && String(readGeneral(workspace, "packageRevision", 0)) === "2"
    && String(readGeneral(resources, "packageRevision", 0)) === "2";
if (!revisionsOk) throw new Error("project widget package revisions changed");
const fontRevisions = [activeTitle, workspace, resources].map(function (widget) {
    return String(readGeneral(widget, "fontPolicyRevision", 0));
});
const sourceState = fontRevisions.every(function (value) { return value === "1"; });
const targetState = fontRevisions.every(function (value) { return value === "2"; });
if (!sourceState && !targetState) throw new Error("mixed font-policy revision state");

let transition = "already-target";
if (sourceState) {
    const positions = [workspace, activeTitle, resources].map(function (widget) {
        if (!widget.geometry || typeof widget.geometry.x !== "number"
                || typeof widget.geometry.y !== "number"
                || typeof widget.geometry.height !== "number") {
            throw new Error("project widget geometry is unavailable");
        }
        return {x: widget.geometry.x, y: widget.geometry.y, height: widget.geometry.height};
    });
    resources.remove();
    activeTitle.remove();
    workspace.remove();
    workspace = panel.addWidget(workspaceType, positions[0].x, positions[0].y, 1, positions[0].height);
    activeTitle = panel.addWidget(activeTitleType, positions[1].x, positions[1].y, 1, positions[1].height);
    resources = panel.addWidget(resourceType, positions[2].x, positions[2].y, 1, positions[2].height);
    if (!workspace || workspace.type !== workspaceType
            || !activeTitle || activeTitle.type !== activeTitleType
            || !resources || resources.type !== resourceType) {
        throw new Error("Plasma did not recreate all project widgets");
    }
    transition = "refresh-project-widgets";
}

configure(activeTitle, 1);
configure(workspace, 2);
configure(resources, 2);
configureClock(clock);
print(
    "MINIMALIST_FONT_LAYOUT_OK"
    + " transition=" + transition
    + " panelId=" + panel.id
    + " workspaceId=" + workspace.id
    + " activeTitleId=" + activeTitle.id
    + " resourceId=" + resources.id
    + " clockId=" + clock.id
);
