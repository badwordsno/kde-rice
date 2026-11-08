#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$SCRIPT_DIR/lib/runtime.sh"
require_test_node
require_test_qmllint
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-minimalist-v03.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-minimalist-v03.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing unsafe cleanup: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v03"
PLASMOID="$REPO_ROOT/plasmoids/org.kde.minimalist.resources"
VOLUME_PROVIDER="$PLASMOID/contents/ui/providers/VolumeProvider.qml"
APPLY_SCRIPT="$REPO_ROOT/scripts/apply-minimalist-v03"
TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
mkdir -p -- "$TARGET_HOME" "$MOCK_BIN"

"$NODE_BIN" --check "$LAYOUT/contents/preflight.js" >/dev/null
"$NODE_BIN" --check "$LAYOUT/contents/layout.js" >/dev/null
"$NODE_BIN" --check "$LAYOUT/contents/postcheck.js" >/dev/null
bash -n "$APPLY_SCRIPT"
"$QMLLINT_BIN" -I "$QML_IMPORT_ROOT" "$PLASMOID/contents/ui/main.qml" \
    || fail "resource Plasmoid QML validation failed"
"$QMLLINT_BIN" -I "$QML_IMPORT_ROOT" "$VOLUME_PROVIDER" \
    || fail "isolated volume-provider QML validation failed"

grep -Fq '"Id": "org.kde.minimalist-v03"' "$LAYOUT/metadata.json" \
    || fail "v0.3 layout package ID is wrong"
grep -Fq '"Id": "org.kde.minimalist.resources"' "$PLASMOID/metadata.json" \
    || fail "resource Plasmoid package ID is wrong"
grep -Fq 'widget.writeConfig("showSeconds", 2);' "$LAYOUT/contents/layout.js" \
    || fail "v0.3 clock seconds policy is missing"
grep -Fq 'widget.writeConfig("showDate", false);' "$LAYOUT/contents/layout.js" \
    || fail "v0.3 clock date-hidden policy is missing"
if grep -Eq 'widget\.writeConfig\("(dateDisplayFormat|dateFormat|customDateFormat)"' \
    "$LAYOUT/contents/layout.js"; then
    fail "v0.3 hidden date preferences must remain user-owned"
fi
grep -Fq 'widget.writeConfig("autoFontAndSize", true);' "$LAYOUT/contents/layout.js" \
    || fail "v0.3 automatic clock font policy is missing"
grep -Fq 'sensorId: "cpu/all/usage"' "$PLASMOID/contents/ui/main.qml" \
    || fail "aggregate CPU sensor is missing"
grep -Fq 'sensorId: "memory/physical/usedPercent"' "$PLASMOID/contents/ui/main.qml" \
    || fail "physical-memory percentage sensor is missing"
if grep -Fq 'import org.kde.plasma.private.volume' "$PLASMOID/contents/ui/main.qml"; then
    fail "private volume import can still disable the entire resource strip"
fi
grep -Fq 'source: "providers/VolumeProvider.qml"' "$PLASMOID/contents/ui/main.qml" \
    || fail "the volume backend is not isolated behind a Loader"
grep -Fq 'import org.kde.plasma.private.volume' "$VOLUME_PROVIDER" \
    || fail "event-driven KDE volume backend import is missing"
grep -Fq 'readonly property var sink: PreferredDevice.sink' "$VOLUME_PROVIDER" \
    || fail "preferred output device binding is missing"
grep -Fq 'Number(PulseAudio.NormalVolume)' "$VOLUME_PROVIDER" \
    || fail "native PulseAudioQt volume normalization is missing"
grep -Fq 'text: "RAM " + root.paddedPercentage(memory)' "$PLASMOID/contents/ui/main.qml" \
    || fail "memory label was not renamed to RAM"
grep -Fq 'text: "VOL " + root.paddedOutputVolume()' "$PLASMOID/contents/ui/main.qml" \
    || fail "output volume percentage label is missing"
