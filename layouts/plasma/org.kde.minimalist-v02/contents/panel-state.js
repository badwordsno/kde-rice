// Read-only Minimalist panel-state probe.
//
// Consumers must parse the JSON following KDE_RICE_PANEL_STATE_JSON=.  This
// script deliberately performs no writes, reloads, widget creation/removal, or
// panel creation/removal.  AppletOrder is authoritative: a missing, duplicate,
// or otherwise malformed order is classified as unknown instead of falling
// back to Plasma's widget creation order.

const minimalistTargetWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const minimalistV03TargetWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const minimalistV04SpacerStagedWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const minimalistV04TaskFrontStagedWidgets = [
    "org.kde.plasma.icontasks",
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const minimalistV04TargetWidgets = [
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
const minimalistV04PagerTargetWidgets = minimalistV04TargetWidgets.slice();
minimalistV04PagerTargetWidgets.splice(1, 0, "org.kde.plasma.pager");
const minimalistV04WorkspacesTargetWidgets = minimalistV04TargetWidgets.slice();
minimalistV04WorkspacesTargetWidgets.splice(1, 0, "org.kde.minimalist.workspaces");
const minimalistV04WorkspacesDuplicateTailWidgets =
    minimalistV04WorkspacesTargetWidgets.concat([
        "org.kde.minimalist.activewindowtitle",
        "org.kde.minimalist.resources"
    ]);
const missingConfigValue = "__KDE_RICE_MISSING__";
const requiredTrayWidgets = [
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.notifications"
];
const requiredBuiltInWidgets = minimalistTargetWidgets.filter(function (widgetType) {
    return widgetType !== "org.kde.minimalist.activewindowtitle";
}).concat(requiredTrayWidgets);

// Narrow fresh-install signatures.  Both require exactly one horizontal
// bottom panel on screen 0 and a valid AppletOrder.  Geometry is reported but
// is not part of the signature because the logical stock height/floating
// default varies across Plasma 6 distribution builds and scale factors.
const plasma6StockWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const plasma6StockImeWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const minimalistV02ShowDesktopWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const minimalistV02NoTitleWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const minimalistV02SpacerRepairWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop",
    "org.kde.plasma.panelspacer"
];
const minimalistV02TitleRepairWidgets = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.minimalist.activewindowtitle"
];

