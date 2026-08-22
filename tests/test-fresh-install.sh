#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$TEST_DIR/lib/runtime.sh"
require_test_node
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-fresh-install.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-fresh-install.*)
            rm -rf -- "$TEMP_ROOT"
            ;;
        *)
            printf 'refusing to clean unexpected test directory: %s\n' "$TEMP_ROOT" >&2
            ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v02"
PROBE="$LAYOUT/contents/panel-state.js"
FRESH_LAYOUT="$LAYOUT/contents/fresh-layout.js"
POSTCHECK="$LAYOUT/contents/postcheck.js"
APPLY_FRESH="$REPO_ROOT/scripts/apply-fresh"

[[ -x $APPLY_FRESH ]] || fail "scripts/apply-fresh is not executable"
bash -n "$APPLY_FRESH" || fail "scripts/apply-fresh has invalid Bash syntax"
"$NODE_BIN" --check "$PROBE" || fail "panel-state probe has invalid JavaScript syntax"
"$NODE_BIN" --check "$FRESH_LAYOUT" || fail "fresh transition has invalid JavaScript syntax"

grep -Fq 'KDE_RICE_PANEL_STATE_JSON=' "$PROBE" || fail "stable JSON panel-state marker is missing"
grep -Fq 'order_valid' "$PROBE" || fail "panel-state schema omits AppletOrder validity"
grep -Fq 'plasma6-stock' "$PROBE" "$FRESH_LAYOUT" || fail "stock signature is undocumented in code"
grep -Fq 'plasma6-stock-ime' "$PROBE" "$FRESH_LAYOUT" || fail "stock IME signature is undocumented in code"
grep -Fq 'MINIMALIST_V02_FRESH_APPLY_OK' "$FRESH_LAYOUT" || fail "fresh apply success marker is missing"
grep -Fq 'originalPanel.remove();' "$FRESH_LAYOUT" || fail "fresh transition does not replace the recognized stock panel"
grep -Fq 'targetPanel.remove();' "$FRESH_LAYOUT" || fail "failed replacement panel is not cleaned up"
grep -Fq 'fresh apply refuses unknown topology' "$FRESH_LAYOUT" || fail "unknown topology refusal is missing"
grep -Fq 'capture_or_reuse_snapshot' "$APPLY_FRESH" || fail "fresh apply does not capture or reuse the complete managed snapshot"
grep -Fq 'Restore apply:' "$APPLY_FRESH" || fail "fresh apply does not print a full restore command"

"$NODE_BIN" - "$PROBE" "$FRESH_LAYOUT" "$POSTCHECK" <<'NODE'
const fs = require("fs");
const vm = require("vm");

const probeSource = fs.readFileSync(process.argv[2], "utf8");
const freshSource = fs.readFileSync(process.argv[3], "utf8");
const postcheckSource = fs.readFileSync(process.argv[4], "utf8");
const stock = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const stockIme = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop"
];
const target = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const trayServices = [
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.notifications"
];
const managedStates = new Map([
    ["minimalist-v01", stockIme],
    ["minimalist-v02-show-desktop", [
        "org.kde.plasma.kickoff", "org.kde.plasma.panelspacer",
        "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
        "org.kde.plasma.systemtray", "org.kde.plasma.digitalclock",
        "org.kde.plasma.showdesktop"
    ]],
    ["minimalist-v02-no-title", [
        "org.kde.plasma.kickoff", "org.kde.plasma.panelspacer",
        "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
        "org.kde.plasma.systemtray", "org.kde.plasma.digitalclock"
    ]],
    ["minimalist-v02-spacer-repair", [
        "org.kde.plasma.kickoff", "org.kde.plasma.marginsseparator",
        "org.kde.plasma.kimpanel", "org.kde.plasma.systemtray",
        "org.kde.plasma.digitalclock", "org.kde.plasma.showdesktop",
        "org.kde.plasma.panelspacer"
    ]],
    ["minimalist-v02-title-repair", [
        "org.kde.plasma.kickoff", "org.kde.plasma.panelspacer",
        "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
        "org.kde.plasma.systemtray", "org.kde.plasma.digitalclock",
        "org.kde.minimalist.activewindowtitle"
    ]]
]);

