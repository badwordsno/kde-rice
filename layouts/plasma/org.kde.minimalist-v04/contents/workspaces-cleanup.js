// Failure cleanup for the Pager-to-Workspaces replacement. Restore one stock
// Pager only when every other live widget is the exact preserved v0.4.1 set.

const pagerType = "org.kde.plasma.pager";
const workspaceType = "org.kde.minimalist.workspaces";
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

function configurePager(pager) {
    const previousGroup = pager.currentConfigGroup;
    pager.currentConfigGroup = ["General"];
    pager.writeConfig("displayedText", 0);
    pager.writeConfig("showWindowOutlines", false);
    pager.writeConfig("showWindowIcons", false);
    pager.reloadConfig();
    pager.currentConfigGroup = previousGroup;
}

function addPager(panel, launcher) {
    const pager = panel.addWidget(
        pagerType,
        launcher.geometry.x + launcher.geometry.width + 1,
        launcher.geometry.y,
        1,
        launcher.geometry.height
    );
    if (!pager || pager.type !== pagerType) {
        throw new Error("cleanup could not restore the stock Pager");
    }
    configurePager(pager);
    return pager;
}

if (panelIds.length !== 1 || knownWidgetTypes.indexOf(pagerType) === -1) {
    throw new Error("cleanup refused: exact panel or stock Pager is unavailable");
}
const panel = panelById(panelIds[0]);
const widgets = panel ? panel.widgets() : [];
const pagerWidgets = widgets.filter(function (widget) {
    return widget.type === pagerType;
});
const workspaceWidgets = widgets.filter(function (widget) {
    return widget.type === workspaceType;
});
const preservedWidgets = widgets.filter(function (widget) {
    return widget.type !== pagerType && widget.type !== workspaceType;
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
        || pagerWidgets.length > 1
        || workspaceWidgets.length > 1
        || (pagerWidgets.length === 1 && workspaceWidgets.length === 1)) {
    throw new Error("cleanup refused: live widgets are not an exact replacement state");
}

if (pagerWidgets.length === 1 && workspaceWidgets.length === 0) {
    configurePager(pagerWidgets[0]);
    print("MINIMALIST_WORKSPACES_CLEANUP_OK transition=already-pager pagerId=" + pagerWidgets[0].id);
} else {
    let removedId = "none";
    if (workspaceWidgets.length === 1) {
        removedId = workspaceWidgets[0].id;
        workspaceWidgets[0].remove();
    }
    const pager = addPager(panel, launcherWidgets[0]);
    print(
        "MINIMALIST_WORKSPACES_CLEANUP_OK"
        + " transition=restore-pager"
        + " removedWorkspaceId=" + removedId
        + " pagerId=" + pager.id
    );
}
