// Minimalist v0.2: the guarded legacy status-strip transition for Plasma 6.
//
// This is a deliberately narrow topology change. It accepts only the approved
// Black Minimal v0.1 strip or its own target state, removes the pager and
// icons-only task manager as part of this historical intermediate step, and
// inserts a compact active-window title plus
// Plasma's built-in flexible spacer. The launcher and status controls keep
// their existing instances and settings.

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const activeTitleRevision = 1;

const baselineWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];

const legacyTargetWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];

const preTitleTargetWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];

const targetWidgets = [
    "org.kde.plasma.kickoff",
    activeTitleType,
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];

// Plasma 6.7 appends a widget created without a position hint. Its scripting
// index property is present but is a no-op in that release, so a failed older
// v0.2 attempt can leave this exact, recognizable order behind.
const spacerRecoveryWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop",
    "org.kde.plasma.panelspacer"
];

const titleRecoveryWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    activeTitleType
];

function widgetTypes(panel) {
    const types = [];
    const widgets = panel.widgets();
    for (let index = 0; index < widgets.length; ++index) {
        types.push(widgets[index].type);
    }
    return types;
}

function orderedWidgetTypes(panel) {
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
        return [];
    }

    const types = [];
    const seen = {};
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!widgetsById[id] || seen[id]) {
            return [];
        }
        seen[id] = true;
        types.push(widgetsById[id].type);
    }
    return types;
}

