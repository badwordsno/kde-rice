#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-snapshot.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-snapshot.*)
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

assert_file_text() {
    local expected=$1
    local file=$2
    local actual

    [[ -f $file ]] || fail "expected regular file: $file"
    actual=$(< "$file")
    [[ $actual == "$expected" ]] || fail "unexpected contents in $file"
}

TARGET_HOME="$TEMP_ROOT/home"
SNAPSHOT="$TEMP_ROOT/snapshot"
DRY_SNAPSHOT="$TEMP_ROOT/dry-snapshot"
STATE_ROOT="$TARGET_HOME/.snapshot-test-state"

if grep -Eq 'RetroWorkstation|retro-workstation|black-minimal-compact-panel|Minimalist''V02' \
    "$REPO_ROOT/config/managed-paths.txt"; then
    fail "retired design path remains in the current managed scope"
fi
grep -Fxq '.local/share/color-schemes/RetroWorkstation.colors' \
    "$REPO_ROOT/config/restore-compat-paths.txt" \
    || fail "retired exact path is missing from restore-only compatibility"
mkdir -p -- "$TARGET_HOME/.config" "$TARGET_HOME/.local/share/konsole"
printf 'baseline-kdeglobals\n' > "$TARGET_HOME/.config/kdeglobals"
printf 'baseline-panel\n' > "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
printf 'baseline-output\n' > "$TARGET_HOME/.config/kwinoutputconfig.json"
printf 'baseline-profile\n' > "$TARGET_HOME/.local/share/konsole/User.profile"

bash "$REPO_ROOT/scripts/inspect" --home "$TARGET_HOME" > "$TEMP_ROOT/inspect.txt"
grep -q 'Explicitly excluded display paths' "$TEMP_ROOT/inspect.txt" || fail "inspect did not report exclusions"
grep -q '.config/kwinoutputconfig.json' "$TEMP_ROOT/inspect.txt" || fail "inspect omitted the display exclusion"

bash "$REPO_ROOT/scripts/snapshot" --home "$TARGET_HOME" --output "$DRY_SNAPSHOT" --dry-run > "$TEMP_ROOT/snapshot-dry-run.txt"
[[ ! -e $DRY_SNAPSHOT ]] || fail "snapshot dry run wrote output"

bash "$REPO_ROOT/scripts/snapshot" --home "$TARGET_HOME" --output "$SNAPSHOT" > "$TEMP_ROOT/snapshot.txt"
[[ -f $SNAPSHOT/complete ]] || fail "snapshot did not complete"
[[ -f $SNAPSHOT/payload/.config/kdeglobals ]] || fail "snapshot omitted kdeglobals"
grep -Fqx $'absent\t.local/share/plasma/layout-templates/org.kde.minimalist-v04' \
    "$SNAPSHOT/state.tsv" || fail "snapshot omitted the exact absent v0.4.1 layout path"
[[ ! -e $SNAPSHOT/payload/.config/kwinoutputconfig.json ]] || fail "snapshot captured display configuration"
if grep -q 'kwinoutputconfig.json' "$SNAPSHOT/state.tsv"; then
    fail "display configuration appeared in snapshot state"
fi

printf 'modified-kdeglobals\n' > "$TARGET_HOME/.config/kdeglobals"
printf 'modified-output\n' > "$TARGET_HOME/.config/kwinoutputconfig.json"
mkdir -p -- "$TARGET_HOME/.local/share/color-schemes"
printf 'new-project-scheme\n' > "$TARGET_HOME/.local/share/color-schemes/BlackMinimal.colors"

bash "$REPO_ROOT/scripts/restore" --backup "$SNAPSHOT" --home "$TARGET_HOME" --state-root "$STATE_ROOT" > "$TEMP_ROOT/restore-dry-run.txt"
assert_file_text 'modified-kdeglobals' "$TARGET_HOME/.config/kdeglobals"
assert_file_text 'modified-output' "$TARGET_HOME/.config/kwinoutputconfig.json"
assert_file_text 'new-project-scheme' "$TARGET_HOME/.local/share/color-schemes/BlackMinimal.colors"

bash "$REPO_ROOT/scripts/restore" --backup "$SNAPSHOT" --home "$TARGET_HOME" --state-root "$STATE_ROOT" --apply > "$TEMP_ROOT/restore-apply.txt"
assert_file_text 'baseline-kdeglobals' "$TARGET_HOME/.config/kdeglobals"
assert_file_text 'modified-output' "$TARGET_HOME/.config/kwinoutputconfig.json"
[[ ! -e $TARGET_HOME/.local/share/color-schemes/BlackMinimal.colors ]] || fail "restore did not return an originally absent path to absent"

