#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

USER_CHROME="$REPO_ROOT/userChrome.css"
USER_JS="$REPO_ROOT/user.js"
GLOBAL="$REPO_ROOT/theme/ffu-global-positioning.css"
NAVBAR="$REPO_ROOT/theme/settings-navbar.css"
SPECIAL_CONFIGS="$REPO_ROOT/theme/ffu-special-configs.css"
NAVBAR_GEOMETRY_VERIFIER="$REPO_ROOT/scripts/verify-navbar-geometry.sh"
URLBAR_FINDBAR_VERIFIER="$REPO_ROOT/scripts/verify-urlbar-findbar-state.sh"
FULLSCREEN_VERIFIER="$REPO_ROOT/scripts/verify-fullscreen-autohide.sh"
LIVE_FULLSCREEN_VERIFIER="$REPO_ROOT/scripts/verify-fullscreen-autohide-live.py"
DOM_FULLSCREEN_FIXTURE="$REPO_ROOT/scripts/fixtures/dom-fullscreen.html"

checks=0

pass() {
    printf 'ok - %s\n' "$1"
}

fail() {
    printf 'error - %s\n' "$1" >&2
    exit 1
}

relative_path() {
    local path="$1"
    printf '%s' "${path#$REPO_ROOT/}"
}

assert_file() {
    local path="$1"
    local description="$2"

    [[ -e "$path" ]] || fail "$description missing: $path"
    checks=$((checks + 1))
    pass "$description"
}

assert_executable() {
    local path="$1"
    local description="$2"

    [[ -x "$path" ]] || fail "$description is not executable: $(relative_path "$path")"
    checks=$((checks + 1))
    pass "$description"
}

assert_contains() {
    local file="$1"
    local needle="$2"
    local description="$3"

    grep -Fq -- "$needle" "$file" || fail "$description missing in $(relative_path "$file"): $needle"
    checks=$((checks + 1))
    pass "$description"
}

assert_regex() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    grep -Eq -- "$pattern" "$file" || fail "$description missing in $(relative_path "$file"): $pattern"
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

extract_css_block() {
    local file="$1"
    local start="$2"

    awk -v start="$start" '
        index($0, start) { capture = 1 }
        capture {
            print
            line = $0
            opens = gsub(/\{/, "{", line)
            line = $0
            closes = gsub(/\}/, "}", line)
            depth += opens - closes
            seen++
            if (seen > 1 && depth <= 0) {
                exit
            }
        }
    ' "$file"
}

assert_nonempty_block() {
    local block="$1"
    local owner="$2"
    local selector="$3"

    [[ -n "$block" ]] || fail "$owner does not contain expected fullscreen boundary block: $selector"
    checks=$((checks + 1))
    pass "$owner contains boundary block: $selector"
}

assert_no_unexpected_fullscreen_prefs() {
    local unexpected=""

    unexpected="$(
        grep -En 'user_pref\("[^"]*((full[-.]?screen|fullscreen|domfullscreen|inDOMFullscreen).*(autohide|geometry|margin|offset|radius|border|seam|content)|(autohide|geometry|margin|offset|radius|border|seam|content).*(full[-.]?screen|fullscreen|domfullscreen|inDOMFullscreen)|autohide\.(edge|seam|hidden|hover|content))' "$USER_JS" \
            | grep -Ev 'user_pref\("full-screen-api\.(transition-duration\.(enter|leave)|warning\.timeout)"' \
            || true
    )"

    if [[ -n "$unexpected" ]]; then
        fail "user.js introduced user-facing fullscreen/autohide geometry pref(s) outside the established navbar/urlbar/full-screen-api contract: $unexpected"
    fi
    checks=$((checks + 1))
    pass "user.js has no unexpected fullscreen/autohide geometry prefs"
}

assert_file "$USER_CHROME" "userChrome.css is present"
assert_file "$USER_JS" "user.js is present"
assert_file "$GLOBAL" "global positioning module is present"
assert_file "$NAVBAR" "navbar settings module is present"
assert_file "$SPECIAL_CONFIGS" "special configs module is present"
assert_file "$NAVBAR_GEOMETRY_VERIFIER" "S01 navbar geometry verifier is present"
assert_file "$URLBAR_FINDBAR_VERIFIER" "S02 urlbar/findbar verifier is present"
assert_file "$FULLSCREEN_VERIFIER" "S03 fullscreen autohide verifier is present"
assert_file "$LIVE_FULLSCREEN_VERIFIER" "S03 live fullscreen autohide verifier is present"
assert_file "$DOM_FULLSCREEN_FIXTURE" "S03 DOM fullscreen fixture is present"
assert_executable "$FULLSCREEN_VERIFIER" "S03 fullscreen autohide verifier is executable"
assert_executable "$LIVE_FULLSCREEN_VERIFIER" "S03 live fullscreen autohide verifier is executable"

