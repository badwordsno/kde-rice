#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$SCRIPT_DIR/lib/runtime.sh"
require_test_node

TEMP_ROOT=$(mktemp -d /tmp/kde-rice-pager-preview.XXXXXX)
cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-pager-preview.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing unsafe cleanup: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

LAYOUT="$REPO_ROOT/layouts/plasma/org.kde.minimalist-v04"
PREFLIGHT="$LAYOUT/contents/pager-preflight.js"
WRITER="$LAYOUT/contents/pager-layout.js"
POSTCHECK="$LAYOUT/contents/pager-postcheck.js"
CLEANUP="$LAYOUT/contents/pager-cleanup.js"
APPLY_SCRIPT="$REPO_ROOT/scripts/apply-pager-preview"
TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
MOCK_PANEL_STATE="$TEMP_ROOT/panel-state"
MOCK_PREFLIGHT_COUNT="$TEMP_ROOT/preflight-count"
MOCK_KWIN_COUNT="$TEMP_ROOT/kwin-count"
MOCK_KWIN_QUERY_COUNT="$TEMP_ROOT/kwin-query-count"

[[ -x $APPLY_SCRIPT ]] || fail "Pager-preview entry point is not executable"
bash -n "$APPLY_SCRIPT"
for script in "$PREFLIGHT" "$WRITER" "$POSTCHECK" "$CLEANUP"; do
    "$NODE_BIN" --check "$script" >/dev/null
done
if rg -n 'writeConfig\("AppletOrder"|\.index[[:space:]]*=' "$WRITER" >/dev/null; then
    fail "Pager writer relies on an ineffective live AppletOrder/index rewrite"
fi
grep -Fq 'panel.addWidget(' "$WRITER" || fail "Pager writer does not use geometry insertion"
for expected_write in \
    'pager.writeConfig("displayedText", 0);' \
    'pager.writeConfig("showWindowOutlines", false);' \
    'pager.writeConfig("showWindowIcons", false);'; do
    grep -Fq "$expected_write" "$WRITER" || fail "missing Pager policy: $expected_write"
done
grep -Fq 'String(displayedText) === "Number"' "$POSTCHECK" \
    || fail "Pager postcheck omits canonical Number enum compatibility"

"$NODE_BIN" - "$PREFLIGHT" "$WRITER" "$POSTCHECK" "$CLEANUP" <<'NODE'
const fs = require("fs");
const vm = require("vm");
const sources = process.argv.slice(2).map(path => fs.readFileSync(path, "utf8"));
const baseTypes = [
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

function assert(condition, message) {
    if (!condition) throw new Error(message);
}

function makeWidget(type, id, x) {
    return {
        id, type,
        geometry: {x, y: 0, width: type === "org.kde.plasma.kickoff" ? 24 : 80, height: 28},
        group: [], config: {"General:userSetting": "preserve-" + id}, writes: [],
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            const composite = this.group.join("/") + ":" + key;
            return Object.prototype.hasOwnProperty.call(this.config, composite)
                ? this.config[composite] : fallback;
        },
        writeConfig(key, value) {
            const composite = this.group.join("/") + ":" + key;
            this.config[composite] = value;
            this.writes.push(composite);
        },
        reloadConfig() {},
        remove() {
            const index = this.panel.items.indexOf(this);
            if (index >= 0) this.panel.items.splice(index, 1);
            this.panel.order = this.panel.order.filter(idValue => idValue !== String(this.id));
        }
    };
}

function makePanel() {
    const items = baseTypes.map((type, index) => makeWidget(type, index + 1, index === 0 ? 5 : 33 + index * 90));
    const panel = {
        id: 17, screen: 0, location: "top", formFactor: "horizontal", height: 32,
        lengthMode: "fill", hiding: "none", floating: false, opacity: "opaque",
        group: [], items, order: items.map(widget => String(widget.id)),
        get currentConfigGroup() { return this.group.slice(); },
        set currentConfigGroup(value) { this.group = value.slice(); },
        readConfig(key, fallback) {
            return this.group.join("/") === "General" && key === "AppletOrder"
                ? this.order.join(";") : fallback;
        },
        widgets() { return this.items.slice(); },
        addWidget(type, x, y, width, height) {
            const widget = makeWidget(type, 99, x);
            widget.geometry = {x, y, width, height};
            widget.panel = this;
            this.items.splice(1, 0, widget);
            this.order.splice(1, 0, String(widget.id));
            return widget;
        }
    };
    items.forEach(widget => { widget.panel = panel; });
    return panel;
}