const shownTrayItemsExpected = [
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.notifications"
];
const hiddenTrayItemsExpected = [
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

function readable(value) {
    if (value === undefined || value === null) {
        return null;
    }
    if (typeof value === "number" || typeof value === "boolean" || typeof value === "string") {
        return value;
    }
    return String(value);
}

function readWidgetConfig(widget, group, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = group;
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

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

function readableDefaultTrue(value) {
    return value === missingConfigValue ? true : readable(value);
}

function readableDefaultFalse(value) {
    return value === missingConfigValue ? false : readable(value);
}

function orderedPanelState(panel) {
    const widgets = panel.widgets();
    const widgetsById = {};
    const rawTypes = [];
    const rawWidgetEntries = [];
    for (let index = 0; index < widgets.length; ++index) {
        const id = String(widgets[index].id);
        widgetsById[id] = widgets[index];
        rawTypes.push(widgets[index].type);
        rawWidgetEntries.push({id: readable(widgets[index].id), type: widgets[index].type});
    }

    const previousGroup = panel.currentConfigGroup;
    panel.currentConfigGroup = ["General"];
    const appletOrder = String(panel.readConfig("AppletOrder", ""));
    panel.currentConfigGroup = previousGroup;
    const orderIds = appletOrder === "" ? [] : appletOrder.split(";");
    const orderedTypes = [];
    const orderedWidgets = [];
    const seen = {};
    let orderValid = orderIds.length === widgets.length && widgets.length > 0;

    if (orderValid) {
        for (let index = 0; index < orderIds.length; ++index) {
            const id = orderIds[index];
            if (!widgetsById[id] || seen[id]) {
                orderValid = false;
                break;
            }
            seen[id] = true;
            orderedTypes.push(widgetsById[id].type);
            orderedWidgets.push(widgetsById[id]);
        }
    }

    return {
        applet_order: appletOrder,
        order_valid: orderValid,
        ordered_types: orderValid ? orderedTypes : [],
        ordered_widgets: orderValid ? orderedWidgets : [],
        raw_types: rawTypes,
        raw_widget_entries: rawWidgetEntries,
        widgets: widgets
    };
}

function widgetCounts(types) {
    const counts = {};
    for (let index = 0; index < types.length; ++index) {
        counts[types[index]] = (counts[types[index]] || 0) + 1;
    }
    return counts;
}

function findSingleWidget(widgets, type) {
    let match = null;
    for (let index = 0; index < widgets.length; ++index) {
        if (widgets[index].type === type) {
            if (match) {
                return null;
            }
            match = widgets[index];
        }
    }
    return match;
}

function findWidgets(widgets, type) {
    const matches = [];
    for (let index = 0; index < widgets.length; ++index) {
        if (widgets[index].type === type) {
            matches.push(widgets[index]);
        }
    }
    return matches;
}

function panelDetails(panel) {
    const orderState = orderedPanelState(panel);
    let geometry = {width: null, height: null};
    try {
        const liveGeometry = screenGeometry(panel.screen);
        geometry = {width: readable(liveGeometry.width), height: readable(liveGeometry.height)};
    } catch (error) {
        geometry = {width: null, height: null};
    }

    return {
        id: readable(panel.id),
        screen: readable(panel.screen),
        location: readable(panel.location),
        form_factor: readable(panel.formFactor),
        height: readable(panel.height),
        length_mode: readable(panel.lengthMode),
        length: readable(panel.length),
        minimum_length: readable(panel.minimumLength),
        maximum_length: readable(panel.maximumLength),
        alignment: readable(panel.alignment),
        offset: readable(panel.offset),
        hiding: readable(panel.hiding),
        floating: readable(panel.floating),
        opacity: readable(panel.opacity),
        screen_geometry: geometry,
        applet_order: orderState.applet_order,
        order_valid: orderState.order_valid,
        widget_types: orderState.ordered_types,
        raw_widget_types: orderState.raw_types,
        widget_entries: orderState.raw_widget_entries,
        widget_counts: widgetCounts(orderState.order_valid ? orderState.ordered_types : orderState.raw_types)
    };
}

function targetPolicy(panel, orderState) {
    const spacers = findWidgets(orderState.widgets, "org.kde.plasma.panelspacer");
    const activeTitle = findSingleWidget(orderState.widgets, "org.kde.minimalist.activewindowtitle");
    const resources = findSingleWidget(orderState.widgets, "org.kde.minimalist.resources");
    const taskManager = findSingleWidget(orderState.widgets, "org.kde.plasma.icontasks");
    const tray = findSingleWidget(orderState.widgets, "org.kde.plasma.systemtray");
    const clock = findSingleWidget(orderState.widgets, "org.kde.plasma.digitalclock");
    const pager = findSingleWidget(orderState.widgets, "org.kde.plasma.pager");
    const workspaceSwitcher = findSingleWidget(orderState.widgets, "org.kde.minimalist.workspaces");
    const geometry = screenGeometry(panel.screen);

    const spacerExpandingValues = spacers.map(function (spacer) {
        return readWidgetConfig(spacer, ["General"], "expanding", false);
    });
    const titleRevision = activeTitle ? readWidgetConfig(activeTitle, ["General"], "packageRevision", 0) : 0;
    const resourceRevision = resources ? readWidgetConfig(resources, ["General"], "packageRevision", 0) : null;
    const taskManagerFill = taskManager ? readWidgetConfig(taskManager, ["General"], "fill", true) : null;
    const taskManagerMaxStripes = taskManager
        ? readWidgetConfig(taskManager, ["General"], "maxStripes", 2)
        : null;
    const taskManagerIconSpacing = taskManager
        ? readWidgetConfig(taskManager, ["General"], "iconSpacing", 1)
        : null;
    const shownItems = tray ? asList(readWidgetConfig(tray, ["General"], "shownItems", [])) : [];
    const hiddenItems = tray ? asList(readWidgetConfig(tray, ["General"], "hiddenItems", [])) : [];
    const showAllItems = tray ? readWidgetConfig(tray, ["General"], "showAllItems", true) : true;
    const iconSpacing = tray ? readWidgetConfig(tray, ["General"], "iconSpacing", 2) : 2;
    const scaleIcons = tray ? readWidgetConfig(tray, ["General"], "scaleIconsToFit", false) : false;
    const showDate = clock ? readWidgetConfig(clock, ["Appearance"], "showDate", missingConfigValue) : missingConfigValue;
    const showSeconds = clock ? readWidgetConfig(clock, ["Appearance"], "showSeconds", missingConfigValue) : missingConfigValue;
    const use24h = clock ? readWidgetConfig(clock, ["Appearance"], "use24hFormat", missingConfigValue) : missingConfigValue;
    const dateDisplayFormat = clock ? readWidgetConfig(clock, ["Appearance"], "dateDisplayFormat", missingConfigValue) : missingConfigValue;
    const dateFormat = clock ? readWidgetConfig(clock, ["Appearance"], "dateFormat", missingConfigValue) : missingConfigValue;
    const customDateFormat = clock ? readWidgetConfig(clock, ["Appearance"], "customDateFormat", missingConfigValue) : missingConfigValue;
    const autoFontAndSize = clock ? readWidgetConfig(clock, ["Appearance"], "autoFontAndSize", missingConfigValue) : missingConfigValue;
    const fontFamily = clock ? readWidgetConfig(clock, ["Appearance"], "fontFamily", missingConfigValue) : missingConfigValue;
    const fontSize = clock ? readWidgetConfig(clock, ["Appearance"], "fontSize", missingConfigValue) : missingConfigValue;
    const fontStyleName = clock ? readWidgetConfig(clock, ["Appearance"], "fontStyleName", missingConfigValue) : missingConfigValue;
    const fontWeight = clock ? readWidgetConfig(clock, ["Appearance"], "fontWeight", missingConfigValue) : missingConfigValue;
    const displayedText = pager ? readWidgetConfig(pager, ["General"], "displayedText", missingConfigValue) : missingConfigValue;
    const showWindowOutlines = pager ? readWidgetConfig(pager, ["General"], "showWindowOutlines", missingConfigValue) : missingConfigValue;
    const showWindowIcons = pager ? readWidgetConfig(pager, ["General"], "showWindowIcons", missingConfigValue) : missingConfigValue;
    const workspaceSwitcherRevision = workspaceSwitcher
        ? readWidgetConfig(workspaceSwitcher, ["General"], "packageRevision", 0)
        : null;

    const geometryOk = panel.screen === 0
        && panel.location === "top"
        && panel.formFactor === "horizontal"
        && Number(panel.height) === 32
        && panel.lengthMode === "fill"
        && panel.alignment === "center"
        && Number(panel.offset) === 0
        && panel.hiding === "none"
        && panel.floating === false
        && panel.opacity === "opaque"
        && Number(panel.minimumLength) === Number(geometry.width)
        && Number(panel.maximumLength) === Number(geometry.width)
        && Number(panel.length) === Number(geometry.width);
    const isV04 = sameSequence(orderState.ordered_types, minimalistV04TargetWidgets)
        || sameSequence(orderState.ordered_types, minimalistV04PagerTargetWidgets)
        || sameSequence(orderState.ordered_types, minimalistV04WorkspacesTargetWidgets);
    const expectedSpacerCount = isV04 ? 2 : 1;
    let spacerOk = spacers.length === expectedSpacerCount;
    for (let spacerIndex = 0; spacerIndex < spacerExpandingValues.length && spacerOk; ++spacerIndex) {
        const expanding = spacerExpandingValues[spacerIndex];
        spacerOk = expanding === true || String(expanding) === "true" || String(expanding) === "1";
    }
    const activeTitleOk = String(titleRevision) === "1";
    const resourceOk = !resources || String(resourceRevision) === "2";
    const taskManagerOk = !isV04 || (!!taskManager
        && (taskManagerFill === false || String(taskManagerFill) === "false" || String(taskManagerFill) === "0")
        && String(taskManagerMaxStripes) === "1"
        && String(taskManagerIconSpacing) === "0");
    const trayOk = (showAllItems === false || String(showAllItems) === "false" || String(showAllItems) === "0")
        && sameMembers(shownItems, shownTrayItemsExpected)
        && sameMembers(hiddenItems, hiddenTrayItemsExpected)
        && String(iconSpacing) === "1"
        && (scaleIcons === true || String(scaleIcons) === "true" || String(scaleIcons) === "1");
    const autoClockFontOk = configTrueOrDefault(autoFontAndSize);
    const minimalistClockFontOk = (autoFontAndSize === false
        || String(autoFontAndSize) === "false" || String(autoFontAndSize) === "0")
        && String(fontFamily) === "Noto Sans"
        && String(fontSize) === "11"
        && String(fontStyleName) === "Regular"
        && String(fontWeight) === "400";
    const clockOk = !!clock
        && configFalse(showDate)
        && enumMatches(showSeconds, 2, "Always")
        && String(use24h) === "2"
        && (autoClockFontOk || minimalistClockFontOk);
    const pagerOk = !pager || ((String(displayedText) === "0" || String(displayedText) === "Number")
        && (showWindowOutlines === false || String(showWindowOutlines) === "false" || String(showWindowOutlines) === "0")
        && (showWindowIcons === false || String(showWindowIcons) === "false" || String(showWindowIcons) === "0"));
    const workspaceSwitcherOk = !workspaceSwitcher || String(workspaceSwitcherRevision) === "2";

    return {
        complete: geometryOk && spacerOk && activeTitleOk && resourceOk && taskManagerOk
            && trayOk && clockOk && pagerOk && workspaceSwitcherOk,
        geometry_ok: geometryOk,
        spacer_ok: spacerOk,
        active_title_ok: activeTitleOk,
        resource_ok: resourceOk,
        task_manager_ok: taskManagerOk,
        tray_ok: trayOk,
        clock_ok: clockOk,
        pager_ok: pagerOk,
        workspace_switcher_ok: workspaceSwitcherOk,
        spacer_count: spacers.length,
        spacer_expanding: spacerExpandingValues.map(readable).join(","),
        active_title_revision: readable(titleRevision),
        resource_revision: readable(resourceRevision),
        task_manager: {
            fill: readable(taskManagerFill),
            max_stripes: readable(taskManagerMaxStripes),
            icon_spacing: readable(taskManagerIconSpacing),
            launchers: "user-owned"
        },
        tray: {
            show_all_items: readable(showAllItems),
            shown_items: shownItems,
            hidden_items: hiddenItems,
            icon_spacing: readable(iconSpacing),
            scale_icons_to_fit: readable(scaleIcons)
        },
        clock: {
            show_date: readableDefaultFalse(showDate),
            show_seconds: readable(showSeconds),
            use_24h_format: readable(use24h),
            date_display_format: readable(dateDisplayFormat),
            date_format: readable(dateFormat),
            custom_date_format: readable(customDateFormat),
            auto_font_and_size: readableDefaultTrue(autoFontAndSize),
            font_family: readable(fontFamily),
            font_size: readable(fontSize),
            font_style_name: readable(fontStyleName),
            font_weight: readable(fontWeight),
            minimalist_font_ok: minimalistClockFontOk
        },
        pager: {
            present: !!pager,
            displayed_text: readable(displayedText),
            show_window_outlines: readable(showWindowOutlines),
            show_window_icons: readable(showWindowIcons)
        },
        workspace_switcher: {
            present: !!workspaceSwitcher,
            package_revision: readable(workspaceSwitcherRevision)
        }
    };
}

const panels = [];
const panelObjects = [];
for (let panelIndex = 0; panelIndex < panelIds.length; ++panelIndex) {
    const resolvedPanel = panelById(panelIds[panelIndex]);
    if (resolvedPanel) {
        panelObjects.push(resolvedPanel);
        panels.push(panelDetails(resolvedPanel));
    }
}

let signature = "unknown";
let transition = "refuse";
let target = {
    complete: false,
    geometry_ok: false,
    spacer_ok: false,
    active_title_ok: false,
    tray_ok: false,
    clock_ok: false
};
let removePanelIds = [];
let removeWidgetIds = [];
let removeWidgetEntries = [];
let createPanel = false;
let reusePanelId = null;

if (panelIds.length === 1 && panelObjects.length === 1) {
    const onlyPanel = panelObjects[0];
    const onlyState = orderedPanelState(onlyPanel);
    const types = onlyState.ordered_types;
    if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistTargetWidgets)) {
        signature = "minimalist-v02";
        transition = "already-target";
        reusePanelId = readable(onlyPanel.id);
        target = targetPolicy(onlyPanel, onlyState);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV03TargetWidgets)) {
        signature = "minimalist-v03";
        transition = "v03-target";
        reusePanelId = readable(onlyPanel.id);
        target = targetPolicy(onlyPanel, onlyState);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV04PagerTargetWidgets)) {
        signature = "minimalist-v04-pager";
        transition = "v04-pager-target";
        reusePanelId = readable(onlyPanel.id);
        target = targetPolicy(onlyPanel, onlyState);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV04WorkspacesDuplicateTailWidgets)) {
        signature = "minimalist-v04-workspaces-duplicate-tail";
        transition = "recover-v04-workspaces-duplicate-tail";
        reusePanelId = readable(onlyPanel.id);
        target = targetPolicy(onlyPanel, {
            ordered_types: onlyState.ordered_types.slice(
                0, minimalistV04WorkspacesTargetWidgets.length),
            widgets: onlyState.ordered_widgets.slice(
                0, minimalistV04WorkspacesTargetWidgets.length)
        });
        target.complete = false;
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV04WorkspacesTargetWidgets)) {
        signature = "minimalist-v04-workspaces";
        transition = "v04-workspaces-target";
        reusePanelId = readable(onlyPanel.id);
        target = targetPolicy(onlyPanel, onlyState);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV04SpacerStagedWidgets)) {
        signature = "minimalist-v04-spacer-staged";
        transition = "complete-v04-staged";
        reusePanelId = readable(onlyPanel.id);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV04TaskFrontStagedWidgets)) {
        signature = "minimalist-v04-task-front-staged";
        transition = "repair-v04-task-order";
        reusePanelId = readable(onlyPanel.id);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV04TargetWidgets)) {
        signature = "minimalist-v04";
        transition = "v04-target";
        reusePanelId = readable(onlyPanel.id);
        target = targetPolicy(onlyPanel, onlyState);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, plasma6StockImeWidgets)) {
        signature = "minimalist-v01";
        transition = "managed-v02-transition";
        reusePanelId = readable(onlyPanel.id);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV02ShowDesktopWidgets)) {
        signature = "minimalist-v02-show-desktop";
        transition = "managed-v02-transition";
        reusePanelId = readable(onlyPanel.id);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV02NoTitleWidgets)) {
        signature = "minimalist-v02-no-title";
        transition = "managed-v02-transition";
        reusePanelId = readable(onlyPanel.id);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV02SpacerRepairWidgets)) {
        signature = "minimalist-v02-spacer-repair";
        transition = "managed-v02-transition";
        reusePanelId = readable(onlyPanel.id);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "top"
        && sameSequence(types, minimalistV02TitleRepairWidgets)) {
        signature = "minimalist-v02-title-repair";
        transition = "managed-v02-transition";
        reusePanelId = readable(onlyPanel.id);
    } else if (onlyState.order_valid
        && onlyPanel.screen === 0
        && onlyPanel.formFactor === "horizontal"
        && onlyPanel.location === "bottom"
        && (sameSequence(types, plasma6StockWidgets) || sameSequence(types, plasma6StockImeWidgets))) {
        signature = sameSequence(types, plasma6StockWidgets) ? "plasma6-stock" : "plasma6-stock-ime";
        transition = "replace-fresh-panel";
        removePanelIds = [readable(onlyPanel.id)];
        for (let widgetIndex = 0; widgetIndex < onlyState.widgets.length; ++widgetIndex) {
            removeWidgetIds.push(readable(onlyState.widgets[widgetIndex].id));
            removeWidgetEntries.push(
                String(onlyState.widgets[widgetIndex].id) + ":" + onlyState.widgets[widgetIndex].type
            );
        }
        createPanel = true;
    }
}

