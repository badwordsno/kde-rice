#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
BUILDER="$REPO_ROOT/scripts/build-extended-release"
VERSION=$(< "$REPO_ROOT/VERSION")
ARCHIVE_NAME="minimalist-black-kde-extended-$VERSION.tar.xz"
MANIFEST="$REPO_ROOT/release/extended-manifest.txt"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

for command_name in cmp cp find grep mktemp realpath sha256sum tar touch xz; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "required Extended release test tool is unavailable: $command_name"
done
[[ -x $BUILDER ]] || fail "Extended release builder is not executable"

TEMP_ROOT=$(mktemp -d /tmp/minimalist-black-kde-extended-test.XXXXXX)
cleanup() {
    case "$TEMP_ROOT" in
        /tmp/minimalist-black-kde-extended-test.*) rm -rf -- "$TEMP_ROOT" ;;
    esac
}
trap cleanup EXIT

copy_public_source() {
    local destination=$1
    local relative
    mkdir -p -- "$destination"
    while IFS= read -r relative || [[ -n $relative ]]; do
        case "$relative" in
            '' | \#*) continue ;;
        esac
        (
            cd -- "$REPO_ROOT"
            cp -a --parents -- "$relative" "$destination"
        )
    done < "$MANIFEST"
}

FIXTURE="$TEMP_ROOT/source"
copy_public_source "$FIXTURE"
find "$FIXTURE" -type f -exec touch -d '@946684800' -- {} +

OUTPUT_ONE="$TEMP_ROOT/output-one"
OUTPUT_TWO="$TEMP_ROOT/output-two"
(
    umask 077
    TZ=Pacific/Honolulu SOURCE_DATE_EPOCH=315532800 \
        "$BUILDER" --source "$FIXTURE" --output "$OUTPUT_ONE"
) > "$TEMP_ROOT/build-one.txt"
find "$FIXTURE" -type f -exec touch -d '@1700000000' -- {} +
(
    umask 022
    TZ=Asia/Seoul SOURCE_DATE_EPOCH=315532800 \
        "$BUILDER" --source "$FIXTURE" --output "$OUTPUT_TWO"
) > "$TEMP_ROOT/build-two.txt"

ARCHIVE_ONE="$OUTPUT_ONE/$ARCHIVE_NAME"
ARCHIVE_TWO="$OUTPUT_TWO/$ARCHIVE_NAME"
[[ -s $ARCHIVE_ONE && -s $ARCHIVE_TWO ]] \
    || fail "Extended builder did not create both archives"
hash_one=$(sha256sum -- "$ARCHIVE_ONE")
hash_two=$(sha256sum -- "$ARCHIVE_TWO")
[[ ${hash_one%% *} == "${hash_two%% *}" ]] \
    || fail "Extended archive changes with source mtime, timezone, or umask"
(
    cd -- "$OUTPUT_ONE"
    sha256sum --check "$ARCHIVE_NAME.sha256"
) >/dev/null || fail "Extended archive checksum sidecar does not verify"

