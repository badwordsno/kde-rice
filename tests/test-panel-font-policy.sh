#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$SCRIPT_DIR/lib/runtime.sh"
require_test_node

TEMP_ROOT=$(mktemp -d /tmp/kde-rice-panel-font.XXXXXX)
cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-panel-font.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing unsafe cleanup: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v04"
PREFLIGHT="$LAYOUT/contents/font-preflight.js"
WRITER="$LAYOUT/contents/font-layout.js"
POSTCHECK="$LAYOUT/contents/font-postcheck.js"
RESTORE="$LAYOUT/contents/font-restore.js"
APPLY_SCRIPT="$REPO_ROOT/scripts/apply-panel-font-policy"
TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
MOCK_STATE="$TEMP_ROOT/font-state"
MOCK_PREFLIGHT_COUNT="$TEMP_ROOT/preflight-count"

[[ -x $APPLY_SCRIPT ]] || fail "panel-font entry point is not executable"
bash -n "$APPLY_SCRIPT"
for script in "$PREFLIGHT" "$WRITER" "$POSTCHECK" "$RESTORE"; do
    "$NODE_BIN" --check "$script" >/dev/null
done
grep -Fq 'font.family: "Noto Sans"' \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle/contents/ui/main.qml" \
    || fail "active-title font differs"
grep -Fq 'metricsFontFamily: "Noto Sans"' \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.resources/contents/ui/main.qml" \
    || fail "resource font differs"
grep -Fq 'font.family: "Noto Sans"' \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.workspaces/contents/ui/main.qml" \
    || fail "Workspaces font differs"
if rg -n 'writeConfig\("AppletOrder"|\.index[[:space:]]*=' "$WRITER" "$RESTORE" >/dev/null; then
    fail "font transaction uses an ineffective live order rewrite"
fi

"$NODE_BIN" - "$PREFLIGHT" "$WRITER" "$POSTCHECK" "$RESTORE" <<'NODE'
const fs = require("fs");
const vm = require("vm");
const sources = process.argv.slice(2).map(path => fs.readFileSync(path, "utf8"));
const activeType = "org.kde.minimalist.activewindowtitle";
const workspaceType = "org.kde.minimalist.workspaces";
const resourceType = "org.kde.minimalist.resources";
const clockType = "org.kde.plasma.digitalclock";
const types = [
    "org.kde.plasma.kickoff", workspaceType, activeType,
    "org.kde.plasma.panelspacer", "org.kde.plasma.icontasks",
    "org.kde.plasma.panelspacer", resourceType,
    "org.kde.plasma.marginsseparator", "org.kde.plasma.kimpanel",
    "org.kde.plasma.systemtray", clockType
];
function assert(value, message) { if (!value) throw new Error(message); }
function widget(type, id, x) {
    const config = {"General:userSetting": "preserve-" + id};
    if (type === activeType) config["General:packageRevision"] = 1;
    if (type === workspaceType || type === resourceType) config["General:packageRevision"] = 2;
    if ([activeType, workspaceType, resourceType].includes(type)) {
        config["General:fontPolicyRevision"] = 1;
    }
    if (type === clockType) Object.assign(config, {
        "Appearance:fontFamily": "Noto Sans Mono", "Appearance:autoFontAndSize": false,
        "Appearance:fontSize": 11, "Appearance:fontStyleName": "Regular",
        "Appearance:fontWeight": 400
    });
    return {
        id, type, geometry: {x, y: 0, width: 60, height: 28}, group: [], config, writes: [],
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            const name = this.group.join("/") + ":" + key;
            return Object.prototype.hasOwnProperty.call(this.config, name) ? this.config[name] : fallback;
        },
        writeConfig(key, value) {
            const name = this.group.join("/") + ":" + key;
            this.config[name] = value; this.writes.push(name);
        },
        reloadConfig() {},
        remove() {
            this.panel.items = this.panel.items.filter(item => item !== this);
            this.panel.order = this.panel.order.filter(idValue => idValue !== String(this.id));
        }
    };
}
function panel() {
    const items = types.map((type, index) => widget(type, index + 1, index * 100 + 5));
    const result = {
        id: 29, screen: 0, location: "top", formFactor: "horizontal", height: 32,
        lengthMode: "fill", hiding: "none", floating: false, opacity: "opaque",
        items, order: items.map(item => String(item.id)), group: [], nextId: 100,
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            return this.group.join("/") === "General" && key === "AppletOrder"
                ? this.order.join(";") : fallback;
        },
        widgets() { return this.items.slice(); },
        addWidget(type, x, y, width, height) {
            const item = widget(type, this.nextId++, x);
            item.geometry = {x, y, width, height}; item.panel = this;
            let insert = this.items.findIndex(existing => existing.geometry.x > x);
            if (insert < 0) insert = this.items.length;
            this.items.splice(insert, 0, item); this.order.splice(insert, 0, String(item.id));
            return item;
        }
    };
    items.forEach(item => { item.panel = result; });
    return result;
}
function run(source, value) {
    const output = [];
    vm.runInNewContext(source, {
        panelIds: [value.id], panelById: id => id === value.id ? value : null,
        knownWidgetTypes: types.slice(), print: text => output.push(String(text)),
        JSON, String, Number, Array, Object, Error
    });
    return output.join("\n");
}
function preserved(value) {
    return JSON.stringify(value.items.filter(item => ![activeType, workspaceType, resourceType].includes(item.type))
        .map(item => ({id: item.id, type: item.type, config: item.config})));
}
const value = panel();
const preservedBefore = preserved(value);
const idsBefore = value.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type)).map(item => item.id);
assert(run(sources[0], value).includes("fontState=source"), "source preflight failed");
assert(run(sources[1], value).includes("transition=refresh-project-widgets"), "writer did not refresh widgets");
assert(value.items.map(item => item.type).join("|") === types.join("|"), "writer changed widget order");
const custom = value.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type));
assert(custom.every(item => !idsBefore.includes(item.id)), "writer reused a stale component");
assert(custom.every(item => item.config["General:fontPolicyRevision"] === 2), "font revision missing");
assert(value.items.find(item => item.type === clockType).config["Appearance:fontFamily"] === "Noto Sans",
    "clock family differs");
