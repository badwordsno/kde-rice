// Receipt-bound, convergent cleanup for the known duplicate tail. This script
// only removes stale applets 76 then 75. It never recreates, reorders, moves,
// or configures a keeper.

const activeTitleType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const stableTypes = [
    "org.kde.plasma.kickoff", workspaceType, activeTitleType,
    "org.kde.plasma.panelspacer", "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer", resourceType,
    "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray", clockType
];
const stableIds = [30, 80, 81, 32, 56, 55, 82, 33, 34, 35, 61];
const staleActiveTitleId = 75;
const staleResourceId = 76;
const userConfigKeys = {};
userConfigKeys[activeTitleType] = [
    ["titleTemplate", "{title}"], ["showIcon", false], ["widthMode", 1],
    ["minimumWidthUnits", 8], ["preferredWidthUnits", 18],
    ["maximumWidthUnits", 20], ["maximizedOnly", false],
    ["wheelSwitch", false], ["doubleClickMaximize", true],
    ["middleClickClose", false], ["density", 0], ["surfaceStyle", 0],
    ["bevelDepth", 2], ["motionEnabled", true]
];
userConfigKeys[workspaceType] = [
    ["labelMode", 0], ["hideWhenSingle", false], ["wrapWheel", false],
    ["invertWheel", false], ["density", 0], ["surfaceStyle", 0],
    ["bevelDepth", 2], ["motionEnabled", true]
];
userConfigKeys[resourceType] = [
    ["metricOrder", "CPU,RAM,GPU,VOL"], ["showCpu", true],
    ["showMemory", true], ["showGpu", true], ["showVolume", true],
    ["updateRateMs", 2000], ["warningPercent", 70],
    ["criticalPercent", 90], ["showStateRails", true], ["density", 0],
    ["surfaceStyle", 0], ["bevelDepth", 2], ["motionEnabled", true]
];

function same(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

function orderedPanelState(panel) {
    const widgets = panel.widgets();
    const byId = {};
    for (let position = 0; position < widgets.length; ++position) {
        byId[String(widgets[position].id)] = widgets[position];
    }
    const previousGroup = panel.currentConfigGroup;
    panel.currentConfigGroup = ["General"];
    const orderText = String(panel.readConfig("AppletOrder", ""));
    panel.currentConfigGroup = previousGroup;
    const orderIds = orderText === "" ? [] : orderText.split(";");
    if (orderIds.length !== widgets.length) return {ids: [], types: [], widgets: []};
    const ids = [];
    const types = [];
    const orderedWidgets = [];
    const seen = {};
    for (let position = 0; position < orderIds.length; ++position) {
        const idText = orderIds[position];
        if (!byId[idText] || seen[idText]) return {ids: [], types: [], widgets: []};
        seen[idText] = true;
        ids.push(Number(byId[idText].id));
        types.push(byId[idText].type);
        orderedWidgets.push(byId[idText]);
    }
    return {ids: ids, types: types, widgets: orderedWidgets};
}

function panelMatchesCapture(panel, captured) {
    return !!panel && !!captured
        && Number(panel.id) === Number(captured.id)
        && Number(panel.screen) === Number(captured.screen)
        && String(panel.location) === String(captured.location)
        && String(panel.formFactor) === String(captured.formFactor)
        && Number(panel.height) === Number(captured.height)
        && String(panel.lengthMode) === String(captured.lengthMode)
        && String(panel.hiding) === String(captured.hiding)
        && (panel.floating === true) === (captured.floating === true)
        && String(panel.opacity) === String(captured.opacity)
        && Number(panel.screen) === 0 && String(panel.location) === "top"
        && String(panel.formFactor) === "horizontal" && Number(panel.height) === 32
        && String(panel.lengthMode) === "fill" && String(panel.hiding) === "none"
        && panel.floating === false && String(panel.opacity) === "opaque";
}

function stringSequence(value) {
    if (!value || typeof value !== "object") return null;
    const length = Number(value.length);
    if (!Number.isFinite(length) || length < 0 || length !== Math.floor(length)
            || length > 256) return null;
    const result = [];
    for (let position = 0; position < length; ++position) {
        if (typeof value[position] === "undefined") return null;
        result.push(String(value[position]));
    }
    return result;
}

function readConfig(widget, group, key, fallback) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = [group];
    const value = widget.readConfig(key, fallback);
    widget.currentConfigGroup = previousGroup;
    return value;
}

