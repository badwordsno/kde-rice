#!/usr/bin/env bash
set -euo pipefail
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-recovery-integrity.XXXXXX)
trap 'rm -rf -- "$TEMP_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
TARGET_HOME="$TEMP_ROOT/home"
BACKUP="$TEMP_ROOT/backup"
mkdir -p "$TARGET_HOME/.config" "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources/empty"
printf 'baseline\n' > "$TARGET_HOME/.config/kdeglobals"
ln -s 'empty' "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources/link"
# Tests never inherit a real account's XDG roots.
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME KDE_RICE_LOCK_FD

for xdg_name in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME; do
    if env "$xdg_name=$TEMP_ROOT/external" "$REPO_ROOT/scripts/snapshot" \
        --home "$TARGET_HOME" --output "$BACKUP" > "$TEMP_ROOT/xdg.txt" 2>&1; then
        fail "snapshot accepted a noncanonical XDG root"
    fi
    [[ ! -e $BACKUP ]] || fail "XDG refusal wrote a backup"
    grep -Fq "$xdg_name" "$TEMP_ROOT/xdg.txt" || fail "XDG refusal lacks reason"
done

# The outer operation and nested snapshot share one lock without a lock file.
bash -c 'source "$1/scripts/lib/common.sh"; acquire_managed_lock "$2"; "$1/scripts/snapshot" --home "$2" --output "$3"' \
    _ "$REPO_ROOT" "$TARGET_HOME" "$BACKUP" > "$TEMP_ROOT/snapshot.txt"
[[ $(< "$BACKUP/format-version") == 2 && -f $BACKUP/content.sha256 ]] || fail "missing v2 checksum"
for xdg_name in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME; do
    if env "$xdg_name=$TEMP_ROOT/external" "$REPO_ROOT/scripts/restore" \
        --home "$TARGET_HOME" --backup "$BACKUP" --apply > "$TEMP_ROOT/xdg.txt" 2>&1; then
        fail "restore accepted a noncanonical XDG root"
    fi
    [[ ! -e $TARGET_HOME/.local/state ]] || fail "XDG refusal displaced files"
done

# A separate operation must fail before either snapshot or restore writes.
coproc HOLDER { bash -c 'source "$1/scripts/lib/common.sh"; acquire_managed_lock "$2"; printf "ready\n"; read -r finish' _ "$REPO_ROOT" "$TARGET_HOME"; }
holder_pid=$HOLDER_PID
read -r ready <&"${HOLDER[0]}"
[[ $ready == ready ]] || fail "lock holder did not start"
if "$REPO_ROOT/scripts/snapshot" --home "$TARGET_HOME" --output "$TEMP_ROOT/blocked" > "$TEMP_ROOT/locked.txt" 2>&1; then
    fail "concurrent snapshot was accepted"
fi
grep -Fq 'another kde-rice operation' "$TEMP_ROOT/locked.txt" || fail "missing lock refusal"
if "$REPO_ROOT/scripts/restore" --home "$TARGET_HOME" --backup "$BACKUP" --apply > "$TEMP_ROOT/locked.txt" 2>&1; then
    fail "concurrent restore was accepted"
fi
[[ ! -e $TEMP_ROOT/blocked && ! -e $TARGET_HOME/.local/state ]] || fail "lock refusal wrote state"
"$REPO_ROOT/scripts/restore" --home "$TARGET_HOME" --backup "$BACKUP" > "$TEMP_ROOT/preview.txt"
printf 'finish\n' >&"${HOLDER[1]}"
wait "$holder_pid"

# An unreadable live target must not be described as unchanged, and comparison
# failure in either mode must happen before displacement or restoration.
mkdir "$TEMP_ROOT/compare-bin"
cat > "$TEMP_ROOT/compare-bin/tar" <<'MOCK'
#!/usr/bin/env bash
previous=
for argument; do
    if [[ $previous == -C && $argument == "$KDE_RICE_COMPARE_HOME" ]]; then
        exit 1
    fi
    previous=$argument