entries=$(tar -tJf "$ARCHIVE_ONE")
while IFS= read -r entry; do
    [[ $entry != /* ]] || fail "Extended archive contains an absolute path: $entry"
    case "/$entry/" in
        */../*) fail "Extended archive contains parent traversal: $entry" ;;
    esac
    case "$entry" in
        "minimalist-black-kde-extended-$VERSION" | "minimalist-black-kde-extended-$VERSION"/*) ;;
        *) fail "Extended archive contains an unexpected root: $entry" ;;
    esac
done <<< "$entries"
if tar -tvJf "$ARCHIVE_ONE" | awk '$1 ~ /^[lhbcps]/ {found=1} END {exit !found}'; then
    fail "Extended archive contains a link or special object"
fi

EXTRACTED_PARENT="$TEMP_ROOT/extracted"
mkdir -p -- "$EXTRACTED_PARENT"
tar -xJf "$ARCHIVE_ONE" -C "$EXTRACTED_PARENT"
EXTRACTED="$EXTRACTED_PARENT/minimalist-black-kde-extended-$VERSION"
[[ -d $EXTRACTED && ! -L $EXTRACTED ]] || fail "Extended archive root is missing"
[[ -z $(find "$EXTRACTED" -type l -print -quit) ]] \
    || fail "Extended archive extracted a symlink"
[[ -z $(find "$EXTRACTED" ! -type d ! -type f -print -quit) ]] \
    || fail "Extended archive extracted an unsupported object"

expected_files=$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$MANIFEST")
actual_files=$(find "$EXTRACTED" -type f -printf '%P\n' | LC_ALL=C sort)
[[ $actual_files == "$expected_files" ]] || fail "Extended archive and manifest differ"
while IFS= read -r relative; do
    cmp -s -- "$REPO_ROOT/$relative" "$EXTRACTED/$relative" \
        || fail "Extended archive changed source bytes: $relative"
done <<< "$expected_files"

for forbidden_path in \
    assets \
    private \
    scripts/apply-personal-wallpaper \
    tests/test-personal-wallpaper.sh \
    tests/test-private-restore-compat.sh \
    .git \
    .agents \
    .codex; do
    [[ ! -e $EXTRACTED/$forbidden_path && ! -L $EXTRACTED/$forbidden_path ]] \
        || fail "Extended archive contains excluded path: $forbidden_path"
done

declare -A forbidden_hash=()
while IFS= read -r digest rest || [[ -n ${digest:-} ]]; do
    case "${digest:-}" in
        '' | \#*) continue ;;
    esac
    forbidden_hash[$digest]=1
done < "$EXTRACTED/release/nonredistributable-payloads.sha256"
while IFS= read -r -d '' public_file; do
    digest=$(sha256sum -- "$public_file")
    digest=${digest%% *}
    [[ -z ${forbidden_hash[$digest]+x} ]] \
        || fail "Extended archive contains an excluded payload hash"
done < <(find "$EXTRACTED" -type f -print0)

TRAVERSAL_SOURCE="$TEMP_ROOT/traversal-source"
cp -a -- "$FIXTURE" "$TRAVERSAL_SOURCE"
printf '../outside\n' >> "$TRAVERSAL_SOURCE/release/extended-manifest.txt"
if "$BUILDER" --source "$TRAVERSAL_SOURCE" --output "$TEMP_ROOT/traversal-output" \
    > "$TEMP_ROOT/traversal.txt" 2>&1; then
    fail "Extended builder accepted a parent-traversal manifest entry"
fi

SYMLINK_SOURCE="$TEMP_ROOT/symlink-source"
cp -a -- "$FIXTURE" "$SYMLINK_SOURCE"
rm -f -- "$SYMLINK_SOURCE/README.md"
ln -s -- /etc/passwd "$SYMLINK_SOURCE/README.md"
if "$BUILDER" --source "$SYMLINK_SOURCE" --output "$TEMP_ROOT/symlink-source-output" \
    > "$TEMP_ROOT/symlink-source.txt" 2>&1; then
    fail "Extended builder accepted a symlinked source entry"
fi

MARKER_SOURCE="$TEMP_ROOT/marker-source"
cp -a -- "$FIXTURE" "$MARKER_SOURCE"
printf '%s\n' 'PRIVATE-''ASSET' >> "$MARKER_SOURCE/README.md"
if "$BUILDER" --source "$MARKER_SOURCE" --output "$TEMP_ROOT/marker-output" \
    > "$TEMP_ROOT/marker.txt" 2>&1; then
    fail "Extended builder accepted a forbidden archival marker"
fi

HOME_PATH_SOURCE="$TEMP_ROOT/home-path-source"
cp -a -- "$FIXTURE" "$HOME_PATH_SOURCE"
printf '%s\n' '/ho''me/example/private-snapshot' >> "$HOME_PATH_SOURCE/README.md"
if "$BUILDER" --source "$HOME_PATH_SOURCE" --output "$TEMP_ROOT/home-path-output" \
    > "$TEMP_ROOT/home-path.txt" 2>&1; then
    fail "Extended builder accepted an absolute user-home path"
fi

BINARY_MARKER_SOURCE="$TEMP_ROOT/binary-marker-source"
cp -a -- "$FIXTURE" "$BINARY_MARKER_SOURCE"
printf '\n%s\n' 'BEGIN PRIVATE ''KEY' \
    >> "$BINARY_MARKER_SOURCE/packages/store/io.github.badwordsno.minimalistblack/contents/previews/preview.png"
if "$BUILDER" --source "$BINARY_MARKER_SOURCE" --output "$TEMP_ROOT/binary-marker-output" \
    > "$TEMP_ROOT/binary-marker.txt" 2>&1; then
    fail "Extended builder accepted a credential marker appended to a binary"
fi

SYMLINK_OUTPUT="$TEMP_ROOT/symlink-output"
SENTINEL="$TEMP_ROOT/sentinel"
mkdir -p -- "$SYMLINK_OUTPUT"
printf 'preserve-me\n' > "$SENTINEL"
ln -s -- "$SENTINEL" "$SYMLINK_OUTPUT/$ARCHIVE_NAME"
if "$BUILDER" --source "$FIXTURE" --output "$SYMLINK_OUTPUT" \
    > "$TEMP_ROOT/symlink-output.txt" 2>&1; then
    fail "Extended builder accepted a symlinked archive target"
fi
[[ $(< "$SENTINEL") == preserve-me ]] \
    || fail "Extended builder overwrote a symlink target"

OUTPUT_DIRECTORY_TARGET="$TEMP_ROOT/output-directory-target"
OUTPUT_DIRECTORY_LINK="$TEMP_ROOT/output-directory-link"
mkdir -p -- "$OUTPUT_DIRECTORY_TARGET"
ln -s -- "$OUTPUT_DIRECTORY_TARGET" "$OUTPUT_DIRECTORY_LINK"
if "$BUILDER" --source "$FIXTURE" --output "$OUTPUT_DIRECTORY_LINK" \
    > "$TEMP_ROOT/symlink-directory.txt" 2>&1; then
    fail "Extended builder accepted a symlinked output directory"
fi
[[ -z $(find "$OUTPUT_DIRECTORY_TARGET" -mindepth 1 -print -quit) ]] \
    || fail "Extended builder wrote through a symlinked output directory"

printf 'PASS: deterministic, allowlisted, public-safe Extended source archive\n'