const known = {};
let knownTargetWidgets = true;
let activeTitleKnown = false;
for (let targetIndex = 0; targetIndex < minimalistTargetWidgets.length; ++targetIndex) {
    const widgetType = minimalistTargetWidgets[targetIndex];
    known[widgetType] = knownWidgetTypes.indexOf(widgetType) !== -1;
    if (!known[widgetType]) {
        knownTargetWidgets = false;
    }
    if (widgetType === "org.kde.minimalist.activewindowtitle") {
        activeTitleKnown = known[widgetType];
    }
}
let knownBuiltInWidgets = true;
const missingBuiltInWidgets = [];
for (let builtInIndex = 0; builtInIndex < requiredBuiltInWidgets.length; ++builtInIndex) {
    const builtInType = requiredBuiltInWidgets[builtInIndex];
    known[builtInType] = knownWidgetTypes.indexOf(builtInType) !== -1;
    if (!known[builtInType]) {
        knownBuiltInWidgets = false;
        missingBuiltInWidgets.push(builtInType);
    }
}
const iconTasksKnown = knownWidgetTypes.indexOf("org.kde.plasma.icontasks") !== -1;
known["org.kde.plasma.icontasks"] = iconTasksKnown;
const pagerKnown = knownWidgetTypes.indexOf("org.kde.plasma.pager") !== -1;
known["org.kde.plasma.pager"] = pagerKnown;
const workspaceSwitcherKnown = knownWidgetTypes.indexOf("org.kde.minimalist.workspaces") !== -1;
known["org.kde.minimalist.workspaces"] = workspaceSwitcherKnown;

