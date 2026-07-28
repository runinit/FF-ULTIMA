#!/usr/bin/env bash

set -u
set -o pipefail

usage() {
    cat <<'EOF'
Usage:
  audit-firefox-state.sh --profile ABSOLUTE_PATH [--file RELATIVE_PATH]... [--pref NAME]...

Read-only checks:
  - validates the explicit Firefox profile path
  - confirms requested repository files exist and are referenced by a CSS import
  - compares requested files with <profile>/chrome/ byte-for-byte
  - reports exact requested prefs from <profile>/prefs.js

Paths passed to --file are relative to the FF Ultima repository root.
Exit status: 0 all checks pass, 1 a requested check fails, 2 invalid usage.
EOF
}

die_usage() {
    printf 'ERROR: %s\n' "$1" >&2
    usage >&2
    exit 2
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/../../../.." && pwd -P)"
profile_path=""
declare -a requested_files=()
declare -a requested_prefs=()

while (($#)); do
    case "$1" in
        --profile)
            (($# >= 2)) || die_usage "--profile requires a value"
            profile_path="$2"
            shift 2
            ;;
        --file)
            (($# >= 2)) || die_usage "--file requires a value"
            requested_files+=("$2")
            shift 2
            ;;
        --pref)
            (($# >= 2)) || die_usage "--pref requires a value"
            requested_prefs+=("$2")
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die_usage "unknown argument: $1"
            ;;
    esac
done

[[ -n "$profile_path" ]] || die_usage "--profile is required"
[[ "$profile_path" == /* ]] || die_usage "--profile must be an absolute path"
[[ -d "$profile_path" ]] || die_usage "profile directory does not exist: $profile_path"

profile_path="$(cd -- "$profile_path" && pwd -P)"
[[ -d "$profile_path/chrome" ]] || die_usage "profile has no chrome directory: $profile_path"
[[ -f "$repo_root/userChrome.css" ]] || die_usage "could not resolve FF Ultima repository root"

if ! command -v rg >/dev/null 2>&1; then
    die_usage "ripgrep (rg) is required"
fi
if ! command -v cmp >/dev/null 2>&1; then
    die_usage "cmp is required"
fi

status=0

printf 'Repository: %s\n' "$repo_root"
printf 'Profile:    %s\n' "$profile_path"

if command -v firefox >/dev/null 2>&1; then
    firefox_version="$(firefox --version 2>/dev/null || true)"
    [[ -n "$firefox_version" ]] && printf 'Firefox:    %s\n' "$firefox_version"
fi

check_import_reference() {
    local source_path="$1"
    local basename_to_find
    local candidate

    basename_to_find="$(basename -- "$source_path")"
    case "$basename_to_find" in
        userChrome.css|userContent.css)
            return 0
            ;;
    esac

    while IFS= read -r candidate; do
        [[ "$candidate" == "$source_path" ]] && continue
        if rg -q --fixed-strings '@import' "$candidate" &&
            rg -q --fixed-strings "$basename_to_find" "$candidate"; then
            return 0
        fi
    done < <(
        rg -l --glob '*.css' --fixed-strings "$basename_to_find" \
            "$repo_root/userChrome.css" \
            "$repo_root/userContent.css" \
            "$repo_root/theme" 2>/dev/null || true
    )

    return 1
}

for relative_path in "${requested_files[@]}"; do
    [[ -n "$relative_path" ]] || die_usage "--file cannot be empty"
    [[ "$relative_path" != /* ]] || die_usage "--file must be relative: $relative_path"
    case "/$relative_path/" in
        */../*|*/./*)
            die_usage "--file cannot contain . or .. path segments: $relative_path"
            ;;
    esac

    source_path="$repo_root/$relative_path"
    installed_path="$profile_path/chrome/$relative_path"

    if [[ ! -f "$source_path" ]]; then
        printf 'FAIL file missing from repository: %s\n' "$relative_path"
        status=1
        continue
    fi

    if [[ "$relative_path" == *.css ]] && ! check_import_reference "$source_path"; then
        printf 'FAIL no CSS import references: %s\n' "$relative_path"
        status=1
    else
        printf 'PASS repository file/import: %s\n' "$relative_path"
    fi

    if [[ ! -f "$installed_path" ]]; then
        printf 'FAIL installed file missing: %s\n' "$installed_path"
        status=1
    elif cmp -s -- "$source_path" "$installed_path"; then
        printf 'PASS profile byte match: %s\n' "$relative_path"
    else
        printf 'FAIL profile byte mismatch: %s\n' "$relative_path"
        status=1
    fi
done

prefs_file="$profile_path/prefs.js"
if ((${#requested_prefs[@]})); then
    if [[ ! -f "$prefs_file" ]]; then
        printf 'FAIL profile prefs missing: %s\n' "$prefs_file"
        status=1
    else
        for pref_name in "${requested_prefs[@]}"; do
            [[ -n "$pref_name" ]] || die_usage "--pref cannot be empty"
            if pref_line="$(rg -n --fixed-strings "user_pref(\"${pref_name}\"," "$prefs_file" | tail -n 1)" &&
                [[ -n "$pref_line" ]]; then
                printf 'PASS pref %s: %s\n' "$pref_name" "$pref_line"
            else
                printf 'FAIL pref not found: %s\n' "$pref_name"
                status=1
            fi
        done
    fi
fi

exit "$status"
