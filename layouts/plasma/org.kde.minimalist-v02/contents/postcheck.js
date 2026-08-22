const expected = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
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

function asList(value) {
    if (Array.isArray(value)) {
        return value.map(String);
    }
    const text = String(value === undefined || value === null ? "" : value);
    return text === "" ? [] : text.split(",").map(function (item) {
        return item.trim();
    });
}

function sameMembers(left, right) {
    if (left.length !== right.length) {
        return false;
    }
    for (let index = 0; index < right.length; ++index) {
        if (left.indexOf(right[index]) === -1) {
            return false;
        }
    }
    return true;
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
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!widgetsById[id] || seen[id]) {
            return {types: [], widgets: widgets, order: orderText};
        }
        seen[id] = true;
        types.push(widgetsById[id].type);
    }
    return {types: types, widgets: widgets, order: orderText};
}

const shownExpected = [
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.notifications"
];
const hiddenExpected = [
    "org.kde.kdeconnect",
    "org.kde.plasma.bluetooth",
    "org.kde.plasma.cameraindicator",
    "org.kde.plasma.clipboard",
    "org.kde.plasma.devicenotifier",
    "org.kde.plasma.manage-inputmethod",
    "org.kde.plasma.mediacontroller",
    "org.kde.plasma.keyboardindicator",
    "org.kde.plasma.weather",
    "org.kde.kscreen",
    "org.kde.plasma.battery",
    "org.kde.plasma.brightness",
    "org.kde.plasma.keyboardlayout",
    "org.kde.plasma.printmanager",
    "firewall-applet",
    "chrome_status_icon_1"
];
const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const state = panel ? orderedPanelState(panel) : {types: [], widgets: [], order: ""};
let spacer = null;
let activeTitle = null;
let tray = null;
let clock = null;
for (let index = 0; index < state.widgets.length; ++index) {
    const widget = state.widgets[index];
    if (widget.type === "org.kde.plasma.panelspacer") {
        spacer = widget;
    } else if (widget.type === "org.kde.minimalist.activewindowtitle") {
        activeTitle = widget;
    } else if (widget.type === "org.kde.plasma.systemtray") {
        tray = widget;
    } else if (widget.type === "org.kde.plasma.digitalclock") {
        clock = widget;
    }
}

let spacerOk = false;
if (spacer) {
    spacer.currentConfigGroup = ["General"];
    const expanding = spacer.readConfig("expanding", false);
    spacerOk = expanding === true || String(expanding) === "true" || String(expanding) === "1";
    spacer.currentConfigGroup = [];
}

let activeTitleOk = false;
if (activeTitle) {
    activeTitle.currentConfigGroup = ["General"];
    activeTitleOk = String(activeTitle.readConfig("packageRevision", 0)) === "1";
    activeTitle.currentConfigGroup = [];
}

let trayOk = false;
if (tray) {
    tray.currentConfigGroup = ["General"];
    const shown = asList(tray.readConfig("shownItems", []));
    const hidden = asList(tray.readConfig("hiddenItems", []));
    const showAll = tray.readConfig("showAllItems", true);
    const iconSpacing = tray.readConfig("iconSpacing", 2);
    const scaleIcons = tray.readConfig("scaleIconsToFit", false);
    trayOk = (showAll === false || String(showAll) === "false" || String(showAll) === "0")
        && sameMembers(shown, shownExpected)
        && sameMembers(hidden, hiddenExpected)
        && String(iconSpacing) === "1"
        && (scaleIcons === true || String(scaleIcons) === "true" || String(scaleIcons) === "1");
    tray.currentConfigGroup = [];
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

const geometryBaseOk = !!panel
    && panel.screen === 0
    && panel.location === "top"
    && panel.formFactor === "horizontal"
    && panel.height === 32
    && panel.lengthMode === "fill"
    && panel.hiding === "none"
    && panel.floating === false;
const opacityOk = !!panel && panel.opacity === "opaque";
const geometryOk = geometryBaseOk && opacityOk;
const topologyOk = JSON.stringify(state.types) === JSON.stringify(expected);

print(
    "post panelId=" + (panel ? panel.id : "none")
    + " geometryBaseOk=" + geometryBaseOk
    + " opacityOk=" + opacityOk
    + " geometryOk=" + geometryOk
    + " topologyOk=" + topologyOk
    + " spacerOk=" + spacerOk
    + " activeTitleOk=" + activeTitleOk
    + " trayOk=" + trayOk
    + " clockOk=" + clockOk
    + " appletOrder=" + state.order
    + " widgets=" + state.types.join(";")
);
if (geometryOk && topologyOk && spacerOk && activeTitleOk && trayOk && clockOk) {
    print(" MINIMALIST_V02_POSTCHECK_OK");
}
