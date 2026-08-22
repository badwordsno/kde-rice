#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
BUILDER="$REPO_ROOT/scripts/build-store-release"
PACKAGE_ID="io.github.badwordsno.minimalistblack"
PACKAGE_ROOT="$REPO_ROOT/packages/store/$PACKAGE_ID"
VERSION=$(< "$REPO_ROOT/VERSION")
ARCHIVE_NAME="minimalist-black-plasma6-$VERSION.zip"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for command_name in diff find grep kpackagetool6 sha256sum unzip zipinfo; do
    command -v -- "$command_name" >/dev/null 2>&1 \
        || fail "required Store release test tool is unavailable: $command_name"
done
[[ -x $BUILDER ]] || fail "Store release builder is not executable"

TEMP_ROOT=$(mktemp -d)
cleanup() {
    rm -rf -- "$TEMP_ROOT"
}
trap cleanup EXIT

OUTPUT_ONE="$TEMP_ROOT/output-one"
OUTPUT_TWO="$TEMP_ROOT/output-two"
SOURCE_DATE_EPOCH=315532800 "$BUILDER" --output "$OUTPUT_ONE" >"$TEMP_ROOT/build-one.txt"
SOURCE_DATE_EPOCH=315532800 "$BUILDER" --output "$OUTPUT_TWO" >"$TEMP_ROOT/build-two.txt"

ARCHIVE_ONE="$OUTPUT_ONE/$ARCHIVE_NAME"
ARCHIVE_TWO="$OUTPUT_TWO/$ARCHIVE_NAME"
[[ -s $ARCHIVE_ONE && -s $ARCHIVE_TWO ]] || fail "Store builder did not create both archives"
hash_one=$(sha256sum "$ARCHIVE_ONE")
hash_two=$(sha256sum "$ARCHIVE_TWO")
[[ ${hash_one%% *} == "${hash_two%% *}" ]] || fail "Store release is not byte-for-byte deterministic"

SYMLINK_OUTPUT="$TEMP_ROOT/symlink-output"
SYMLINK_SENTINEL="$TEMP_ROOT/symlink-sentinel"
mkdir -p -- "$SYMLINK_OUTPUT"
printf 'preserve-me\n' >"$SYMLINK_SENTINEL"
ln -s -- "$SYMLINK_SENTINEL" "$SYMLINK_OUTPUT/$ARCHIVE_NAME"
if "$BUILDER" --output "$SYMLINK_OUTPUT" >"$TEMP_ROOT/symlink-build.txt" 2>&1; then
    fail "Store builder accepted a symbolic-link release target"
fi
grep -Fq 'refusing a symbolic-link release target' "$TEMP_ROOT/symlink-build.txt" \
    || fail "Store builder did not explain the symbolic-link refusal"
[[ $(< "$SYMLINK_SENTINEL") == preserve-me ]] \
    || fail "Store builder changed the symbolic-link target"

SYMLINK_DIRECTORY_TARGET="$TEMP_ROOT/symlink-directory-target"
SYMLINK_DIRECTORY="$TEMP_ROOT/symlink-directory"
mkdir -p -- "$SYMLINK_DIRECTORY_TARGET"
ln -s -- "$SYMLINK_DIRECTORY_TARGET" "$SYMLINK_DIRECTORY"
if "$BUILDER" --output "$SYMLINK_DIRECTORY" \
    >"$TEMP_ROOT/symlink-directory-build.txt" 2>&1; then
    fail "Store builder accepted a symbolic-link output directory"
fi
[[ -z $(find "$SYMLINK_DIRECTORY_TARGET" -mindepth 1 -print -quit) ]] \
    || fail "Store builder wrote through a symbolic-link output directory"

CREDENTIAL_SOURCE="$TEMP_ROOT/credential-source"
mkdir -p -- "$CREDENTIAL_SOURCE/scripts" "$CREDENTIAL_SOURCE/packages/store" \
    "$CREDENTIAL_SOURCE/release"
cp -- "$REPO_ROOT/VERSION" "$CREDENTIAL_SOURCE/VERSION"
cp -- "$BUILDER" "$CREDENTIAL_SOURCE/scripts/build-store-release"
cp -- "$REPO_ROOT/release/nonredistributable-payloads.sha256" \
    "$CREDENTIAL_SOURCE/release/nonredistributable-payloads.sha256"
cp -a -- "$PACKAGE_ROOT" "$CREDENTIAL_SOURCE/packages/store/$PACKAGE_ID"
printf '\n# %s\n' 'BEGIN OPENSSH PRIVATE ''KEY' \
    >> "$CREDENTIAL_SOURCE/packages/store/$PACKAGE_ID/contents/colors"