# T03 runtime proof surface. The live verifier is intentionally self-contained and
# launches a disposable Marionette profile instead of mutating a user's default profile.
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'FF_ULTIMA_FIREFOX_BIN' "live verifier allows overriding the Firefox binary"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" '-remote-allow-system-access' "live verifier requests Firefox chrome-context Marionette access"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'tempfile.mkdtemp(prefix="ff-ultima-s03-fullscreen-"' "live verifier creates a disposable profile"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'user_pref("marionette.port"' "live verifier assigns a disposable Marionette port"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' "live verifier enables userChrome in the disposable profile"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'user_pref("ultima.navbar.autohide", true);' "live verifier forces navbar autohide for S03 proof"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'user_pref("ultima.navbar.bookmarks.autohide", true);' "live verifier forces bookmarks autohide for S03 proof"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'WebDriver:NewSession' "live verifier uses Marionette without geckodriver"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'Marionette:SetContext' "live verifier switches Marionette chrome/content contexts"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'InspectorUtils.addPseudoClassLock(toolbox, ":hover")' "live verifier locks toolbox hover for reveal evidence"
assert_contains "$LIVE_FULLSCREEN_VERIFIER" 'macOS fullscreen evidence:' "live verifier prints whether macOS fullscreen evidence was captured"
assert_contains "$DOM_FULLSCREEN_FIXTURE" 'target.requestFullscreen()' "DOM fullscreen fixture triggers requestFullscreen from a user click"
assert_contains "$DOM_FULLSCREEN_FIXTURE" 'id="fullscreen-target"' "DOM fullscreen fixture exposes a stable fullscreen target"

# Required owner imports. customChrome.css remains intentionally optional for users.
assert_contains "$USER_CHROME" '@import url(theme/ffu-global-positioning.css);' "userChrome imports global fullscreen positioning owner"
assert_contains "$USER_CHROME" '@import url(theme/settings-navbar.css);' "userChrome imports navbar autohide owner"
assert_contains "$USER_CHROME" '@import url(theme/ffu-special-configs.css);' "userChrome imports special fullscreen/title owner"

assert_contains "$USER_JS" 'user_pref("full-screen-api.transition-duration.enter", "0 0");' "user.js keeps fullscreen enter transition disabled"
assert_contains "$USER_JS" 'user_pref("full-screen-api.transition-duration.leave", "0 0");' "user.js keeps fullscreen leave transition disabled"
assert_contains "$USER_JS" 'user_pref("full-screen-api.warning.timeout", 0);' "user.js keeps fullscreen warning timeout disabled"
assert_contains "$USER_JS" 'user_pref("ultima.navbar.autohide", false);' "user.js keeps navbar autohide pref in established namespace"
assert_contains "$USER_JS" 'user_pref("ultima.navbar.position", "top");' "user.js keeps navbar position pref in established namespace"
assert_contains "$USER_JS" 'user_pref("ultima.urlbar.float", false);' "user.js keeps urlbar float pref in established namespace"
assert_no_unexpected_fullscreen_prefs

root_fullscreen_block="$(extract_css_block "$GLOBAL" ':root[inFullscreen="true"]')"
assert_nonempty_block "$root_fullscreen_block" "theme/ffu-global-positioning.css" ':root[inFullscreen="true"]'
assert_block_contains "$root_fullscreen_block" '--uc-menubar-height: 0px !important;' "global fullscreen root zeroes menubar height"
assert_block_contains "$root_fullscreen_block" '--uc-bookbar-height: 0px !important;' "global fullscreen root zeroes bookmarks height"
assert_block_contains "$root_fullscreen_block" '@media -moz-pref("sidebar.verticalTabs")' "global fullscreen root carries vertical-tabs height branch"
assert_block_contains "$root_fullscreen_block" '--uc-tabbar-height: 0px !important;' "global fullscreen root zeroes vertical tabbar height"

