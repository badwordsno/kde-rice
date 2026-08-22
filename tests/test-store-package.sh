#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
PACKAGE_ID="io.github.badwordsno.minimalistblack"
PACKAGE_ROOT="$REPO_ROOT/packages/store/$PACKAGE_ID"
VERSION=$(< "$REPO_ROOT/VERSION")

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for command_name in awk cmp find grep jq kpackagetool6 magick sha256sum; do
    command -v -- "$command_name" >/dev/null 2>&1 \
        || fail "required Store package test tool is unavailable: $command_name"
done

[[ $VERSION == 1.0.0 ]] || fail "unexpected public release version: $VERSION"

expected_files=$(printf '%s\n' \
    'LICENSE' \
    'contents/colors' \
    'contents/defaults' \
    'contents/previews/fullscreenpreview.jpg' \
    'contents/previews/preview.png' \
    'manifest.json' \
    'metadata.json')
actual_files=$(find "$PACKAGE_ROOT" -mindepth 1 -type f -printf '%P\n' | LC_ALL=C sort)
[[ $actual_files == "$expected_files" ]] || fail "Store package file allowlist changed"
expected_directories=$(printf '%s\n' 'contents' 'contents/previews')
actual_directories=$(find "$PACKAGE_ROOT" -mindepth 1 -type d -printf '%P\n' | LC_ALL=C sort)
[[ $actual_directories == "$expected_directories" ]] || fail "Store package directory allowlist changed"

[[ -z $(find "$PACKAGE_ROOT" -mindepth 1 -type l -print -quit) ]] \
    || fail "Store package contains a symbolic link"
[[ -z $(find "$PACKAGE_ROOT" -mindepth 1 ! -type d ! -type f -print -quit) ]] \
    || fail "Store package contains an unsupported filesystem object"

jq -e --arg id "$PACKAGE_ID" --arg version "$VERSION" '
    .KPackageStructure == "Plasma/LookAndFeel"
    and .KPlugin.Id == $id
    and .KPlugin.Version == $version
    and .KPlugin.License == "MIT"
    and (.KPlugin.BugReportUrl | startswith("https://github.com/"))
    and .["X-Plasma-API-Minimum-Version"] == "6.0"
' "$PACKAGE_ROOT/metadata.json" >/dev/null \
    || fail "Store metadata contract is invalid"
cmp -s "$REPO_ROOT/LICENSE" "$PACKAGE_ROOT/LICENSE" \
    || fail "Store package license differs from the project MIT license"

jq -e --arg id "$PACKAGE_ID" --arg version "$VERSION" '
    .schemaVersion == 1
    and .package.id == $id
    and .package.version == $version
    and .package.structure == "Plasma/LookAndFeel"
    and .scope.mode == "appearance-only"
    and .compatibility.plasmaMajor == 6
    and .compatibility.breezeRequired == true
    and .assets.previewOrigin == "generated"
    and .assets.privateAssetsIncluded == false
    and .assets.previews.fullscreen.path == "contents/previews/fullscreenpreview.jpg"
    and .assets.previews.tile.path == "contents/previews/preview.png"
    and (.scope.excluded | index("desktop-layout")) != null
    and (.scope.excluded | index("wallpaper")) != null
    and (.scope.excluded | index("applets")) != null
    and (.scope.excluded | index("scripts")) != null
' "$PACKAGE_ROOT/manifest.json" >/dev/null \
    || fail "Store manifest contract is invalid"

defaults="$PACKAGE_ROOT/contents/defaults"
colors="$PACKAGE_ROOT/contents/colors"
grep -Fqx '[kdeglobals][KDE]' "$defaults" || fail "Breeze widget style group is missing"
grep -Fqx 'widgetStyle=Breeze' "$defaults" || fail "Breeze widget style is missing"
grep -Fqx 'ColorScheme=KdeRiceStoreBlack' "$defaults" || fail "unique Store palette is not selected"
grep -Fqx 'name=default' "$defaults" || fail "Breeze Plasma style is missing"
grep -Fqx 'library=org.kde.breeze' "$defaults" || fail "Breeze decoration library is missing"
grep -Fqx 'theme=Breeze' "$defaults" || fail "Breeze decoration theme is missing"
grep -Fqx 'ColorScheme=KdeRiceStoreBlack' "$colors" || fail "embedded Store palette identity is wrong"
grep -Fqx 'BackgroundNormal=145,70,255' "$colors" || fail "purple selection color is missing"

if grep -Eq '^\[Wallpaper\]|LookAndFeelPackage|ShellPackage' "$defaults"; then
    fail "Store defaults exceed the appearance-only boundary"
fi
if find "$PACKAGE_ROOT" -mindepth 1 -print \
    | grep -Eiq '/(layouts?|wallpapers?|applets?|plasmoids?|scripts?)(/|$)'; then
    fail "Store package contains a forbidden component path"
