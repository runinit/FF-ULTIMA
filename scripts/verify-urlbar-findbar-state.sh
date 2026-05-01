#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

USER_CHROME="$REPO_ROOT/userChrome.css"
USER_JS="$REPO_ROOT/user.js"
APPEARANCE="$REPO_ROOT/theme/ffu-internal-appearance.css"
URLBAR="$REPO_ROOT/theme/settings-urlbar.css"
FINDBAR="$REPO_ROOT/theme/settings-findbar.css"
SPECIAL_CONFIGS="$REPO_ROOT/theme/ffu-special-configs.css"
NAVBAR_GEOMETRY_VERIFIER="$REPO_ROOT/scripts/verify-navbar-geometry.sh"

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

assert_regex_count() {
    local file="$1"
    local pattern="$2"
    local expected="$3"
    local description="$4"
    local matches=""
    local actual=0

    matches="$(grep -E -- "$pattern" "$file" || true)"
    if [[ -n "$matches" ]]; then
        actual="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"
    fi

    [[ "$actual" == "$expected" ]] || fail "$description expected $expected match(es), got $actual in $(relative_path "$file"): $pattern"
    checks=$((checks + 1))
    pass "$description"
}

assert_min_count() {
    local file="$1"
    local needle="$2"
    local minimum="$3"
    local description="$4"
    local matches=""
    local actual=0

    matches="$(grep -F -- "$needle" "$file" || true)"
    if [[ -n "$matches" ]]; then
        actual="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"
    fi

    (( actual >= minimum )) || fail "$description expected at least $minimum match(es), got $actual in $(relative_path "$file"): $needle"
    checks=$((checks + 1))
    pass "$description"
}

assert_line_order() {
    local file="$1"
    local first="$2"
    local second="$3"
    local description="$4"
    local first_line=""
    local second_line=""

    first_line="$(grep -nF -- "$first" "$file" | head -n 1 | cut -d: -f1 || true)"
    second_line="$(grep -nF -- "$second" "$file" | head -n 1 | cut -d: -f1 || true)"

    [[ -n "$first_line" ]] || fail "$description missing first marker in $(relative_path "$file"): $first"
    [[ -n "$second_line" ]] || fail "$description missing second marker in $(relative_path "$file"): $second"
    (( first_line < second_line )) || fail "$description order violation in $(relative_path "$file"): '$first' must come before '$second'"
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

assert_file "$USER_CHROME" "userChrome.css is present"
assert_file "$USER_JS" "user.js is present"
assert_file "$APPEARANCE" "internal appearance module is present"
assert_file "$URLBAR" "urlbar settings module is present"
assert_file "$FINDBAR" "findbar settings module is present"
assert_file "$SPECIAL_CONFIGS" "special configs module is present"
assert_file "$NAVBAR_GEOMETRY_VERIFIER" "navbar geometry verifier is present for S01 gate delegation"

# Resolve userChrome theme imports; customChrome.css is intentionally optional for users.
while IFS= read -r import_path; do
    [[ -n "$import_path" ]] || continue
    assert_file "$REPO_ROOT/$import_path" "import resolves: $import_path"
done < <(
    grep -Eo '@import url\([^)]+\)' "$USER_CHROME" \
        | sed -E 's/@import url\(([^)]+)\).*/\1/' \
        | grep '^theme/'
)

assert_contains "$USER_CHROME" '@import url(theme/ffu-internal-appearance.css);' "userChrome imports internal appearance"
assert_contains "$USER_CHROME" '@import url(theme/settings-urlbar.css);' "userChrome imports urlbar settings"
assert_contains "$USER_CHROME" '@import url(theme/settings-findbar.css);' "userChrome imports findbar settings"
assert_contains "$USER_CHROME" '@import url(theme/ffu-special-configs.css);' "userChrome imports special configs"
assert_contains "$USER_CHROME" '@import url(customChrome.css);' "userChrome keeps customChrome as optional user import"
assert_line_order "$USER_CHROME" '@import url(theme/ffu-internal-appearance.css);' '@import url(theme/settings-urlbar.css);' "internal appearance loads before urlbar settings"
assert_line_order "$USER_CHROME" '@import url(theme/settings-urlbar.css);' '@import url(theme/settings-findbar.css);' "urlbar settings load before findbar settings"
assert_line_order "$USER_CHROME" '@import url(theme/settings-findbar.css);' '@import url(theme/ffu-special-configs.css);' "settings load before special configs"
assert_line_order "$USER_CHROME" '@import url(theme/ffu-special-configs.css);' '@import url(customChrome.css);' "customChrome remains the final optional override"

assert_contains "$USER_JS" 'user_pref("user.theme.transparent", false);' "user.js defaults global theme transparency off"
assert_contains "$USER_JS" 'user_pref("browser.tabs.allow_transparent_browser", false);' "user.js defaults Firefox transparent browser support off"
assert_contains "$USER_JS" 'user_pref("ultima.urlbar.transparent", false);' "user.js defaults urlbar transparency off"
assert_contains "$USER_JS" 'user_pref("ultima.findbar.position.top", true);' "user.js defaults top findbar on"

unexpected_s02_prefs="$(
    grep -En 'user_pref\("ultima\.(urlbar|tabs?|findbar)\.[^"]*(color|background|transparent|solid|geometry|flush|gap|margin|offset)' "$USER_JS" \
        | grep -Ev 'ultima\.urlbar\.transparent|ultima\.findbar\.disable\.background\.image|ultima\.tabs\.pinned\.transparent\.background|ultima\.tabs\.tabgroups\.background\.[123]|ultima\.tabs\.splitview\.gradient\.background|ultima\.tabs\.tab\.outline\.color' \
        || true
)"
if [[ -n "$unexpected_s02_prefs" ]]; then
    fail "unexpected S02 urlbar/tab/findbar color or geometry pref(s) found in user.js: $unexpected_s02_prefs"