if "$CREDENTIAL_SOURCE/scripts/build-store-release" \
    --output "$TEMP_ROOT/credential-output" \
    > "$TEMP_ROOT/credential-build.txt" 2>&1; then
    fail "Store builder accepted a credential marker in an allowed file"
fi

expected_entries=$(printf '%s\n' \
    'LICENSE' \
    'contents/colors' \
    'contents/defaults' \
    'contents/previews/fullscreenpreview.jpg' \
    'contents/previews/preview.png' \
    'manifest.json' \
    'metadata.json')
actual_entries=$(unzip -Z1 "$ARCHIVE_ONE" | LC_ALL=C sort)
[[ $actual_entries == "$expected_entries" ]] || fail "Store archive entry allowlist changed"

while IFS= read -r entry; do
    [[ $entry != /* ]] || fail "Store archive contains an absolute path: $entry"
    case "/$entry/" in
        */../*) fail "Store archive contains parent traversal: $entry" ;;
    esac
done <<< "$actual_entries"

if zipinfo -l "$ARCHIVE_ONE" | awk 'NR > 3 && $1 ~ /^l/ {found=1} END {exit !found}'; then
    fail "Store archive contains a symbolic link"
fi

EXTRACTED="$TEMP_ROOT/extracted"
mkdir -p -- "$EXTRACTED"
unzip -q "$ARCHIVE_ONE" -d "$EXTRACTED"
[[ -z $(find "$EXTRACTED" -type l -print -quit) ]] || fail "Store archive extracted a symbolic link"
[[ -z $(find "$EXTRACTED" ! -type d ! -type f -print -quit) ]] \
    || fail "Store archive extracted an unsupported object"
diff -qr -- "$PACKAGE_ROOT" "$EXTRACTED" >/dev/null \
    || fail "Store archive payload differs from the source package"

forbidden_content_pattern='Minimalist''V02|PRIVATE-''ASSET|Propriet''ary|assets/wall''papers|/ho''me/|/Us''ers/|[A-Za-z]:\\Us''ers\\|BEGIN (RSA |OPENSSH |EC )?PRIVATE ''KEY|kwinoutputconfig|\.local/share/kscreen'
if grep -aEq "$forbidden_content_pattern" \
    "$EXTRACTED/metadata.json" "$EXTRACTED/manifest.json" \
    "$EXTRACTED/contents/defaults" "$EXTRACTED/contents/colors" \
    "$EXTRACTED/contents/previews/preview.png" \
    "$EXTRACTED/contents/previews/fullscreenpreview.jpg"; then
    fail "Store archive contains a private, user-specific, or display-state marker"
fi
declare -A forbidden_hash=()
while IFS= read -r digest rest || [[ -n ${digest:-} ]]; do
    case "${digest:-}" in
        '' | \#*) continue ;;
    esac
    forbidden_hash[$digest]=1
done < "$REPO_ROOT/release/nonredistributable-payloads.sha256"
while IFS= read -r -d '' archive_file; do
    archive_hash=$(sha256sum -- "$archive_file")
    archive_hash=${archive_hash%% *}
    [[ -z ${forbidden_hash[$archive_hash]+x} ]] \
        || fail "Store archive contains an excluded archival payload hash"
done < <(find "$EXTRACTED" -type f -print0)

TEST_HOME="$TEMP_ROOT/home"
TEST_DATA="$TEST_HOME/.local/share"
TEST_CONFIG="$TEST_HOME/.config"
TEST_STATE="$TEST_HOME/.local/state"
TEST_CACHE="$TEST_HOME/.cache"
TEST_RUNTIME="$TEMP_ROOT/runtime"
mkdir -p -- "$TEST_DATA" "$TEST_CONFIG" "$TEST_STATE" "$TEST_CACHE" "$TEST_RUNTIME"
chmod 700 "$TEST_RUNTIME"

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

run_kpackage --install "$ARCHIVE_ONE" >"$TEMP_ROOT/archive-install.txt"
installed="$TEST_DATA/plasma/look-and-feel/$PACKAGE_ID"
[[ -d $installed ]] || fail "archive install did not stay inside the temporary XDG data root"
run_kpackage --show "$PACKAGE_ID" >"$TEMP_ROOT/archive-show.txt"
grep -Fq 'Minimalist Black' "$TEMP_ROOT/archive-show.txt" \
    || fail "archive-installed package could not be shown"
run_kpackage --upgrade "$ARCHIVE_TWO" >"$TEMP_ROOT/archive-upgrade.txt"
run_kpackage --remove "$PACKAGE_ID" >"$TEMP_ROOT/archive-remove.txt"
[[ ! -e $installed ]] || fail "archive-installed package survived isolated removal"

printf 'PASS: deterministic Store archive, payload safety, and isolated archive lifecycle\n'