assert(preserved(value) !== preservedBefore,
    "clock was expected to be the only preserved widget with a managed change");
assert(run(sources[2], value).includes("MINIMALIST_FONT_POSTCHECK_OK"), "postcheck failed");
const targetIds = custom.map(item => item.id);
assert(run(sources[1], value).includes("transition=already-target"), "target reapply failed");
assert(JSON.stringify(value.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type)).map(item => item.id))
    === JSON.stringify(targetIds), "target reapply replaced widgets");
assert(run(sources[3], value).includes("MINIMALIST_FONT_RESTORE_OK"), "restore failed");
assert(value.items.map(item => item.type).join("|") === types.join("|"), "restore changed widget order");
assert(value.items.filter(item => [activeType, workspaceType, resourceType].includes(item.type))
    .every(item => item.config["General:fontPolicyRevision"] === 1), "restore revision differs");
assert(value.items.find(item => item.type === clockType).config["Appearance:fontFamily"] === "Noto Sans Mono",
    "restore clock family differs");
const unsafe = panel(); unsafe.items[4].type = "org.example.foreign";
let refused = false; try { run(sources[1], unsafe); } catch (error) { refused = true; }
assert(refused, "unknown topology was accepted");
NODE

mkdir -p -- "$TARGET_HOME/.config" "$TARGET_HOME/.local/state" "$MOCK_BIN" \
    "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources"
printf 'baseline panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'old layout\n' > "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt"
for package in org.kde.minimalist.activewindowtitle org.kde.minimalist.workspaces org.kde.minimalist.resources; do
    printf 'old %s\n' "$package" > "$TARGET_HOME/.local/share/plasma/plasmoids/$package/old.txt"
done
printf 'source\n' > "$MOCK_STATE"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"