fi
checks=$((checks + 1))
pass "user.js has no new S02 urlbar/tab/findbar color or geometry prefs"

findbar_top_block="$(extract_css_block "$FINDBAR" '@media -moz-pref("ultima.findbar.position.top")')"
assert_block_contains "$findbar_top_block" '.browserContainer > findbar' "top findbar block targets browserContainer findbar"
assert_block_contains "$findbar_top_block" 'order: -1;' "top findbar block moves findbar above content"
assert_block_contains "$findbar_top_block" 'margin-top: 0;' "top findbar block keeps Firefox 150+ findbar flush"
assert_block_contains "$findbar_top_block" '.browserContainer > findbar .findbar-textbox' "top findbar block keeps textbox width scoped"

transparent_urlbar_block="$(extract_css_block "$URLBAR" '@media -moz-pref("ultima.urlbar.transparent")')"
assert_block_contains "$transparent_urlbar_block" '#main-window[lwtheme], #main-window:not([lwtheme])' "transparent urlbar block covers lwtheme and default paths"
assert_block_contains "$transparent_urlbar_block" '& #urlbar:not([open])' "transparent urlbar block only targets closed urlbar"
assert_block_contains "$transparent_urlbar_block" '& #urlbar-background,' "transparent urlbar block targets urlbar background id"
assert_block_contains "$transparent_urlbar_block" '& .urlbar-background' "transparent urlbar block targets urlbar background class"
assert_block_contains "$transparent_urlbar_block" '& #searchbar:not(:focus-within)' "transparent urlbar block targets inactive searchbar explicitly"
assert_block_contains "$transparent_urlbar_block" 'background-color: color-mix(in srgb, var(--uc-urlbar-background) 55%, transparent) !important;' "transparent urlbar block applies frosted uc urlbar background"
assert_block_contains "$transparent_urlbar_block" 'backdrop-filter: blur(12px) saturate(140%) !important;' "transparent urlbar block applies frosted backdrop"
assert_block_contains "$transparent_urlbar_block" 'box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--uc-accent-color-3) 22%, transparent), var(--uc-box-shadow) !important;' "transparent urlbar block keeps subtle frosted border and shadow"
assert_block_not_contains "$transparent_urlbar_block" 'background-color: transparent !important;' "transparent urlbar block avoids bare transparent chrome"
assert_block_not_contains "$transparent_urlbar_block" 'box-shadow: none !important;' "transparent urlbar block avoids bare shadowless chrome"
assert_regex_count "$URLBAR" '^[[:space:]]*background(-color)?:[[:space:]]*transparent[[:space:]]*!important;' 0 "urlbar settings define no bare transparent backgrounds"

urlbar_appearance_section="$(awk '/\/\* Url Bar / { capture = 1 } /\/\* Browser Content adjustments/ { capture = 0 } capture { print }' "$APPEARANCE")"
assert_block_contains "$urlbar_appearance_section" '#main-window:not([lwtheme]), #main-window[lwtheme]' "solid urlbar section covers default and lwtheme paths"
assert_block_contains "$urlbar_appearance_section" '& #urlbar-background,' "solid urlbar section targets urlbar background id"
assert_block_contains "$urlbar_appearance_section" '& .urlbar-background, & #searchbar' "solid urlbar section targets urlbar class and searchbar"
assert_block_contains "$urlbar_appearance_section" 'background-color: var(--uc-urlbar-background) !important;' "solid urlbar section applies uc urlbar background"
assert_block_contains "$urlbar_appearance_section" 'box-shadow: var(--uc-box-shadow) !important;' "solid urlbar section applies uc urlbar shadow"
assert_block_contains "$urlbar_appearance_section" '& #urlbar:is([focused="true"], & [open]) > #urlbar-background,' "solid urlbar focus/open id selector remains in internal appearance"
assert_block_contains "$urlbar_appearance_section" '& #urlbar:is([focused="true"], & [open]) > .urlbar-background,' "solid urlbar focus/open class selector remains in internal appearance"