fi
forbidden_content_pattern='Minimalist''V02|PRIVATE-''ASSET|Propriet''ary|assets/wall''papers|/ho''me/|/Us''ers/|[A-Za-z]:\\Us''ers\\|BEGIN (RSA |OPENSSH |EC )?PRIVATE ''KEY|kwinoutputconfig|\.local/share/kscreen'
if grep -aEq "$forbidden_content_pattern" \
    "$PACKAGE_ROOT/metadata.json" "$PACKAGE_ROOT/manifest.json" "$defaults" "$colors" \
    "$PACKAGE_ROOT/contents/previews/preview.png" \
    "$PACKAGE_ROOT/contents/previews/fullscreenpreview.jpg"; then
    fail "Store package contains a private, user-specific, or display-state marker"
fi

preview_info=$(magick identify -format '%m %wx%h' "$PACKAGE_ROOT/contents/previews/preview.png")
[[ $preview_info == 'PNG 960x540' ]] || fail "unexpected compact preview: $preview_info"
fullscreen_info=$(magick identify -format '%m %wx%h' "$PACKAGE_ROOT/contents/previews/fullscreenpreview.jpg")
[[ $fullscreen_info == 'JPEG 1920x1080' ]] || fail "unexpected fullscreen preview: $fullscreen_info"
expected_preview_hashes=$(jq -r '.assets.previews | [.fullscreen.sha256, .tile.sha256] | .[]' "$PACKAGE_ROOT/manifest.json")
actual_preview_hashes=$(sha256sum \
    "$PACKAGE_ROOT/contents/previews/fullscreenpreview.jpg" \
    "$PACKAGE_ROOT/contents/previews/preview.png" \
    | awk '{print $1}')
[[ $actual_preview_hashes == "$expected_preview_hashes" ]] || fail "Store preview hashes differ from manifest"

TEMP_ROOT=$(mktemp -d)
cleanup() {
    rm -rf -- "$TEMP_ROOT"
}
trap cleanup EXIT

TEST_HOME="$TEMP_ROOT/home"
TEST_DATA="$TEST_HOME/.local/share"
TEST_CONFIG="$TEST_HOME/.config"
TEST_STATE="$TEST_HOME/.local/state"
TEST_CACHE="$TEST_HOME/.cache"
TEST_RUNTIME="$TEMP_ROOT/runtime"
mkdir -p -- "$TEST_DATA" "$TEST_CONFIG" "$TEST_STATE" "$TEST_CACHE" "$TEST_RUNTIME"
chmod 700 "$TEST_RUNTIME"
printf 'sentinel-active-config\n' > "$TEST_CONFIG/kdeglobals"
active_config_before=$(sha256sum -- "$TEST_CONFIG/kdeglobals")

run_kpackage() {
    env -i \
        HOME="$TEST_HOME" \
        PATH="$PATH" \
        XDG_CACHE_HOME="$TEST_CACHE" \
        XDG_CONFIG_HOME="$TEST_CONFIG" \
        XDG_DATA_HOME="$TEST_DATA" \
        XDG_RUNTIME_DIR="$TEST_RUNTIME" \
        XDG_STATE_HOME="$TEST_STATE" \
        kpackagetool6 --type Plasma/LookAndFeel "$@"
}

run_kpackage --install "$PACKAGE_ROOT" >"$TEMP_ROOT/install.txt"
installed="$TEST_DATA/plasma/look-and-feel/$PACKAGE_ID"
[[ -d $installed ]] || fail "kpackagetool6 escaped the temporary XDG data root or did not install"
[[ ! -e "$REPO_ROOT/$PACKAGE_ID" ]] || fail "unexpected repository-root install target appeared"
run_kpackage --show "$PACKAGE_ID" >"$TEMP_ROOT/show.txt"
grep -Fq "Name: Minimalist Black" "$TEMP_ROOT/show.txt" \
    || grep -Fq "Minimalist Black" "$TEMP_ROOT/show.txt" \
    || fail "kpackagetool6 show did not resolve the installed package"
run_kpackage --upgrade "$PACKAGE_ROOT" >"$TEMP_ROOT/upgrade.txt"
run_kpackage --remove "$PACKAGE_ID" >"$TEMP_ROOT/remove.txt"
[[ ! -e $installed ]] || fail "kpackagetool6 remove left the isolated package installed"
[[ $(sha256sum -- "$TEST_CONFIG/kdeglobals") == "$active_config_before" ]] \
    || fail "KPackage install/upgrade/remove changed active configuration"
[[ $(find "$TEST_CONFIG" -type f -printf '%P\n') == kdeglobals ]] \
    || fail "KPackage lifecycle wrote unexpected active configuration"

printf 'PASS: Store package contract and isolated KPackage lifecycle\n'
