// Read-only postcheck for the Minimalist v0.3 resource strip.

const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const expected = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const missingConfigValue = "__KDE_RICE_MISSING__";

function configTrueOrDefault(value) {
    return value === missingConfigValue
        || value === true
        || String(value) === "true"
        || String(value) === "1";
}

function configFalse(value) {
    return value === false || String(value) === "false" || String(value) === "0";
}

function enumMatches(value, numberValue, nameValue) {
    return String(value) === String(numberValue) || String(value) === nameValue;
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
        return {types: [], widgets: widgets, order: orderText};
    }
    const types = [];
    const orderedWidgets = [];
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!widgetsById[id] || seen[id]) {
            return {types: [], widgets: widgets, order: orderText};
        }
        seen[id] = true;
        types.push(widgetsById[id].type);
        orderedWidgets.push(widgetsById[id]);
    }
    return {types: types, widgets: orderedWidgets, order: orderText};
}

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: [], order: ""};
let resource = null;
let clock = null;
for (let index = 0; index < state.widgets.length; ++index) {
    if (state.widgets[index].type === resourceType) {
        if (resource) {
            resource = null;
            break;
        }
        resource = state.widgets[index];
    } else if (state.widgets[index].type === clockType) {
        if (clock) {
            clock = null;
            break;
        }
        clock = state.widgets[index];
    }
}
let resourceOk = false;
if (resource) {
    resource.currentConfigGroup = ["General"];
    resourceOk = String(resource.readConfig("packageRevision", 0)) === "2";
    resource.currentConfigGroup = [];
}
let clockOk = false;
if (clock) {
    clock.currentConfigGroup = ["Appearance"];
    const showDate = clock.readConfig("showDate", missingConfigValue);
    const showSeconds = clock.readConfig("showSeconds", missingConfigValue);
    const use24h = clock.readConfig("use24hFormat", missingConfigValue);
    const autoFontAndSize = clock.readConfig("autoFontAndSize", missingConfigValue);
    clockOk = configFalse(showDate)
        && enumMatches(showSeconds, 2, "Always")
        && String(use24h) === "2"
        && configTrueOrDefault(autoFontAndSize);
    clock.currentConfigGroup = [];
}
const geometryOk = !!panel
    && panel.screen === 0
    && panel.location === "top"
    && panel.formFactor === "horizontal"
    && Number(panel.height) === 32
    && panel.lengthMode === "fill"
    && panel.hiding === "none"
    && panel.floating === false
    && panel.opacity === "opaque";
const topologyOk = JSON.stringify(state.types) === JSON.stringify(expected);

print(
    "MINIMALIST_V03_POSTCHECK"
    + " geometryOk=" + geometryOk
    + " topologyOk=" + topologyOk
    + " resourceOk=" + resourceOk
    + " clockOk=" + clockOk
    + " appletOrder=" + state.order
    + " widgets=" + (state.types.length ? state.types.join(";") : "none")
);
if (geometryOk && topologyOk && resourceOk && clockOk) {
    print(" MINIMALIST_V03_POSTCHECK_OK");
}