let desktopCount = null;
try {
    const desktopContainments = desktops();
    desktopCount = desktopContainments && typeof desktopContainments.length === "number"
        ? desktopContainments.length
        : null;
} catch (error) {
    desktopCount = null;
}

let orderValid = false;
let noDuplicateTargetWidgets = false;
let markerWidgetTypes = "none";
let markerGeometry = "none";
let observedTargetWidgets = minimalistTargetWidgets;
if (signature === "minimalist-v03") {
    observedTargetWidgets = minimalistV03TargetWidgets;
} else if (signature === "minimalist-v04-spacer-staged") {
    observedTargetWidgets = minimalistV04SpacerStagedWidgets;
} else if (signature === "minimalist-v04-task-front-staged") {
    observedTargetWidgets = minimalistV04TaskFrontStagedWidgets;
} else if (signature === "minimalist-v04") {
    observedTargetWidgets = minimalistV04TargetWidgets;
} else if (signature === "minimalist-v04-pager") {
    observedTargetWidgets = minimalistV04PagerTargetWidgets;
} else if (signature === "minimalist-v04-workspaces") {
    observedTargetWidgets = minimalistV04WorkspacesTargetWidgets;
} else if (signature === "minimalist-v04-workspaces-duplicate-tail") {
    observedTargetWidgets = minimalistV04WorkspacesDuplicateTailWidgets;
}
if (panels.length === 1) {
    const markerPanel = panels[0];
    orderValid = markerPanel.order_valid === true;
    markerWidgetTypes = orderValid ? markerPanel.widget_types.join(";") : "none";
    markerGeometry = [
        markerPanel.screen,
        markerPanel.location,
        markerPanel.form_factor,
        markerPanel.height,
        markerPanel.opacity,
        markerPanel.length_mode,
        markerPanel.minimum_length,
        markerPanel.maximum_length,
        markerPanel.length
    ].join(",");
    const expectedCounts = widgetCounts(observedTargetWidgets);
    noDuplicateTargetWidgets = orderValid
        && markerPanel.widget_types.length === observedTargetWidgets.length;
    for (const expectedType in expectedCounts) {
        if (Object.prototype.hasOwnProperty.call(expectedCounts, expectedType)
            && Number(markerPanel.widget_counts[expectedType] || 0) !== expectedCounts[expectedType]) {
            noDuplicateTargetWidgets = false;
        }
    }
    if (signature === "minimalist-v04-workspaces-duplicate-tail") {
        noDuplicateTargetWidgets = false;
    }
}