function assert(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

function assertClockPolicy(widget, label) {
    const previousGroup = widget.currentConfigGroup;
    widget.currentConfigGroup = ["Appearance"];
    const expected = {
        showDate: false,
        showSeconds: 2,
        use24hFormat: 2,
        autoFontAndSize: true
    };
    for (const [key, value] of Object.entries(expected)) {
        assert(widget.readConfig(key, null) === value, label + ": clock " + key + " policy differs");
    }
    widget.currentConfigGroup = previousGroup;
}

function newModel(types, options = {}) {
    const model = {panels: [], nextPanelId: 50, nextWidgetId: 101};
    const panelOptions = {
        id: options.id === undefined ? 42 : options.id,
        screen: options.screen === undefined ? 0 : options.screen,
        location: options.location || "bottom",
        formFactor: options.formFactor || "horizontal"
    };
    if (Object.prototype.hasOwnProperty.call(options, "orderOverride")) {
        panelOptions.orderOverride = options.orderOverride;
    }
    addPanel(model, types, panelOptions);
    return model;
}

function makeWidget(model, panel, type) {
    let configGroup = [];
    const config = new Map();
    const widget = {
        id: model.nextWidgetId++,
        type,
        set currentConfigGroup(value) {
            configGroup = value.slice();
        },
        get currentConfigGroup() {
            return configGroup.slice();
        },
        writeConfig(key, value) {
            config.set(configGroup.join("/") + "/" + key, value);
        },
        readConfig(key, fallback) {
            const fullKey = configGroup.join("/") + "/" + key;
            return config.has(fullKey) ? config.get(fullKey) : fallback;
        },
        reloadConfig() {},
        remove() {
            panel._widgets = panel._widgets.filter((candidate) => candidate !== widget);
            panel._order = panel._order.filter((id) => id !== widget.id);
        },
        _config: config
    };
    return widget;
}

function addPanel(model, types, options = {}) {
    let configGroup = [];
    const config = new Map();
    const panel = {
        id: options.id === undefined ? model.nextPanelId++ : options.id,
        screen: options.screen === undefined ? 0 : options.screen,
        location: options.location || "bottom",
        formFactor: options.formFactor || "horizontal",
        height: 44,
        lengthMode: "fill",
        length: 2400,
        minimumLength: 2400,
        maximumLength: 2400,
        alignment: "center",
        offset: 0,
        hiding: "none",
        floating: true,
        opacity: "adaptive",
        _widgets: [],
        _order: [],
        _orderOverride: Object.prototype.hasOwnProperty.call(options, "orderOverride") ? options.orderOverride : null,
        _config: config
    };
    Object.defineProperty(panel, "currentConfigGroup", {
        get() {
            return configGroup.slice();
        },
        set(value) {
            configGroup = value.slice();
        }
    });
    panel.readConfig = function (key, fallback) {
        if (configGroup.join("/") === "General" && key === "AppletOrder") {
            return this._orderOverride === null ? this._order.join(";") : this._orderOverride;
        }
        const fullKey = configGroup.join("/") + "/" + key;
        return config.has(fullKey) ? config.get(fullKey) : fallback;
    };
    panel.writeConfig = function (key, value) {
        config.set(configGroup.join("/") + "/" + key, value);
    };
    panel.reloadConfig = function () {};
    panel.widgets = function (type) {
        return type ? this._widgets.filter((widget) => widget.type === type) : this._widgets.slice();
    };
    panel.addWidget = function (type) {
        if (model.failWidgetType === type) {
            return null;
        }
        const widget = makeWidget(model, panel, type);
        this._widgets.push(widget);
        this._order.push(widget.id);
        return widget;
    };
    panel.remove = function () {
        model.panels = model.panels.filter((candidate) => candidate !== panel);
    };
    for (const type of types) {
        panel.addWidget(type);
    }
    model.panels.push(panel);
    return panel;
}

function contextFor(model, output) {
    function Panel() {
        return addPanel(model, [], {
            screen: 0,
            location: "bottom",
            formFactor: "horizontal"
        });
    }
    const context = {
        Panel,
        panelById: (id) => model.panels.find((panel) => panel.id === Number(id)) || null,
        knownWidgetTypes: Array.from(new Set(target.concat(stock, trayServices))),
        desktops: () => [{screen: 0}],
        screenGeometry: () => ({width: 2400, height: 1350}),
        print: (value) => output.push(String(value))
    };
    Object.defineProperty(context, "panelIds", {
        enumerable: true,
        get() {
            return model.panels.map((panel) => panel.id);
        }
    });
    return context;
}

function run(source, model) {
    const output = [];
    vm.runInNewContext(source, contextFor(model, output));
    return output.join("\n");
}

function probe(model) {
    const output = run(probeSource, model);
    const line = output.split("\n").find((candidate) => candidate.startsWith("KDE_RICE_PANEL_STATE_JSON="));
    assert(line, "probe did not return its JSON marker");
    return {output, state: JSON.parse(line.slice("KDE_RICE_PANEL_STATE_JSON=".length))};
}

function digest(model) {
    return JSON.stringify(model.panels.map((panel) => ({
        id: panel.id,
        screen: panel.screen,
        location: panel.location,
        formFactor: panel.formFactor,
        height: panel.height,
        lengthMode: panel.lengthMode,
        length: panel.length,
        minimumLength: panel.minimumLength,
        maximumLength: panel.maximumLength,
        alignment: panel.alignment,
        offset: panel.offset,
        hiding: panel.hiding,
        floating: panel.floating,
        opacity: panel.opacity,
        order: panel._order.slice(),
        widgets: panel._widgets.map((widget) => ({
            id: widget.id,
            type: widget.type,
            config: Array.from(widget._config.entries())
        })),
        config: Array.from(panel._config.entries())
    })));
}

for (const [types, wantedSignature] of [[stock, "plasma6-stock"], [stockIme, "plasma6-stock-ime"]]) {
    const model = newModel(types);
    const before = digest(model);
    const result = probe(model);
    assert(result.state.schema_version === 1, "panel-state schema version changed");
    assert(result.state.signature === wantedSignature, "fresh stock signature was not classified");
    assert(result.state.transition === "replace-fresh-panel", "fresh replacement was not planned");
    assert(result.state.panels[0].order_valid === true, "valid AppletOrder was rejected");
    assert(JSON.stringify(result.state.plan.remove_panel_ids) === JSON.stringify([42]), "removed panel ID was not exact");
    assert(result.state.plan.remove_widget_ids.length === types.length, "removed widget IDs were incomplete");
    assert(JSON.stringify(result.state.plan.create_widgets) === JSON.stringify(target), "created target order was not exact");
    assert(digest(model) === before, "read-only panel-state probe mutated Plasma state");
}

for (const [signature, types] of managedStates) {
    const model = newModel(types, {location: "top"});
    const state = probe(model).state;
    assert(state.signature === signature, "managed transition signature was not classified: " + signature);
    assert(state.transition === "managed-v02-transition", "managed transition was routed as fresh: " + signature);
}

const malformed = newModel(stock, {orderOverride: ""});
const malformedBefore = digest(malformed);
assert(probe(malformed).state.signature === "unknown", "malformed AppletOrder was accepted");
let malformedRefused = false;
try {
    run(freshSource, malformed);
} catch (error) {
    malformedRefused = String(error).includes("malformed AppletOrder");
}
assert(malformedRefused, "fresh transition did not reject malformed AppletOrder");
assert(digest(malformed) === malformedBefore, "malformed topology was mutated");

const unknown = newModel(stock.concat(["org.example.foreign"]));
const unknownBefore = digest(unknown);
assert(probe(unknown).state.signature === "unknown", "foreign widget topology was accepted");
let unknownRefused = false;
try {
    run(freshSource, unknown);
} catch (error) {
    unknownRefused = String(error).includes("refuses unknown topology");
}
assert(unknownRefused, "fresh transition did not reject an unknown topology");
assert(digest(unknown) === unknownBefore, "unknown topology was mutated before refusal");

const creationFailure = newModel(stock);
const creationFailureBefore = digest(creationFailure);
creationFailure.failWidgetType = "org.kde.plasma.panelspacer";
let creationFailed = false;
try {
    run(freshSource, creationFailure);
} catch (error) {
    creationFailed = String(error).includes("could not create target widget");
}
assert(creationFailed, "fresh transition did not surface a target creation failure");
assert(creationFailure.panels.length === 1 && creationFailure.panels[0].id === 42,
    "fresh transition did not remove its partial target panel");
assert(digest(creationFailure) === creationFailureBefore,
    "fresh transition changed the recognized stock panel after target creation failed");

const model = newModel(stock);
const oldPanelId = model.panels[0].id;
const oldWidgetIds = model.panels[0]._widgets.map((widget) => widget.id);
const first = run(freshSource, model);
assert(first.includes("MINIMALIST_V02_FRESH_APPLY_OK"), "fresh transition success marker is missing");
assert(first.includes("transition=replace-fresh-panel"), "fresh transition kind was not reported");
assert(first.includes("removedPanelIds=" + oldPanelId), "removed panel ID was not reported");
assert(first.includes("removedWidgetIds=" + oldWidgetIds.join(",")), "removed widget IDs were not reported");
assert(model.panels.length === 1, "fresh transition left duplicate panels");
const targetPanel = model.panels[0];
assert(targetPanel.id !== oldPanelId, "fresh transition did not replace the stock panel");
assert(JSON.stringify(targetPanel.widgets().map((widget) => widget.type)) === JSON.stringify(target), "fresh target widget order is wrong");
assert(targetPanel.location === "top" && targetPanel.screen === 0 && targetPanel.height === 32, "fresh target geometry is wrong");
assert(targetPanel.lengthMode === "fill" && targetPanel.floating === false && targetPanel.opacity === "opaque", "fresh target strip policy is wrong");
assertClockPolicy(targetPanel.widgets("org.kde.plasma.digitalclock")[0], "fresh target");
assert(run(postcheckSource, model).includes("MINIMALIST_V02_POSTCHECK_OK"), "fresh target failed the existing postcheck");
const targetProbe = probe(model).state;
assert(targetProbe.signature === "minimalist-v02", "fresh target was not classified as Minimalist v0.2");
assert(targetProbe.target_complete === true, "fresh target policy was not mechanically complete");
assert(targetProbe.target_policy.clock.show_date === false
    && targetProbe.target_policy.clock.show_seconds === 2
    && targetProbe.target_policy.clock.use_24h_format === 2,
"fresh target probe omitted the exact date-hidden 24-hour clock policy");
const targetClock = targetPanel.widgets("org.kde.plasma.digitalclock")[0];
targetClock.currentConfigGroup = ["Appearance"];
targetClock.writeConfig("showSeconds", "Always");
targetClock.currentConfigGroup = [];
assert(run(postcheckSource, model).includes("MINIMALIST_V02_POSTCHECK_OK"),
    "fresh postcheck rejected Plasma's canonical showSeconds enum name");
assert(probe(model).state.target_complete === true,
    "panel-state rejected Plasma's canonical showSeconds enum name");

const targetId = targetPanel.id;
const targetWidgetIds = targetPanel._widgets.map((widget) => widget.id);
const second = run(freshSource, model);
assert(second.includes("transition=already-target"), "fresh reapply was not idempotent");
assert(model.panels.length === 1 && model.panels[0].id === targetId, "fresh reapply duplicated or replaced the target panel");
assert(JSON.stringify(model.panels[0]._widgets.map((widget) => widget.id)) === JSON.stringify(targetWidgetIds), "fresh reapply duplicated target widgets");
NODE

TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/mock-bin"
mkdir -p -- "$TARGET_HOME/.config" "$MOCK_BIN"
printf 'baseline-kdeglobals\n' > "$TARGET_HOME/.config/kdeglobals"
printf 'baseline-panel\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'baseline-shell\n' > "$TARGET_HOME/.config/plasmashellrc"
printf 'excluded-display\n' > "$TARGET_HOME/.config/kwinoutputconfig.json"

cat > "$MOCK_BIN/qdbus6" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
script=${!#}
target='org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
entries='101:org.kde.plasma.kickoff,102:org.kde.plasma.pager,103:org.kde.plasma.icontasks,104:org.kde.plasma.marginsseparator,105:org.kde.plasma.systemtray,106:org.kde.plasma.digitalclock,107:org.kde.plasma.showdesktop'
if [[ $script == *'Read-only Minimalist panel-state probe.'* ]]; then
    signature=${MOCK_PANEL_SIGNATURE:-plasma6-stock}
    case "$signature" in
        plasma6-stock)
            transition=replace-fresh-panel
            remove_panels=42
            remove_widgets=101,102,103,104,105,106,107
            remove_entries=$entries
            create=true
            complete=false
            ;;
        minimalist-v02)
            transition=already-target
            remove_panels=none
            remove_widgets=none
            remove_entries=none
            create=false
            complete=true
            ;;
        *)
            transition=refuse
            remove_panels=none
            remove_widgets=none
            remove_entries=none
            create=false
            complete=false
            ;;
    esac
    printf 'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"signature":"%s"}' "$signature"
    printf 'KDE_RICE_PANEL_STATE schema=1 signature=%s transition=%s supported=%s targetComplete=%s removePanelIds=%s removeWidgetIds=%s removeWidgetEntries=%s createPanel=%s targetWidgets=%s\n' \
        "$signature" "$transition" "$([[ $signature != unknown ]] && printf true || printf false)" "$complete" \
        "$remove_panels" "$remove_widgets" "$remove_entries" "$create" "$target"
