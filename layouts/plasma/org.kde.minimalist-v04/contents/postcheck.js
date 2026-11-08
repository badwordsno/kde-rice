// Read-only postcheck for the Minimalist v0.4.1 centered task strip.

// BEGIN GENERATED PANEL CONSTANTS
const spacerType = "org.kde.plasma.panelspacer";
const taskType = "org.kde.plasma.icontasks";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const pagerType = "org.kde.plasma.pager";
const workspaceType = "org.kde.minimalist.workspaces";
const expected = [
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
const expectedPositions = {
    "launcher": 0,
    "title": 1,
    "leftSpacer": 2,
    "tasks": 3,
    "rightSpacer": 4,
    "resources": 5,
    "margin": 6,
    "input": 7,
    "tray": 8,
    "clock": 9
};
const pagerExpected = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
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
const pagerExpectedPositions = {
    "launcher": 0,
    "pager": 1,
    "title": 2,
    "leftSpacer": 3,
    "tasks": 4,
    "rightSpacer": 5,
    "resources": 6,
    "margin": 7,
    "input": 8,
    "tray": 9,
    "clock": 10
};
const workspacesExpected = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.workspaces",
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
const workspacesExpectedPositions = {
    "launcher": 0,
    "workspaces": 1,
    "title": 2,
    "leftSpacer": 3,
    "tasks": 4,
    "rightSpacer": 5,
    "resources": 6,
    "margin": 7,
    "input": 8,
    "tray": 9,
    "clock": 10
};
// END GENERATED PANEL CONSTANTS
const missingConfigValue = "__KDE_RICE_MISSING__";


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

function readGeneralConfig(widget, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

function readAppearanceConfig(widget, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["Appearance"];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

function configTrue(value) {
    return value === true || String(value) === "true" || String(value) === "1";
}

function enumMatches(value, numberValue, nameValue) {
    return String(value) === String(numberValue) || String(value) === nameValue;
}

function configFalse(value) {
    return value === false || String(value) === "false" || String(value) === "0";
}

function sameSequence(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: [], order: ""};
let topology = "unknown";
let positions = null;
if (sameSequence(state.types, expected)) {
    topology = "minimalist-v04";
    positions = expectedPositions;
} else if (sameSequence(state.types, pagerExpected)) {
    topology = "minimalist-v04-pager";
    positions = pagerExpectedPositions;
} else if (sameSequence(state.types, workspacesExpected)) {
    topology = "minimalist-v04-workspaces";
    positions = workspacesExpectedPositions;
}
const topologyOk = topology !== "unknown";
// Check the live widget type before inspecting its policy, independently of
// the mutation code and the generated role-to-position data.
function widgetForRole(role, type) {
    const widget = positions ? state.widgets[positions[role]] : null;
    return widget && widget.type === type ? widget : null;
}
const optionalWidget = topology === "minimalist-v04-pager"
    ? widgetForRole("pager", pagerType) : widgetForRole("workspaces", workspaceType);
const leftSpacer = widgetForRole("leftSpacer", spacerType);
const tasks = widgetForRole("tasks", taskType);
const rightSpacer = widgetForRole("rightSpacer", spacerType);
const resource = widgetForRole("resources", resourceType);
const clock = widgetForRole("clock", clockType);
let optionalWidgetOk = topology === "minimalist-v04" || !!optionalWidget;
if (topology === "minimalist-v04-pager" && optionalWidget) {
    const displayedText = readGeneralConfig(optionalWidget, "displayedText", missingConfigValue);
    const showWindowOutlines = readGeneralConfig(optionalWidget, "showWindowOutlines", missingConfigValue);
    const showWindowIcons = readGeneralConfig(optionalWidget, "showWindowIcons", missingConfigValue);
    optionalWidgetOk = (String(displayedText) === "0" || String(displayedText) === "Number")
        && configFalse(showWindowOutlines)
        && configFalse(showWindowIcons);
} else if (topology === "minimalist-v04-workspaces" && optionalWidget) {
    optionalWidgetOk = String(readGeneralConfig(optionalWidget, "packageRevision", 0)) === "2";
}
const leftSpacerOk = !!leftSpacer
    && configTrue(readGeneralConfig(leftSpacer, "expanding", false));
const rightSpacerOk = !!rightSpacer
    && configTrue(readGeneralConfig(rightSpacer, "expanding", false));
const taskFillOk = !!tasks
    && configFalse(readGeneralConfig(tasks, "fill", true));
const taskStripesOk = !!tasks
    && String(readGeneralConfig(tasks, "maxStripes", 0)) === "1";
const taskSpacingOk = !!tasks
    && String(readGeneralConfig(tasks, "iconSpacing", -1)) === "0";
const taskPolicyOk = taskFillOk && taskStripesOk && taskSpacingOk;
const resourceOk = !!resource
    && String(readGeneralConfig(resource, "packageRevision", 0)) === "2";
const showDate = clock ? readAppearanceConfig(clock, "showDate", missingConfigValue) : missingConfigValue;
const showSeconds = clock ? readAppearanceConfig(clock, "showSeconds", missingConfigValue) : missingConfigValue;
const use24h = clock ? readAppearanceConfig(clock, "use24hFormat", missingConfigValue) : missingConfigValue;
const autoFontAndSize = clock ? readAppearanceConfig(clock, "autoFontAndSize", missingConfigValue) : missingConfigValue;
const fontFamily = clock ? readAppearanceConfig(clock, "fontFamily", missingConfigValue) : missingConfigValue;
const fontSize = clock ? readAppearanceConfig(clock, "fontSize", missingConfigValue) : missingConfigValue;
const fontStyleName = clock ? readAppearanceConfig(clock, "fontStyleName", missingConfigValue) : missingConfigValue;
const fontWeight = clock ? readAppearanceConfig(clock, "fontWeight", missingConfigValue) : missingConfigValue;
const clockOk = !!clock
    && configFalse(showDate)
    && enumMatches(showSeconds, 2, "Always")
    && String(use24h) === "2"
    && (autoFontAndSize === false || String(autoFontAndSize) === "false"
        || String(autoFontAndSize) === "0")
    && String(fontFamily) === "Noto Sans"
    && String(fontSize) === "11"
    && String(fontStyleName) === "Regular"
    && String(fontWeight) === "400";
const geometryOk = !!panel
    && panel.screen === 0
    && panel.location === "top"
    && panel.formFactor === "horizontal"
    && Number(panel.height) === 32
    && panel.lengthMode === "fill"
    && panel.hiding === "none"
    && panel.floating === false
    && panel.opacity === "opaque";

print(
    "MINIMALIST_V04_POSTCHECK"
    + " topology=" + topology
    + " geometryOk=" + geometryOk
    + " topologyOk=" + topologyOk
    + " optionalWidgetOk=" + optionalWidgetOk
    + " leftSpacerOk=" + leftSpacerOk
    + " rightSpacerOk=" + rightSpacerOk
    + " taskPolicyOk=" + taskPolicyOk
    + " taskFillOk=" + taskFillOk
    + " taskStripesOk=" + taskStripesOk
    + " taskSpacingOk=" + taskSpacingOk
    + " resourceOk=" + resourceOk
    + " clockOk=" + clockOk
    + " appletOrder=" + state.order
    + " widgets=" + (state.types.length ? state.types.join(";") : "none")
);
if (geometryOk && topologyOk && optionalWidgetOk && leftSpacerOk && rightSpacerOk
    && taskPolicyOk && resourceOk && clockOk) {
    print(" MINIMALIST_V04_POSTCHECK_OK");
}