function run(source, panel) {
    const output = [];
    vm.runInNewContext(source, {
        panelIds: [panel.id], panelById: id => id === panel.id ? panel : null,
        knownWidgetTypes: baseTypes.concat(["org.kde.plasma.pager"]),
        print: value => output.push(String(value)),
        JSON, String, Number, Array, Object, Error
    });
    return output.join("\n");
}

function digest(panel) {
    return JSON.stringify({
        order: panel.order,
        widgets: panel.items.map(widget => ({id: widget.id, type: widget.type, config: widget.config})),
        geometry: [panel.screen, panel.location, panel.formFactor, panel.height, panel.lengthMode,
            panel.hiding, panel.floating, panel.opacity]
    });
}

const panel = makePanel();
const baseDigest = digest(panel);
assert(run(sources[0], panel).includes("topology=minimalist-v04"), "base preflight failed");
assert(run(sources[1], panel).includes("MINIMALIST_PAGER_LAYOUT_OK"), "Pager writer failed");
assert(panel.items[1].type === "org.kde.plasma.pager", "Pager was not inserted after launcher");
assert(panel.items.slice(0, 1).concat(panel.items.slice(2)).map(widget => widget.type).join("|")
    === baseTypes.join("|"), "existing widget order changed");
const pager = panel.items[1];
assert(JSON.stringify(pager.writes) === JSON.stringify([
    "General:displayedText", "General:showWindowOutlines", "General:showWindowIcons"
]), "Pager writer touched keys outside its three-key policy");
assert(pager.config["General:displayedText"] === 0
    && pager.config["General:showWindowOutlines"] === false
    && pager.config["General:showWindowIcons"] === false, "wrong Pager policy");
assert(run(sources[2], panel).includes("MINIMALIST_PAGER_POSTCHECK_OK"), "Pager postcheck failed");
const postDigest = digest(panel);
run(sources[2], panel);
assert(digest(panel) === postDigest, "Pager postcheck was not read-only");

pager.config["General:displayedText"] = "Number";
assert(run(sources[2], panel).includes("MINIMALIST_PAGER_POSTCHECK_OK"),
    "Pager postcheck rejected canonical Number enum");
pager.config["General:displayedText"] = "None";
assert(!run(sources[2], panel).includes("MINIMALIST_PAGER_POSTCHECK_OK"),
    "Pager postcheck accepted hidden numbers");
pager.config["General:displayedText"] = 0;

assert(run(sources[3], panel).includes("transition=remove-pager"), "Pager cleanup failed");
assert(digest(panel) === baseDigest, "Pager cleanup changed the preserved base panel");

const wrong = makePanel();
wrong.items[4].type = "org.example.foreign";
const wrongBefore = digest(wrong);
let refused = false;
try { run(sources[1], wrong); } catch (error) { refused = true; }
assert(refused && digest(wrong) === wrongBefore, "wrong topology was not refused before mutation");

const unsafeCleanup = makePanel();
run(sources[1], unsafeCleanup);
unsafeCleanup.items.push(makeWidget("org.example.foreign", 123, 900));
unsafeCleanup.items[unsafeCleanup.items.length - 1].panel = unsafeCleanup;
unsafeCleanup.order.push("123");
const unsafeBefore = digest(unsafeCleanup);
refused = false;
try { run(sources[3], unsafeCleanup); } catch (error) { refused = true; }
assert(refused && digest(unsafeCleanup) === unsafeBefore,
    "cleanup removed a widget from an unknown concurrent topology");
NODE

