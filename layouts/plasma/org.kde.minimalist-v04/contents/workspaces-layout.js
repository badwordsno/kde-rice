// Replace one exact built-in Pager with Minimalist Workspaces at the launcher
// anchor. Geometry is used because live AppletOrder rewrites are unreliable.

const pagerType = "org.kde.plasma.pager";
const workspaceType = "org.kde.minimalist.workspaces";
const workspaceUserConfigKeys = [
    ["labelMode", 0], ["hideWhenSingle", false], ["wrapWheel", false],
    ["invertWheel", false], ["density", 0], ["surfaceStyle", 0],
    ["bevelDepth", 2],
    ["motionEnabled", true]
];
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
    "org.kde.plasma.digitalclock"
];
const pagerWidgets = baseWidgets.slice();
pagerWidgets.splice(1, 0, pagerType);
const workspaceWidgets = baseWidgets.slice();
workspaceWidgets.splice(1, 0, workspaceType);

function sameSequence(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

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

function captureWorkspaceUserConfig(widget) {
    const result = {};
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    for (let index = 0; index < workspaceUserConfigKeys.length; ++index) {
        const entry = workspaceUserConfigKeys[index];
        result[entry[0]] = widget.readConfig(entry[0], entry[1]);
    }
    widget.currentConfigGroup = previousGroup;
    return result;
}

function configureWorkspaceSwitcher(widget, userConfig) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    if (userConfig) {
        const keys = Object.keys(userConfig);
        for (let index = 0; index < keys.length; ++index) {
            widget.writeConfig(keys[index], userConfig[keys[index]]);
        }
    }
    widget.writeConfig("packageRevision", 2);
    widget.reloadConfig();
    widget.currentConfigGroup = previousGroup;
}

if (panelIds.length !== 1) {
    throw new Error("expected exactly one panel for Minimalist Workspaces");
}
const panel = panelById(panelIds[0]);
if (!panel || !exactGeometry(panel)
        || knownWidgetTypes.indexOf(pagerType) === -1
        || knownWidgetTypes.indexOf(workspaceType) === -1) {
    throw new Error("Minimalist Workspaces prerequisites changed");
}
const before = orderedPanelState(panel);
let workspaceSwitcher = null;
let workspaceUserConfig = null;
let transition = "already-target";
if (sameSequence(before.types, pagerWidgets)) {
    const launcher = before.widgets[0];
    const pager = before.widgets[1];
    const title = before.widgets[2];
    if (!launcher.geometry || !pager.geometry || !title.geometry
            || typeof launcher.geometry.x !== "number"
            || typeof launcher.geometry.width !== "number"
            || typeof launcher.geometry.height !== "number"
            || typeof title.geometry.x !== "number"
            || launcher.geometry.x + launcher.geometry.width >= title.geometry.x) {
        throw new Error("launcher-to-title replacement anchor is unavailable");
    }
    pager.remove();
    workspaceSwitcher = panel.addWidget(
        workspaceType,
        launcher.geometry.x + launcher.geometry.width + 1,
        launcher.geometry.y,
        1,
        launcher.geometry.height
    );
    if (!workspaceSwitcher || workspaceSwitcher.type !== workspaceType) {
        throw new Error("Plasma did not create Minimalist Workspaces");
    }
    transition = "replace-pager-after-launcher";
} else if (sameSequence(before.types, workspaceWidgets)) {
    workspaceSwitcher = before.widgets[1];
    const previousGroup = workspaceSwitcher.currentConfigGroup;
    workspaceSwitcher.currentConfigGroup = ["General"];
    const currentRevision = String(workspaceSwitcher.readConfig("packageRevision", 0));
    workspaceSwitcher.currentConfigGroup = previousGroup;
    if (currentRevision === "1") {
        workspaceUserConfig = captureWorkspaceUserConfig(workspaceSwitcher);
        const launcher = before.widgets[0];
        const title = before.widgets[2];
        if (!launcher.geometry || !workspaceSwitcher.geometry || !title.geometry
                || typeof launcher.geometry.x !== "number"
                || typeof launcher.geometry.width !== "number"
                || typeof launcher.geometry.height !== "number"
                || typeof title.geometry.x !== "number"
                || launcher.geometry.x + launcher.geometry.width >= title.geometry.x) {
            throw new Error("launcher-to-title refresh anchor is unavailable");
        }
        workspaceSwitcher.remove();
        workspaceSwitcher = panel.addWidget(
            workspaceType,
            launcher.geometry.x + launcher.geometry.width + 1,
            launcher.geometry.y,
            1,
            launcher.geometry.height
        );
        if (!workspaceSwitcher || workspaceSwitcher.type !== workspaceType) {
            throw new Error("Plasma did not refresh Minimalist Workspaces");
        }
        transition = "refresh-workspaces-after-launcher";
    } else if (currentRevision !== "2") {
        throw new Error("unsupported Minimalist Workspaces package revision: " + currentRevision);
    }
} else {
    throw new Error("panel is not an exact Pager source or Workspaces target");
}

configureWorkspaceSwitcher(workspaceSwitcher, workspaceUserConfig);
print(
    "MINIMALIST_WORKSPACES_LAYOUT_OK"
    + " transition=" + transition
    + " panelId=" + panel.id
    + " workspaceId=" + workspaceSwitcher.id
);