elif [[ $script == *'Minimalist v0.2 fresh-install transition for Plasma 6.'* ]]; then
    printf 'MINIMALIST_V02_FRESH_APPLY_OK transition=replace-fresh-panel\n'
elif [[ $script == *'MINIMALIST_V02_POSTCHECK_OK'* ]]; then
    if [[ ${MOCK_POSTCHECK_OPACITY_FAIL:-0} == 1 ]]; then
        printf 'post panelId=27 geometryBaseOk=true opacityOk=false geometryOk=false topologyOk=true spacerOk=true activeTitleOk=true trayOk=true clockOk=true\n'
    else
        printf 'post panelId=27 geometryBaseOk=true opacityOk=true geometryOk=true topologyOk=true spacerOk=true activeTitleOk=true trayOk=true clockOk=true MINIMALIST_V02_POSTCHECK_OK\n'
    fi
else
    printf 'unexpected mock Plasma script\n' >&2
    exit 1
fi
MOCK
chmod +x "$MOCK_BIN/qdbus6"
cat > "$MOCK_BIN/doctor" <<'MOCK'
#!/usr/bin/env bash
status=${MOCK_DOCTOR_STATUS:-0}
printf 'KDE Rice Doctor\nStatus: %s\nExit code: %s\n' \
    "$([[ $status == 0 ]] && printf supported || printf unsupported)" "$status"
