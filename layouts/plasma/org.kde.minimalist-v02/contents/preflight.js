// Read panel order from AppletOrder. Plasma 6.7 keeps widgets() in creation
// order, which can differ from the order shown by the panel after an insert.
const activeTitleType = "org.kde.minimalist.activewindowtitle";
const baseline = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const legacyTarget = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const preTitleTarget = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const target = [
    "org.kde.plasma.kickoff",
    activeTitleType,
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const spacerRecovery = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop",
    "org.kde.plasma.panelspacer"
];
const titleRecovery = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    activeTitleType
];

function rawWidgets(panel) {
    return panel.widgets();
}

function widgetTypes(widgets) {
    const types = [];
    for (let index = 0; index < widgets.length; ++index) {
        types.push(widgets[index].type);
    }
    return types;
}

function orderedTypes(panel) {
    const widgets = rawWidgets(panel);
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
        return [];
    }

    const ordered = [];
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!widgetsById[id] || seen[id]) {
            return [];
        }
        seen[id] = true;
        ordered.push(widgetsById[id].type);
    }
    return ordered;
}

function sameSequence(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const rawTypes = panel ? widgetTypes(rawWidgets(panel)) : [];
const types = panel ? orderedTypes(panel) : [];
let topology = "unknown";
if (sameSequence(types, baseline)) {
    topology = "v0.1";
} else if (sameSequence(types, legacyTarget)) {
    topology = "v0.2-show-desktop";
} else if (sameSequence(types, preTitleTarget)) {
    topology = "v0.2-no-title";
} else if (sameSequence(types, target)) {
    topology = "v0.2";
} else if (sameSequence(types, spacerRecovery)) {
    topology = "v0.2-spacer-repair";
} else if (sameSequence(types, titleRecovery)) {
    topology = "v0.2-title-repair";
}
const spacerKnown = knownWidgetTypes.indexOf("org.kde.plasma.panelspacer") !== -1;
const activeTitleKnown = knownWidgetTypes.indexOf(activeTitleType) !== -1;

print(
    "panels=" + panelIds.length
    + " id=" + (panel ? panel.id : "none")
    + " screen=" + (panel ? panel.screen : "none")
    + " location=" + (panel ? panel.location : "none")
    + " form=" + (panel ? panel.formFactor : "none")
    + " height=" + (panel ? panel.height : "none")
    + " topology=" + topology
    + " spacerKnown=" + spacerKnown
    + " activeTitleKnown=" + activeTitleKnown
    + " widgets=" + types.join(";")
    + " rawWidgets=" + rawTypes.join(";")
);
if (panelIds.length === 1
    && panel
    && panel.screen === 0
    && panel.location === "top"
    && panel.formFactor === "horizontal"
    && topology !== "unknown"
    && spacerKnown) {
    print(" MINIMALIST_V02_PREFLIGHT_OK");
}