cat > "$MOCK_BIN/doctor" <<'MOCK'
#!/usr/bin/env bash
[[ $# == 2 && $1 == --target && $2 == minimalist-v04 ]] || exit 64
printf 'mock doctor status=%s\n' "${MOCK_DOCTOR_STATUS:-0}"
exit "${MOCK_DOCTOR_STATUS:-0}"
MOCK
cat > "$MOCK_BIN/qdbus6" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
script=${4:-}
state=$(< "${MOCK_FONT_STATE:?}")
if [[ $script == *MINIMALIST_FONT_PREFLIGHT* ]]; then
    count=$(( $(< "${MOCK_PREFLIGHT_COUNT:?}") + 1 ))
    printf '%s\n' "$count" > "$MOCK_PREFLIGHT_COUNT"
    [[ ${MOCK_TOCTOU_FAIL:-false} != true || $count -le 1 ]] || state=unknown
    if [[ $state == source ]]; then revisions='1 1 1'; family=Noto_Sans_Mono; else revisions='2 2 2'; family=Noto_Sans; fi
    read -r active workspace resource <<< "$revisions"
    printf 'MINIMALIST_FONT_PREFLIGHT panelCount=1 topologyOk=true geometryOk=true anchorsReady=true customTypesKnown=true fontState=%s activeRevision=1 workspaceRevision=2 resourceRevision=2 activeFontRevision=%s workspaceFontRevision=%s resourceFontRevision=%s clockFontFamily=%s widgets=mock\n' \
        "$state" "$active" "$workspace" "$resource" "$family"
    [[ $state == source || $state == target ]] && printf '%s\n' ' MINIMALIST_FONT_PREFLIGHT_OK'
elif [[ $script == *MINIMALIST_FONT_LAYOUT_OK* ]]; then
    shopt -s nullglob
    complete=("${MOCK_TARGET_HOME:?}/.local/state/kde-rice/snapshots/"*/complete)
    ((${#complete[@]} > 0)) || exit 70
    printf 'target\n' > "$MOCK_FONT_STATE"
    printf 'font policy applied\n' > "${MOCK_APPLETSRC:?}"
    printf 'MINIMALIST_FONT_LAYOUT_OK transition=refresh-project-widgets panelId=29 workspaceId=100 activeTitleId=101 resourceId=102 clockId=61\n'
elif [[ $script == *MINIMALIST_FONT_POSTCHECK* ]]; then
    if [[ ${MOCK_POSTCHECK_FAIL:-false} == true ]]; then
        printf 'MINIMALIST_FONT_POSTCHECK topologyOk=true geometryOk=true projectWidgetsOk=false clockOk=true widgets=mock\n'
    else
        printf 'MINIMALIST_FONT_POSTCHECK topologyOk=true geometryOk=true projectWidgetsOk=true clockOk=true widgets=mock\n'
        printf '%s\n' ' MINIMALIST_FONT_POSTCHECK_OK'
    fi
elif [[ $script == *MINIMALIST_FONT_RESTORE_OK* ]]; then
    printf 'source\n' > "$MOCK_FONT_STATE"
    printf 'MINIMALIST_FONT_RESTORE_OK workspaceId=200 activeTitleId=201 resourceId=202 clockId=61\n'
else
    exit 2
fi
MOCK
cat > "$MOCK_BIN/verify" <<'MOCK'
#!/usr/bin/env bash
[[ $* == *'--panel-target minimalist-v04-workspaces'* ]] || exit 2
printf '%s\n' '{"schema_version":1,"status":"mismatch","checks":[{"name":"panel_topology","ok":true},{"name":"display_configuration_unchanged","ok":false}]}'
exit 1
MOCK
chmod +x "$MOCK_BIN/doctor" "$MOCK_BIN/qdbus6" "$MOCK_BIN/verify"

run_policy() {
    HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    KDE_RICE_TEST_MODE=1 KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    KDE_RICE_VERIFY_COMMAND="$MOCK_BIN/verify" KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    KDE_RICE_FONT_MATCH='Noto Sans' MOCK_TARGET_HOME="$TARGET_HOME" \
    MOCK_APPLETSRC="$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
    MOCK_FONT_STATE="$MOCK_STATE" MOCK_PREFLIGHT_COUNT="$MOCK_PREFLIGHT_COUNT" \
    "$APPLY_SCRIPT" "$@"
}

run_policy --dry-run > "$TEMP_ROOT/dry-run.txt"
grep -Fq 'selected Fedora family: Noto Sans' "$TEMP_ROOT/dry-run.txt" || fail "plan omitted font"
grep -Fq 'panel removals: exactly one active-title, one Workspaces, and one resource' \
    "$TEMP_ROOT/dry-run.txt" || fail "plan omitted exact removals"
[[ $(< "$MOCK_STATE") == source ]] || fail "dry-run changed live state"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "dry-run created transaction state"

run_policy --apply > "$TEMP_ROOT/apply.txt"
[[ $(< "$MOCK_STATE") == target ]] || fail "apply did not reach target"
for pair in \
    "plasmoids/org.kde.minimalist.activewindowtitle .local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle" \
    "plasmoids/org.kde.minimalist.workspaces .local/share/plasma/plasmoids/org.kde.minimalist.workspaces" \
    "plasmoids/org.kde.minimalist.resources .local/share/plasma/plasmoids/org.kde.minimalist.resources"; do
    read -r source target <<< "$pair"
    diff -qr -- "$REPO_ROOT/$source" "$TARGET_HOME/$target" >/dev/null || fail "installed package differs: $target"
done
grep -Fq 'MINIMALIST_FONT_POSTCHECK_OK' "$TEMP_ROOT/apply.txt" || fail "postcheck marker missing"
snapshot=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt" | tail -n 1)
[[ -f $snapshot/complete ]] || fail "complete snapshot missing"

if [[ -d $TARGET_HOME/.local/state/kde-rice ]]; then
    mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/success-state"
fi
for package in org.kde.minimalist.activewindowtitle org.kde.minimalist.workspaces org.kde.minimalist.resources; do
    rm -rf -- "$TARGET_HOME/.local/share/plasma/plasmoids/$package"
    mkdir -p -- "$TARGET_HOME/.local/share/plasma/plasmoids/$package"
    printf 'old %s\n' "$package" > "$TARGET_HOME/.local/share/plasma/plasmoids/$package/old.txt"
done
rm -rf -- "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04"
mkdir -p -- "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents"
printf 'old layout again\n' > "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt"
printf 'pre-failure panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'source\n' > "$MOCK_STATE"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
set +e
MOCK_POSTCHECK_FAIL=true run_policy --apply > "$TEMP_ROOT/failure.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "failed postcheck did not fail transaction"
[[ $(< "$MOCK_STATE") == source ]] || fail "failure did not reload source live"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'pre-failure panel config' ]] \
    || fail "failure did not restore panel config"
for package in org.kde.minimalist.activewindowtitle org.kde.minimalist.workspaces org.kde.minimalist.resources; do
    [[ -f $TARGET_HOME/.local/share/plasma/plasmoids/$package/old.txt ]] || fail "failure did not restore $package"
done
grep -Fq 'the three snapshotted project packages and prior clock family were reloaded live' \
    "$TEMP_ROOT/failure.txt" || fail "failure omitted live reload confirmation"

printf 'PASS: guarded Noto Sans panel-font policy tests\n'