function sameSequence(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

function findWidget(panel, type) {
    const widgets = panel.widgets(type);
    return widgets.length === 1 ? widgets[0] : null;
}

function positionedWidgetAfterLauncher(panel, type, label) {
    const launcher = findWidget(panel, "org.kde.plasma.kickoff");
    if (!launcher) {
        throw new Error("could not resolve the launcher for " + label + " placement");
    }

    const launcherGeometry = launcher.geometry;
    if (!launcherGeometry
        || typeof launcherGeometry.x !== "number"
        || typeof launcherGeometry.y !== "number"
        || typeof launcherGeometry.width !== "number"
        || typeof launcherGeometry.height !== "number") {
        throw new Error("could not resolve launcher geometry for " + label + " placement");
    }

    const position = {
        x: launcherGeometry.x + launcherGeometry.width + 1,
        y: launcherGeometry.y,
        width: 1,
        height: launcherGeometry.height
    };
    const added = panel.addWidget(
        type,
        position.x,
        position.y,
        position.width,
        position.height
    );
    if (!added) {
        throw new Error("could not add the positioned " + label);
    }
    return added;
}

function positionedSpacer(panel) {
    return positionedWidgetAfterLauncher(
        panel,
        "org.kde.plasma.panelspacer",
        "flexible spacer"
    );
}

function positionedActiveTitle(panel) {
    return positionedWidgetAfterLauncher(panel, activeTitleType, "active-window title");
}

function configureActiveTitle(activeTitle) {
    activeTitle.currentConfigGroup = ["General"];
    activeTitle.writeConfig("packageRevision", activeTitleRevision);
    activeTitle.reloadConfig();
    activeTitle.currentConfigGroup = [];
}

function configuredActiveTitleRevision(activeTitle) {
    activeTitle.currentConfigGroup = ["General"];
    const revision = Number(activeTitle.readConfig("packageRevision", 0));
    activeTitle.currentConfigGroup = [];
    return revision;
}

function configureSpacer(spacer) {
    spacer.currentConfigGroup = ["General"];
    spacer.writeConfig("expanding", true);
    spacer.reloadConfig();
    spacer.currentConfigGroup = [];
}

if (panelIds.length !== 1) {
    throw new Error("expected exactly one existing panel; found " + panelIds.length);
}

const panel = panelById(panelIds[0]);
if (!panel) {
    throw new Error("could not resolve the existing panel");
}
if (panel.screen !== 0 || panel.formFactor !== "horizontal" || panel.location !== "top") {
    throw new Error(
        "expected one horizontal top panel on screen 0; found screen=" + panel.screen
        + " formFactor=" + panel.formFactor + " location=" + panel.location
    );
}
if (knownWidgetTypes.indexOf("org.kde.plasma.panelspacer") === -1) {
    throw new Error("the built-in Plasma panel spacer is unavailable");
}
if (knownWidgetTypes.indexOf(activeTitleType) === -1) {
    throw new Error("the Minimalist active-window title widget is unavailable");
}

const beforeTypes = orderedWidgetTypes(panel);
let transition = "already-target";
let spacer = null;
let activeTitle = null;

if (sameSequence(beforeTypes, baselineWidgets)) {
    transition = "v0.1-to-v0.2";
    const pager = findWidget(panel, "org.kde.plasma.pager");
    const tasks = findWidget(panel, "org.kde.plasma.icontasks");
    const showDesktop = findWidget(panel, "org.kde.plasma.showdesktop");
    if (!pager || !tasks || !showDesktop) {
        throw new Error("could not resolve the v0.1 navigation widgets");
    }

    spacer = positionedSpacer(panel);
    configureSpacer(spacer);
    pager.remove();
    tasks.remove();
    showDesktop.remove();
    activeTitle = positionedActiveTitle(panel);
    configureActiveTitle(activeTitle);
} else if (sameSequence(beforeTypes, legacyTargetWidgets)) {
    transition = "remove-show-desktop";
    spacer = findWidget(panel, "org.kde.plasma.panelspacer");
    const showDesktop = findWidget(panel, "org.kde.plasma.showdesktop");
    if (!spacer || !showDesktop) {
        throw new Error("could not resolve the legacy v0.2 widgets");
    }
    showDesktop.remove();
    activeTitle = positionedActiveTitle(panel);
    configureActiveTitle(activeTitle);
} else if (sameSequence(beforeTypes, preTitleTargetWidgets)) {
    transition = "add-active-window-title";
    spacer = findWidget(panel, "org.kde.plasma.panelspacer");
    activeTitle = positionedActiveTitle(panel);
    configureActiveTitle(activeTitle);
} else if (sameSequence(beforeTypes, targetWidgets)) {
    spacer = findWidget(panel, "org.kde.plasma.panelspacer");
    activeTitle = findWidget(panel, activeTitleType);
    if (activeTitle && configuredActiveTitleRevision(activeTitle) < activeTitleRevision) {
        transition = "refresh-active-window-title";
        activeTitle.remove();
        activeTitle = positionedActiveTitle(panel);
        configureActiveTitle(activeTitle);
    }
} else if (sameSequence(beforeTypes, spacerRecoveryWidgets)) {
    transition = "repair-v0.2-spacer-order";
    const appendedSpacer = findWidget(panel, "org.kde.plasma.panelspacer");
    const showDesktop = findWidget(panel, "org.kde.plasma.showdesktop");
    if (!appendedSpacer || !showDesktop) {
        throw new Error("could not resolve the interrupted v0.2 widgets");
    }
    spacer = positionedSpacer(panel);
    configureSpacer(spacer);
    appendedSpacer.remove();
    showDesktop.remove();
    activeTitle = positionedActiveTitle(panel);
    configureActiveTitle(activeTitle);
} else if (sameSequence(beforeTypes, titleRecoveryWidgets)) {
    transition = "repair-v0.2-title-order";
    spacer = findWidget(panel, "org.kde.plasma.panelspacer");
    const appendedTitle = findWidget(panel, activeTitleType);
    if (!spacer || !appendedTitle) {
        throw new Error("could not resolve the interrupted active-window title widgets");
    }
    appendedTitle.remove();
    activeTitle = positionedActiveTitle(panel);
    configureActiveTitle(activeTitle);
} else {
    throw new Error("panel topology differs from the approved v0.1/v0.2 states: " + beforeTypes.join(";"));
}

if (!spacer) {
    throw new Error("could not resolve the v0.2 flexible spacer");
}
if (!activeTitle) {
    throw new Error("could not resolve the v0.2 active-window title");
}

panel.height = 32;
panel.alignment = "center";
panel.offset = 0;
panel.hiding = "none";
panel.floating = false;
panel.opacity = "opaque";
panel.lengthMode = "fill";
const geometry = screenGeometry(panel.screen);
panel.minimumLength = geometry.width;
panel.maximumLength = geometry.width;
panel.length = geometry.width;

configureSpacer(spacer);

const tray = findWidget(panel, "org.kde.plasma.systemtray");
const clock = findWidget(panel, "org.kde.plasma.digitalclock");
if (!tray || !clock) {
    throw new Error("required system tray or digital clock widget is missing");
}

const alwaysShownTrayItems = [
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.notifications"
];
const alwaysHiddenTrayItems = [
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
tray.currentConfigGroup = ["General"];
tray.writeConfig("showAllItems", false);
tray.writeConfig("shownItems", alwaysShownTrayItems);
tray.writeConfig("hiddenItems", alwaysHiddenTrayItems);
tray.writeConfig("iconSpacing", 1);
tray.writeConfig("scaleIconsToFit", true);
tray.reloadConfig();
tray.currentConfigGroup = [];

clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", false);
clock.writeConfig("showSeconds", 2);
clock.writeConfig("use24hFormat", 2);
clock.writeConfig("autoFontAndSize", true);
clock.reloadConfig();
clock.currentConfigGroup = [];

print(
    "MINIMALIST_V02_STATUS_STRIP_OK"
    + " transition=" + transition
    + " id=" + panel.id
    + " width=" + geometry.width
    + " height=" + panel.height
    + " widgets=" + targetWidgets.join(";")
);
