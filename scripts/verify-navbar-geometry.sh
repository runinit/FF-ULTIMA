#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

USER_CHROME="$REPO_ROOT/userChrome.css"
USER_JS="$REPO_ROOT/user.js"
NAVBAR="$REPO_ROOT/theme/settings-navbar.css"
URLBAR="$REPO_ROOT/theme/settings-urlbar.css"
GLOBAL="$REPO_ROOT/theme/ffu-global-positioning.css"

checks=0

pass() {
    printf 'ok - %s\n' "$1"
}

fail() {
    printf 'error - %s\n' "$1" >&2
    exit 1
}

assert_file() {
    local path="$1"
    local description="$2"

    [[ -e "$path" ]] || fail "$description missing: $path"
    checks=$((checks + 1))
    pass "$description"
}

assert_contains() {
    local file="$1"
    local needle="$2"
    local description="$3"

    grep -Fq -- "$needle" "$file" || fail "$description missing in ${file#$REPO_ROOT/}: $needle"
    checks=$((checks + 1))
    pass "$description"
}

assert_regex() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    grep -Eq -- "$pattern" "$file" || fail "$description missing in ${file#$REPO_ROOT/}: $pattern"
    checks=$((checks + 1))
    pass "$description"
}

assert_not_regex() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if grep -Eq -- "$pattern" "$file"; then
        fail "$description found in ${file#$REPO_ROOT/}: $pattern"
    fi
    checks=$((checks + 1))
    pass "$description"
}

assert_block_contains() {
    local block="$1"
    local needle="$2"
    local description="$3"

    [[ "$block" == *"$needle"* ]] || fail "$description missing: $needle"
    checks=$((checks + 1))
    pass "$description"
}

assert_block_not_contains() {
    local block="$1"
    local needle="$2"
    local description="$3"

    if [[ "$block" == *"$needle"* ]]; then
        fail "$description found: $needle"
    fi
    checks=$((checks + 1))
    pass "$description"
}

assert_file "$USER_CHROME" "userChrome.css is present"
assert_file "$USER_JS" "user.js is present"
assert_file "$NAVBAR" "navbar settings module is present"
assert_file "$URLBAR" "urlbar settings module is present"
assert_file "$GLOBAL" "global positioning module is present"

# Resolve userChrome theme imports; customChrome.css is intentionally optional for users.
while IFS= read -r import_path; do
    [[ -n "$import_path" ]] || continue
    assert_file "$REPO_ROOT/$import_path" "import resolves: $import_path"
done < <(
    grep -Eo '@import url\([^)]+\)' "$USER_CHROME" \
        | sed -E 's/@import url\(([^)]+)\).*/\1/' \
        | grep '^theme/'
)

assert_contains "$USER_CHROME" '@import url(theme/ffu-global-positioning.css);' "userChrome imports global positioning before settings"
assert_contains "$USER_CHROME" '@import url(theme/settings-urlbar.css);' "userChrome imports urlbar settings"
assert_contains "$USER_CHROME" '@import url(theme/settings-navbar.css);' "userChrome imports navbar settings"

assert_contains "$USER_JS" 'user_pref("ultima.navbar.autohide", false);' "user.js declares navbar autohide pref"
assert_contains "$USER_JS" 'user_pref("ultima.navbar.float", false);' "user.js declares navbar float pref"
assert_contains "$USER_JS" 'user_pref("ultima.navbar.float.fullsize", false);' "user.js declares navbar fullsize float pref"
assert_contains "$USER_JS" 'user_pref("ultima.navbar.position", "top");' "user.js declares navbar position pref"
assert_contains "$USER_JS" 'user_pref("ultima.urlbar.float", false);' "user.js declares urlbar float pref"
assert_not_regex "$USER_JS" 'user_pref\("ultima\.(navbar|urlbar)\.(bottom|fixed|geometry|spring|searchmode\.bottom|search\.oneoffs)' "bottom geometry fix adds no new user-facing prefs"

assert_contains "$GLOBAL" '--uc-topbars-combined-height: calc(var(--uc-menubar-height) + var(--uc-navbar-height) + var(--uc-tabbar-height) + var(--uc-bookbar-height));' "global positioning owns combined toolbar height"
assert_contains "$GLOBAL" '--uc-navbar-autohide-edge-seam: 3px;' "global positioning owns autohide edge seam"
assert_contains "$GLOBAL" '--uc-navbar-autohide-hidden-offset:' "global positioning owns autohide hidden offset"
assert_contains "$GLOBAL" '--uc-navbar-autohide-hover-offset:' "global positioning owns autohide hover offset"
assert_contains "$GLOBAL" '--uc-navbar-autohide-content-offset:' "global positioning owns autohide content offset"

