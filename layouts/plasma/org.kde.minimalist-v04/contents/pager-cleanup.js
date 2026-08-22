// Failure cleanup for the optional Pager. Remove only one Pager when every
// other live widget is exactly the preserved Minimalist v0.4.1 base set.

const pagerType = "org.kde.plasma.pager";
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

if (panelIds.length !== 1) {
    throw new Error("cleanup refused: expected exactly one panel");
}
const panel = panelById(panelIds[0]);
const widgets = panel ? panel.widgets() : [];
const pagerWidgets = widgets.filter(function (widget) {
    return widget.type === pagerType;
});
const nonPagerTypes = widgets.filter(function (widget) {
    return widget.type !== pagerType;
}).map(function (widget) {
    return widget.type;
});

if (pagerWidgets.length === 0 && sameCounts(widgets.map(function (widget) {
    return widget.type;
}), baseWidgets)) {
    print("MINIMALIST_PAGER_CLEANUP_OK transition=already-base");
} else if (pagerWidgets.length === 1 && sameCounts(nonPagerTypes, baseWidgets)) {
    const removedId = pagerWidgets[0].id;
    pagerWidgets[0].remove();
    print("MINIMALIST_PAGER_CLEANUP_OK transition=remove-pager pagerId=" + removedId);
} else {
    throw new Error("cleanup refused: live widgets are not exact base plus one Pager");
}
