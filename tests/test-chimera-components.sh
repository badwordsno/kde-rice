#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$TEST_DIR/lib/runtime.sh"
require_test_node
require_test_qmllint

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

SYNC="$REPO_ROOT/scripts/sync-chimera-components"
CANONICAL="$REPO_ROOT/design/chimera"
CATALOG="$REPO_ROOT/research/chimera-components.json"
packages=(
    org.kde.minimalist.activewindowtitle
    org.kde.minimalist.resources
    org.kde.minimalist.workspaces
)
components=(ChimeraFrame.qml ChimeraTokens.qml)

for command_name in cmp diff find jq kpackagetool6 xmllint; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "required Chimera test tool is unavailable: $command_name"
done

TEMP_ROOT=$(mktemp -d /tmp/kde-rice-chimera-components.XXXXXX)
cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-chimera-components.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing unsafe cleanup: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT
TARGET_HOME="$TEMP_ROOT/home"
TARGET_RUNTIME="$TEMP_ROOT/runtime"
mkdir -p -- "$TARGET_HOME/.config" "$TARGET_HOME/.local/share" \
    "$TARGET_HOME/.cache" "$TARGET_RUNTIME"
chmod 700 "$TARGET_RUNTIME"

[[ -x $SYNC && ! -L $SYNC ]] || fail "Chimera sync command is unavailable"
bash -n "$SYNC"
"$SYNC" --check >/dev/null || fail "package-local Chimera components are stale"

for package in "${packages[@]}"; do
    package_root="$REPO_ROOT/plasmoids/$package"
    [[ -d $package_root && ! -L $package_root ]] || fail "unsafe package root: $package"
    jq -e --arg package "$package" \
        '.KPackageStructure == "Plasma/Applet"
            and .KPlugin.Id == $package
            and .KPlugin.License == "MIT"
            and ."X-Plasma-API-Minimum-Version" == "6.0"' \
        "$package_root/metadata.json" >/dev/null \
        || fail "invalid Chimera package metadata: $package"
    xmllint --noout "$package_root/contents/config/main.xml" \
        || fail "invalid KConfig XML: $package"

    for component in "${components[@]}"; do
        cmp -s -- "$CANONICAL/$component" \
            "$package_root/contents/ui/chimera/$component" \
            || fail "component drift in $package: $component"
    done

    while IFS= read -r -d '' qml_file; do
        "$QMLLINT_BIN" -I "$QML_IMPORT_ROOT" "$qml_file" \
            || fail "QML validation failed: ${qml_file#"$REPO_ROOT/"}"
    done < <(find "$package_root" -type f -name '*.qml' -print0)
done