assert_contains "$NAVBAR" '@media -moz-pref("ultima.navbar.autohide")' "navbar settings owns autohide pref gate"
assert_contains "$NAVBAR" '#navigator-toolbox {' "navbar settings scopes navigator toolbox rules"
assert_contains "$NAVBAR" 'position: absolute !important;' "autohide keeps toolbox absolute"
assert_contains "$NAVBAR" 'top: var(--uc-navbar-autohide-hidden-offset);' "top autohide uses shared hidden offset"
assert_contains "$NAVBAR" 'bottom: var(--uc-navbar-autohide-hidden-offset);' "bottom autohide uses shared hidden offset"
assert_contains "$NAVBAR" 'top: var(--uc-navbar-autohide-hover-offset);' "top hover zone uses shared hover offset"
assert_contains "$NAVBAR" 'bottom: var(--uc-navbar-autohide-hover-offset);' "bottom hover zone uses shared hover offset"
assert_contains "$NAVBAR" '--uc-navbar-autohide-top-content-margin: var(--uc-navbar-autohide-edge-seam);' "top hidden content margin keeps seam"
assert_contains "$NAVBAR" '--uc-navbar-autohide-top-content-margin: var(--uc-navbar-autohide-content-offset);' "top revealed content margin reserves toolbar height"
assert_contains "$NAVBAR" 'margin-top: var(--uc-navbar-autohide-top-content-margin) !important;' "browser margin follows top autohide contract"

assert_contains "$NAVBAR" '@media not -moz-pref("ultima.navbar.position","bottom")' "navbar has top-position pref gates"
assert_contains "$NAVBAR" '@media -moz-pref("ultima.navbar.position","bottom")' "navbar has bottom-position pref gates"
assert_contains "$NAVBAR" '/* nav bar bottom position without autohide/float' "bottom fixed mode block remains present"
assert_contains "$NAVBAR" '#browser { order: 1 !important; }' "bottom fixed mode keeps browser before toolbox"
assert_contains "$NAVBAR" '#navigator-toolbox { order: 2 !important; }' "bottom fixed mode keeps toolbox after browser"

bottom_fixed_navbar_block="$(awk '/\/\* nav bar bottom position without autohide\/float/ {capture=1} /\/\* tweak to allow urlbar/ {capture=0} capture {print}' "$NAVBAR")"
assert_block_contains "$bottom_fixed_navbar_block" '@media -moz-pref("ultima.navbar.position","bottom")' "bottom fixed navbar block is bottom-position gated"
assert_block_contains "$bottom_fixed_navbar_block" '@media not -moz-pref("ultima.navbar.autohide")' "bottom fixed navbar block excludes autohide"
assert_block_contains "$bottom_fixed_navbar_block" '@media not -moz-pref("ultima.navbar.float")' "bottom fixed navbar block excludes navbar float"
assert_block_contains "$bottom_fixed_navbar_block" '@media not -moz-pref("ultima.navbar.float.fullsize")' "bottom fixed navbar block excludes fullsize navbar float"
assert_block_contains "$bottom_fixed_navbar_block" '--uc-bottom-navbar-urlbar-offset: 24px;' "bottom fixed navbar block owns urlbar upward offset"
assert_block_contains "$bottom_fixed_navbar_block" '--uc-bottom-navbar-urlbar-margin: 36px;' "bottom fixed navbar block owns urlbar upward margin"
assert_block_contains "$bottom_fixed_navbar_block" '--uc-bottom-navbar-search-one-offs-margin: 6px;' "bottom fixed navbar block owns search one-offs margin"
assert_regex "$NAVBAR" '@media \(-moz-pref\("ultima\.navbar\.autohide"\)\) or \(-moz-pref\("ultima\.navbar\.float"\)\) or \(-moz-pref\("ultima\.navbar\.float\.fullsize"\)\)' "bottom urlbar spring-up gate covers autohide and float modes"
assert_contains "$NAVBAR" '@media not -moz-pref("ultima.urlbar.float")' "bottom urlbar spring-up respects urlbar float pref"