dom_root_block="$(extract_css_block "$GLOBAL" ':root[inDOMFullscreen],')"
assert_nonempty_block "$dom_root_block" "theme/ffu-global-positioning.css" ':root[inDOMFullscreen] / #main-window[inDOMFullscreen="true"]'
assert_block_contains "$dom_root_block" '#main-window[inDOMFullscreen="true"]' "global DOM fullscreen cleanup covers main-window attribute"
assert_block_contains "$dom_root_block" '--uc-content-margins: 0px !important;' "global DOM fullscreen zeroes content margins variable"
assert_block_contains "$dom_root_block" '--uc-content-border-radius: 0px !important;' "global DOM fullscreen zeroes content radius variable"
assert_block_contains "$dom_root_block" '--uc-sidebar-border-radius: 0px !important;' "global DOM fullscreen zeroes sidebar radius variable"
assert_block_contains "$dom_root_block" '--uc-sb-margins: 0px !important;' "global DOM fullscreen zeroes sidebar margins variable"
assert_block_contains "$dom_root_block" '--uc-sb-margins-right: 0px !important;' "global DOM fullscreen zeroes right sidebar margins variable"

dom_tabbox_block="$(extract_css_block "$GLOBAL" ':root[inDOMFullscreen] #tabbrowser-tabbox')"
assert_nonempty_block "$dom_tabbox_block" "theme/ffu-global-positioning.css" ':root[inDOMFullscreen] #tabbrowser-tabbox'
assert_block_contains "$dom_tabbox_block" '#main-window[inDOMFullscreen="true"] #tabbrowser-tabbox' "global DOM fullscreen tabbox cleanup covers main-window attribute"
assert_block_contains "$dom_tabbox_block" 'margin-inline-start: 0px !important;' "global DOM fullscreen clears tabbox inline margin"

browser_fullscreen_compact_block="$(extract_css_block "$GLOBAL" '#main-window[sizemode="fullscreen"] *')"
assert_nonempty_block "$browser_fullscreen_compact_block" "theme/ffu-global-positioning.css" '#main-window[sizemode="fullscreen"] *'
assert_block_contains "$browser_fullscreen_compact_block" '@media not (-moz-platform: macos)' "global browser fullscreen compacting documents representative non-mac path"
assert_block_contains "$browser_fullscreen_compact_block" '--uc-content-border-radius: 0px;' "global browser fullscreen zeroes content radius variable"
assert_block_contains "$browser_fullscreen_compact_block" '--uc-sidebar-border-radius: 0px;' "global browser fullscreen zeroes sidebar radius variable"
assert_block_contains "$browser_fullscreen_compact_block" '--uc-content-margins: 0px !important;' "global browser fullscreen zeroes content margins variable"
assert_block_contains "$browser_fullscreen_compact_block" '--uc-sb-margins: 0px !important;' "global browser fullscreen zeroes sidebar margins variable"
assert_block_contains "$browser_fullscreen_compact_block" '--uc-sb-margins-right: 0px !important;' "global browser fullscreen zeroes right sidebar margins variable"

browser_fullscreen_content_block="$(extract_css_block "$GLOBAL" '#main-window[sizemode="fullscreen"] #tabbrowser-tabpanels browser[type] {')"
assert_contains "$GLOBAL" '#main-window[sizemode="fullscreen"] #browser,' "global browser fullscreen content cleanup targets browser container"
assert_contains "$GLOBAL" '#main-window[sizemode="fullscreen"] #tabbrowser-tabbox,' "global browser fullscreen content cleanup targets tabbox"
assert_contains "$GLOBAL" '#main-window[sizemode="fullscreen"] #tabbrowser-tabpanels,' "global browser fullscreen content cleanup targets tabpanels"
assert_nonempty_block "$browser_fullscreen_content_block" "theme/ffu-global-positioning.css" '#main-window[sizemode="fullscreen"] #tabbrowser-tabpanels browser[type]'
assert_block_contains "$browser_fullscreen_content_block" 'margin: 0 !important;' "global browser fullscreen content cleanup zeroes retained content margins"
assert_block_contains "$browser_fullscreen_content_block" 'border-radius: 0 !important;' "global browser fullscreen content cleanup zeroes content radius"
assert_block_contains "$browser_fullscreen_content_block" 'box-shadow: none !important;' "global browser fullscreen content cleanup suppresses shadow seams"
assert_block_contains "$browser_fullscreen_content_block" 'outline: none !important;' "global browser fullscreen content cleanup suppresses outline seams"
assert_contains "$GLOBAL" '#main-window[sizemode="fullscreen"] #tabbrowser-tabpanels browser[type] {' "global browser fullscreen browser-content border cleanup exists"
assert_contains "$GLOBAL" 'border: 0 !important;' "global browser fullscreen browser-content border cleanup suppresses border seams"