for qml_file in "$CANONICAL"/*.qml; do
    "$QMLLINT_BIN" -I "$QML_IMPORT_ROOT" "$qml_file" \
        || fail "canonical Chimera QML validation failed"
done

for package in "${packages[@]}"; do
    package_root="$REPO_ROOT/plasmoids/$package"
    env -i HOME="$TARGET_HOME" PATH="$PATH" LC_ALL=C TZ=UTC \
        XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        XDG_DATA_HOME="$TARGET_HOME/.local/share" \
        XDG_CACHE_HOME="$TARGET_HOME/.cache" \
        XDG_RUNTIME_DIR="$TARGET_RUNTIME" \
        kpackagetool6 --type Plasma/Applet --install "$package_root" >/dev/null \
        || fail "isolated KPackage install failed: $package"
    installed="$TARGET_HOME/.local/share/plasma/plasmoids/$package"
    diff -qr -- "$package_root" "$installed" >/dev/null \
        || fail "installed KPackage differs from source: $package"
    env -i HOME="$TARGET_HOME" PATH="$PATH" LC_ALL=C TZ=UTC \
        XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        XDG_DATA_HOME="$TARGET_HOME/.local/share" \
        XDG_CACHE_HOME="$TARGET_HOME/.cache" \
        XDG_RUNTIME_DIR="$TARGET_RUNTIME" \
        kpackagetool6 --type Plasma/Applet --remove "$package" >/dev/null \
        || fail "isolated KPackage removal failed: $package"
    [[ ! -e $installed ]] || fail "isolated KPackage removal left files: $package"
done

"$NODE_BIN" - "$REPO_ROOT" "${packages[@]}" <<'NODE'
const fs = require("fs");
const path = require("path");

const root = process.argv[2];
const fontMigrations = [
    "layouts/plasma/org.kde.minimalist-v04/contents/font-layout.js",
    "layouts/plasma/org.kde.minimalist-v04/contents/font-restore.js"
];
const workspaceMigrations = [
    "layouts/plasma/org.kde.minimalist-v04/contents/workspaces-layout.js",
    "layouts/plasma/org.kde.minimalist-v04/contents/workspaces-refresh-restore.js"
];
for (const packageId of process.argv.slice(3)) {
    const packageRoot = path.join(root, "plasmoids", packageId);
    const xml = fs.readFileSync(path.join(packageRoot, "contents/config/main.xml"), "utf8");
    const ui = fs.readFileSync(path.join(packageRoot, "contents/ui/configGeneral.qml"), "utf8");
    const entries = [...xml.matchAll(/<entry name="([^"]+)" type="([^"]+)">/g)]
        .map(match => match[1]);
    const aliases = [...ui.matchAll(/property alias cfg_([A-Za-z0-9_]+):/g)]
        .map(match => match[1]);
    if (entries.length === 0 || new Set(entries).size !== entries.length) {
        throw new Error(packageId + ": empty or duplicate KConfig entries");
    }
    for (const entry of entries) {
        if (!aliases.includes(entry)) {
            throw new Error(packageId + ": no config UI alias for " + entry);
        }
    }
    for (const alias of aliases) {
        if (!entries.includes(alias)) {
            throw new Error(packageId + ": dangling config UI alias " + alias);
        }
    }
    const migrationFiles = packageId.endsWith(".workspaces")
        ? fontMigrations.concat(workspaceMigrations) : fontMigrations;
    for (const migrationFile of migrationFiles) {
        const migration = fs.readFileSync(path.join(root, migrationFile), "utf8");
        for (const entry of entries) {
            if (!migration.includes("[\"" + entry + "\",")) {
                throw new Error(packageId + ": migration " + migrationFile
                    + " does not preserve " + entry);
            }
        }
    }
}
NODE

"$NODE_BIN" - \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle/contents/ui/main.qml" \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.resources/contents/ui/main.qml" <<'NODE'
const fs = require("fs");
const vm = require("vm");

function extract(source, name, nextName) {
    const end = nextName
        ? "\\n    function " + nextName + "\\("
        : "\\n    }";
    const expression = new RegExp("    function " + name
        + "\\([^]*?" + end);
    const match = source.match(expression);
    if (!match) throw new Error("missing function " + name);
    let text = match[0];
    if (nextName) text = text.slice(0, text.lastIndexOf("\n    function "));
    return text.replace(/^    /gm, "");
}

const activeSource = fs.readFileSync(process.argv[2], "utf8");
const active = {};
vm.runInNewContext(extract(activeSource, "formatTitle", "refreshActiveTitle"), active);
const titleCases = [
    [["{title}", "Kate", "notes.txt"], "notes.txt"],
    [["{app} · {title}", "Kate", "notes.txt"], "Kate · notes.txt"],
    [["{app}", "Kate", "notes.txt"], "Kate"],
    [["{unknown}", "Kate", "notes.txt"], "notes.txt"],
    [["", "Kate", "<img src=x>"], "<img src=x>"]
];
for (const [args, expected] of titleCases) {
    const actual = active.formatTitle(...args);
    if (actual !== expected) throw new Error("unsafe or incorrect title formatting");
}

const resourceSource = fs.readFileSync(process.argv[3], "utf8");
const order = {};
vm.runInNewContext(extract(resourceSource, "normalizedMetricOrder", "metricVisible"), order);
const orderCases = [
    ["VOL,CPU,RAM,GPU", "VOL,CPU,RAM,GPU"],
    ["GPU,GPU,bad,CPU", "GPU,CPU,RAM,VOL"],
    ["", "CPU,RAM,GPU,VOL"]
];
for (const [input, expected] of orderCases) {
    const actual = order.normalizedMetricOrder(input).join(",");
    if (actual !== expected) throw new Error("metric order normalization failed");
}

const severity = {
    Plasmoid: {configuration: {warningPercent: 70, criticalPercent: 90}},
    Math,
    Number
};
vm.runInNewContext(extract(resourceSource, "severityFor", null), severity);
for (const [value, expected] of [[-1, 0], [69, 0], [70, 1], [89, 1], [90, 2]]) {
    if (severity.severityFor(value) !== expected) {
        throw new Error("threshold classification failed");
    }
}
NODE

jq -e '
    .schemaVersion == 1
    and .policy.coreLicense == "MIT"
    and .policy.sourceArtifact == "MIT-only"
    and .policy.externalCodeIncluded == false
    and ([.components[].id] | length == (unique | length))
    and ([.components[] | select(.decision == "future-separate-gpl-extra")]
        | length >= 3)
    and ([.components[] | select(.license | startswith("NOASSERTION"))]
        | length >= 1)
' "$CATALOG" >/dev/null || fail "Chimera research/license catalog is invalid"

if rg -n 'Text\.RichText|DataSource.*executable|QProcess|/bin/(ba)?sh|playerctl|nvidia-smi|rocm-smi|curl|wget|pkill' \
    "$REPO_ROOT/design/chimera" \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle" \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.resources" \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.workspaces" >/dev/null; then
    fail "Chimera runtime contains a rich-text, shell, network, or process escape"
fi

mapfile -t private_imports < <(rg -l 'import org\.kde\..*private' \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle" \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.resources" \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.workspaces" | LC_ALL=C sort)
expected_private="$REPO_ROOT/plasmoids/org.kde.minimalist.resources/contents/ui/providers/VolumeProvider.qml"
[[ ${#private_imports[@]} -eq 1 && ${private_imports[0]} == "$expected_private" ]] \
    || fail "a private KDE API escaped its isolated provider allowlist"

grep -Fq 'readonly property int unit: 2' "$CANONICAL/ChimeraTokens.qml" \
    || fail "the 2 px Chimera grid changed"
grep -Fq 'readonly property int radius: 0' "$CANONICAL/ChimeraTokens.qml" \
    || fail "the square-corner Chimera invariant changed"
grep -Fq 'property int surfaceStyle: 0' "$CANONICAL/ChimeraTokens.qml" \
    || fail "the flat-strip Chimera default changed"
grep -Fq 'readonly property int controlHeight: 24' \
    "$CANONICAL/ChimeraTokens.qml" \
    || fail "the common 24 px control height changed"
grep -Fq 'tokens.flatSurface ? "transparent" : tokens.surfaceRaised' \
    "$CANONICAL/ChimeraFrame.qml" \
    || fail "flat resting surfaces are no longer transparent"
grep -Fq 'root.tokens.beveledSurface && root.tokens.bevelDepth > 0' \
    "$CANONICAL/ChimeraFrame.qml" \
    || fail "bevels are no longer opt-in"
grep -Fq 'readonly property int motionFast: motionEnabled ? 110 : 0' \
    "$CANONICAL/ChimeraTokens.qml" || fail "the motion invariant changed"
grep -Fq 'color: root.pressed ? root.tokens.edgeDark : root.tokens.edgeLight' \
    "$CANONICAL/ChimeraFrame.qml" || fail "raised/pressed bevel inversion is missing"
grep -Fq 'textFormat: Text.PlainText' \
    "$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle/contents/ui/main.qml" \
    || fail "window titles are no longer plain text"

printf 'PASS: cohesive, configurable, license-bounded Chimera components\n'