function geometryMatches(widget, captured) {
    return !!widget && !!widget.geometry && !!captured && !!captured.geometry
        && Number.isFinite(Number(widget.geometry.x))
        && Number.isFinite(Number(widget.geometry.y))
        && Number.isFinite(Number(widget.geometry.width))
        && Number.isFinite(Number(widget.geometry.height))
        && Number(widget.geometry.width) > 0 && Number(widget.geometry.height) > 0
        && Number(widget.geometry.y) === Number(captured.geometry.y)
        && Number(widget.geometry.height) === Number(captured.geometry.height);
}

function userConfigMatches(widget, captured) {
    const entries = userConfigKeys[widget.type] || [];
    if (!captured || !captured.userConfig
            || !Array.isArray(captured.presentUserConfigKeys)) return false;
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["General"];
    const storedKeys = stringSequence(widget.configKeys);
    if (storedKeys === null) {
        widget.currentConfigGroup = previousGroup;
        return false;
    }
    const presentKeys = [];
    const values = {};
    for (let position = 0; position < entries.length; ++position) {
        const key = entries[position][0];
        values[key] = widget.readConfig(key, entries[position][1]);
        if (storedKeys.indexOf(key) !== -1) presentKeys.push(key);
    }
    widget.currentConfigGroup = previousGroup;
    return same(values, captured.userConfig)
        && same(presentKeys, captured.presentUserConfigKeys);
}

function projectWidgetMatches(widget, captured) {
    return !!widget && !!captured && Number(widget.id) === Number(captured.id)
        && widget.type === captured.type && geometryMatches(widget, captured)
        && String(readConfig(widget, "General", "packageRevision", 0))
            === String(captured.generalPolicy.packageRevision)
        && String(readConfig(widget, "General", "fontPolicyRevision", 0))
            === String(captured.generalPolicy.fontPolicyRevision)
        && String(readConfig(widget, "General", "chimeraUiRevision", -1))
            === String(captured.generalPolicy.chimeraUiRevision)
        && userConfigMatches(widget, captured);
}

function stableWidgetMatches(widget, captured, position) {
    if (!widget || !captured || Number(widget.id) !== Number(captured.id)
            || widget.type !== captured.type || !geometryMatches(widget, captured)) return false;
    if (position === 1 || position === 2 || position === 6) {
        return projectWidgetMatches(widget, captured);
    }
    if (position === 10) {
        const policy = captured.appearancePolicy || {};
        return String(readConfig(widget, "Appearance", "fontFamily", "missing"))
                === String(policy.fontFamily)
            && String(readConfig(widget, "Appearance", "autoFontAndSize", "missing"))
                === String(policy.autoFontAndSize)
            && String(readConfig(widget, "Appearance", "fontSize", "missing"))
                === String(policy.fontSize)
            && String(readConfig(widget, "Appearance", "fontStyleName", "missing"))
                === String(policy.fontStyleName)
            && String(readConfig(widget, "Appearance", "fontWeight", "missing"))
                === String(policy.fontWeight);
    }
    return true;
}

function capturedGeometryValid(captured, compact) {
    if (!captured || !captured.geometry
            || !Number.isFinite(Number(captured.geometry.x))
            || !Number.isFinite(Number(captured.geometry.y))
            || !Number.isFinite(Number(captured.geometry.width))
            || !Number.isFinite(Number(captured.geometry.height))
            || Number(captured.geometry.width) <= 0
            || Number(captured.geometry.height) <= 0) return false;
    return !compact || (Number(captured.geometry.y) === 4
        && Number(captured.geometry.height) === 24);
}

function capturedProjectValid(captured, expected, id, type, requireCompact) {
    if (!captured || !expected || Number(captured.id) !== Number(id)
            || captured.type !== type
            || !capturedGeometryValid(captured, requireCompact)
            || !captured.generalPolicy || !captured.userConfig
            || !Array.isArray(captured.presentUserConfigKeys)
            || !same(captured.userConfig, expected.userConfig)
            || !same(captured.presentUserConfigKeys,
                expected.presentUserConfigKeys)) return false;
    return String(captured.generalPolicy.packageRevision)
            === (type === activeTitleType ? "1" : "2")
        && String(captured.generalPolicy.fontPolicyRevision) === "2"
        && String(captured.generalPolicy.chimeraUiRevision) === "1";
}

