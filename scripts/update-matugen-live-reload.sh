#!/usr/bin/env bash

set -euo pipefail

DEFAULT_PROFILE="${FF_ULTIMA_BETA_PROFILE:-$HOME/.mozilla/firefox/ltotchqe.default-beta}"
PROFILE_DIR=""
ENABLE_PREFS=0
DRY_RUN=0

usage() {
    cat <<USAGE
Usage: $(basename "$0") [--profile PATH] [--enable-prefs] [--dry-run]

Updates the profile-side FF Ultima Matugen live reload files from this working
tree. This does not install Firefox's root-owned autoconfig boot files; run
scripts/install-matugen-live-reload.sh once for that.

It updates:
  - chrome/scripts/ffu-matugen-live.uc.js live watcher
  - chrome/utils/ compatibility files for FF Ultima's optional autoconfig scripts
  - chrome/theme/color-schemes/matugen/ffu-colorscheme.css
  - chrome/theme/color-schemes/matugen/ffu-matugen-colors.template.css

It intentionally does not overwrite:
  - chrome/theme/color-schemes/matugen/ffu-matugen-colors.css

Options:
  --profile PATH    Firefox profile directory.
  --enable-prefs    Add/update profile user.js prefs for Matugen/live reload.
  --dry-run         Print planned actions without copying files.
  -h, --help        Show this help text.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            shift
            [[ $# -gt 0 ]] || { echo "error: --profile requires a path" >&2; exit 2; }
            PROFILE_DIR="$1"
            ;;
        --enable-prefs)
            ENABLE_PREFS=1
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unexpected argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

PROFILE_DIR="${PROFILE_DIR:-$DEFAULT_PROFILE}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHROME_DIR="$PROFILE_DIR/chrome"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

[[ -d "$PROFILE_DIR" ]] || { echo "error: Firefox profile not found: $PROFILE_DIR" >&2; exit 1; }

required_repo_paths=(
    ".autoconfig/chrome/utils/userChrome.js"
    ".autoconfig/chrome/scripts/ffu-matugen-live.uc.js"
    "theme/color-schemes/matugen/ffu-colorscheme.css"
    "theme/color-schemes/matugen/ffu-matugen-colors.template.css"
)
for path in "${required_repo_paths[@]}"; do
    [[ -e "$REPO_ROOT/$path" ]] || { echo "error: missing repository path: $REPO_ROOT/$path" >&2; exit 1; }
done

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

echo "Updating FF Ultima Matugen live reload profile files"
echo "  repo:    $REPO_ROOT"
echo "  profile: $PROFILE_DIR"

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
    ensure_user_pref "$PROFILE_DIR/user.js" "ultima.matugen.live-reload.interval_ms" "1000"
fi

if [[ ! -e "$CHROME_DIR/theme/color-schemes/matugen/ffu-matugen-colors.css" ]]; then
    cat <<WARN
warning: generated Matugen CSS is missing:
  $CHROME_DIR/theme/color-schemes/matugen/ffu-matugen-colors.css
Render theme/color-schemes/matugen/ffu-matugen-colors.template.css to that path.
WARN
fi

cat <<DONE

Update complete. If scripts/install-matugen-live-reload.sh has already installed
Firefox's autoconfig boot files, restart Firefox once after watcher updates.
DONE
