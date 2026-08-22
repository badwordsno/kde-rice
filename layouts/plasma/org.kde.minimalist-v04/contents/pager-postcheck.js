// Read-only exact postcheck for the optional Minimalist v0.4.1 Pager.

const pagerType = "org.kde.plasma.pager";
const expectedWidgets = [
    "org.kde.plasma.kickoff",
    pagerType,
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
const missingConfigValue = "__KDE_RICE_MISSING__";

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

function configFalse(value) {
    return value === false || String(value) === "false" || String(value) === "0";
}

function exactGeometry(panel) {
    return !!panel
        && panel.screen === 0
        && panel.location === "top"
        && panel.formFactor === "horizontal"
        && Number(panel.height) === 32
        && panel.lengthMode === "fill"
        && panel.hiding === "none"
        && panel.floating === false
        && panel.opacity === "opaque";
}

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: []};
const topologyOk = JSON.stringify(state.types) === JSON.stringify(expectedWidgets);
const pager = topologyOk ? state.widgets[1] : null;
let pagerOk = false;
if (pager && pager.type === pagerType) {
    const previousGroup = pager.currentConfigGroup;
    pager.currentConfigGroup = ["General"];
    const displayedText = pager.readConfig("displayedText", missingConfigValue);
    const showWindowOutlines = pager.readConfig("showWindowOutlines", missingConfigValue);
    const showWindowIcons = pager.readConfig("showWindowIcons", missingConfigValue);
    pager.currentConfigGroup = previousGroup;
    pagerOk = (String(displayedText) === "0" || String(displayedText) === "Number")
        && configFalse(showWindowOutlines)
        && configFalse(showWindowIcons);
}
const geometryOk = exactGeometry(panel);

print(
    "MINIMALIST_PAGER_POSTCHECK"
    + " panelCount=" + panelIds.length
    + " topologyOk=" + topologyOk
    + " geometryOk=" + geometryOk
    + " pagerOk=" + pagerOk
    + " widgets=" + (state.types.length ? state.types.join(";") : "none")
);
if (topologyOk && geometryOk && pagerOk) {
    print(" MINIMALIST_PAGER_POSTCHECK_OK");
}
