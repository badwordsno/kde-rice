#!/usr/bin/env bash

# Shared safety helpers. Caller scripts enable their own shell options.

KDE_RICE_FORMAT_VERSION=1

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

warn() {
    printf 'warning: %s\n' "$*" >&2
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

resolve_dbus_tool() {
    local candidate
    local resolved
    local -a candidates=()

    if [[ -n ${KDE_RICE_DBUS_TOOL+x} ]]; then
        [[ -n $KDE_RICE_DBUS_TOOL && ${KDE_RICE_TEST_MODE:-0} == 1 ]] || {
            printf 'error: KDE_RICE_DBUS_TOOL is an isolated-test seam only\n' >&2
            return 1
        }
        candidates+=("$KDE_RICE_DBUS_TOOL")
    fi
    candidates+=(qdbus6 qdbus-qt6 qdbus)

    for candidate in "${candidates[@]}"; do
        if [[ $candidate == */* ]]; then
            [[ -x $candidate ]] || continue
            printf '%s\n' "$candidate"
            return 0
        fi
        resolved=$(command -v -- "$candidate" 2>/dev/null) || continue
        [[ -x $resolved ]] || continue
        printf '%s\n' "$resolved"
        return 0
    done
    return 1
}

# Plasma's evaluateScript D-Bus reply may concatenate consecutive print()
# calls instead of preserving their newline. Normalize the stable text markers
# so all consumers can parse both live replies and newline-delimited fixtures.
normalize_plasma_probe_output() {
    local output=$1

    output=${output//KDE_RICE_PANEL_STATE schema=/$'\n'KDE_RICE_PANEL_STATE schema=}
    output=${output#$'\n'}
    printf '%s\n' "$output"
}

account_home_for_current_uid() {
    local entry=
    local account_home=
    local passwd_name passwd_password passwd_uid passwd_gid passwd_gecos passwd_home passwd_shell

    if command -v getent >/dev/null 2>&1; then
        entry=$(getent passwd "$EUID" 2>/dev/null || true)
    fi
    if [[ -n $entry ]]; then
        IFS=: read -r passwd_name passwd_password passwd_uid passwd_gid passwd_gecos passwd_home passwd_shell <<< "$entry"
        account_home=$passwd_home
    elif [[ -r /etc/passwd ]]; then
        while IFS=: read -r passwd_name passwd_password passwd_uid passwd_gid passwd_gecos passwd_home passwd_shell; do
            if [[ $passwd_uid == "$EUID" ]]; then
                account_home=$passwd_home
                break
            fi
        done < /etc/passwd
    fi

    [[ -n $account_home && $account_home == /* && -d $account_home ]] || return 1
    realpath -e -- "$account_home"
}

require_canonical_xdg_roots() {
    local target_home=$1
    local xdg_path
    local xdg_expected
    local xdg_name
    local xdg_parent

    for xdg_name in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME; do
        case "$xdg_name" in
            XDG_CONFIG_HOME) xdg_expected="$target_home/.config" ;;
            XDG_DATA_HOME) xdg_expected="$target_home/.local/share" ;;
            XDG_STATE_HOME) xdg_expected="$target_home/.local/state" ;;
        esac
        xdg_path=${!xdg_name-}
        [[ -n $xdg_path ]] || xdg_path=$xdg_expected
        [[ $xdg_path == /* ]] \
            || die "$xdg_name must be unset or use its canonical path inside the target home"
        xdg_path=$(realpath -m -- "$xdg_path") \
            || die "could not normalize $xdg_name safely"
        if [[ $xdg_path != "$xdg_expected" ]]; then
            [[ ! -L $xdg_expected ]] \
                || die "$xdg_name must not be a symlink: $xdg_expected"
            die "$xdg_name must be unset or equal $xdg_expected"
        fi
        xdg_parent=$(dirname -- "$xdg_expected")
        while [[ $xdg_parent != "$target_home" ]]; do
            [[ ! -L $xdg_parent ]] \
                || die "$xdg_name parent path must not contain a symlink: $xdg_parent"
            xdg_parent=$(dirname -- "$xdg_parent")
        done
        [[ ! -L $xdg_expected ]] \
            || die "$xdg_name must not be a symlink: $xdg_expected"
    done
}

require_current_desktop_home() {
    local target_home=$1
    local test_scope=${2:-}
    local environment_home
    local account_home
    local mock_dbus
    local mock_step_runner
    local test_root

    environment_home=$(normalize_existing_directory "${HOME:-}" "current environment home")
    [[ $target_home == "$environment_home" ]] \
        || die "live desktop access is allowed only for the current environment home"

    require_canonical_xdg_roots "$target_home"

    account_home=$(account_home_for_current_uid) \
        || die "could not resolve the current account home safely"
    if [[ $target_home == "$account_home" ]]; then
        [[ ${KDE_RICE_TEST_MODE:-0} != 1 ]] \
            || die "isolated test mode cannot target the current account home"
        return 0
    fi

    # Isolated integration tests may bind HOME to a disposable /tmp tree, but
    # only while every Plasma D-Bus call is forced through a non-system mock in
    # the same kde-rice test tree. This is not a live-apply escape hatch.
    [[ -n $test_scope && ${KDE_RICE_TEST_MODE:-0} == 1 ]] \
        || die "live desktop access is allowed only for the current account home"
    case "$target_home" in
        /tmp/kde-rice-*/*) ;;
        *) die "test-mode home must be inside a /tmp/kde-rice-* tree" ;;
    esac
    test_root=${target_home#/tmp/}
    test_root="/tmp/${test_root%%/*}"
    [[ ${KDE_RICE_DBUS_TOOL:-} == /* ]] \
        || die "test mode requires an absolute KDE_RICE_DBUS_TOOL mock path"
    mock_dbus=$(realpath -e -- "$KDE_RICE_DBUS_TOOL" 2>/dev/null) \
        || die "test-mode D-Bus mock cannot be resolved"
    case "$mock_dbus" in
        "$test_root"/*) ;;
        *) die "test-mode D-Bus tool must resolve inside the same disposable test tree" ;;
    esac
    [[ -x $mock_dbus ]] || die "test-mode D-Bus mock is not executable"

    if [[ $test_scope == bootstrap-mock ]]; then
        [[ ${KDE_RICE_STEP_RUNNER:-} == /* ]] \
            || die "bootstrap test mode requires an absolute step-runner mock path"
        mock_step_runner=$(realpath -e -- "$KDE_RICE_STEP_RUNNER" 2>/dev/null) \
            || die "bootstrap test-mode step runner cannot be resolved"
        case "$mock_step_runner" in
            "$test_root"/*) ;;
            *) die "bootstrap test-mode step runner must resolve inside the same disposable test tree" ;;
        esac
        [[ -x $mock_step_runner ]] || die "bootstrap test-mode step runner is not executable"
    elif [[ $test_scope != dbus-mock ]]; then
        die "unknown isolated test scope"
    fi
}

refuse_root() {
    ((EUID != 0)) || die "run kde-rice as the desktop user, never as root"
}

normalize_existing_directory() {
    local directory=$1
    local label=$2
    local normalized

    [[ -n $directory ]] || die "$label must not be empty"
    [[ $directory == /* ]] || die "$label must be an absolute path: $directory"
    [[ -d $directory ]] || die "$label is not a directory: $directory"

    normalized=$(realpath -e -- "$directory") || die "cannot resolve $label: $directory"
    [[ $normalized != / ]] || die "$label must not be the filesystem root"
    printf '%s\n' "$normalized"
}

normalize_output_path() {
    local path=$1
    local normalized

    [[ -n $path ]] || die "output path must not be empty"
    [[ $path == /* ]] || die "output path must be absolute: $path"
    normalized=$(realpath -m -- "$path") || die "cannot normalize output path: $path"
    [[ $normalized != / ]] || die "output path must not be the filesystem root"
    printf '%s\n' "$normalized"
}

validate_relative_path() {
    local relative=$1
    local segment
    local -a segments

    [[ -n $relative ]] || return 1
    [[ $relative != /* ]] || return 1
    [[ $relative != *$'\n'* && $relative != *$'\r'* && $relative != *$'\t'* ]] || return 1

    IFS='/' read -r -a segments <<< "$relative"
    for segment in "${segments[@]}"; do
        [[ -n $segment && $segment != . && $segment != .. ]] || return 1
    done

    case "$relative" in
        *kwinoutputconfig.json* | .local/share/kscreen | .local/share/kscreen/*)
            return 1
            ;;
    esac

    return 0
}

load_managed_paths() {
    local manifest=$1
    local line
    local -A seen=()

    [[ -f $manifest ]] || die "managed-path manifest not found: $manifest"
    MANAGED_PATHS=()

    while IFS= read -r line || [[ -n $line ]]; do
        line=${line%$'\r'}
        [[ -z $line || $line == \#* ]] && continue
        validate_relative_path "$line" || die "unsafe managed path in $manifest: $line"
        [[ -z ${seen[$line]+x} ]] || die "duplicate managed path in $manifest: $line"
        seen[$line]=1
        MANAGED_PATHS+=("$line")
    done < "$manifest"

    ((${#MANAGED_PATHS[@]} > 0)) || die "managed-path manifest is empty: $manifest"
}

path_type() {
    local path=$1

    if [[ -L $path ]]; then
        printf 'symlink\n'
    elif [[ -f $path ]]; then
        printf 'file\n'
    elif [[ -d $path ]]; then
        printf 'directory\n'
    elif [[ -e $path ]]; then
        printf 'unsupported\n'
    else
        printf 'absent\n'
    fi
}

assert_parent_within_home() {
    local target_home=$1
    local relative=$2
    local parent="$target_home/$(dirname -- "$relative")"
    local probe=$parent
    local resolved

    while [[ ! -e $probe && ! -L $probe ]]; do
        [[ $probe != "$target_home" ]] || break
        probe=$(dirname -- "$probe")
    done

    resolved=$(realpath -e -- "$probe") || die "cannot resolve parent for managed path: $relative"
    case "$resolved" in
        "$target_home" | "$target_home"/*)
            ;;
        *)
            die "managed path escapes target home through its parent: $relative"
            ;;
    esac
}

assert_no_symlink_parents() {
    local root=$1
    local relative=$2
    local current=$root
    local segment
    local -a segments
    local index

    IFS='/' read -r -a segments <<< "$relative"
    for ((index = 0; index < ${#segments[@]} - 1; index++)); do
        segment=${segments[$index]}
        current="$current/$segment"
        [[ ! -L $current ]] || die "snapshot payload contains a symlink parent: $relative"
    done
}

print_managed_paths() {
    local target_home=$1
    local relative
    local type

    for relative in "${MANAGED_PATHS[@]}"; do
        assert_parent_within_home "$target_home" "$relative"
        type=$(path_type "$target_home/$relative")
        printf '%-9s %s\n' "$type" "$relative"
    done
}

js_string_literal() {
    local value=$1
    local character
    local ordinal
    local index
    local LC_ALL=C

    printf '"'
    for ((index = 0; index < ${#value}; ++index)); do
        character=${value:index:1}
        case "$character" in
            '"') printf '\\"' ;;
            '\\') printf '\\\\' ;;
            $'\b') printf '\\b' ;;
            $'\f') printf '\\f' ;;
            $'\n') printf '\\n' ;;
            $'\r') printf '\\r' ;;
            $'\t') printf '\\t' ;;
            *)
                printf -v ordinal '%d' "'$character"
                if ((ordinal < 32)); then
                    printf '\\u%04x' "$ordinal"
                else
                    printf '%s' "$character"
                fi
                ;;
        esac
    done
    printf '"'
}

# Component entry points normally capture their own complete managed snapshot.
# During the integrated bootstrap, however, the transaction has already
# captured that exact scope before any component runs. Reuse it only when the
# receipt and snapshot form a complete, canonical in-home transaction pair.
capture_or_reuse_snapshot() {
    local target_home=$1
    local requested_snapshot=$2
    local snapshot_command=$3
    local output_variable=$4
    local transaction_snapshot=${KDE_RICE_TRANSACTION_SNAPSHOT:-}
    local transaction_receipt=${KDE_RICE_TRANSACTION_RECEIPT:-}
    local snapshot_root
    local receipt_root
    local recorded_snapshot

    if [[ -z $transaction_snapshot && -z $transaction_receipt ]]; then
        "$snapshot_command" --home "$target_home" --output "$requested_snapshot"
        printf -v "$output_variable" '%s' "$requested_snapshot"
        return 0
    fi

    [[ -n $transaction_snapshot && -n $transaction_receipt ]] \
        || die "bootstrap transaction snapshot and receipt must be provided together"
    [[ $transaction_snapshot == /* && $transaction_receipt == /* ]] \
        || die "bootstrap transaction paths must be absolute"
    [[ -d $transaction_snapshot && ! -L $transaction_snapshot \
        && -f $transaction_snapshot/complete && ! -L $transaction_snapshot/complete ]] \
        || die "bootstrap transaction snapshot is incomplete or unsafe"
    [[ -d $transaction_receipt && ! -L $transaction_receipt \
        && -f $transaction_receipt/snapshot-path && ! -L $transaction_receipt/snapshot-path ]] \
        || die "bootstrap transaction receipt is incomplete or unsafe"
    [[ ! -e $transaction_receipt/failed && ! -L $transaction_receipt/failed \
        && ! -e $transaction_receipt/complete && ! -L $transaction_receipt/complete ]] \
        || die "bootstrap transaction receipt is not active"

    transaction_snapshot=$(realpath -e -- "$transaction_snapshot") \
        || die "cannot resolve bootstrap transaction snapshot"
    transaction_receipt=$(realpath -e -- "$transaction_receipt") \
        || die "cannot resolve bootstrap transaction receipt"
    snapshot_root=$(realpath -m -- "$target_home/.local/state/kde-rice/snapshots") \
        || die "cannot resolve bootstrap snapshot root"
    receipt_root=$(realpath -m -- "$target_home/.local/state/kde-rice/bootstrap") \
        || die "cannot resolve bootstrap receipt root"
    case "$transaction_snapshot" in
        "$snapshot_root"/*) ;;
        *) die "bootstrap transaction snapshot is outside the canonical state root" ;;
    esac
    case "$transaction_receipt" in
        "$receipt_root"/*) ;;
        *) die "bootstrap transaction receipt is outside the canonical state root" ;;
    esac

    recorded_snapshot=$(< "$transaction_receipt/snapshot-path")
    [[ $recorded_snapshot == "$transaction_snapshot" ]] \
        || die "bootstrap receipt does not name the active transaction snapshot"

    printf 'Reusing bootstrap baseline snapshot: %s\n' "$transaction_snapshot"
    printf -v "$output_variable" '%s' "$transaction_snapshot"
}