function capturedClockValid(captured) {
    if (!captured || Number(captured.id) !== stableIds[10]
            || captured.type !== clockType || !capturedGeometryValid(captured, false)
            || !captured.appearancePolicy) return false;
    const policy = captured.appearancePolicy;
    return String(policy.fontFamily) === "Noto Sans"
        && ["false", "0"].indexOf(String(policy.autoFontAndSize)) !== -1
        && String(policy.fontSize) === "11"
        && String(policy.fontStyleName) === "Regular"
        && String(policy.fontWeight) === "400";
}

function validateInjectedState() {
    if (typeof expectedStablePanelState !== "object" || !expectedStablePanelState
            || expectedStablePanelState.schemaVersion !== 1
            || !same(expectedStablePanelState.orderedIds, stableIds)
            || !same(expectedStablePanelState.orderedTypes, stableTypes)
            || typeof capturedDuplicateTailState !== "object"
            || !capturedDuplicateTailState
            || capturedDuplicateTailState.schemaVersion !== 1
            || !Array.isArray(capturedDuplicateTailState.stableWidgets)
            || capturedDuplicateTailState.stableWidgets.length !== 11
            || !capturedDuplicateTailState.panel
            || Number(capturedDuplicateTailState.panel.id)
                !== Number(expectedStablePanelState.panelId)
            || Number(capturedDuplicateTailState.panel.screen) !== 0
            || String(capturedDuplicateTailState.panel.location) !== "top"
            || String(capturedDuplicateTailState.panel.formFactor) !== "horizontal"
            || Number(capturedDuplicateTailState.panel.height) !== 32
            || String(capturedDuplicateTailState.panel.lengthMode) !== "fill"
            || String(capturedDuplicateTailState.panel.hiding) !== "none"
            || capturedDuplicateTailState.panel.floating !== false
            || String(capturedDuplicateTailState.panel.opacity) !== "opaque") {
        throw new Error("cleanup refused: receipt or preflight capture is missing");
    }
    for (let position = 0; position < stableIds.length; ++position) {
        const captured = capturedDuplicateTailState.stableWidgets[position];
        if (!captured || Number(captured.id) !== stableIds[position]
                || captured.type !== stableTypes[position]) {
            throw new Error("cleanup refused: preflight stable identity is malformed");
        }
        if (position !== 1 && position !== 2 && position !== 6
                && position !== 10 && !capturedGeometryValid(captured, false)) {
            throw new Error("cleanup refused: preflight keeper geometry is malformed");
        }
    }
    if (!capturedProjectValid(capturedDuplicateTailState.stableWidgets[1],
            expectedStablePanelState.workspace, stableIds[1], workspaceType, true)
            || !capturedProjectValid(capturedDuplicateTailState.stableWidgets[2],
                expectedStablePanelState.activeTitle, stableIds[2], activeTitleType, true)
            || !capturedProjectValid(capturedDuplicateTailState.stableWidgets[6],
                expectedStablePanelState.resources, stableIds[6], resourceType, true)
            || !capturedClockValid(capturedDuplicateTailState.stableWidgets[10])) {
        throw new Error("cleanup refused: preflight keeper policy is malformed");
    }
    if (["source13", "partial12", "target11"].indexOf(
            capturedDuplicateTailState.topologyState) === -1) {
        throw new Error("cleanup refused: preflight topology state is malformed");
    }
    if (capturedDuplicateTailState.topologyState === "source13"
            && (!capturedDuplicateTailState.staleActiveTitle
                || !capturedDuplicateTailState.staleResources
                || !capturedProjectValid(
                    capturedDuplicateTailState.staleActiveTitle,
                    expectedStablePanelState.activeTitle,
                    staleActiveTitleId, activeTitleType, false)
                || !capturedProjectValid(
                    capturedDuplicateTailState.staleResources,
                    expectedStablePanelState.resources,
                    staleResourceId, resourceType, false))) {
        throw new Error("cleanup refused: source capture omitted stale applets");
    }
    if (capturedDuplicateTailState.topologyState === "partial12"
            && (!capturedDuplicateTailState.staleActiveTitle
                || capturedDuplicateTailState.staleResources !== null
                || !capturedProjectValid(
                    capturedDuplicateTailState.staleActiveTitle,
                    expectedStablePanelState.activeTitle,
                    staleActiveTitleId, activeTitleType, false))) {
        throw new Error("cleanup refused: partial capture is malformed");
    }
    if (capturedDuplicateTailState.topologyState === "target11"
            && (capturedDuplicateTailState.staleActiveTitle !== null
                || capturedDuplicateTailState.staleResources !== null)) {
        throw new Error("cleanup refused: target capture is malformed");
    }
}

