#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-fastfetch.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-fastfetch.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing to clean unexpected test directory: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

SOURCE="$REPO_ROOT/config/fastfetch/config.jsonc"
APPLY="$REPO_ROOT/scripts/apply-fastfetch"
TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
mkdir -p -- "$TARGET_HOME/.config/fastfetch" "$MOCK_BIN"
printf 'personal fastfetch config\n' > "$TARGET_HOME/.config/fastfetch/config.jsonc"
printf 'shell sentinel\n' > "$TARGET_HOME/.bashrc"

cat > "$MOCK_BIN/fastfetch" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --version ]]; then
    printf 'fastfetch 2.66.0\n'
    exit 0
fi
[[ ${1:-} == --config && -f ${2:-} ]] || exit 64
grep -Fq '"type": "auto"' "$2" || exit 65
grep -Fq '"key": "RAM"' "$2" || exit 66
! grep -Fqi 'localip' "$2" || exit 67
exit 0
EOF
chmod +x "$MOCK_BIN/fastfetch"

grep -Fxq '.config/fastfetch/config.jsonc' "$REPO_ROOT/config/managed-paths.txt" \
    || fail "Fastfetch config is outside the managed boundary"
grep -Fq '"type": "auto"' "$SOURCE" \
    || fail "Fastfetch automatic distro logo is not preserved"
if grep -Eqi '"type"[[:space:]]*:[[:space:]]*"title"|^[[:space:]]*"separator",[[:space:]]*$' "$SOURCE"; then
    fail "Fastfetch source still renders the user/host title or its underline"
fi
grep -Fq '"key": "RAM"' "$SOURCE" || fail "Fastfetch memory key is not RAM"
if grep -Eqi 'localip|publicip|"type"[[:space:]]*:[[:space:]]*"host"' "$SOURCE"; then
    fail "Fastfetch source exposes a host or network identifier"
fi
for module in os kernel uptime packages shell display de wm theme icons terminal terminalfont cpu gpu memory swap disk; do
    grep -Eq '"(type": )?'"$module"'"' "$SOURCE" \
        || fail "medium-density Fastfetch source omitted $module"
done

before_config=$(sha256sum "$TARGET_HOME/.config/fastfetch/config.jsonc")
before_shell=$(sha256sum "$TARGET_HOME/.bashrc")
PATH="$MOCK_BIN:$PATH" bash "$APPLY" --home "$TARGET_HOME" --install-only --dry-run \
    > "$TEMP_ROOT/dry-run.txt"
grep -Fq 'rollback apply:' "$TEMP_ROOT/dry-run.txt" \
    || fail "Fastfetch dry-run omitted rollback"
[[ $(sha256sum "$TARGET_HOME/.config/fastfetch/config.jsonc") == "$before_config" ]] \
    || fail "Fastfetch dry run changed the existing config"
[[ ! -e $TARGET_HOME/.local ]] || fail "Fastfetch dry run created state"

PATH="$MOCK_BIN:$PATH" bash "$APPLY" --home "$TARGET_HOME" --install-only --apply \
    > "$TEMP_ROOT/apply.txt"
snapshot_path=$(sed -n 's/^Pre-apply snapshot: //p' "$TEMP_ROOT/apply.txt")
[[ -n $snapshot_path && -f $snapshot_path/complete ]] \
    || fail "Fastfetch apply snapshot is incomplete"
cmp -s "$SOURCE" "$TARGET_HOME/.config/fastfetch/config.jsonc" \
    || fail "installed Fastfetch config differs from source"
[[ $(sha256sum "$TARGET_HOME/.bashrc") == "$before_shell" ]] \
    || fail "Fastfetch apply edited shell startup configuration"
grep -Fq 'privacy: omit Host, Local IP, public IP' "$TEMP_ROOT/apply.txt" \
    || fail "Fastfetch privacy policy was not reported"
grep -Fq 'presentation: automatic distro logo' "$TEMP_ROOT/apply.txt" \
    || fail "Fastfetch distro-logo policy was not reported"

bash "$REPO_ROOT/scripts/restore" --backup "$snapshot_path" --home "$TARGET_HOME" \
    --state-root "$TARGET_HOME/.local/state/kde-rice/test-restore" --apply \
    > "$TEMP_ROOT/restore.txt"
[[ $(< "$TARGET_HOME/.config/fastfetch/config.jsonc") == 'personal fastfetch config' ]] \
    || fail "restore did not recover the previous Fastfetch config"
[[ $(sha256sum "$TARGET_HOME/.bashrc") == "$before_shell" ]] \
    || fail "restore changed shell startup configuration"

if rg -n '(^|[[:space:]])(sudo|pkexec|pacman|dnf|apt-get)[[:space:]]' "$APPLY"; then
    fail "Fastfetch component contains a package-manager or privilege-elevation action"
fi

printf 'PASS: managed Fastfetch presentation tests\n'
