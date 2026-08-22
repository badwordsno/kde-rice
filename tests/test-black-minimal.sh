#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-black.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-black.*)
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

SCHEME="$REPO_ROOT/config/color-schemes/BlackMinimal.colors"
KONSOLE_SCHEME="$REPO_ROOT/config/konsole/BlackMinimal.colorscheme"
KONSOLE_PROFILE="$REPO_ROOT/config/konsole/BlackMinimal.profile"
TARGET_HOME="$TEMP_ROOT/home"

grep -Fq 'ColorScheme=BlackMinimal' "$SCHEME" || fail "KDE scheme identity is wrong"
grep -Fq 'Name=Black Minimal' "$SCHEME" || fail "KDE scheme name is wrong"
[[ $(grep -Fc 'BackgroundNormal=0,0,0' "$SCHEME") -ge 4 ]] || fail "major KDE surfaces are not true black"
grep -Fq 'DecorationFocus=145,70,255' "$SCHEME" || fail "vivid-purple focus color is missing"
grep -Fq 'BackgroundNormal=145,70,255' "$SCHEME" || fail "vivid-purple selection background is missing"
grep -Fq 'BackgroundNormal=12,12,15' "$SCHEME" || fail "secondary surface tone is missing"
grep -Fq 'Color=0,0,0' "$KONSOLE_SCHEME" || fail "Konsole background is not true black"
grep -Fq 'Opacity=1' "$KONSOLE_SCHEME" || fail "Konsole is not opaque"
grep -Fq 'Blur=false' "$KONSOLE_SCHEME" || fail "Konsole blur is enabled"
grep -Fq 'ColorScheme=BlackMinimal' "$KONSOLE_PROFILE" || fail "Konsole profile uses the wrong scheme"
grep -Fq 'Font=Hack,11' "$KONSOLE_PROFILE" || fail "Konsole font baseline changed"

for target in \
    .local/share/color-schemes/BlackMinimal.colors \
    .local/share/konsole/BlackMinimal.colorscheme \
    .local/share/konsole/BlackMinimal.profile; do
    grep -Fxq "$target" "$REPO_ROOT/config/managed-paths.txt" || fail "asset is outside the managed boundary: $target"
done

if grep -Eq 'plasma-apply-wallpaperimage|applywindowdecoration|evaluateScript|kwinoutputconfig|\.local/share/kscreen' "$REPO_ROOT/scripts/apply-black"; then
    fail "Black Minimal apply path may change wallpaper, shell geometry, decoration, or display settings"
fi

grep -Fq 'plasma-apply-colorscheme BlackMinimal' "$REPO_ROOT/scripts/apply-black" || fail "KDE scheme activation is missing"
grep -Fq "plasma-apply-colorscheme --accent-color '#9146FF'" "$REPO_ROOT/scripts/apply-black" || fail "accent activation is missing"
if grep -Fq "plasma-apply-colorscheme --accent-color '#9146FF' BlackMinimal" "$REPO_ROOT/scripts/apply-black"; then
    fail "scheme and accent are combined in a Plasma 6.7-incompatible call"
fi
grep -Fq -- '--group "Colors:Selection" --key BackgroundNormal "145,70,255"' "$REPO_ROOT/scripts/apply-black" || fail "exact selection color activation is missing"
grep -Fq '[[ $active_scheme == BlackMinimal ]]' "$REPO_ROOT/scripts/apply-black" || fail "post-apply scheme verification is missing"
grep -Fq '[[ $active_selection == 145,70,255 ]]' "$REPO_ROOT/scripts/apply-black" || fail "post-apply selection verification is missing"

mkdir -p -- "$TARGET_HOME/.config"
printf 'baseline-kdeglobals\n' > "$TARGET_HOME/.config/kdeglobals"
printf 'baseline-konsole\n' > "$TARGET_HOME/.config/konsolerc"
printf 'baseline-kwin\n' > "$TARGET_HOME/.config/kwinrc"
printf 'active-personal-wallpaper\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'baseline-shell\n' > "$TARGET_HOME/.config/plasmashellrc"
printf 'baseline-output\n' > "$TARGET_HOME/.config/kwinoutputconfig.json"