const observedPanelIds = [];
const observedWidgetEntries = [];
for (let detailIndex = 0; detailIndex < panels.length; ++detailIndex) {
    observedPanelIds.push(String(panels[detailIndex].id));
    for (let entryIndex = 0; entryIndex < panels[detailIndex].widget_entries.length; ++entryIndex) {
        const entry = panels[detailIndex].widget_entries[entryIndex];
        observedWidgetEntries.push(String(entry.id) + ":" + entry.type);
    }
}

const result = {
    schema_version: 1,
    panel_count: panelIds.length,
    desktop_count: desktopCount,
    resolved_panel_count: panelObjects.length,
    signature: signature,
    transition: transition,
    supported_transition: signature !== "unknown",
    target_complete: target.complete,
    target_policy: target,
    known_widgets: known,
    known_target_widgets: knownTargetWidgets,
    known_built_in_widgets: knownBuiltInWidgets,
    missing_built_in_widgets: missingBuiltInWidgets,
    icon_tasks_known: iconTasksKnown,
    pager_known: pagerKnown,
    workspace_switcher_known: workspaceSwitcherKnown,
    active_title_known: activeTitleKnown,
    order_valid: orderValid,
    no_duplicate_target_widgets: noDuplicateTargetWidgets,
    panels: panels,
    plan: {
        remove_panel_ids: removePanelIds,
        remove_widget_ids: removeWidgetIds,
        remove_widget_entries: removeWidgetEntries,
        create_panel: createPanel,
        create_widgets: minimalistTargetWidgets,
        reuse_panel_id: reusePanelId
    },
    plan_signature: signature,
    plan_transition: transition,
    remove_panel_ids_csv: removePanelIds.join(","),
    remove_widget_ids_csv: removeWidgetIds.join(","),
    remove_widget_entries_csv: removeWidgetEntries.join(","),
    observed_panel_ids_csv: observedPanelIds.join(","),
    observed_widget_entries_csv: observedWidgetEntries.join(","),
    target_widgets_csv: minimalistTargetWidgets.join(",")
};

