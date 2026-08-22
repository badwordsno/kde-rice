// Read-only postcheck for the exact Minimalist v0.4.1 clock policy.

const clockType = "org.kde.plasma.digitalclock";
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
    clockType
];
const pagerWidgets = baseWidgets.slice();
pagerWidgets.splice(1, 0, "org.kde.plasma.pager");
const workspaceWidgets = baseWidgets.slice();
workspaceWidgets.splice(1, 0, "org.kde.minimalist.workspaces");
const missingConfigValue = "__KDE_RICE_MISSING__";

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
        return {types: [], widgets: []};
    }
    const types = [];
    const orderedWidgets = [];
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!widgetsById[id] || seen[id]) {
            return {types: [], widgets: []};
        }
        seen[id] = true;
        types.push(widgetsById[id].type);
        orderedWidgets.push(widgetsById[id]);
    }
    return {types: types, widgets: orderedWidgets};
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

function configFalse(value) {
    return value === false || String(value) === "false" || String(value) === "0";
}

function enumMatches(value, numberValue, nameValue) {
    return String(value) === String(numberValue) || String(value) === nameValue;
}

function acceptedTopology(types) {
    if (sameSequence(types, baseWidgets)) {
        return "minimalist-v04";
    }
    if (sameSequence(types, pagerWidgets)) {
        return "minimalist-v04-pager";
    }
    if (sameSequence(types, workspaceWidgets)) {
        return "minimalist-v04-workspaces";
    }
    return "unknown";
}

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: []};
const topology = acceptedTopology(state.types);
const topologyOk = topology !== "unknown";
const geometryOk = exactGeometry(panel);
const clock = topologyOk ? state.widgets[state.widgets.length - 1] : null;
let clockOk = false;
if (clock && clock.type === clockType) {
    const previousGroup = clock.currentConfigGroup;
    clock.currentConfigGroup = ["Appearance"];
    const showDate = clock.readConfig("showDate", missingConfigValue);
    const showSeconds = clock.readConfig("showSeconds", missingConfigValue);
    const use24h = clock.readConfig("use24hFormat", missingConfigValue);
    const autoFontAndSize = clock.readConfig("autoFontAndSize", missingConfigValue);
    const fontFamily = clock.readConfig("fontFamily", missingConfigValue);
    const fontSize = clock.readConfig("fontSize", missingConfigValue);
    const fontStyleName = clock.readConfig("fontStyleName", missingConfigValue);
    const fontWeight = clock.readConfig("fontWeight", missingConfigValue);
    clock.currentConfigGroup = previousGroup;
    clockOk = configFalse(showDate)
        && enumMatches(showSeconds, 2, "Always")
        && String(use24h) === "2"
        && (autoFontAndSize === false || String(autoFontAndSize) === "false"
            || String(autoFontAndSize) === "0")
        && String(fontFamily) === "Noto Sans"
        && String(fontSize) === "11"
        && String(fontStyleName) === "Regular"
        && String(fontWeight) === "400";
}

print(
    "MINIMALIST_CLOCK_POSTCHECK"
    + " panelCount=" + panelIds.length
    + " topology=" + topology
    + " topologyOk=" + topologyOk
    + " geometryOk=" + geometryOk
    + " clockOk=" + clockOk
    + " widgets=" + (state.types.length ? state.types.join(";") : "none")
);
if (topologyOk && geometryOk && clockOk) {
    print(" MINIMALIST_CLOCK_POSTCHECK_OK");
}