kde_before=$(sha256sum "$TARGET_HOME/.config/kdeglobals")
konsole_before=$(sha256sum "$TARGET_HOME/.config/konsolerc")
kwin_before=$(sha256sum "$TARGET_HOME/.config/kwinrc")
wallpaper_before=$(sha256sum "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc")
shell_before=$(sha256sum "$TARGET_HOME/.config/plasmashellrc")
display_before=$(sha256sum "$TARGET_HOME/.config/kwinoutputconfig.json")

bash "$REPO_ROOT/scripts/apply-black" --home "$TARGET_HOME" --install-only --dry-run > "$TEMP_ROOT/dry-run.txt"
[[ ! -e $TARGET_HOME/.local ]] || fail "dry run wrote to the target home"

if bash "$REPO_ROOT/scripts/apply-black" --home "$TARGET_HOME" --dry-run > "$TEMP_ROOT/foreign-live.txt" 2>&1; then
    fail "live activation was allowed for a foreign home"
fi

bash "$REPO_ROOT/scripts/apply-black" --home "$TARGET_HOME" --install-only --apply > "$TEMP_ROOT/apply.txt"
snapshot_path=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt")

[[ -n $snapshot_path && -f $snapshot_path/complete ]] || fail "pre-apply snapshot is incomplete"
diff -q "$SCHEME" "$TARGET_HOME/.local/share/color-schemes/BlackMinimal.colors" >/dev/null || fail "installed KDE scheme differs from source"
diff -q "$KONSOLE_SCHEME" "$TARGET_HOME/.local/share/konsole/BlackMinimal.colorscheme" >/dev/null || fail "installed Konsole scheme differs from source"
diff -q "$KONSOLE_PROFILE" "$TARGET_HOME/.local/share/konsole/BlackMinimal.profile" >/dev/null || fail "installed Konsole profile differs from source"
[[ $(sha256sum "$TARGET_HOME/.config/kdeglobals") == "$kde_before" ]] || fail "install-only changed KDE configuration"
[[ $(sha256sum "$TARGET_HOME/.config/konsolerc") == "$konsole_before" ]] || fail "install-only changed Konsole configuration"
[[ $(sha256sum "$TARGET_HOME/.config/kwinrc") == "$kwin_before" ]] || fail "install-only changed KWin configuration"
[[ $(sha256sum "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == "$wallpaper_before" ]] || fail "install-only changed the wallpaper configuration"
[[ $(sha256sum "$TARGET_HOME/.config/plasmashellrc") == "$shell_before" ]] || fail "install-only changed panel geometry"
[[ $(sha256sum "$TARGET_HOME/.config/kwinoutputconfig.json") == "$display_before" ]] || fail "install-only changed display configuration"

bash "$REPO_ROOT/scripts/restore" --backup "$snapshot_path" --home "$TARGET_HOME" --state-root "$TARGET_HOME/.local/state/kde-rice/test-restore" --apply > "$TEMP_ROOT/restore.txt"
[[ ! -e $TARGET_HOME/.local/share/color-schemes/BlackMinimal.colors ]] || fail "restore left the KDE scheme installed"
[[ ! -e $TARGET_HOME/.local/share/konsole/BlackMinimal.colorscheme ]] || fail "restore left the Konsole scheme installed"
[[ ! -e $TARGET_HOME/.local/share/konsole/BlackMinimal.profile ]] || fail "restore left the Konsole profile installed"
[[ $(sha256sum "$TARGET_HOME/.config/kdeglobals") == "$kde_before" ]] || fail "restore changed KDE baseline"
[[ $(sha256sum "$TARGET_HOME/.config/konsolerc") == "$konsole_before" ]] || fail "restore changed Konsole baseline"
[[ $(sha256sum "$TARGET_HOME/.config/kwinrc") == "$kwin_before" ]] || fail "restore changed KWin baseline"
[[ $(sha256sum "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc") == "$wallpaper_before" ]] || fail "restore changed wallpaper baseline"
[[ $(sha256sum "$TARGET_HOME/.config/plasmashellrc") == "$shell_before" ]] || fail "restore changed panel baseline"
[[ $(sha256sum "$TARGET_HOME/.config/kwinoutputconfig.json") == "$display_before" ]] || fail "restore changed display baseline"

printf 'PASS: Black Minimal visual layer tests\n'