grep -Fq 'opacity: root.volumeMuted ? 0.55 : 1' "$PLASMOID/contents/ui/main.qml" \
    || fail "muted output has no click-free visual state"
grep -Fq 'sensorId: "gpu/gpu0/usage"' "$PLASMOID/contents/ui/main.qml" \
    || fail "preferred gpu0 sensor is missing"
grep -Fq 'sensorId: "gpu/all/usage"' "$PLASMOID/contents/ui/main.qml" \
    || fail "portable aggregate GPU fallback is missing"
grep -Fq 'gpuPrimary.status === Sensors.Sensor.Ready' "$PLASMOID/contents/ui/main.qml" \
    || fail "GPU availability is not guarded by the native sensor state"
grep -Fq 'readonly property int sensorUpdateLimit: 2000' "$PLASMOID/contents/ui/main.qml" \
    || fail "resource polling limit is not two seconds"
grep -Fq 'readonly property real stableLabelWidth:' "$PLASMOID/contents/ui/main.qml" \
    || fail "resource labels do not reserve a stable maximum width"
grep -Fq 'labelMetrics.advanceWidth("RAM 100%")' "$PLASMOID/contents/ui/main.qml" \
    || fail "resource width does not include the widest metric label"
grep -Fq 'function paddedPercentage(sensor)' "$PLASMOID/contents/ui/main.qml" \
    || fail "resource percentages are not padded against digit-count jitter"
if rg -n 'Layout\.(minimumWidth|preferredWidth|maximumWidth): metrics\.' \
    "$PLASMOID/contents/ui/main.qml" >/dev/null; then
    fail "resource root still references a deferred representation ID"
fi
grep -Fq 'require_component_diagnosis "$DOCTOR_COMMAND" minimalist-v03' "$APPLY_SCRIPT" \
    || fail "v0.3 apply does not request the v0.3 doctor capability target"
"$NODE_BIN" - "$PLASMOID/contents/ui/main.qml" <<'NODE'
const fs = require("fs");
const vm = require("vm");
const source = fs.readFileSync(process.argv[2], "utf8");
const functions = source.match(/    function percentage\(sensor\) \{[\s\S]*?\n    \}\n\n    function paddedPercentage\(sensor\) \{[\s\S]*?\n    \}/);
if (!functions) process.exit(1);
const context = {Math, Number, Sensors: {Sensor: {Ready: 1}}};
vm.runInNewContext(functions[0].replace(/^    /gm, ""), context);
const cases = [
    [{status: 0, value: 0}, "\u2007\u2007--"],
    [{status: 1, value: 0}, "\u2007\u20070%"],
    [{status: 1, value: 9.4}, "\u2007\u20079%"],
    [{status: 1, value: 10}, "\u200710%"],
    [{status: 1, value: 99.6}, "100%"],
    [{status: 1, value: 110}, "100%"]
];
for (const [sensor, expected] of cases) {
    const actual = context.paddedPercentage(sensor);
    if (actual !== expected || actual.length !== 4) process.exit(2);
}
NODE
"$NODE_BIN" - "$PLASMOID/contents/ui/main.qml" <<'NODE'
const fs = require("fs");
const vm = require("vm");
const source = fs.readFileSync(process.argv[2], "utf8");
const functions = source.match(/    function outputVolumePercentage\(\) \{[\s\S]*?\n    \}\n\n    function paddedOutputVolume\(\) \{[\s\S]*?\n    \}/);
if (!functions) process.exit(1);
const context = {
    Math,
    Number,
    root: {normalVolume: 65536},
    volumeAvailable: false,
    outputSink: {volume: 0}
};
vm.runInNewContext(functions[0].replace(/^    /gm, ""), context);
const cases = [
    [false, 0, "\u2007--%"],
    [true, 0, "\u2007\u20070%"],
    [true, 32768, "\u200750%"],
    [true, 65536, "100%"],
    [true, 98304, "150%"],
    [true, 9999999, "999%"]
];
for (const [available, volume, expected] of cases) {
    context.volumeAvailable = available;
    context.outputSink = {volume};
    const actual = context.paddedOutputVolume();
    if (actual !== expected || actual.length !== 4) process.exit(2);
}
NODE
if rg -n 'nvidia-smi|rocm-smi|daemon|python|shell' "$PLASMOID" >/dev/null; then
    fail "resource Plasmoid depends on an external monitor or status daemon"
