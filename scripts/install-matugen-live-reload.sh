#!/usr/bin/env bash

set -euo pipefail

PROFILE_ROOT="${FF_ULTIMA_PROFILE_ROOT:-$HOME/.mozilla/firefox}"
DEFAULT_PROFILE_FROM_ENV="${FF_ULTIMA_BETA_PROFILE:-}"
DEFAULT_PROFILE="${DEFAULT_PROFILE_FROM_ENV:-$PROFILE_ROOT/ltotchqe.default-beta}"
DEFAULT_FIREFOX_DIR="${FF_ULTIMA_FIREFOX_DIR:-/opt/firefox-beta}"
PROFILE_DIR=""
FIREFOX_DIR=""
DRY_RUN=0
USE_SUDO=1
ENABLE_PREFS=1
INSTALL_BOOT=1
INSTALL_PROFILE=1
SELECT_PROFILE=0
SELECT_FIREFOX=0
LIST_PROFILES=0
ASSUME_YES=0
INTERVAL_MS=1000

usage() {
    cat <<USAGE
Usage: $(basename "$0") [options]

Installs FF Ultima's optional autoconfig live reload support for
Matugen-generated colors.

Interactive behavior:
  If no --profile is provided and the script is run in a terminal, it shows a
  numbered Firefox profile selector from profiles.ini. Otherwise it falls back
  to $DEFAULT_PROFILE.

Installs, depending on options:
  1. Firefox install-level autoconfig boot files
  2. Profile chrome/scripts/ffu-matugen-live.uc.js live watcher
  3. Profile chrome/utils compatibility files for FF Ultima's optional autoconfig scripts
  4. Profile theme/color-schemes/matugen loader/template files
  5. Optional profile user.js prefs for Matugen/live reload

Defaults:
  --profile-root $PROFILE_ROOT
  --profile      auto-select in terminal, otherwise $DEFAULT_PROFILE
  --firefox-dir  $DEFAULT_FIREFOX_DIR
  --interval-ms  $INTERVAL_MS

Profile options:
  --profile PATH         Firefox profile directory; skips the selector.
  --profile-root PATH    Directory containing profiles.ini.
  --select-profile       Force interactive profile selector.
  --list-profiles        Print detected Firefox profiles and exit.

Firefox install options:
  --firefox-dir PATH     Firefox installation directory containing config.js.
  --select-firefox       Force interactive Firefox install directory selector.
  --no-install-boot      Skip install-level autoconfig boot files.
  --no-sudo              Do not use sudo; fail if install-level files need it.

Profile install options:
  --no-install-profile   Skip profile-side files.
  --enable-prefs         Add/update Matugen/live prefs in profile user.js.
  --no-enable-prefs      Do not add/update profile user.js prefs.
  --interval-ms MS       Poll interval for ultima.matugen.live-reload.interval_ms.

Convenience modes:
  --profile-only         Same as --no-install-boot.
  --boot-only            Install only Firefox install-level boot files.
  --yes                 Do not prompt for final confirmation.
  --dry-run              Print planned actions without copying files.
  -h, --help             Show this help text.

Examples:
  $(basename "$0")
  $(basename "$0") --select-profile --select-firefox
  $(basename "$0") --profile ~/.mozilla/firefox/ltotchqe.default-beta --firefox-dir /opt/firefox-beta
  $(basename "$0") --profile-only --profile ~/.mozilla/firefox/ltotchqe.default-beta
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
        --firefox-dir)
            shift
            [[ $# -gt 0 ]] || fail "--firefox-dir requires a path"
            FIREFOX_DIR="$1"
            ;;
        --select-firefox)
            SELECT_FIREFOX=1
            ;;
        --no-install-boot)
            INSTALL_BOOT=0
            ;;
        --no-install-profile)
            INSTALL_PROFILE=0
            ;;
        --profile-only)
            INSTALL_BOOT=0
            INSTALL_PROFILE=1
            ;;
        --boot-only)
            INSTALL_BOOT=1
            INSTALL_PROFILE=0
            ENABLE_PREFS=0
            ;;
        --no-sudo)
            USE_SUDO=0
            ;;
        --enable-prefs)
            ENABLE_PREFS=1
            ;;
        --no-enable-prefs)
            ENABLE_PREFS=0
            ;;
        --interval-ms)
            shift
            [[ $# -gt 0 ]] || fail "--interval-ms requires a value"
            [[ "$1" =~ ^[0-9]+$ ]] || fail "--interval-ms must be an integer"
            INTERVAL_MS="$1"
            ;;
        --yes)
            ASSUME_YES=1
            ;;
        --dry-run)
            DRY_RUN=1
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

DEFAULT_PROFILE="${DEFAULT_PROFILE_FROM_ENV:-$PROFILE_ROOT/ltotchqe.default-beta}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

