// Read-only preflight for the additive Minimalist v0.3 resource strip.

const resourceType = "org.kde.minimalist.resources";
const v02Widgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const v03Widgets = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    resourceType,
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];

function sameSequence(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
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

const panel = panelIds.length === 1 ? panelById(panelIds[0]) : null;
const types = panel ? orderedWidgetTypes(panel) : [];
let topology = "unknown";
if (sameSequence(types, v02Widgets)) {
    topology = "minimalist-v02";
} else if (sameSequence(types, v03Widgets)) {
    topology = "minimalist-v03";
}
const geometryOk = !!panel
    && panel.screen === 0
    && panel.location === "top"
    && panel.formFactor === "horizontal"
    && (Number(panel.height) === 28 || Number(panel.height) === 32)
    && panel.lengthMode === "fill"
    && panel.hiding === "none"
    && panel.floating === false
    && panel.opacity === "opaque";

print(
    "MINIMALIST_V03_PREFLIGHT"
    + " panelCount=" + panelIds.length
    + " topology=" + topology
    + " height=" + (panel ? Number(panel.height) : "none")
    + " geometryOk=" + geometryOk
    + " resourceKnown=" + (knownWidgetTypes.indexOf(resourceType) !== -1)
    + " widgets=" + (types.length ? types.join(";") : "none")
);
if (topology !== "unknown" && geometryOk) {
    print(" MINIMALIST_V03_PREFLIGHT_OK");
}
