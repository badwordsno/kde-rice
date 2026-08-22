#!/usr/bin/env bash

# Read-only fingerprints for the two display-configuration paths that are
# deliberately outside kde-rice's managed allowlist. Only type and SHA-256
# digests are emitted; configuration contents and absolute paths are not.

display_parent_is_safe() {
    local target_home=$1
    local relative=$2
    local current=$target_home
    local segment
    local -a segments
    local index

    IFS='/' read -r -a segments <<< "$relative"
    for ((index = 0; index < ${#segments[@]} - 1; index++)); do
        segment=${segments[$index]}
        current="$current/$segment"
        if [[ -L $current ]]; then
            return 1
        fi
        if [[ ! -e $current ]]; then
            return 0
        fi
    done
    return 0
}

display_path_fingerprint() {
    local target_home=$1
    local relative=$2
    local path="$target_home/$relative"
    local digest
    local parent
    local base

    if ! display_parent_is_safe "$target_home" "$relative"; then
        return 1
    elif [[ -L $path ]]; then
        return 1
    elif [[ -f $path ]]; then
        digest=$(sha256sum -- "$path" | awk '{print $1}') || return 1
        printf 'file:%s\n' "$digest"
    elif [[ -d $path ]]; then
        parent=$(dirname -- "$path")
        base=$(basename -- "$path")
        digest=$(LC_ALL=C tar --sort=name --format=ustar --numeric-owner \
            --owner=0 --group=0 --mtime='UTC 1970-01-01' -cf - -C "$parent" "$base" 2>/dev/null \
            | sha256sum | awk '{print $1}') || return 1
        printf 'directory:%s\n' "$digest"
    elif [[ -e $path ]]; then
        return 1
    else
        printf 'absent\n'
    fi
}

display_state_lines() {
    local target_home=$1
    local relative
    local fingerprint
    local -a excluded_paths=(
        .config/kwinoutputconfig.json
        .local/share/kscreen
    )

    [[ -n $target_home && $target_home == /* && -d $target_home ]] || return 1
    target_home=$(realpath -e -- "$target_home") || return 1
    [[ $target_home != / ]] || return 1

    for relative in "${excluded_paths[@]}"; do
        fingerprint=$(display_path_fingerprint "$target_home" "$relative") || return 1
        printf '%s\t%s\n' "$relative" "$fingerprint"
    done
}
