#!/usr/bin/env bash

set -euo pipefail

DEFAULT_PROFILE="${FF_ULTIMA_TEST_PROFILE:-$HOME/.mozilla/firefox/fe8v2rcc.default-release-1777589610774}"
PROFILE_DIR=""
COPY_USER_JS=1
DRY_RUN=0

usage() {
    cat <<USAGE
Usage: $(basename "$0") [--profile PATH] [--no-user-js] [--dry-run]

Installs the working tree into a Firefox profile for local theme testing.

Defaults to:
  $DEFAULT_PROFILE

Options:
  --profile PATH  Install into a different Firefox profile directory.
  --no-user-js    Do not copy user.js into the profile root.
  --dry-run       Show the target paths without copying files.
  -h, --help      Show this help text.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            shift
            if [[ $# -eq 0 ]]; then
                echo "error: --profile requires a path" >&2
                exit 2
            fi
            PROFILE_DIR="$1"
            ;;
        --no-user-js)
            COPY_USER_JS=0
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$PROFILE_DIR" ]]; then
                PROFILE_DIR="$1"
            else
                echo "error: unexpected argument: $1" >&2
                usage >&2
                exit 2
            fi
            ;;
    esac
    shift
done

PROFILE_DIR="${PROFILE_DIR:-$DEFAULT_PROFILE}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHROME_DIR="$PROFILE_DIR/chrome"

if [[ ! -d "$PROFILE_DIR" ]]; then
    echo "error: Firefox profile not found: $PROFILE_DIR" >&2
    exit 1
fi

for required in userChrome.css userContent.css user.js theme; do
    if [[ ! -e "$REPO_ROOT/$required" ]]; then
        echo "error: missing required repository path: $REPO_ROOT/$required" >&2
        exit 1
    fi
done

echo "Installing FF Ultima test copy"
echo "  repo:    $REPO_ROOT"
echo "  profile: $PROFILE_DIR"
echo "  chrome:  $CHROME_DIR"
if [[ "$COPY_USER_JS" -eq 1 ]]; then
    echo "  user.js: $PROFILE_DIR/user.js"
else
    echo "  user.js: skipped"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Dry run only; no files copied."
    exit 0
fi

mkdir -p "$CHROME_DIR"

# Replace managed theme files while preserving any local customChrome/customContent tweaks.
rm -rf "$CHROME_DIR/theme"
cp -a "$REPO_ROOT/theme" "$CHROME_DIR/theme"
cp -a "$REPO_ROOT/userChrome.css" "$REPO_ROOT/userContent.css" "$CHROME_DIR/"

# The main CSS imports these optional files; create placeholders if the test profile
# does not already have them.
[[ -e "$CHROME_DIR/customChrome.css" ]] || : > "$CHROME_DIR/customChrome.css"
[[ -e "$CHROME_DIR/customContent.css" ]] || : > "$CHROME_DIR/customContent.css"

if [[ "$COPY_USER_JS" -eq 1 ]]; then
    cp -a "$REPO_ROOT/user.js" "$PROFILE_DIR/user.js"
fi

echo "Install complete. Restart Firefox to load the updated chrome CSS."