mkdir -p -- "$TARGET_HOME/.config" \
    "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents" \
    "$TARGET_HOME/.local/state" "$MOCK_BIN"
printf 'baseline panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'baseline kwin config\n' > "$TARGET_HOME/.config/kwinrc"
printf 'old layout\n' > "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/contents/old.txt"
printf 'minimalist-v04\n' > "$MOCK_PANEL_STATE"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
printf '1\n' > "$MOCK_KWIN_COUNT"
printf '0\n' > "$MOCK_KWIN_QUERY_COUNT"

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
state=$(< "${MOCK_PANEL_STATE:?}")
if [[ $script == *MINIMALIST_PAGER_PREFLIGHT* ]]; then
    count=$(( $(< "${MOCK_PREFLIGHT_COUNT:?}") + 1 ))
    printf '%s\n' "$count" > "$MOCK_PREFLIGHT_COUNT"
    if [[ ${MOCK_PANEL_TOCTOU:-false} == true && $count -gt 1 ]]; then state=unknown; fi
    printf 'MINIMALIST_PAGER_PREFLIGHT panelCount=1 topology=%s height=32 geometryOk=true anchorReady=true pagerKnown=true widgets=mock\n' "$state"
    [[ $state == minimalist-v04 || $state == minimalist-v04-pager ]] \
        && printf '%s\n' ' MINIMALIST_PAGER_PREFLIGHT_OK'
elif [[ $script == *MINIMALIST_PAGER_LAYOUT_OK* ]]; then
    snapshot_complete=false
    shopt -s nullglob
    for complete in "${MOCK_TARGET_HOME:?}/.local/state/kde-rice/snapshots/"*/complete; do
        [[ -f $complete ]] && snapshot_complete=true
    done
    $snapshot_complete || { printf 'Pager ran before snapshot\n' >&2; exit 70; }
    printf 'minimalist-v04-pager\n' > "$MOCK_PANEL_STATE"
    printf 'Pager applied\n' > "${MOCK_APPLETSRC:?}"
    printf 'MINIMALIST_PAGER_LAYOUT_OK transition=add-pager-after-launcher panelId=17 pagerId=99\n'
elif [[ $script == *MINIMALIST_PAGER_POSTCHECK* ]]; then
    if [[ ${MOCK_POSTCHECK_FAIL:-false} == true ]]; then
        printf 'MINIMALIST_PAGER_POSTCHECK panelCount=1 topologyOk=false geometryOk=true pagerOk=false widgets=mock\n'
    else
        printf 'MINIMALIST_PAGER_POSTCHECK panelCount=1 topologyOk=true geometryOk=true pagerOk=true widgets=mock\n'
        printf '%s\n' ' MINIMALIST_PAGER_POSTCHECK_OK'
    fi
elif [[ $script == *MINIMALIST_PAGER_CLEANUP_OK* ]]; then
    if [[ $state == minimalist-v04-pager ]]; then
        printf 'minimalist-v04\n' > "$MOCK_PANEL_STATE"
        printf 'MINIMALIST_PAGER_CLEANUP_OK transition=remove-pager pagerId=99\n'
    else
        printf 'MINIMALIST_PAGER_CLEANUP_OK transition=already-base\n'
    fi
else
    printf 'unexpected Plasma script\n' >&2
    exit 2
fi
MOCK