dom_content_block="$(extract_css_block "$GLOBAL" '#main-window[inDOMFullscreen="true"][inFullscreen="true"]')"
assert_nonempty_block "$dom_content_block" "theme/ffu-global-positioning.css" '#main-window[inDOMFullscreen="true"][inFullscreen="true"]'
assert_block_contains "$dom_content_block" '& #browser,' "global DOM fullscreen content cleanup targets browser container"
assert_block_contains "$dom_content_block" '& #tabbrowser-tabbox,' "global DOM fullscreen content cleanup targets tabbox"
assert_block_contains "$dom_content_block" '& #tabbrowser-tabpanels {' "global DOM fullscreen content cleanup targets tabpanels"
assert_block_contains "$dom_content_block" '#tabbrowser-tabpanels browser[type]' "global DOM fullscreen content cleanup targets browser content"
assert_block_contains "$dom_content_block" 'margin: 0 !important;' "global DOM fullscreen content cleanup zeroes retained content margins"
assert_block_contains "$dom_content_block" 'border-radius: 0 !important;' "global DOM fullscreen content cleanup zeroes content radius"
assert_block_contains "$dom_content_block" 'border: 0 !important;' "global DOM fullscreen content cleanup suppresses browser border"
assert_block_contains "$dom_content_block" 'box-shadow: none !important;' "global DOM fullscreen content cleanup suppresses shadow seams"
assert_block_contains "$dom_content_block" 'outline: none !important;' "global DOM fullscreen content cleanup suppresses outline seams"

assert_contains "$GLOBAL" '#main-window[inFullscreen="true"] { #sidebar-box, #sidebar {' "global positioning owns fullscreen sidebar radius cleanup"
assert_contains "$GLOBAL" 'border-radius: 0px !important;' "global positioning zeroes fullscreen sidebar/content radii"

autohide_block="$(extract_css_block "$NAVBAR" '@media -moz-pref("ultima.navbar.autohide")')"
assert_nonempty_block "$autohide_block" "theme/settings-navbar.css" '@media -moz-pref("ultima.navbar.autohide")'
assert_block_contains "$autohide_block" '#main-window:is([sizemode="normal"],[sizemode="maximized"]):not([customizing=""])' "navbar autohide baseline remains normal/maximized scoped before T02 fullscreen tightening"
assert_block_contains "$autohide_block" '#navigator-toolbox' "navbar autohide owns navigator toolbox movement"
assert_block_contains "$autohide_block" 'position: absolute !important;' "navbar autohide keeps toolbox absolute positioning"
assert_block_contains "$autohide_block" 'top: var(--uc-navbar-autohide-hidden-offset);' "navbar autohide uses shared top hidden offset"
assert_block_contains "$autohide_block" 'bottom: var(--uc-navbar-autohide-hidden-offset);' "navbar autohide uses shared bottom hidden offset"
assert_block_contains "$autohide_block" 'top: var(--uc-navbar-autohide-hover-offset);' "navbar autohide uses shared top hover offset"
assert_block_contains "$autohide_block" 'bottom: var(--uc-navbar-autohide-hover-offset);' "navbar autohide uses shared bottom hover offset"
assert_block_contains "$autohide_block" '--uc-navbar-autohide-top-content-margin: var(--uc-navbar-autohide-edge-seam);' "navbar autohide hidden state keeps top seam"
assert_block_contains "$autohide_block" '--uc-navbar-autohide-top-content-margin: var(--uc-navbar-autohide-content-offset);' "navbar autohide reveal state reserves toolbar height"
assert_block_contains "$autohide_block" '#tabContextMenu[state="open"]' "navbar autohide popup exception preserves tab context open state"
assert_block_contains "$autohide_block" '#downloadsPanel[panelopen="true"]' "navbar autohide popup exception preserves downloads panel state"
assert_block_contains "$autohide_block" '#protections-popup[panelopen="true"]' "navbar autohide popup exception preserves protections popup state"
assert_block_not_contains "$autohide_block" '#main-window[sizemode="fullscreen"]' "navbar autohide normal block avoids a direct browser fullscreen selector"
assert_contains "$NAVBAR" '&#main-window:not([inFullscreen="true"])' "navbar bookmarks autohide explicitly excludes browser fullscreen"