fi
grep -Fxq '.local/share/plasma/layout-templates/org.kde.minimalist-v03' "$REPO_ROOT/config/managed-paths.txt" \
    || fail "v0.3 layout target is outside the managed allowlist"
grep -Fxq '.local/share/plasma/plasmoids/org.kde.minimalist.resources' "$REPO_ROOT/config/managed-paths.txt" \
    || fail "resource Plasmoid target is outside the managed allowlist"

"$NODE_BIN" - "$LAYOUT" <<'NODE'
const fs = require("fs");
const vm = require("vm");
const path = require("path");

const layoutRoot = process.argv[2];
const v02Types = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];
const v03Types = [
    "org.kde.plasma.kickoff",
    "org.kde.minimalist.activewindowtitle",
    "org.kde.plasma.panelspacer",
    "org.kde.minimalist.resources",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.digitalclock"
];

function assert(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

function assertClockPolicy(widget, label) {
    const expected = {
        showDate: false,
        showSeconds: 2,
        use24hFormat: 2,
        autoFontAndSize: true
    };
    for (const [key, value] of Object.entries(expected)) {
        assert(widget.config["Appearance:" + key] === value,
            label + ": clock " + key + " policy differs");
    }
}

function createPanel(types) {
    let nextId = 1;
    const widgets = types.map((type, index) => ({
        id: nextId++,
        type,
        geometry: {x: index * 100, y: 0, width: 80, height: 28},
        group: [],
        config: {},
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        writeConfig(key, value) { this.config[this.group.join("/") + ":" + key] = value; },
        readConfig(key, fallback) {
            const composite = this.group.join("/") + ":" + key;
            return Object.prototype.hasOwnProperty.call(this.config, composite)
                ? this.config[composite]
                : fallback;
        },
        reloadConfig() {}
    }));
    const panel = {
        id: 7,
        screen: 0,
        location: "top",
        formFactor: "horizontal",
        height: 28,
        lengthMode: "fill",
        hiding: "none",
        floating: false,
        opacity: "opaque",
        group: [],
        order: widgets.map(widget => String(widget.id)),
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            return key === "AppletOrder" ? this.order.join(";") : fallback;
        },
        widgets(type) {
            return type ? widgets.filter(widget => widget.type === type) : widgets.slice();
        },
        addWidget(type, x, y, width, height) {
            const widget = {
                id: nextId++, type,
                geometry: {x, y, width, height},
                group: [], config: {},
                get currentConfigGroup() { return this.group.slice(); },
                set currentConfigGroup(value) { this.group = value.slice(); },
                writeConfig(key, value) { this.config[this.group.join("/") + ":" + key] = value; },
                readConfig(key, fallback) {
                    const composite = this.group.join("/") + ":" + key;
                    return Object.prototype.hasOwnProperty.call(this.config, composite)
                        ? this.config[composite]
                        : fallback;
                },
                reloadConfig() {}
            };
            widgets.push(widget);
            const marginIndex = this.order.findIndex(id => {
                const existing = widgets.find(candidate => String(candidate.id) === id);
                return existing && existing.type === "org.kde.plasma.marginsseparator";
            });
            this.order.splice(marginIndex, 0, String(widget.id));
            return widget;
        }
    };
    return panel;
}