done
exec "$KDE_RICE_REAL_TAR" "$@"
MOCK
chmod +x "$TEMP_ROOT/compare-bin/tar"
for mode in --dry-run --apply; do
    if KDE_RICE_COMPARE_HOME="$TARGET_HOME" KDE_RICE_REAL_TAR="$(command -v tar)" \
        PATH="$TEMP_ROOT/compare-bin:$PATH" "$REPO_ROOT/scripts/restore" \
        --home "$TARGET_HOME" --backup "$BACKUP" "$mode" > "$TEMP_ROOT/compare-failed.txt" 2>&1; then
        fail "restore accepted a failed current-target comparison in $mode"
    fi
    grep -Fq 'cannot compare current target: .config/kdeglobals; nothing restored' \
        "$TEMP_ROOT/compare-failed.txt" || fail "missing comparison failure diagnostic"
    [[ $(< "$TARGET_HOME/.config/kdeglobals") == baseline ]] || fail "comparison failure changed the target"
    [[ ! -e $TARGET_HOME/.local/state ]] || fail "comparison failure displaced files"
done

printf 'current\n' > "$TARGET_HOME/.config/kdeglobals"
for variant in content missing-checksum extra-entry missing-entry; do
    damaged="$TEMP_ROOT/$variant"
    cp -a "$BACKUP" "$damaged"
    case "$variant" in
        content) printf 'corrupted\n' > "$damaged/payload/.config/kdeglobals" ;;
        missing-checksum) rm "$damaged/content.sha256" ;;
        extra-entry) touch "$damaged/payload/unexpected" ;;
        missing-entry) rmdir "$damaged/payload/.local/share/plasma/plasmoids/org.kde.minimalist.resources/empty" ;;
    esac
    if "$REPO_ROOT/scripts/restore" --home "$TARGET_HOME" --backup "$damaged" --apply > "$TEMP_ROOT/damaged.txt" 2>&1; then
        fail "restore accepted $variant"
    fi
    [[ $(< "$TARGET_HOME/.config/kdeglobals") == current ]] || fail "damaged backup changed target"
    [[ ! -e $TARGET_HOME/.local/state ]] || fail "damaged backup displaced files"
done

# A copy tool returning success with wrong contents must not report completion.
mkdir "$TEMP_ROOT/bin"
cat > "$TEMP_ROOT/bin/cp" <<'MOCK'
#!/usr/bin/env bash
/bin/cp "$@"
for destination; do :; done
if [[ $destination == */.config/kdeglobals ]]; then
    printf 'bad-copy\n' > "$destination"
fi
MOCK
chmod +x "$TEMP_ROOT/bin/cp"
if PATH="$TEMP_ROOT/bin:$PATH" "$REPO_ROOT/scripts/restore" --home "$TARGET_HOME" \
    --backup "$BACKUP" --state-root "$TARGET_HOME/.failed-restore" --apply > "$TEMP_ROOT/failed.txt" 2>&1; then
    fail "incorrect restored contents were reported as complete"
fi
grep -Fq 'restore content verification failed' "$TEMP_ROOT/failed.txt" || fail "missing post-copy diagnostic"
[[ -z $(find "$TARGET_HOME/.failed-restore" -name complete -print -quit) ]] || fail "failed restore marked complete"

"$REPO_ROOT/scripts/restore" --home "$TARGET_HOME" --backup "$BACKUP" \
    --state-root "$TARGET_HOME/.good-restore" --apply > "$TEMP_ROOT/restored.txt"
[[ $(< "$TARGET_HOME/.config/kdeglobals") == baseline ]] || fail "baseline not restored"
[[ -L $TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources/link ]] || fail "symlink not preserved"
[[ -n $(find "$TARGET_HOME/.good-restore" -name complete -print -quit) ]] || fail "verified restore not marked complete"
printf 'PASS: recovery integrity, canonical roots, locking, and post-copy verification\n'
