#!/usr/bin/env bash

set -euo pipefail

DEFAULT_PROFILE_ROOT="${FF_ULTIMA_PROFILE_ROOT:-$HOME/.mozilla/firefox}"
PROFILE_DIR=""
PROFILE_ROOT="$DEFAULT_PROFILE_ROOT"
SELECT_PROFILE=0
LIST_PROFILES=0
DRY_RUN=0
ASSUME_YES=0
UPDATE_BOOT=0
FIREFOX_DIR=""

usage() {
    cat <<USAGE
Usage: $(basename "$0") [options]

Removes the retired FF Ultima Matugen live-reload files from a Firefox profile
and restores Pywalfox as the supported dynamic color bridge.

Options:
  --profile PATH       Firefox profile directory to clean.
  --profile-root PATH  Root containing Firefox profiles. Default:
                       $DEFAULT_PROFILE_ROOT
  --select-profile     Prompt for a profile from --profile-root.
  --list-profiles      List discovered profiles and exit.
  --dry-run            Print planned actions without changing files.
  --yes                Do not prompt before applying changes.
  --update-boot        Refresh Firefox app autoconfig files from this repo.
  --firefox-dir PATH   Firefox application directory for --update-boot.
  -h, --help           Show this help text.
USAGE
}

fail() {
    echo "error: $*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            shift
            [[ $# -gt 0 ]] || fail "--profile requires a path"
            PROFILE_DIR="$1"
            ;;
        --profile-root)
            shift
            [[ $# -gt 0 ]] || fail "--profile-root requires a path"
            PROFILE_ROOT="$1"
            ;;
        --select-profile)
            SELECT_PROFILE=1
            ;;
        --list-profiles)
            LIST_PROFILES=1
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        --yes)
            ASSUME_YES=1
            ;;
        --update-boot)
            UPDATE_BOOT=1
            ;;
        --firefox-dir)
            shift
            [[ $# -gt 0 ]] || fail "--firefox-dir requires a path"
            FIREFOX_DIR="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unexpected argument: $1"
            ;;
    esac
    shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

discover_profiles() {
    [[ -d "$PROFILE_ROOT" ]] || return 0
    find "$PROFILE_ROOT" -mindepth 1 -maxdepth 1 -type d \
        \( -name "*.default*" -o -name "*.release*" -o -name "*.beta*" -o -name "*.dev-edition*" -o -name "*.nightly*" \) \
        | sort
}

mapfile -t DISCOVERED_PROFILES < <(discover_profiles)

if [[ "$LIST_PROFILES" -eq 1 ]]; then
    if [[ "${#DISCOVERED_PROFILES[@]}" -eq 0 ]]; then
        echo "No Firefox profiles found under: $PROFILE_ROOT"
        exit 1
    fi
    printf '%s\n' "${DISCOVERED_PROFILES[@]}"
    exit 0
fi

if [[ "$SELECT_PROFILE" -eq 1 ]]; then
    [[ "${#DISCOVERED_PROFILES[@]}" -gt 0 ]] || fail "no Firefox profiles found under: $PROFILE_ROOT"
    echo "Select a Firefox profile:"
    select selected in "${DISCOVERED_PROFILES[@]}"; do
        if [[ -n "${selected:-}" ]]; then
            PROFILE_DIR="$selected"
            break
        fi
        echo "Invalid selection." >&2
    done
fi

if [[ -z "$PROFILE_DIR" && "${#DISCOVERED_PROFILES[@]}" -eq 1 ]]; then
    PROFILE_DIR="${DISCOVERED_PROFILES[0]}"
fi

if [[ -z "$PROFILE_DIR" && "$UPDATE_BOOT" -eq 0 ]]; then
    fail "no profile selected; use --profile PATH, --select-profile, or --list-profiles"
fi

if [[ "$UPDATE_BOOT" -eq 1 && -z "$FIREFOX_DIR" ]]; then
    fail "--update-boot requires --firefox-dir PATH"
fi

run() {
    echo "+ $*"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        "$@"
    fi
}

confirm() {
    [[ "$DRY_RUN" -eq 1 || "$ASSUME_YES" -eq 1 ]] && return 0
    printf 'Apply these changes? [y/N] '
    read -r answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) echo "Aborted."; exit 1 ;;
    esac
}

backup_file() {
    local path="$1"
    [[ -e "$path" ]] || return 0
    run cp -a "$path" "$path.bak-ffu-matugen-remove-$STAMP"
}

remove_file_if_present() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        run rm -f "$path"
    else
        echo "- missing $path"
    fi
}