exit "$status"
MOCK
chmod +x "$MOCK_BIN/doctor"

set +e
HOME="$TARGET_HOME" PATH="$MOCK_BIN:$PATH" bash "$APPLY_FRESH" --not-an-option > "$TEMP_ROOT/usage.txt" 2>&1
usage_status=$?
set -e
[[ $usage_status -eq 64 ]] || fail "apply-fresh usage errors must exit 64"

HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    PATH="$MOCK_BIN:$PATH" KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    bash "$APPLY_FRESH" --home "$TARGET_HOME" > "$TEMP_ROOT/dry-run.txt"
grep -Fq 'Fresh-install mode: DRY RUN' "$TEMP_ROOT/dry-run.txt" || fail "default invocation is not a dry run"
grep -Fq 'recognized signature: plasma6-stock' "$TEMP_ROOT/dry-run.txt" || fail "dry run omitted the recognized fresh signature"
grep -Fq 'remove panel id: 42' "$TEMP_ROOT/dry-run.txt" || fail "dry run omitted the removed panel ID"
grep -Fq 'remove widget: 101:org.kde.plasma.kickoff' "$TEMP_ROOT/dry-run.txt" || fail "dry run omitted exact removed widget identity"
grep -Fq 'target widget 7: org.kde.plasma.digitalclock' "$TEMP_ROOT/dry-run.txt" || fail "dry run omitted the exact target order"
grep -Fq -- "--home $TARGET_HOME" "$TEMP_ROOT/dry-run.txt" || fail "dry-run restore command omits the target home"
[[ ! -e $TARGET_HOME/.local ]] || fail "default fresh dry run changed the test home"

