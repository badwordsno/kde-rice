// Add and configure one built-in Pager after the launcher. Geometry is used
// because live AppletOrder/index rewrites are not reliable on Plasma 6.7.

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
const pagerWidgets = baseWidgets.slice();
pagerWidgets.splice(1, 0, pagerType);

function sameSequence(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

function orderedPanelState(panel) {
    const widgets = panel.widgets();
    const byId = {};
    for (let index = 0; index < widgets.length; ++index) {
        byId[String(widgets[index].id)] = widgets[index];
    }
    const previousGroup = panel.currentConfigGroup;
    panel.currentConfigGroup = ["General"];
    const orderText = String(panel.readConfig("AppletOrder", ""));
    panel.currentConfigGroup = previousGroup;
    const orderIds = orderText === "" ? [] : orderText.split(";");
    if (orderIds.length !== widgets.length) {
        return {types: [], widgets: []};
    }
    const types = [];
    const orderedWidgets = [];
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!byId[id] || seen[id]) {
            return {types: [], widgets: []};
        }
        seen[id] = true;
        types.push(byId[id].type);
        orderedWidgets.push(byId[id]);
    }
    return {types: types, widgets: orderedWidgets};
}

function exactGeometry(panel) {
    return panel.screen === 0
        && panel.location === "top"
        && panel.formFactor === "horizontal"
        && Number(panel.height) === 32
        && panel.lengthMode === "fill"
        && panel.hiding === "none"
        && panel.floating === false
        && panel.opacity === "opaque";
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

if (panelIds.length !== 1) {
    throw new Error("expected exactly one panel for Pager preview");
}
const panel = panelById(panelIds[0]);
if (!panel || !exactGeometry(panel) || knownWidgetTypes.indexOf(pagerType) === -1) {
    throw new Error("Pager preview prerequisites changed");
}
const before = orderedPanelState(panel);
let pager = null;
let transition = "already-target";
if (sameSequence(before.types, baseWidgets)) {
    const launcher = before.widgets[0];
    const title = before.widgets[1];
    if (!launcher.geometry || !title.geometry
        || typeof launcher.geometry.x !== "number"
        || typeof launcher.geometry.width !== "number"
        || typeof launcher.geometry.height !== "number"
        || typeof title.geometry.x !== "number"
        || launcher.geometry.x + launcher.geometry.width >= title.geometry.x) {
        throw new Error("launcher-to-title insertion anchor is unavailable");
    }
    pager = panel.addWidget(
        pagerType,
        launcher.geometry.x + launcher.geometry.width + 1,
        launcher.geometry.y,
        1,
        launcher.geometry.height
    );
    if (!pager || pager.type !== pagerType) {
        throw new Error("Plasma did not create the built-in Pager");
    }
    transition = "add-pager-after-launcher";
} else if (sameSequence(before.types, pagerWidgets)) {
    pager = before.widgets[1];
} else {
    throw new Error("panel is not an exact Pager-preview source or target");
}

configurePager(pager);
print(
    "MINIMALIST_PAGER_LAYOUT_OK"
    + " transition=" + transition
    + " panelId=" + panel.id
    + " pagerId=" + pager.id
);