title_block="$(extract_css_block "$SPECIAL_CONFIGS" ':root:not([sizemode="fullscreen"]):not([inDOMFullscreen="true"]):has(#toolbar-menubar:not([inactive="true"])) > head')"
assert_nonempty_block "$title_block" "theme/ffu-special-configs.css" ':root:not([sizemode="fullscreen"]):not([inDOMFullscreen="true"]):has(#toolbar-menubar:not([inactive="true"])) > head'
assert_contains "$SPECIAL_CONFIGS" '@media not -moz-pref("ultima.navbar.autohide")' "special configs title handling is disabled when navbar autohide owns chrome"
assert_block_contains "$title_block" 'display: block;' "special configs title handling displays only outside browser and DOM fullscreen"
assert_block_contains "$title_block" 'position: fixed; top: 12px; right: 140px;' "special configs title handling positions menu-bar title"
assert_block_contains "$title_block" 'pointer-events: none;' "special configs title handling remains non-interactive"
assert_block_contains "$title_block" '& title {' "special configs title handling scopes title child"
assert_regex "$SPECIAL_CONFIGS" ':root:not\(\[sizemode="fullscreen"\]\):not\(\[inDOMFullscreen="true"\]\):has\(#toolbar-menubar:not\(\[inactive="true"\]\)\) > head' "special configs title selector keeps browser and DOM fullscreen guards"
assert_contains "$SPECIAL_CONFIGS" '#main-window:not([sizemode="fullscreen"]):not([inDOMFullscreen="true"]):has(#tabbrowser-tabs[orient="horizontal"]) #browser' "special configs horizontal browser margin excludes browser and DOM fullscreen"
assert_contains "$SPECIAL_CONFIGS" 'fullscreen content seam cleanup must run after ffu-internal-appearance/color modules' "special configs documents late fullscreen content seam cleanup"
assert_contains "$SPECIAL_CONFIGS" '#main-window[sizemode="fullscreen"] #tabbrowser-tabpanels,' "special configs browser fullscreen late cleanup targets tabpanels"
assert_contains "$SPECIAL_CONFIGS" '#main-window[sizemode="fullscreen"] #tabbrowser-tabpanels browser[type],' "special configs browser fullscreen late cleanup targets browser content"
assert_contains "$SPECIAL_CONFIGS" '#main-window[inDOMFullscreen="true"][inFullscreen="true"] #tabbrowser-tabpanels,' "special configs DOM fullscreen late cleanup targets tabpanels"
assert_contains "$SPECIAL_CONFIGS" '#main-window[inDOMFullscreen="true"][inFullscreen="true"] #tabbrowser-tabpanels browser[type] {' "special configs DOM fullscreen late cleanup targets browser content"
late_fullscreen_content_block="$(extract_css_block "$SPECIAL_CONFIGS" '#main-window[inDOMFullscreen="true"][inFullscreen="true"] #tabbrowser-tabpanels browser[type] {')"
assert_nonempty_block "$late_fullscreen_content_block" "theme/ffu-special-configs.css" 'late browser/DOM fullscreen content seam cleanup'
assert_block_contains "$late_fullscreen_content_block" 'margin: 0 !important;' "special configs late fullscreen cleanup zeroes retained content margins"
assert_block_contains "$late_fullscreen_content_block" 'border-radius: 0 !important;' "special configs late fullscreen cleanup zeroes retained content radius"
assert_block_contains "$late_fullscreen_content_block" 'border: 0 !important;' "special configs late fullscreen cleanup suppresses retained borders"
assert_block_contains "$late_fullscreen_content_block" 'box-shadow: none !important;' "special configs late fullscreen cleanup suppresses retained shadows"
assert_block_contains "$late_fullscreen_content_block" 'outline: none !important;' "special configs late fullscreen cleanup suppresses retained outlines"

printf 'All %d fullscreen autohide checks passed.\n' "$checks"