function run(name, panel, knownExtra = true) {
    const output = [];
    const known = Array.from(new Set(v03Types.concat([
        "org.kde.plasma.networkmanagement",
        "org.kde.plasma.volume",
        "org.kde.plasma.notifications"
    ])));
    if (!knownExtra) {
        known.splice(known.indexOf("org.kde.minimalist.resources"), 1);
    }
    const context = {
        panelIds: [panel.id],
        panelById: id => id === panel.id ? panel : null,
        knownWidgetTypes: known,
        print: value => output.push(String(value)),
        JSON, String, Number, Math, Array, Object, Error
    };
    vm.runInNewContext(fs.readFileSync(path.join(layoutRoot, "contents", name), "utf8"), context, {filename: name});
    return output.join("\n");
}

const panel = createPanel(v02Types);
assert(run("preflight.js", panel, false).includes("MINIMALIST_V03_PREFLIGHT_OK"),
    "exact v0.2 preflight was not accepted before resource installation");
assert(run("layout.js", panel).includes("transition=v0.2-to-v0.3"),
    "v0.2-to-v0.3 transition did not run");
assert(panel.height === 32, "legacy 28px v0.2 panel was not migrated to 32px");
assert(JSON.stringify(panel.order.map(id => panel.widgets().find(widget => String(widget.id) === id).type)) === JSON.stringify(v03Types),
    "resource widget was not inserted before the margin separator");
const resources = panel.widgets("org.kde.minimalist.resources");
assert(resources.length === 1, "resource transition did not create exactly one widget");
resources[0].currentConfigGroup = ["General"];
assert(String(resources[0].readConfig("packageRevision", 0)) === "2", "resource revision was not configured");
resources[0].currentConfigGroup = [];
const clock = panel.widgets("org.kde.plasma.digitalclock")[0];
assertClockPolicy(clock, "v0.3 transition");
assert(run("postcheck.js", panel).includes("MINIMALIST_V03_POSTCHECK_OK"),
    "v0.3 postcheck did not accept the exact target");
clock.config["Appearance:showSeconds"] = 1;
assert(!run("postcheck.js", panel).includes("MINIMALIST_V03_POSTCHECK_OK"),
    "v0.3 postcheck accepted seconds that are not always visible");
assert(run("layout.js", panel).includes("transition=already-target"),
    "v0.3 target is not idempotent");
assertClockPolicy(clock, "v0.3 clock repair");
clock.config["Appearance:showSeconds"] = "Always";
assert(run("postcheck.js", panel).includes("MINIMALIST_V03_POSTCHECK_OK"),
    "v0.3 postcheck rejected Plasma's canonical showSeconds enum name");
assert(panel.widgets("org.kde.minimalist.resources").length === 1,
    "idempotent v0.3 apply duplicated the resource widget");

const unknown = createPanel(v02Types.concat(["org.kde.plasma.showdesktop"]));
const before = unknown.order.join(";");
assert(!run("preflight.js", unknown).includes("MINIMALIST_V03_PREFLIGHT_OK"),
    "unknown topology passed v0.3 preflight");
let refused = false;
try {
    run("layout.js", unknown);
} catch (error) {
    refused = true;
}
assert(refused, "unknown topology was not refused by v0.3 layout");
assert(unknown.order.join(";") === before, "refused topology was mutated");
NODE

cat > "$MOCK_BIN/doctor" <<'EOF'
#!/usr/bin/env bash
printf 'mock doctor: supported\n'
exit "${MOCK_DOCTOR_STATUS:-0}"
EOF
chmod +x "$MOCK_BIN/doctor"

cat > "$MOCK_BIN/qdbus6" <<'EOF'
#!/usr/bin/env bash
script=${4:-}
if [[ $script == *MINIMALIST_V03_PREFLIGHT* ]]; then
    topology=${MOCK_PREFLIGHT_TOPOLOGY:-minimalist-v02}
    if [[ $topology == minimalist-v03 ]]; then resource_known=true; else resource_known=false; fi
    printf 'MINIMALIST_V03_PREFLIGHT panelCount=1 topology=%s height=28 geometryOk=true resourceKnown=%s widgets=mock\n' \
        "$topology" "$resource_known"
    printf '%s\n' ' MINIMALIST_V03_PREFLIGHT_OK'