find "$STATE_ROOT/restore-displaced" -path '*/.config/kdeglobals' -type f | grep -q . || fail "modified kdeglobals was not displaced"
find "$STATE_ROOT/restore-displaced" -path '*/BlackMinimal.colors' -type f | grep -q . || fail "new project scheme was not displaced"

OLDER="$TEMP_ROOT/older-manifest"
cp -a -- "$SNAPSHOT" "$OLDER"
sed -i '/^\.config\/plasmashellrc$/d' "$OLDER/managed-paths.txt"
sed -i '/\.config\/plasmashellrc$/d' "$OLDER/state.tsv"
bash "$REPO_ROOT/scripts/restore" --backup "$OLDER" --home "$TARGET_HOME" > "$TEMP_ROOT/older-manifest.txt"
grep -q 'Dry run only' "$TEMP_ROOT/older-manifest.txt" || fail "restore did not accept a safe older manifest subset"

UNMANAGED="$TEMP_ROOT/unmanaged"
cp -a -- "$SNAPSHOT" "$UNMANAGED"
printf '.config/not-managed-by-kde-rice\n' >> "$UNMANAGED/managed-paths.txt"
printf 'absent\t.config/not-managed-by-kde-rice\n' >> "$UNMANAGED/state.tsv"
if bash "$REPO_ROOT/scripts/restore" --backup "$UNMANAGED" --home "$TARGET_HOME" > "$TEMP_ROOT/unmanaged.txt" 2>&1; then
    fail "restore accepted a snapshot path outside the current managed manifest"
fi

LEGACY="$TEMP_ROOT/legacy-manifest"
cp -a -- "$SNAPSHOT" "$LEGACY"
printf '.local/share/color-schemes/RetroWorkstation.colors\n' >> "$LEGACY/managed-paths.txt"
printf 'file\t.local/share/color-schemes/RetroWorkstation.colors\n' >> "$LEGACY/state.tsv"
mkdir -p -- "$LEGACY/payload/.local/share/color-schemes"
printf 'trusted-legacy-snapshot\n' \
    > "$LEGACY/payload/.local/share/color-schemes/RetroWorkstation.colors"
bash "$REPO_ROOT/scripts/restore" --backup "$LEGACY" --home "$TARGET_HOME" \
    > "$TEMP_ROOT/legacy-manifest.txt"
grep -q 'Dry run only' "$TEMP_ROOT/legacy-manifest.txt" \
    || fail "restore rejected a retired exact path from a trusted older snapshot"
bash "$REPO_ROOT/scripts/restore" --backup "$LEGACY" --home "$TARGET_HOME" \
    --state-root "$TARGET_HOME/.legacy-restore-state" --apply \
    > "$TEMP_ROOT/legacy-restore.txt"
assert_file_text 'trusted-legacy-snapshot' \
    "$TARGET_HOME/.local/share/color-schemes/RetroWorkstation.colors"
TAMPERED="$TEMP_ROOT/tampered"
cp -a -- "$SNAPSHOT" "$TAMPERED"
printf '.config/kwinoutputconfig.json\n' >> "$TAMPERED/managed-paths.txt"
if bash "$REPO_ROOT/scripts/restore" --backup "$TAMPERED" --home "$TARGET_HOME" > "$TEMP_ROOT/tampered.txt" 2>&1; then
    fail "restore accepted a tampered manifest"
fi

if bash -c 'source "$1"; validate_relative_path ".config/../.ssh/config"' _ "$REPO_ROOT/scripts/lib/common.sh"; then
    fail "path validator accepted parent traversal"
fi
if bash -c 'source "$1"; validate_relative_path ".config/kwinoutputconfig.json"' _ "$REPO_ROOT/scripts/lib/common.sh"; then
    fail "path validator accepted display configuration"
fi

ESCAPE_HOME="$TEMP_ROOT/escape-home"
OUTSIDE_CONFIG="$TEMP_ROOT/outside-config"
mkdir -p -- "$ESCAPE_HOME" "$OUTSIDE_CONFIG"
ln -s -- "$OUTSIDE_CONFIG" "$ESCAPE_HOME/.config"
if bash "$REPO_ROOT/scripts/inspect" --home "$ESCAPE_HOME" > "$TEMP_ROOT/escape.txt" 2>&1; then
    fail "inspect accepted a managed parent that escapes the target home"
fi

printf 'PASS: snapshot and restore safety tests\n'