required_repo_paths=(
    ".autoconfig/firefox/config.js"
    ".autoconfig/firefox/defaults/pref/config-prefs.js"
    ".autoconfig/chrome/scripts/ffu-matugen-live.uc.js"
    ".autoconfig/chrome/utils/userChrome.js"
    "theme/color-schemes/matugen/ffu-colorscheme.css"
    "theme/color-schemes/matugen/ffu-matugen-colors.template.css"
)

for path in "${required_repo_paths[@]}"; do
    [[ -e "$REPO_ROOT/$path" ]] || fail "missing repository path: $REPO_ROOT/$path"
done

is_tty() {
    [[ -t 0 && -t 1 ]]
}

profile_rows() {
    python3 - "$PROFILE_ROOT" <<'PY'
from pathlib import Path
import configparser
import sys

root = Path(sys.argv[1]).expanduser()
ini = root / "profiles.ini"
if not ini.exists():
    sys.exit(0)

parser = configparser.RawConfigParser()
parser.read(ini)
rows = []
for section in parser.sections():
    if not section.startswith("Profile"):
        continue
    name = parser.get(section, "Name", fallback=section)
    rel = parser.getint(section, "IsRelative", fallback=1)
    raw_path = parser.get(section, "Path", fallback="")
    if not raw_path:
        continue
    profile_path = root / raw_path if rel else Path(raw_path).expanduser()
    default = parser.get(section, "Default", fallback="0") == "1"
    exists = profile_path.exists()
    rows.append((section, name, str(profile_path), default, exists))

rows.sort(key=lambda row: (not row[3], row[1].lower(), row[2]))
for idx, (section, name, path, default, exists) in enumerate(rows, start=1):
    print("|".join([str(idx), section, name, path, "default" if default else "", "exists" if exists else "missing"]))
PY
}

print_profiles() {
    local rows
    rows="$(profile_rows)"
    if [[ -z "$rows" ]]; then
        echo "No Firefox profiles found under: $PROFILE_ROOT"
        return 1
    fi

    printf 'Detected Firefox profiles under %s:\n' "$PROFILE_ROOT"
    while IFS='|' read -r idx section name path default exists; do
        local marks=()
        [[ "$default" == "default" ]] && marks+=(default)
        [[ "$exists" == "missing" ]] && marks+=(missing)
        local suffix=""
        if [[ "${#marks[@]}" -gt 0 ]]; then
            suffix=" (${marks[*]})"
        fi
        printf '  %s) %s [%s]%s\n     %s\n' "$idx" "$name" "$section" "$suffix" "$path"
    done <<< "$rows"
}

select_profile() {
    local rows count choice selected
    rows="$(profile_rows)"
    [[ -n "$rows" ]] || fail "no Firefox profiles found under $PROFILE_ROOT; pass --profile PATH"

    print_profiles
    count="$(printf '%s\n' "$rows" | wc -l)"
    while true; do
        printf 'Select profile [1-%s] or enter a path: ' "$count"
        IFS= read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
            selected="$(printf '%s\n' "$rows" | while IFS='|' read -r idx _section _name path _default _exists; do
                if [[ "$idx" == "$choice" ]]; then
                    printf '%s\n' "$path"
                    break
                fi
            done)"
            [[ -n "$selected" ]] || fail "could not resolve selected profile"
            PROFILE_DIR="$selected"
            return
        fi
        if [[ -n "$choice" ]]; then
            PROFILE_DIR="$choice"
            return
        fi
    done
}

firefox_candidates() {
    python3 <<'PY'
from pathlib import Path
import os
import shutil

candidates = []
for path in [
    os.environ.get("FF_ULTIMA_FIREFOX_DIR"),
    "/opt/firefox-beta",
    "/opt/firefox",
    "/usr/lib/firefox-beta",
    "/usr/lib/firefox",
    "/usr/lib/firefox-developer-edition",
    "/usr/lib/librewolf",
]:
    if path:
        candidates.append(Path(path).expanduser())

for binary in ["firefox-beta", "firefox", "firefox-developer-edition", "librewolf"]:
    found = shutil.which(binary)
    if found:
        candidates.append(Path(found).resolve().parent)


def looks_like_firefox_root(path: Path) -> bool:
    return any([
        (path / "omni.ja").exists(),
        (path / "browser" / "omni.ja").exists(),
        (path / "application.ini").exists() and (path / "defaults").exists(),
        (path / "firefox-bin").exists() and (path / "defaults").exists(),
    ])

seen = set()
for candidate in candidates:
    key = str(candidate)
    if key in seen:
        continue
    seen.add(key)
    if candidate.exists() and looks_like_firefox_root(candidate):
        marker = "config.js" if (candidate / "config.js").exists() else ""
        writable = "writable" if os.access(candidate, os.W_OK) else "needs-root"
        print("|".join([key, marker, writable]))
PY
}