set +e
HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    PATH="$MOCK_BIN:$PATH" KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    MOCK_DOCTOR_STATUS=2 \
    bash "$APPLY_FRESH" --home "$TARGET_HOME" --apply > "$TEMP_ROOT/unsupported-doctor.txt" 2>&1
unsupported_status=$?
set -e
[[ $unsupported_status -eq 1 ]] || fail "apply-fresh did not refuse an unsupported doctor result"
[[ ! -e $TARGET_HOME/.local ]] || fail "unsupported doctor result wrote fresh-install state"

set +e
HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    PATH="$MOCK_BIN:$PATH" KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    MOCK_PANEL_SIGNATURE=unknown \
    bash "$APPLY_FRESH" --home "$TARGET_HOME" --apply > "$TEMP_ROOT/unknown.txt" 2>&1
unknown_status=$?
set -e
[[ $unknown_status -eq 1 ]] || fail "unknown topology must exit 1"
[[ ! -e $TARGET_HOME/.local ]] || fail "unknown topology wrote before refusal"
grep -Fq 'refuses unknown panel topology' "$TEMP_ROOT/unknown.txt" || fail "unknown topology reason was not reported"

display_before=$(sha256sum "$TARGET_HOME/.config/kwinoutputconfig.json")
HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    PATH="$MOCK_BIN:$PATH" KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    MOCK_PANEL_SIGNATURE=plasma6-stock \
    bash "$APPLY_FRESH" --home "$TARGET_HOME" --apply > "$TEMP_ROOT/apply.txt"