bottom_fixed_urlbar_block="$(awk '/\/\* bottom fixed navbar urlbar\/search alignment/ {capture=1} /@media -moz-pref\("ultima.urlbar.float"\)/ {capture=0} capture {print}' "$URLBAR")"
assert_block_contains "$bottom_fixed_urlbar_block" '@media -moz-pref("ultima.navbar.position","bottom")' "bottom fixed urlbar block is bottom-position gated"
assert_block_contains "$bottom_fixed_urlbar_block" '@media not -moz-pref("ultima.navbar.autohide")' "bottom fixed urlbar block excludes autohide"
assert_block_contains "$bottom_fixed_urlbar_block" '@media not -moz-pref("ultima.navbar.float")' "bottom fixed urlbar block excludes navbar float"
assert_block_contains "$bottom_fixed_urlbar_block" '@media not -moz-pref("ultima.navbar.float.fullsize")' "bottom fixed urlbar block excludes fullsize navbar float"
assert_block_contains "$bottom_fixed_urlbar_block" '@media not -moz-pref("ultima.urlbar.float")' "bottom fixed urlbar block excludes urlbar float"
assert_block_not_contains "$bottom_fixed_urlbar_block" '@media -moz-pref("ultima.urlbar.float")' "bottom fixed urlbar block does not broaden urlbar float"
assert_block_contains "$bottom_fixed_urlbar_block" '#urlbar[breakout-extend],' "bottom fixed urlbar handles breakout extension"
assert_block_contains "$bottom_fixed_urlbar_block" ':root:has(#urlbar-searchmode-switcher[open]) #urlbar' "bottom fixed urlbar handles searchmode switcher popup"
assert_block_contains "$bottom_fixed_urlbar_block" 'top: unset !important;' "bottom fixed urlbar clears top offset"
assert_block_contains "$bottom_fixed_urlbar_block" 'bottom: var(--uc-bottom-navbar-urlbar-offset, 24px) !important;' "bottom fixed urlbar anchors upward from bottom chrome"
assert_block_contains "$bottom_fixed_urlbar_block" 'margin-bottom: var(--uc-bottom-navbar-urlbar-margin, 36px) !important;' "bottom fixed urlbar reserves upward popup margin"
assert_block_contains "$bottom_fixed_urlbar_block" '.search-one-offs:not([hidden])' "bottom fixed urlbar handles visible search one-offs"
assert_block_contains "$bottom_fixed_urlbar_block" 'margin-bottom: var(--uc-bottom-navbar-search-one-offs-margin, 6px) !important;' "bottom fixed search one-offs get upward spacing"
assert_contains "$URLBAR" '@media -moz-pref("ultima.urlbar.float")' "urlbar float pref gate remains present"
assert_contains "$URLBAR" '#urlbar, :root:has(#urlbar-searchmode-switcher[open]) #urlbar' "urlbar float searchmode selector remains scoped"

assert_contains "$NAVBAR" '#tabContextMenu:hover' "popup exception keeps tab context hover state"
assert_contains "$NAVBAR" '#tabContextMenu[state="open"]' "popup exception keeps tab context open state"
assert_contains "$NAVBAR" '#tabContextMenu[state="showing"]' "popup exception keeps tab context showing state"
assert_contains "$NAVBAR" '#tabContextMenu[open]' "popup exception keeps tab context open attribute"
assert_contains "$NAVBAR" '#tabContextMenu[open="true"]' "popup exception keeps tab context open=true attribute"
assert_contains "$NAVBAR" '#window-modal-dialog[open]' "popup exception keeps modal dialog open state"
assert_contains "$NAVBAR" '#downloadsPanel[panelopen="true"]' "popup exception keeps downloads panel open state"
assert_contains "$NAVBAR" '#protections-popup[panelopen="true"]' "popup exception keeps protections popup open state"

autohide_block="$(awk '/\/\* nav bar autohide / {capture=1} /@media -moz-pref\("ultima.navbar.float"\)/ {capture=0} capture {print}' "$NAVBAR")"
if grep -Eq 'inFullscreen|sizemode="fullscreen"|fullscreen' <<< "$autohide_block"; then
    fail "top autohide block contains fullscreen-specific selector"
fi
checks=$((checks + 1))
pass "top autohide block avoids fullscreen-specific selectors"

printf 'All %d navbar geometry checks passed.\n' "$checks"
