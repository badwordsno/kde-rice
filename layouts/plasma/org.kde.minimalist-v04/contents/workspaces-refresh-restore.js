// Failure recovery for the revision-1 to revision-2 Workspaces refresh.
// The snapshot has already restored the revision-1 package on disk. Recreate
// only the exact Workspaces instance so Plasma reloads that restored package.

const workspaceType = "org.kde.minimalist.workspaces";
const workspaceUserConfigKeys = [
    ["labelMode", 0], ["hideWhenSingle", false], ["wrapWheel", false],
    ["invertWheel", false], ["density", 0], ["surfaceStyle", 0],
    ["bevelDepth", 2],
    ["motionEnabled", true]
];
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
    "org.kde.plasma.digitalclock"
];

function counts(types) {
    const result = {};
    for (let index = 0; index < types.length; ++index) {
        result[types[index]] = (result[types[index]] || 0) + 1;
    }
    return result;
}

function sameCounts(left, right) {
    const leftCounts = counts(left);
    const rightCounts = counts(right);
    const leftKeys = Object.keys(leftCounts).sort();
    const rightKeys = Object.keys(rightCounts).sort();
    if (JSON.stringify(leftKeys) !== JSON.stringify(rightKeys)) {
        return false;
    }
    for (let index = 0; index < leftKeys.length; ++index) {
        if (leftCounts[leftKeys[index]] !== rightCounts[leftKeys[index]]) {
            return false;
        }
    }
    return true;
}

function captureWorkspaceUserConfig(widget) {
    if (!widget) return null;
    const result = {};
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    for (let index = 0; index < workspaceUserConfigKeys.length; ++index) {
        const entry = workspaceUserConfigKeys[index];
        result[entry[0]] = widget.readConfig(entry[0], entry[1]);
    }
    widget.currentConfigGroup = previousGroup;
    return result;
}

function configureRevisionOne(widget, userConfig) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    if (userConfig) {
        const keys = Object.keys(userConfig);
        for (let index = 0; index < keys.length; ++index) {
            widget.writeConfig(keys[index], userConfig[keys[index]]);
        }
    }
    widget.writeConfig("packageRevision", 1);
    widget.reloadConfig();
    widget.currentConfigGroup = previousGroup;
}

if (panelIds.length !== 1 || knownWidgetTypes.indexOf(workspaceType) === -1) {
    throw new Error("refresh restore refused: exact panel or Workspaces package is unavailable");
}
const panel = panelById(panelIds[0]);
const widgets = panel ? panel.widgets() : [];
const workspaceWidgets = widgets.filter(function (widget) {
    return widget.type === workspaceType;
});
const preservedWidgets = widgets.filter(function (widget) {
    return widget.type !== workspaceType;
});
const preservedTypes = preservedWidgets.map(function (widget) {
    return widget.type;
});
const launcherWidgets = preservedWidgets.filter(function (widget) {
    return widget.type === "org.kde.plasma.kickoff";
});

if (!sameCounts(preservedTypes, baseWidgets)
        || launcherWidgets.length !== 1
        || !launcherWidgets[0].geometry
        || workspaceWidgets.length > 1) {
    throw new Error("refresh restore refused: live widgets are not an exact refresh state");
}

let removedId = "none";
const workspaceUserConfig = workspaceWidgets.length === 1
    ? captureWorkspaceUserConfig(workspaceWidgets[0]) : null;
if (workspaceWidgets.length === 1) {
    removedId = workspaceWidgets[0].id;
    workspaceWidgets[0].remove();
}
const launcher = launcherWidgets[0];
const workspace = panel.addWidget(
    workspaceType,
    launcher.geometry.x + launcher.geometry.width + 1,
    launcher.geometry.y,
    1,
    launcher.geometry.height
);
if (!workspace || workspace.type !== workspaceType) {
    throw new Error("refresh restore could not recreate Minimalist Workspaces");
}
configureRevisionOne(workspace, workspaceUserConfig);
print(
    "MINIMALIST_WORKSPACES_REFRESH_RESTORE_OK"
    + " removedWorkspaceId=" + removedId
    + " workspaceId=" + workspace.id
    + " packageRevision=1"
);