select_firefox_dir() {
    local rows count choice selected idx path marker writable
    rows="$(firefox_candidates)"
    [[ -n "$rows" ]] || fail "no Firefox install directories found; pass --firefox-dir PATH"

    printf 'Detected Firefox install directories:\n'
    idx=0
    while IFS='|' read -r path marker writable; do
        idx=$((idx + 1))
        local suffix=""
        [[ -n "$marker" ]] && suffix=" existing-autoconfig"
        printf '  %s) %s (%s%s)\n' "$idx" "$path" "$writable" "$suffix"
    done <<< "$rows"
    count="$idx"

    while true; do
        printf 'Select Firefox install dir [1-%s] or enter a path: ' "$count"
        IFS= read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
            selected=""
            idx=0
            while IFS='|' read -r path _marker _writable; do
                idx=$((idx + 1))
                if [[ "$idx" -eq "$choice" ]]; then
                    selected="$path"
                    break
                fi
            done <<< "$rows"
            [[ -n "$selected" ]] || fail "could not resolve selected Firefox dir"
            FIREFOX_DIR="$selected"
            return
        fi
        if [[ -n "$choice" ]]; then
            FIREFOX_DIR="$choice"
            return
        fi
    done
}

expand_path() {
    python3 - "$1" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).expanduser())
PY
}

if [[ "$LIST_PROFILES" -eq 1 ]]; then
    print_profiles
    exit 0
fi

if [[ -z "$PROFILE_DIR" && ( "$SELECT_PROFILE" -eq 1 || ( "$INSTALL_PROFILE" -eq 1 && is_tty ) ) ]]; then
    select_profile
fi
PROFILE_DIR="$(expand_path "${PROFILE_DIR:-$DEFAULT_PROFILE}")"
CHROME_DIR="$PROFILE_DIR/chrome"

if [[ -z "$FIREFOX_DIR" && ( "$SELECT_FIREFOX" -eq 1 || ( "$INSTALL_BOOT" -eq 1 && is_tty ) ) ]]; then
    select_firefox_dir
fi
FIREFOX_DIR="$(expand_path "${FIREFOX_DIR:-$DEFAULT_FIREFOX_DIR}")"

[[ "$INSTALL_BOOT" -eq 1 || "$INSTALL_PROFILE" -eq 1 ]] || fail "nothing to install; both boot and profile installs are disabled"
if [[ "$INSTALL_PROFILE" -eq 1 ]]; then
    [[ -d "$PROFILE_DIR" ]] || fail "Firefox profile not found: $PROFILE_DIR"
fi
if [[ "$INSTALL_BOOT" -eq 1 ]]; then
    [[ -d "$FIREFOX_DIR" ]] || fail "Firefox install dir not found: $FIREFOX_DIR"
fi

run() {
    echo "+ $*"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        "$@"
    fi
}

copy_file_with_backup() {
    local src="$1"
    local dst="$2"
    local mode="${3:-0644}"
    local dst_dir
    dst_dir="$(dirname "$dst")"

    run mkdir -p "$dst_dir"
    if [[ -e "$dst" && "$DRY_RUN" -eq 0 ]] && ! cmp -s "$src" "$dst"; then
        run cp -a "$dst" "$dst.bak-ffu-matugen-live-$STAMP"
    fi
    run install -m "$mode" "$src" "$dst"
}

copy_dir_files_with_backup() {
    local src_dir="$1"
    local dst_dir="$2"
    local src
    local rel

    while IFS= read -r -d '' src; do
        rel="${src#"$src_dir"/}"
        copy_file_with_backup "$src" "$dst_dir/$rel"
    done < <(find "$src_dir" -type f -print0)
}

copy_file_with_privilege() {
    local src="$1"
    local dst="$2"
    local mode="${3:-0644}"
    local dst_dir
    dst_dir="$(dirname "$dst")"

    if [[ -w "$dst_dir" ]]; then
        copy_file_with_backup "$src" "$dst" "$mode"
        return
    fi

    if [[ "$USE_SUDO" -eq 0 ]]; then
        fail "destination requires privilege and --no-sudo was set: $dst"
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "+ sudo mkdir -p $dst_dir"
        if [[ -e "$dst" ]]; then
            echo "+ sudo cp -a $dst $dst.bak-ffu-matugen-live-$STAMP   # if content differs"
        fi
        echo "+ sudo install -m $mode $src $dst"
        return
    fi

    if [[ -e "$dst" ]] && ! cmp -s "$src" "$dst"; then
        run sudo cp -a "$dst" "$dst.bak-ffu-matugen-live-$STAMP"
    fi
    run sudo mkdir -p "$dst_dir"
    run sudo install -m "$mode" "$src" "$dst"
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

confirm_plan() {
    [[ "$ASSUME_YES" -eq 0 && "$DRY_RUN" -eq 0 ]] || return 0
    is_tty || return 0

    printf '\nProceed with install? [y/N] '
    local answer
    IFS= read -r answer
    case "$answer" in
        y|Y|yes|YES|Yes) ;;
        *) echo "Aborted."; exit 1 ;;
    esac
}