print("KDE_RICE_PANEL_STATE_JSON=" + JSON.stringify(result));
print(
    "KDE_RICE_PANEL_STATE"
    + " schema=1"
    + " panelCount=" + panelIds.length
    + " desktopCount=" + (desktopCount === null ? "unknown" : desktopCount)
    + " signature=" + signature
    + " transition=" + transition
    + " supported=" + (signature !== "unknown")
    + " targetComplete=" + target.complete
    + " orderValid=" + orderValid
    + " geometryOk=" + (target.geometry_ok === true)
    + " spacerOk=" + (target.spacer_ok === true)
    + " activeTitleOk=" + (target.active_title_ok === true)
    + " resourceOk=" + (target.resource_ok === true)
    + " taskManagerOk=" + (target.task_manager_ok === true)
    + " trayOk=" + (target.tray_ok === true)
    + " clockOk=" + (target.clock_ok === true)
    + " pagerOk=" + (target.pager_ok === true)
    + " workspaceSwitcherOk=" + (target.workspace_switcher_ok === true)
    + " noDuplicateTargetWidgets=" + noDuplicateTargetWidgets
    + " knownTargetWidgets=" + knownTargetWidgets
    + " knownBuiltInWidgets=" + knownBuiltInWidgets
    + " missingBuiltInWidgets=" + (missingBuiltInWidgets.length ? missingBuiltInWidgets.join(",") : "none")
    + " iconTasksKnown=" + iconTasksKnown
    + " pagerKnown=" + pagerKnown
    + " workspaceSwitcherKnown=" + workspaceSwitcherKnown
    + " activeTitleKnown=" + activeTitleKnown
    + " spacerCount=" + (target.spacer_count === undefined ? "none" : target.spacer_count)
    + " spacerExpanding=" + (target.spacer_expanding === undefined || target.spacer_expanding === "" ? "none" : target.spacer_expanding)
    + " activeTitleRevision=" + (target.active_title_revision === undefined ? "none" : target.active_title_revision)
    + " resourceRevision=" + (target.resource_revision === undefined || target.resource_revision === null ? "none" : target.resource_revision)
    + " taskManagerFill=" + (!target.task_manager || target.task_manager.fill === null ? "none" : target.task_manager.fill)
    + " taskManagerMaxStripes=" + (!target.task_manager || target.task_manager.max_stripes === null ? "none" : target.task_manager.max_stripes)
    + " taskManagerIconSpacing=" + (!target.task_manager || target.task_manager.icon_spacing === null ? "none" : target.task_manager.icon_spacing)
    + " pagerDisplayedText=" + (!target.pager || target.pager.displayed_text === null ? "none" : target.pager.displayed_text)
    + " pagerShowWindowOutlines=" + (!target.pager || target.pager.show_window_outlines === null ? "none" : target.pager.show_window_outlines)
    + " pagerShowWindowIcons=" + (!target.pager || target.pager.show_window_icons === null ? "none" : target.pager.show_window_icons)
    + " workspaceSwitcherRevision=" + (!target.workspace_switcher || target.workspace_switcher.package_revision === null ? "none" : target.workspace_switcher.package_revision)
    + " widgetTypes=" + markerWidgetTypes
    + " geometry=" + markerGeometry
    + " removePanelIds=" + (removePanelIds.length ? removePanelIds.join(",") : "none")
    + " removeWidgetIds=" + (removeWidgetIds.length ? removeWidgetIds.join(",") : "none")
    + " removeWidgetEntries=" + (removeWidgetEntries.length ? removeWidgetEntries.join(",") : "none")
    + " createPanel=" + createPanel
    + " targetWidgets=" + minimalistTargetWidgets.join(",")
);
