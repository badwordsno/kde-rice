// Reload the snapshotted pre-font-policy project packages after a failed write.

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const customTypes = [workspaceType, activeTitleType, resourceType];
const preservedTypesExpected = [
    "org.kde.plasma.kickoff", "org.kde.plasma.panelspacer",
    "org.kde.plasma.icontasks", "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray", "org.kde.plasma.digitalclock"
];

function counts(types) {
    const result = {};
    for (const type of types) result[type] = (result[type] || 0) + 1;
    return result;
}

function sameCounts(left, right) {
    const a = counts(left);
    const b = counts(right);
    const aKeys = Object.keys(a).sort();
    const bKeys = Object.keys(b).sort();
    if (JSON.stringify(aKeys) !== JSON.stringify(bKeys)) return false;
    for (const key of aKeys) if (a[key] !== b[key]) return false;
    return true;
}

function configure(widget, packageRevision) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    widget.writeConfig("packageRevision", packageRevision);
    widget.writeConfig("fontPolicyRevision", 1);
    widget.reloadConfig();
    widget.currentConfigGroup = previousGroup;
}

if (panelIds.length !== 1 || customTypes.some(function (type) {
    return knownWidgetTypes.indexOf(type) === -1;
})) {
    throw new Error("font restore refused: exact panel or restored packages are unavailable");
}
const panel = panelById(panelIds[0]);
const widgets = panel ? panel.widgets() : [];
const customWidgets = widgets.filter(function (widget) {
    return customTypes.indexOf(widget.type) !== -1;
});
const preservedWidgets = widgets.filter(function (widget) {
    return customTypes.indexOf(widget.type) === -1;
});
if (!sameCounts(preservedWidgets.map(function (widget) { return widget.type; }), preservedTypesExpected)
        || customWidgets.filter(function (widget) { return widget.type === workspaceType; }).length > 1
        || customWidgets.filter(function (widget) { return widget.type === activeTitleType; }).length > 1
        || customWidgets.filter(function (widget) { return widget.type === resourceType; }).length > 1) {
    throw new Error("font restore refused: live widgets are not an exact refresh state");
}
const launcher = preservedWidgets.find(function (widget) { return widget.type === "org.kde.plasma.kickoff"; });
const spacers = preservedWidgets.filter(function (widget) { return widget.type === "org.kde.plasma.panelspacer"; });
spacers.sort(function (left, right) { return left.geometry.x - right.geometry.x; });
const margin = preservedWidgets.find(function (widget) { return widget.type === "org.kde.plasma.marginsseparator"; });
const clock = preservedWidgets.find(function (widget) { return widget.type === "org.kde.plasma.digitalclock"; });
if (!launcher || !launcher.geometry || spacers.length !== 2 || !spacers[0].geometry
        || !margin || !margin.geometry || !clock) {
    throw new Error("font restore refused: safe widget anchors are unavailable");
}
for (const widget of customWidgets) widget.remove();
const workspace = panel.addWidget(workspaceType,
    launcher.geometry.x + launcher.geometry.width + 1, launcher.geometry.y, 1, launcher.geometry.height);
const activeTitle = panel.addWidget(activeTitleType,
    spacers[0].geometry.x - 1, spacers[0].geometry.y, 1, spacers[0].geometry.height);
const resources = panel.addWidget(resourceType,
    margin.geometry.x - 1, margin.geometry.y, 1, margin.geometry.height);
if (!workspace || workspace.type !== workspaceType
        || !activeTitle || activeTitle.type !== activeTitleType
        || !resources || resources.type !== resourceType) {
    throw new Error("font restore could not recreate all project widgets");
}
configure(activeTitle, 1);
configure(workspace, 2);
configure(resources, 2);
const previousGroup = clock.currentConfigGroup;
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("fontFamily", "Noto Sans Mono");
clock.reloadConfig();
clock.currentConfigGroup = previousGroup;
print(
    "MINIMALIST_FONT_RESTORE_OK"
    + " workspaceId=" + workspace.id
    + " activeTitleId=" + activeTitle.id
    + " resourceId=" + resources.id
    + " clockId=" + clock.id
);