echo "Installing FF Ultima Matugen live reload support"
echo "  repo:             $REPO_ROOT"
if [[ "$INSTALL_PROFILE" -eq 1 ]]; then
    echo "  profile:          $PROFILE_DIR"
    echo "  profile files:    enabled"
    echo "  profile prefs:    $([[ "$ENABLE_PREFS" -eq 1 ]] && echo enabled || echo disabled)"
    echo "  live interval ms: $INTERVAL_MS"
else
    echo "  profile files:    disabled"
fi
if [[ "$INSTALL_BOOT" -eq 1 ]]; then
    echo "  firefox dir:      $FIREFOX_DIR"
    echo "  boot files:       enabled"
    echo "  sudo:             $([[ "$USE_SUDO" -eq 1 ]] && echo enabled || echo disabled)"
else
    echo "  boot files:       disabled"
fi
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  dry run:          yes"
fi

confirm_plan

if [[ "$INSTALL_BOOT" -eq 1 ]]; then
    copy_file_with_privilege "$REPO_ROOT/.autoconfig/firefox/config.js" \
        "$FIREFOX_DIR/config.js"
    copy_file_with_privilege "$REPO_ROOT/.autoconfig/firefox/defaults/pref/config-prefs.js" \
        "$FIREFOX_DIR/defaults/pref/config-prefs.js"
fi

if [[ "$INSTALL_PROFILE" -eq 1 ]]; then
    run mkdir -p "$CHROME_DIR/utils" "$CHROME_DIR/scripts" "$CHROME_DIR/theme/color-schemes/matugen"
    copy_dir_files_with_backup "$REPO_ROOT/.autoconfig/chrome/utils" "$CHROME_DIR/utils"
    copy_file_with_backup "$REPO_ROOT/.autoconfig/chrome/scripts/ffu-matugen-live.uc.js" \
        "$CHROME_DIR/scripts/ffu-matugen-live.uc.js"
    copy_file_with_backup "$REPO_ROOT/theme/color-schemes/matugen/ffu-colorscheme.css" \
        "$CHROME_DIR/theme/color-schemes/matugen/ffu-colorscheme.css"
    copy_file_with_backup "$REPO_ROOT/theme/color-schemes/matugen/ffu-matugen-colors.template.css" \
        "$CHROME_DIR/theme/color-schemes/matugen/ffu-matugen-colors.template.css"
    if [[ -e "$REPO_ROOT/theme/color-schemes/matugen/readme.md" ]]; then
        copy_file_with_backup "$REPO_ROOT/theme/color-schemes/matugen/readme.md" \
            "$CHROME_DIR/theme/color-schemes/matugen/readme.md"
    fi

    if [[ "$ENABLE_PREFS" -eq 1 ]]; then
        ensure_user_pref "$PROFILE_DIR/user.js" "user.theme.0.default" "false"
        ensure_user_pref "$PROFILE_DIR/user.js" "user.theme.pywalfox" "false"
        ensure_user_pref "$PROFILE_DIR/user.js" "user.theme.matugen" "true"
        ensure_user_pref "$PROFILE_DIR/user.js" "ultima.matugen.live-reload" "true"
        ensure_user_pref "$PROFILE_DIR/user.js" "ultima.matugen.live-reload.interval_ms" "$INTERVAL_MS"
    fi

    if [[ ! -e "$CHROME_DIR/theme/color-schemes/matugen/ffu-matugen-colors.css" ]]; then
        cat <<WARN
warning: generated Matugen CSS is missing:
  $CHROME_DIR/theme/color-schemes/matugen/ffu-matugen-colors.css
Render theme/color-schemes/matugen/ffu-matugen-colors.template.css to that path.
WARN
    fi
fi

cat <<DONE

Install complete.
DONE

if [[ "$INSTALL_BOOT" -eq 1 ]]; then
    cat <<DONE
Restart Firefox once so install-level autoconfig can load the Matugen live watcher.
DONE
fi

if [[ "$INSTALL_PROFILE" -eq 1 ]]; then
    cat <<DONE
After restart, Matugen/Noctalia rewrites of ffu-matugen-colors.css should be live-reloaded by:
  $CHROME_DIR/scripts/ffu-matugen-live.uc.js
DONE
fi
