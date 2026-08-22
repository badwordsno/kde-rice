// Guarded clock-only policy writer for an exact Minimalist v0.4.1 panel.

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
    return panel.screen === 0
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

function clockPolicyMatches(clock) {
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
    return configFalse(showDate)
        && enumMatches(showSeconds, 2, "Always")
        && String(use24h) === "2"
        && (autoFontAndSize === false || String(autoFontAndSize) === "false"
            || String(autoFontAndSize) === "0")
        && String(fontFamily) === "Noto Sans"
        && String(fontSize) === "11"
        && String(fontStyleName) === "Regular"
        && String(fontWeight) === "400";
}

if (panelIds.length !== 1) {
    throw new Error("expected exactly one panel; found " + panelIds.length);
}
const panel = panelById(panelIds[0]);
if (!panel) {
    throw new Error("could not resolve the only panel");
}
const state = orderedPanelState(panel);
const topology = acceptedTopology(state.types);
if (topology === "unknown" || !exactGeometry(panel)) {
    throw new Error("panel is not the exact 32px Minimalist v0.4.1 target");
}
const clock = state.widgets[state.widgets.length - 1];
if (!clock || clock.type !== clockType) {
    throw new Error("could not resolve the exact built-in digital clock");
}

const previousGroup = clock.currentConfigGroup;
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", false);
clock.writeConfig("showSeconds", 2);
clock.writeConfig("use24hFormat", 2);
clock.writeConfig("autoFontAndSize", false);
clock.writeConfig("fontFamily", "Noto Sans");
clock.writeConfig("fontSize", 11);
clock.writeConfig("fontStyleName", "Regular");
clock.writeConfig("fontWeight", 400);
clock.reloadConfig();
clock.currentConfigGroup = previousGroup;

if (!clockPolicyMatches(clock)) {
    throw new Error("digital clock did not retain the exact managed Appearance policy");
}
print(
    "MINIMALIST_CLOCK_POLICY_OK"
    + " topology=" + topology
    + " panelId=" + panel.id
    + " clockId=" + clock.id
    + " clockOk=true"
);