function classifyAndValidate(panel, state) {
    if (!panelMatchesCapture(panel, capturedDuplicateTailState.panel)) {
        throw new Error("cleanup refused: panel geometry changed after preflight");
    }
    let topology = "unknown";
    if (same(state.ids, stableIds.concat([staleActiveTitleId, staleResourceId]))
            && same(state.types, stableTypes.concat([activeTitleType, resourceType]))) {
        topology = "source13";
    } else if (same(state.ids, stableIds.concat([staleActiveTitleId]))
            && same(state.types, stableTypes.concat([activeTitleType]))) {
        topology = "partial12";
    } else if (same(state.ids, stableIds) && same(state.types, stableTypes)) {
        topology = "target11";
    } else {
        throw new Error("cleanup refused: live topology is not a recognized convergence state");
    }
    const stages = {source13: 0, partial12: 1, target11: 2};
    if (stages[topology] < stages[capturedDuplicateTailState.topologyState]) {
        throw new Error("cleanup refused: stale applets appeared after preflight");
    }
    for (let position = 0; position < stableIds.length; ++position) {
        if (!stableWidgetMatches(state.widgets[position],
                capturedDuplicateTailState.stableWidgets[position], position)) {
            throw new Error("cleanup refused: a keeper changed after preflight");
        }
    }
    if (topology === "source13") {
        if (!capturedDuplicateTailState.staleActiveTitle
                || !capturedDuplicateTailState.staleResources
                || !projectWidgetMatches(state.widgets[11],
                    capturedDuplicateTailState.staleActiveTitle)
                || !projectWidgetMatches(state.widgets[12],
                    capturedDuplicateTailState.staleResources)) {
            throw new Error("cleanup refused: duplicate tail changed after preflight");
        }
    } else if (topology === "partial12") {
        if (!capturedDuplicateTailState.staleActiveTitle
                || !projectWidgetMatches(state.widgets[11],
                    capturedDuplicateTailState.staleActiveTitle)) {
            throw new Error("cleanup refused: stale title changed after preflight");
        }
    }
    return topology;
}

validateInjectedState();
if (panelIds.length !== 1) throw new Error("cleanup refused: expected exactly one panel");
let panel = panelById(panelIds[0]);
if (!panel || Number(panel.id) !== Number(expectedStablePanelState.panelId)) {
    throw new Error("cleanup refused: receipt-bound panel is unavailable");
}
let state = orderedPanelState(panel);
const initialTopology = classifyAndValidate(panel, state);
let removedResourceId = "none";
let removedActiveTitleId = "none";

if (initialTopology === "source13") {
    removedResourceId = String(state.widgets[12].id);
    state.widgets[12].remove();
    if (typeof duplicateTailTestFailAfterFirstRemoval !== "undefined"
            && duplicateTailTestFailAfterFirstRemoval === true) {
        throw new Error("injected duplicate-tail failure after resource removal");
    }
    panel = panelById(panelIds[0]);
    state = orderedPanelState(panel);
    if (classifyAndValidate(panel, state) !== "partial12") {
        throw new Error("cleanup stopped outside the exact partial state");
    }
}
if (initialTopology === "source13" || initialTopology === "partial12") {
    removedActiveTitleId = String(state.widgets[11].id);
    state.widgets[11].remove();
    panel = panelById(panelIds[0]);
    state = orderedPanelState(panel);
    if (classifyAndValidate(panel, state) !== "target11") {
        throw new Error("cleanup did not converge to the exact stable target");
    }
}

let transition = "already-target";
if (initialTopology === "source13") transition = "remove-both";
if (initialTopology === "partial12") transition = "remove-active-title";
print(
    "MINIMALIST_V04_DUPLICATE_TAIL_CLEANUP_OK"
    + " transition=" + transition
    + " removedResourceId=" + removedResourceId
    + " removedActiveTitleId=" + removedActiveTitleId
    + " keeperIds=" + stableIds.join(";")
);
