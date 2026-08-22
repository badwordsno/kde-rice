// Minimalist v0.2 fresh-install transition for Plasma 6.
//
// This is intentionally separate from layout.js so the existing v0.1/v0.2
// transition guards stay unchanged.  It accepts only:
//   1. the exact seven-widget Plasma 6 stock bottom panel;
//   2. that exact stock panel with kimpanel between the margin separator and
//      system tray; or
//   3. the exact Minimalist v0.2 target for an idempotent reapply.
// AppletOrder must be present and valid.  Unknown or interrupted states are
// rejected before any panel or widget mutation.

const targetWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const stockWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const stockImeWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];

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

function sameSequence(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

function strictOrderedState(panel) {
    const widgets = panel.widgets();
    const widgetsById = {};
    for (let index = 0; index < widgets.length; ++index) {
        widgetsById[String(widgets[index].id)] = widgets[index];
    }

    const previousGroup = panel.currentConfigGroup;
    panel.currentConfigGroup = ["General"];
    const appletOrder = String(panel.readConfig("AppletOrder", ""));
    panel.currentConfigGroup = previousGroup;
    const orderIds = appletOrder === "" ? [] : appletOrder.split(";");
    if (orderIds.length !== widgets.length || widgets.length === 0) {
        return {valid: false, types: [], widgets: widgets};
    }

    const seen = {};
    const types = [];
    for (let index = 0; index < orderIds.length; ++index) {
        const id = orderIds[index];
        if (!widgetsById[id] || seen[id]) {
            return {valid: false, types: [], widgets: widgets};
        }
        seen[id] = true;
        types.push(widgetsById[id].type);
    }
    return {valid: true, types: types, widgets: widgets};
}

function rawWidgetTypes(panel) {
    const widgets = panel.widgets();
    const types = [];
    for (let index = 0; index < widgets.length; ++index) {
        types.push(widgets[index].type);
    }
    return types;
}

function findSingleWidget(panel, type) {
    const widgets = panel.widgets(type);
    return widgets.length === 1 ? widgets[0] : null;
}

function configureWidget(widget, group, values) {
    widget.currentConfigGroup = group;
    for (const key in values) {
        if (Object.prototype.hasOwnProperty.call(values, key)) {
            widget.writeConfig(key, values[key]);
        }
    }
    widget.reloadConfig();
    widget.currentConfigGroup = [];
}

function configureTargetPanel(panel) {
    const geometry = screenGeometry(0);
    panel.screen = 0;
    panel.location = "top";
    panel.height = 32;
    panel.alignment = "center";
    panel.offset = 0;
    panel.hiding = "none";
    panel.floating = false;
    panel.opacity = "opaque";
    panel.lengthMode = "fill";
    panel.minimumLength = geometry.width;
    panel.maximumLength = geometry.width;
    panel.length = geometry.width;

    const activeTitle = findSingleWidget(panel, "org.kde.minimalist.activewindowtitle");
    const spacer = findSingleWidget(panel, "org.kde.plasma.panelspacer");
    const tray = findSingleWidget(panel, "org.kde.plasma.systemtray");
    const clock = findSingleWidget(panel, "org.kde.plasma.digitalclock");
    if (!activeTitle || !spacer || !tray || !clock) {
        throw new Error("new target is missing the active title, spacer, tray, or clock");
    }

    configureWidget(activeTitle, ["General"], {packageRevision: 1});
    configureWidget(spacer, ["General"], {expanding: true});
    configureWidget(tray, ["General"], {
        showAllItems: false,
        shownItems: alwaysShownTrayItems,
        hiddenItems: alwaysHiddenTrayItems,
        iconSpacing: 1,
        scaleIconsToFit: true
    });
    configureWidget(clock, ["Appearance"], {
        showDate: false,
        showSeconds: 2,
        use24hFormat: 2,
        autoFontAndSize: true
    });
}

if (panelIds.length !== 1) {
    throw new Error("fresh apply requires exactly one existing panel; found " + panelIds.length);
}
const originalPanel = panelById(panelIds[0]);
if (!originalPanel) {
    throw new Error("could not resolve the single existing panel");
}
const originalState = strictOrderedState(originalPanel);
if (!originalState.valid) {
    throw new Error("fresh apply refuses a missing or malformed AppletOrder");
}

const isTarget = originalPanel.screen === 0
    && originalPanel.formFactor === "horizontal"
    && originalPanel.location === "top"
    && sameSequence(originalState.types, targetWidgets);
const isStock = originalPanel.screen === 0
    && originalPanel.formFactor === "horizontal"
    && originalPanel.location === "bottom"
    && sameSequence(originalState.types, stockWidgets);
const isStockIme = originalPanel.screen === 0
    && originalPanel.formFactor === "horizontal"
    && originalPanel.location === "bottom"
    && sameSequence(originalState.types, stockImeWidgets);

if (!isTarget && !isStock && !isStockIme) {
    throw new Error(
        "fresh apply refuses unknown topology: screen=" + originalPanel.screen
        + " location=" + originalPanel.location
        + " form=" + originalPanel.formFactor
        + " widgets=" + originalState.types.join(";")
    );
}

for (let requiredIndex = 0; requiredIndex < targetWidgets.length; ++requiredIndex) {
    if (knownWidgetTypes.indexOf(targetWidgets[requiredIndex]) === -1) {
        throw new Error("required target widget is unavailable: " + targetWidgets[requiredIndex]);
    }
}

let transition = "already-target";
let removedPanelIds = [];
let removedWidgetIds = [];
let createdPanelId = "none";
let targetPanel = originalPanel;

if (isStock || isStockIme) {
    transition = "replace-fresh-panel";
    removedPanelIds = [originalPanel.id];
    for (let oldIndex = 0; oldIndex < originalState.widgets.length; ++oldIndex) {
        removedWidgetIds.push(originalState.widgets[oldIndex].id);
    }

    // Build and validate the replacement before removing the recognized stock
    // panel.  A failure therefore leaves the original panel available and the
    // pre-apply snapshot can restore any partial managed state.
    targetPanel = new Panel();
    createdPanelId = targetPanel.id;
    try {
        for (let targetIndex = 0; targetIndex < targetWidgets.length; ++targetIndex) {
            const added = targetPanel.addWidget(targetWidgets[targetIndex]);
            if (!added) {
                throw new Error("could not create target widget: " + targetWidgets[targetIndex]);
            }
        }
        if (!sameSequence(rawWidgetTypes(targetPanel), targetWidgets)) {
            throw new Error("new panel widget creation order differs from the target");
        }
        configureTargetPanel(targetPanel);
    } catch (error) {
        targetPanel.remove();
        throw error;
    }
    originalPanel.remove();
} else {
    configureTargetPanel(targetPanel);
}

if (!sameSequence(rawWidgetTypes(targetPanel), targetWidgets)) {
    throw new Error("fresh transition did not produce the exact target widget set");
}

print(
    "MINIMALIST_V02_FRESH_APPLY_OK"
    + " transition=" + transition
    + " removedPanelIds=" + (removedPanelIds.length ? removedPanelIds.join(",") : "none")
    + " removedWidgetIds=" + (removedWidgetIds.length ? removedWidgetIds.join(",") : "none")
    + " createdPanelId=" + createdPanelId
    + " targetPanelId=" + targetPanel.id
    + " widgets=" + targetWidgets.join(";")
);