ensure_user_pref() {
    local pref_file="$1"
    local pref_name="$2"
    local pref_value="$3"
    local line="user_pref(\"$pref_name\", $pref_value);"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "+ ensure pref $pref_name=$pref_value in $pref_file"
        return
    fi

    touch "$pref_file"
    python3 - "$pref_file" "$pref_name" "$line" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
pref = sys.argv[2]
line = sys.argv[3]
text = path.read_text() if path.exists() else ""
pattern = re.compile(rf'^user_pref\("{re.escape(pref)}",\s*.*?\);\s*$', re.MULTILINE)
if pattern.search(text):
    text = pattern.sub(line, text)
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += line + "\n"
path.write_text(text)
PY
}

install_file_with_backup() {
    local src="$1"
    local dst="$2"
    [[ -e "$src" ]] || fail "missing repository path: $src"
    run mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && "$DRY_RUN" -eq 0 ]] && ! cmp -s "$src" "$dst"; then
        backup_file "$dst"
    fi
    run install -m 0644 "$src" "$dst"
}

if [[ -n "$PROFILE_DIR" ]]; then
    [[ -d "$PROFILE_DIR" ]] || fail "Firefox profile not found: $PROFILE_DIR"
fi

echo "Removing retired FF Ultima Matugen live reload support"
echo "  repo:         $REPO_ROOT"
if [[ -n "$PROFILE_DIR" ]]; then
    echo "  profile:      $PROFILE_DIR"
else
    echo "  profile:      skipped"
fi
if [[ "$UPDATE_BOOT" -eq 1 ]]; then
    echo "  firefox dir:  $FIREFOX_DIR"
fi

confirm

if [[ -n "$PROFILE_DIR" ]]; then
    CHROME_DIR="$PROFILE_DIR/chrome"
    MATUGEN_DIR="$CHROME_DIR/theme/color-schemes/matugen"
    USER_JS="$PROFILE_DIR/user.js"

    remove_file_if_present "$CHROME_DIR/scripts/ffu-matugen-live.uc.js"
    remove_file_if_present "$MATUGEN_DIR/ffu-colorscheme.css"
    remove_file_if_present "$MATUGEN_DIR/ffu-matugen-colors.template.css"
    remove_file_if_present "$MATUGEN_DIR/ffu-matugen-colors.css"
    remove_file_if_present "$MATUGEN_DIR/readme.md"

    if [[ -d "$MATUGEN_DIR" ]]; then
        run rmdir "$MATUGEN_DIR" 2>/dev/null || echo "- kept non-empty $MATUGEN_DIR"
    fi

    backup_file "$USER_JS"
    ensure_user_pref "$USER_JS" "user.theme.0.default" "false"
    ensure_user_pref "$USER_JS" "user.theme.pywalfox" "true"
    ensure_user_pref "$USER_JS" "user.theme.matugen" "false"
    ensure_user_pref "$USER_JS" "ultima.matugen.live-reload" "false"
fi

if [[ "$UPDATE_BOOT" -eq 1 ]]; then
    [[ -d "$FIREFOX_DIR" ]] || fail "Firefox application directory not found: $FIREFOX_DIR"
    install_file_with_backup "$REPO_ROOT/.autoconfig/firefox/config.js" "$FIREFOX_DIR/config.js"
    install_file_with_backup "$REPO_ROOT/.autoconfig/firefox/defaults/pref/config-prefs.js" \
        "$FIREFOX_DIR/defaults/pref/config-prefs.js"
fi

cat <<DONE

Removal complete. Restart Firefox so profile CSS prefs and autoconfig changes are re-read.
Pywalfox remains the supported dynamic color path; apply Pywalfox colors and keep
user.theme.pywalfox=true for FF Ultima's dynamic palette bridge.
DONE