snapshot_path=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt")
[[ -n $snapshot_path && -f $snapshot_path/complete ]] || fail "fresh apply did not produce a complete pre-apply snapshot"
grep -Fq $'absent\t.local/share/plasma/layout-templates/org.kde.minimalist-v02' "$snapshot_path/state.tsv" || fail "layout package was written before the snapshot"
grep -Fq $'absent\t.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle' "$snapshot_path/state.tsv" || fail "Plasmoid was written before the snapshot"
[[ -f $snapshot_path/payload/.config/plasma-org.kde.plasma.desktop-appletsrc ]] || fail "fresh snapshot omitted panel topology"
[[ ! -e $snapshot_path/payload/.config/kwinoutputconfig.json ]] || fail "fresh snapshot captured excluded display configuration"
diff -qr -- "$LAYOUT" "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v02" >/dev/null || fail "installed fresh layout differs from source"
diff -qr -- "$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle" "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle" >/dev/null || fail "installed active-title package differs from source"
[[ $(sha256sum "$TARGET_HOME/.config/kwinoutputconfig.json") == "$display_before" ]] || fail "fresh apply changed excluded display configuration"
grep -Fq -- "--home $TARGET_HOME --apply" "$TEMP_ROOT/apply.txt" || fail "apply output omits the full restore command"

OPACITY_HOME="$TEMP_ROOT/opacity-home"
mkdir -p -- "$OPACITY_HOME/.config"
printf 'baseline-panel\n' > "$OPACITY_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'baseline-shell\n' > "$OPACITY_HOME/.config/plasmashellrc"
set +e
HOME="$OPACITY_HOME" XDG_CONFIG_HOME="$OPACITY_HOME/.config" \
    XDG_DATA_HOME="$OPACITY_HOME/.local/share" XDG_STATE_HOME="$OPACITY_HOME/.local/state" \
    PATH="$MOCK_BIN:$PATH" KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    MOCK_PANEL_SIGNATURE=plasma6-stock MOCK_POSTCHECK_OPACITY_FAIL=1 \
    bash "$APPLY_FRESH" --home "$OPACITY_HOME" --apply > "$TEMP_ROOT/opacity-failure.txt" 2>&1
opacity_status=$?
set -e
[[ $opacity_status == 1 ]] || fail "opacity-only postcheck failure did not stop apply"
grep -Fq 'change only this panel to Opaque in edit mode' "$TEMP_ROOT/opacity-failure.txt" \
    || fail "opacity-only failure omitted the manual recovery path"
grep -Fq 'exact failed-receipt resume commands printed by bootstrap' \
    "$TEMP_ROOT/opacity-failure.txt" \
    || fail "opacity-only failure omitted the receipt resume boundary"
grep -Fq 'instead of starting a new live bootstrap' "$TEMP_ROOT/opacity-failure.txt" \
    || fail "opacity-only failure did not prevent a duplicate live transaction"

bash "$REPO_ROOT/scripts/restore" --backup "$snapshot_path" --home "$TARGET_HOME" \
    --state-root "$TARGET_HOME/.local/state/kde-rice/test-fresh-restore" --apply > "$TEMP_ROOT/restore.txt"
[[ ! -e $TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v02 ]] || fail "restore left the fresh layout installed"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle ]] || fail "restore left the active-title Plasmoid installed"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == baseline-panel ]] || fail "restore did not recover the stock panel file"
[[ $(< "$TARGET_HOME/.config/plasmashellrc") == baseline-shell ]] || fail "restore did not recover the stock panel-view file"
[[ $(sha256sum "$TARGET_HOME/.config/kwinoutputconfig.json") == "$display_before" ]] || fail "restore changed excluded display configuration"

printf 'PASS: fresh-install transition and recovery tests\n'