cat > "$MOCK_BIN/busctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
args=" $* "
count=$(< "${MOCK_KWIN_COUNT:?}")
desktops_json() {
    case "$1" in
        1) printf '%s\n' '{"type":"a(uss)","data":[[0,"desktop-1","Desktop 1"]]}' ;;
        2) printf '%s\n' '{"type":"a(uss)","data":[[0,"desktop-1","Desktop 1"],[1,"desktop-2","2"]]}' ;;
        3) printf '%s\n' '{"type":"a(uss)","data":[[0,"desktop-1","Desktop 1"],[1,"desktop-2","2"],[2,"desktop-3","3"]]}' ;;
        4) printf '%s\n' '{"type":"a(uss)","data":[[0,"desktop-1","Desktop 1"],[1,"desktop-2","2"],[2,"desktop-3","3"],[3,"desktop-4","4"]]}' ;;
    esac
}
if [[ $args == *' get-property '* ]]; then
    property=${!#}
    if [[ $property == count ]]; then
        query=$(( $(< "${MOCK_KWIN_QUERY_COUNT:?}") + 1 ))
        printf '%s\n' "$query" > "$MOCK_KWIN_QUERY_COUNT"
        if [[ ${MOCK_KWIN_TOCTOU:-false} == true && $query -gt 1 && $count == 1 ]]; then
            printf '%s\n' '{"type":"u","data":2}'
        else
            printf '{"type":"u","data":%s}\n' "$count"
        fi
    elif [[ $property == rows ]]; then
        printf '%s\n' '{"type":"u","data":1}'
    elif [[ $property == desktops ]]; then
        desktops_json "$count"
    else
        exit 2
    fi
elif [[ $args == *' createDesktop '* ]]; then
    snapshot_complete=false
    shopt -s nullglob
    for complete in "${MOCK_TARGET_HOME:?}/.local/state/kde-rice/snapshots/"*/complete; do
        [[ -f $complete ]] && snapshot_complete=true
    done
    $snapshot_complete || { printf 'desktop created before snapshot\n' >&2; exit 70; }
    count=$((count + 1))
    printf '%s\n' "$count" > "$MOCK_KWIN_COUNT"
    printf '{"type":"s","data":["desktop-%s"]}\n' "$count"
elif [[ $args == *' setDesktopName '* ]]; then
    printf '%s\n' 's ""'
elif [[ $args == *' removeDesktop '* ]]; then
    ((count > 1)) || exit 2
    count=$((count - 1))
    printf '%s\n' "$count" > "$MOCK_KWIN_COUNT"
    printf '%s\n' 's ""'
else
    exit 2
fi
MOCK

cat > "$MOCK_BIN/verify" <<'MOCK'
#!/usr/bin/env bash
[[ $* == *'--panel-target minimalist-v04-pager'* ]] || exit 2
if [[ ${MOCK_VERIFY_FAIL:-false} == true ]]; then
    printf '%s\n' '{"schema_version":1,"status":"mismatch","checks":[{"name":"pager_policy","ok":false}]}'
    exit 1
fi
printf '%s\n' '{"schema_version":1,"status":"mismatch","checks":[{"name":"pager_policy","ok":true},{"name":"virtual_desktop_count","ok":true},{"name":"display_configuration_unchanged","ok":false}]}'
exit 1
MOCK
chmod +x "$MOCK_BIN/doctor" "$MOCK_BIN/qdbus6" "$MOCK_BIN/busctl" "$MOCK_BIN/verify"

run_pager() {
    HOME="$TARGET_HOME" \
    XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    XDG_DATA_HOME="$TARGET_HOME/.local/share" \
    XDG_STATE_HOME="$TARGET_HOME/.local/state" \
    KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DOCTOR_COMMAND="$MOCK_BIN/doctor" \
    KDE_RICE_VERIFY_COMMAND="$MOCK_BIN/verify" \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    KDE_RICE_KWIN_BUSCTL="$MOCK_BIN/busctl" \
    MOCK_TARGET_HOME="$TARGET_HOME" \
    MOCK_APPLETSRC="$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
    MOCK_PANEL_STATE="$MOCK_PANEL_STATE" \
    MOCK_PREFLIGHT_COUNT="$MOCK_PREFLIGHT_COUNT" \
    MOCK_KWIN_COUNT="$MOCK_KWIN_COUNT" \
    MOCK_KWIN_QUERY_COUNT="$MOCK_KWIN_QUERY_COUNT" \
    "$APPLY_SCRIPT" "$@"
}

run_pager --dry-run > "$TEMP_ROOT/dry-run.txt"
grep -Fq 'current accepted topology: minimalist-v04 on one screen-0 top panel at 32 logical px' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted exact current topology"
grep -Fq 'virtual desktop additions: exactly three' "$TEMP_ROOT/dry-run.txt" \
    || fail "dry-run omitted desktop additions"
grep -Fq 'panel additions: one built-in org.kde.plasma.pager after the launcher' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted Pager placement"
grep -Fq 'managed configs that may change: .config/kwinrc; .config/plasma-org.kde.plasma.desktop-appletsrc' \
    "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted exact managed config targets"
grep -Fq 'panel removals: none' "$TEMP_ROOT/dry-run.txt" || fail "dry-run omitted zero removals"
[[ $(< "$MOCK_KWIN_COUNT") == 1 ]] || fail "dry-run changed virtual desktops"
[[ $(< "$MOCK_PANEL_STATE") == minimalist-v04 ]] || fail "dry-run changed panel"
[[ ! -d $TARGET_HOME/.local/state/kde-rice ]] || fail "dry-run created transaction state"

set +e
MOCK_DOCTOR_STATUS=2 run_pager --dry-run > "$TEMP_ROOT/unsupported.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "unsupported diagnosis was not refused"

printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
printf '0\n' > "$MOCK_KWIN_QUERY_COUNT"
set +e
MOCK_PANEL_TOCTOU=true run_pager --apply > "$TEMP_ROOT/toctou.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "panel TOCTOU change was not refused"
grep -Fq 'pre-apply managed files were restored automatically' "$TEMP_ROOT/toctou.txt" \
    || fail "TOCTOU refusal did not restore snapshot"
mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/toctou-state"

printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
printf '0\n' > "$MOCK_KWIN_QUERY_COUNT"
run_pager --apply > "$TEMP_ROOT/apply.txt" 2>&1
[[ $(< "$MOCK_KWIN_COUNT") == 4 ]] || fail "apply did not create four desktops"
[[ $(< "$MOCK_PANEL_STATE") == minimalist-v04-pager ]] || fail "apply did not create Pager target"
grep -Fq 'MINIMALIST_PAGER_POSTCHECK_OK' "$TEMP_ROOT/apply.txt" || fail "postcheck success missing"
grep -Fq 'pre-existing out-of-scope display fingerprint mismatch' "$TEMP_ROOT/apply.txt" \
    || fail "known display mismatch was not reported"
snapshot=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt" | tail -n 1)
[[ -f $snapshot/complete ]] || fail "complete snapshot missing"
cmp -- "$REPO_ROOT/config/managed-paths.txt" "$snapshot/managed-paths.txt" >/dev/null \
    || fail "snapshot did not capture complete exact manifest"
grep -Fq $'file\t.config/kwinrc' "$snapshot/state.tsv" || fail "snapshot omitted kwinrc"
grep -Fq $'file\t.config/plasma-org.kde.plasma.desktop-appletsrc' "$snapshot/state.tsv" \
    || fail "snapshot omitted panel config"

mv -- "$TARGET_HOME/.local/state/kde-rice" "$TEMP_ROOT/success-state"
printf 'minimalist-v04\n' > "$MOCK_PANEL_STATE"
printf '1\n' > "$MOCK_KWIN_COUNT"
printf '0\n' > "$MOCK_PREFLIGHT_COUNT"
printf '0\n' > "$MOCK_KWIN_QUERY_COUNT"
printf 'pre-failure panel config\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'pre-failure kwin config\n' > "$TARGET_HOME/.config/kwinrc"
set +e
MOCK_POSTCHECK_FAIL=true run_pager --apply > "$TEMP_ROOT/postcheck-fail.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "Pager postcheck failure did not fail apply"
[[ $(< "$MOCK_PANEL_STATE") == minimalist-v04 ]] || fail "failure did not remove transaction Pager"
[[ $(< "$MOCK_KWIN_COUNT") == 1 ]] || fail "failure did not remove transaction desktops"
[[ $(< "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == 'pre-failure panel config' ]] \
    || fail "failure did not restore panel config"
[[ $(< "$TARGET_HOME/.config/kwinrc") == 'pre-failure kwin config' ]] \
    || fail "failure did not restore kwinrc"

printf 'PASS: guarded Minimalist Pager-preview tests\n'
