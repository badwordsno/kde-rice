#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-modern.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-modern.*)
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

SCRIPT="$REPO_ROOT/scripts/apply-modern"
TARGET_HOME="$TEMP_ROOT/home"

bash -n "$SCRIPT"
grep -Fq 'PLASMA_TARGET=default' "$SCRIPT" || fail "modern Plasma target changed"
grep -Fq 'DECORATION_TARGET=Breeze' "$SCRIPT" || fail "modern decoration target changed"
grep -Fq 'resolve_kwin_decoration_tool()' "$SCRIPT" || fail "portable KWin decoration tool discovery is missing"
grep -Fq 'capture_or_reuse_snapshot' "$SCRIPT" || fail "safe snapshot capture/reuse call is missing"
grep -Fq 'plasma-apply-desktoptheme "$PLASMA_TARGET"' "$SCRIPT" || fail "supported Plasma apply tool is missing"
grep -Fq '"$KWIN_APPLY_TOOL" "$DECORATION_TARGET"' "$SCRIPT" || fail "supported KWin apply tool is missing"
grep -Fq 'plasma_active=${plasma_active:-default}' "$SCRIPT" \
    || fail "implicit default Plasma Style is not accepted"
grep -Fq 'kwin_library_active=${kwin_library_active:-org.kde.breeze}' "$SCRIPT" \
    || fail "implicit default Breeze decoration library is not accepted"
grep -Fq 'kwin_theme_active=${kwin_theme_active:-Breeze}' "$SCRIPT" \
    || fail "implicit default Breeze decoration theme is not accepted"

snapshot_line=$(grep -nF 'capture_or_reuse_snapshot' "$SCRIPT" | cut -d: -f1)
plasma_line=$(grep -nF 'plasma_result=$(plasma-apply-desktoptheme' "$SCRIPT" | cut -d: -f1)
decoration_line=$(grep -nF 'decoration_result=$("$KWIN_APPLY_TOOL"' "$SCRIPT" | cut -d: -f1)
((snapshot_line < plasma_line && snapshot_line < decoration_line)) || fail "snapshot does not precede live activation"

if grep -Eq 'kwinoutputconfig|\.local/share/kscreen|kwriteconfig|evaluateScript|rm[[:space:]]' "$SCRIPT"; then
    fail "modern switcher may touch excluded settings or bypass supported apply tools"
fi

mkdir -p -- "$TARGET_HOME/.config"
printf '[Theme]\nname=legacy-custom-style\n' > "$TARGET_HOME/.config/plasmarc"
printf '%s\n' \
    '[Tiling][screen]' \
    'padding=4' \
    'tiles={"layoutDirection":"horizontal","tiles":[{"width":0.25},{"width":0.5},{"width":0.25}]}' \
    '' \
    '[org.kde.kdecoration2]' \
    'library=org.kde.kwin.aurorae.v2' \
    'theme=__aurorae__svg__legacy-custom-decoration' \
    > "$TARGET_HOME/.config/kwinrc"
printf 'baseline-panel\n' > "$TARGET_HOME/.config/plasmashellrc"
printf 'baseline-widgets\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'baseline-output\n' > "$TARGET_HOME/.config/kwinoutputconfig.json"

before=$(sha256sum "$TARGET_HOME/.config"/*)
bash "$SCRIPT" --home "$TARGET_HOME" --dry-run > "$TEMP_ROOT/dry-run.txt"
after=$(sha256sum "$TARGET_HOME/.config"/*)
[[ $after == "$before" ]] || fail "modern dry run changed the target home"
grep -Fq 'Current Plasma Style: legacy-custom-style' "$TEMP_ROOT/dry-run.txt" || fail "dry run omitted the current Plasma Style"
grep -Fq 'Target Plasma Style: Breeze (default)' "$TEMP_ROOT/dry-run.txt" || fail "dry run omitted the modern target"

set +e
KDE_RICE_KWIN_DECORATION_TOOL=/tmp/untrusted-decoration-helper \
    bash "$SCRIPT" --home "$TARGET_HOME" --dry-run > "$TEMP_ROOT/untrusted-override.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "modern switcher accepted a decoration helper override outside isolated test mode"
grep -Fq 'isolated-test seam only' "$TEMP_ROOT/untrusted-override.txt" \
    || fail "decoration helper override refusal reason is missing"

if bash "$SCRIPT" --home "$TARGET_HOME" --apply > "$TEMP_ROOT/foreign-apply.txt" 2>&1; then
    fail "modern switcher allowed live activation for a foreign home"
fi
[[ $(sha256sum "$TARGET_HOME/.config"/*) == "$before" ]] || fail "refused foreign activation changed the target home"

printf 'PASS: modern shell switch tests\n'