assert_contains "$APPEARANCE" '--uc-urlbar-background:  var(--uc-layered-background);' "default path defines solid urlbar background variable"
assert_contains "$APPEARANCE" '--uc-tabsbar-background: var(--uc-browser-color);' "default path defines tab-strip background variable"
assert_contains "$APPEARANCE" '--uc-tab-selected:       color-mix(in srgb, var(--toolbar-bgcolor) 90%, black);' "default path defines selected tab color variable"
assert_contains "$APPEARANCE" '--tab-selected-bgcolor: var(--uc-tab-selected) !important;' "non-lwtheme path exports selected tab bgcolor variable"
assert_min_count "$APPEARANCE" '--uc-urlbar-background:  color-mix(in srgb, var(--lwt-accent-color)' 2 "lwtheme paths define urlbar background variables"
assert_min_count "$APPEARANCE" '--uc-tabsbar-background: var(--uc-browser-color);' 3 "default and lwtheme paths define tab-strip variables"
assert_min_count "$APPEARANCE" '--uc-tab-selected:       var(--uc-layered-background);' 2 "lwtheme paths define selected tab color variables"
assert_min_count "$APPEARANCE" '--tab-selected-bgcolor: var(--uc-tab-selected) !important;' 3 "default and lwtheme paths export selected tab bgcolor"

tabs_appearance_section="$(awk '/\/\* Overall Tabs Appearance/ { capture = 1 } /\/\* Vertical Tabs Appearance/ { capture = 0 } capture { print }' "$APPEARANCE")"
assert_block_contains "$tabs_appearance_section" '#main-window:not([lwtheme]), #main-window[lwtheme]' "tab appearance section covers default and lwtheme paths"
assert_block_contains "$tabs_appearance_section" '& #TabsToolbar,' "tab appearance section covers tabs toolbar surface"
assert_block_contains "$tabs_appearance_section" '& #TabsToolbar-customization-target,' "tab appearance section covers tabs customization target surface"
assert_block_contains "$tabs_appearance_section" '& #tabbrowser-tabs' "tab appearance section covers tabbrowser tabs surface"
assert_block_contains "$tabs_appearance_section" 'background-color: var(--uc-tabsbar-background) !important;' "tab-strip surfaces use uc tabsbar background"
assert_block_contains "$tabs_appearance_section" '& .tab-label-container[selected]' "tab appearance section styles selected tab label"
assert_block_contains "$tabs_appearance_section" 'color: var(--uc-tab-selected-text) !important;' "selected tab label uses selected tab text variable"
assert_block_contains "$tabs_appearance_section" '& .tab-background[selected]' "tab appearance section styles selected tab background"
assert_block_contains "$tabs_appearance_section" 'background-color: var(--tab-selected-bgcolor) !important;' "selected and active tab backgrounds use selected tab variable"
assert_block_contains "$tabs_appearance_section" '--tab-selected-background: var(--tab-selected-bgcolor) !important;' "lwtheme selected tab background variable remains solid"
assert_block_not_contains "$tabs_appearance_section" 'background: transparent !important;' "tab appearance section avoids transparent tab-strip surfaces"
assert_block_not_contains "$tabs_appearance_section" 'background-color: transparent !important;' "tab appearance section avoids transparent tab-strip colors"
assert_block_not_contains "$tabs_appearance_section" '--tab-selected-background: red !important;' "tab appearance section avoids debug selected-tab color"

vertical_tabs_appearance_section="$(awk '/\/\* Vertical Tabs Appearance/ { capture = 1 } /\/\* Split View Tabs/ { capture = 0 } capture { print }' "$APPEARANCE")"
assert_block_contains "$vertical_tabs_appearance_section" '#main-window:not([lwtheme])' "vertical tabs default path is scoped"
assert_block_contains "$vertical_tabs_appearance_section" '#main-window[lwtheme]' "vertical tabs lwtheme path is scoped"
assert_block_contains "$vertical_tabs_appearance_section" 'background:var(--uc-tabsbar-background) !important;' "vertical tabs default surface uses tabsbar variable"
assert_block_contains "$vertical_tabs_appearance_section" 'background: var(--uc-tabsbar-background) !important;' "vertical tabs lwtheme surface uses tabsbar variable"
assert_block_not_contains "$vertical_tabs_appearance_section" 'background: var(--lwt-accent-color) !important;' "vertical tabs lwtheme surface avoids raw accent-color leak"

printf 'All %d urlbar/findbar state checks passed.\n' "$checks"