elif [[ $script == *MINIMALIST_V03_RESOURCE_STRIP_OK* ]]; then
    printf '%s\n' 'MINIMALIST_V03_RESOURCE_STRIP_OK transition=v0.2-to-v0.3 id=7 added=true widgets=mock'
elif [[ $script == *MINIMALIST_V03_POSTCHECK* ]]; then
	    printf '%s\n' 'MINIMALIST_V03_POSTCHECK geometryOk=true topologyOk=true resourceOk=true clockOk=true widgets=mock'
    printf '%s\n' ' MINIMALIST_V03_POSTCHECK_OK'
else
    printf 'unexpected Plasma script\n' >&2
    exit 2
fi
EOF
chmod +x "$MOCK_BIN/qdbus6"

run_v03() {
    HOME="$TARGET_HOME" \
    XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" \
    XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$APPLY_SCRIPT" "$@"
}

run_v03 --dry-run > "$TEMP_ROOT/dry-run.txt"
grep -Fq 'panel removals: none' "$TEMP_ROOT/dry-run.txt" || fail "dry-run omits the zero-removal plan"
grep -Fq 'panel additions: one org.kde.minimalist.resources widget' "$TEMP_ROOT/dry-run.txt" \
    || fail "dry-run omits the exact widget addition"
grep -Fq 'panel height: 28 -> 32 logical px; preserve the existing panel instance' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omits the panel-height migration"
grep -Fq 'clock policy: date hidden; 24-hour time with seconds; automatic system font sizing' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omits the exact clock policy"
grep -Fq 'rollback apply:' "$TEMP_ROOT/dry-run.txt" || fail "dry-run omits rollback"
[[ ! -e $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources ]] \
    || fail "dry-run installed the resource Plasmoid"

MOCK_PREFLIGHT_TOPOLOGY=minimalist-v03 run_v03 --dry-run > "$TEMP_ROOT/dry-run-v03.txt"
grep -Fq 'current accepted topology: minimalist-v03' "$TEMP_ROOT/dry-run-v03.txt" \
    || fail "v0.3 dry-run omitted its actual source topology"
grep -Fq 'panel additions: none; preserve and reconfigure the existing org.kde.minimalist.resources widget' \
    "$TEMP_ROOT/dry-run-v03.txt" || fail "v0.3 reapply plan falsely reports a widget addition"

run_v03 --apply > "$TEMP_ROOT/apply.txt"
resource_target="$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources"
layout_target="$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v03"
diff -qr -- "$PLASMOID" "$resource_target" >/dev/null \
    || fail "installed resource Plasmoid differs from source"
diff -qr -- "$LAYOUT" "$layout_target" >/dev/null \
    || fail "installed v0.3 layout differs from source"
snapshot=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt" | tail -n 1)
[[ -d $snapshot && -f $snapshot/complete ]] || fail "v0.3 apply did not create a complete snapshot"
grep -Fq $'absent\t.local/share/plasma/layout-templates/org.kde.minimalist-v03' "$snapshot/state.tsv" \
    || fail "snapshot did not record the absent v0.3 layout"
grep -Fq $'absent\t.local/share/plasma/plasmoids/org.kde.minimalist.resources' "$snapshot/state.tsv" \
    || fail "snapshot did not record the absent resource Plasmoid"
grep -Fq 'MINIMALIST_V03_POSTCHECK_OK' "$TEMP_ROOT/apply.txt" \
    || fail "v0.3 apply did not report read-only postcheck success"

MOCK_PREFLIGHT_TOPOLOGY=minimalist-v03 run_v03 --apply > "$TEMP_ROOT/reapply-v03.txt"
grep -Fq 'Plasma may retain the already-running applet QML until the next user sign-in.' \
    "$TEMP_ROOT/reapply-v03.txt" || fail "v0.3 reapply omitted the live QML cache limitation"

printf 'PASS: Minimalist v0.3 resource-strip tests\n'
