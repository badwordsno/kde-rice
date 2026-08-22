#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$TEST_DIR/lib/runtime.sh"
require_test_node

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

metadata_files=()
for metadata_root in \
    "$REPO_ROOT/layouts/plasma" \
    "$REPO_ROOT/plasmoids" \
    "$REPO_ROOT/packages/store"; do
    [[ -d $metadata_root ]] || continue
    while IFS= read -r -d '' metadata_file; do
        metadata_files+=("$metadata_file")
    done < <(find "$metadata_root" -type f \
        \( -name metadata.json -o -name manifest.json \) -print0)
done

((${#metadata_files[@]} > 0)) || fail "no public package metadata was found"

"$NODE_BIN" - "${metadata_files[@]}" <<'NODE'
const fs = require("fs");

const files = process.argv.slice(2);
for (const file of files) {
    let metadata;
    try {
        metadata = JSON.parse(fs.readFileSync(file, "utf8"));
    } catch (error) {
        console.error("FAIL: invalid public package metadata JSON: " + file + ": " + error.message);
        process.exit(1);
    }
    if (metadata === null || Array.isArray(metadata) || typeof metadata !== "object") {
        console.error("FAIL: public package metadata root is not an object: " + file);
        process.exit(1);
    }
}
NODE

printf 'PASS: %d public package metadata files contain valid JSON\n' \
    "${#metadata_files[@]}"
