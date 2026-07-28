#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

USER_CHROME="$REPO_ROOT/userChrome.css"
USER_CONTENT="$REPO_ROOT/userContent.css"
USER_JS="$REPO_ROOT/user.js"
APPEARANCE="$REPO_ROOT/theme/ffu-internal-appearance.css"
NOVA_TOKENS="$REPO_ROOT/theme/ffu-nova-tokens.css"
THEME_STYLES="$REPO_ROOT/theme/ffu-theme-styles.css"
STANDARDS="$REPO_ROOT/theme/ffu-cs-standards.css"
EXTENSION_COLORS="$REPO_ROOT/theme/color-schemes/apply-cs-extensions.css"
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
assert_file "$USER_CONTENT" "userContent.css is present"
assert_file "$USER_JS" "user.js is present"
assert_file "$APPEARANCE" "internal appearance module is present"
assert_file "$NOVA_TOKENS" "Nova token module is present"
assert_file "$THEME_STYLES" "theme style modifier module is present"
assert_file "$STANDARDS" "Firefox compatibility alias module is present"
assert_file "$EXTENSION_COLORS" "extension color adapter is present"
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

while IFS= read -r import_path; do
    [[ -n "$import_path" ]] || continue
    assert_file "$REPO_ROOT/$import_path" "userContent import resolves: $import_path"
done < <(
    grep -Eo '@import url\([^)]+\)' "$USER_CONTENT" \
        | sed -E 's/@import url\(([^)]+)\).*/\1/' \
        | grep '^theme/'
)

assert_contains "$USER_CHROME" '@import url(theme/ffu-theme-styles.css);' "userChrome imports additive theme styles"
assert_contains "$USER_CHROME" '@import url(theme/ffu-internal-appearance.css);' "userChrome imports internal appearance"
assert_contains "$USER_CHROME" '@import url(theme/settings-urlbar.css);' "userChrome imports urlbar settings"
assert_contains "$USER_CHROME" '@import url(theme/settings-findbar.css);' "userChrome imports findbar settings"
assert_contains "$USER_CHROME" '@import url(theme/ffu-special-configs.css);' "userChrome imports special configs"
assert_contains "$USER_CHROME" '@import url(customChrome.css);' "userChrome keeps customChrome as optional user import"
assert_line_order "$USER_CHROME" '@import url(theme/ffu-nova-tokens.css);' '@import url(theme/ffu-theme-styles.css);' "Nova semantics load before theme styles"
assert_line_order "$USER_CHROME" '@import url(theme/ffu-theme-styles.css);' '@import url(theme/ffu-cs-standards.css);' "theme styles load before Firefox aliases"
assert_line_order "$USER_CHROME" '@import url(theme/ffu-internal-appearance.css);' '@import url(theme/settings-urlbar.css);' "internal appearance loads before urlbar settings"
assert_line_order "$USER_CHROME" '@import url(theme/settings-urlbar.css);' '@import url(theme/settings-findbar.css);' "urlbar settings load before findbar settings"
assert_line_order "$USER_CHROME" '@import url(theme/settings-findbar.css);' '@import url(theme/ffu-special-configs.css);' "settings load before special configs"
assert_line_order "$USER_CHROME" '@import url(theme/ffu-special-configs.css);' '@import url(customChrome.css);' "customChrome remains the final optional override"

assert_contains "$USER_CONTENT" '@import url(theme/ffu-theme-styles.css);' "userContent imports additive theme styles"
assert_line_order "$USER_CONTENT" '@import url(theme/ffu-nova-tokens.css);' '@import url(theme/ffu-theme-styles.css);' "content Nova semantics load before theme styles"
assert_line_order "$USER_CONTENT" '@import url(theme/ffu-theme-styles.css);' '@import url(theme/ffu-cs-standards.css);' "content theme styles load before Firefox aliases"

assert_contains "$USER_JS" 'user_pref("user.theme.style.colourful", false);' "user.js defaults colourful style off"
assert_contains "$USER_JS" 'user_pref("user.theme.style.glass", false);' "user.js defaults glass style off"
assert_regex_count "$USER_JS" 'user_pref\("user\.theme\.transparent"' 0 "retired global transparent theme pref is absent"
assert_contains "$USER_JS" 'user_pref("browser.tabs.allow_transparent_browser", false);' "user.js defaults Firefox transparent browser support off"
assert_contains "$USER_JS" 'user_pref("ultima.urlbar.transparent", false);' "user.js defaults urlbar transparency off"
assert_contains "$USER_JS" 'user_pref("ultima.findbar.position.top", false);' "user.js defaults native findbar position"

assert_contains "$NOVA_TOKENS" '--uc-nova-selected-border-width: 2px;' "selected tab border width is shared at 2px"
assert_contains "$THEME_STYLES" '@media -moz-pref("user.theme.style.colourful")' "colourful style is pref gated"
assert_contains "$THEME_STYLES" 'var(--uc-nova-accent-leading) 70%, black' "colourful tab border darkens the primary accent"
assert_contains "$THEME_STYLES" 'var(--uc-nova-accent-leading) 55%, black' "Sidebery colourful border has a stronger dark endpoint"
assert_contains "$THEME_STYLES" 'var(--uc-nova-accent-leading) 55%,' "colourful toolbox uses the balanced primary tint"
assert_contains "$THEME_STYLES" 'var(--uc-nova-chrome-block-base-surface) 82%,' "glass keeps one dark window backing"
assert_contains "$THEME_STYLES" 'var(--uc-nova-chrome-block-base-surface) 64%,' "glass uses the balanced shell opacity"
assert_contains "$THEME_STYLES" '@media -moz-pref("browser.tabs.allow_transparent_browser")' "glass requires Firefox native transparency"
assert_contains "$THEME_STYLES" '--uc-nova-sidebar-box-surface: transparent;' "glass avoids double tinting sidebar browsers"
assert_contains "$THEME_STYLES" '--uc-nova-extension-frame-surface: var(--uc-nova-chrome-block-surface);' "Sidebery paints one glass frame surface"
assert_contains "$THEME_STYLES" '--uc-nova-extension-toolbar-surface: transparent;' "Sidebery toolbar avoids a second glass tint"
assert_regex_count "$THEME_STYLES" 'backdrop-filter' 0 "theme styles rely on native/compositor transparency"
assert_contains "$APPEARANCE" 'border: var(--uc-nova-selected-border-width, 2px) solid transparent !important;' "native selected tabs consume the shared 2px width"
assert_contains "$EXTENSION_COLORS" 'border: var(--uc-nova-selected-border-width, 2px) solid transparent !important;' "Sidebery selected tabs consume the shared 2px width"
assert_contains "$EXTENSION_COLORS" '--uc-nova-sidebery-selected-border' "Sidebery selected tabs consume their darker gradient role"

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
assert_block_contains "$findbar_top_block" 'padding-block: var(--uc-findbar-top-clearance, 16px) 6px !important;' "top findbar block keeps configurable titlebar clearance"
assert_block_contains "$findbar_top_block" '.browserContainer > findbar .findbar-container' "top findbar block scopes container alignment"
assert_block_contains "$findbar_top_block" 'height: auto !important;' "top findbar container can grow with titlebar clearance"
assert_block_contains "$findbar_top_block" 'min-height: 38px !important;' "top findbar container keeps base control height"
assert_block_contains "$findbar_top_block" 'margin-top: 0 !important;' "top findbar container cancels base pull-up"
assert_block_contains "$findbar_top_block" '.browserContainer > findbar .findbar-closebutton' "top findbar block scopes close button alignment"
assert_block_contains "$findbar_top_block" 'margin-block: 0 !important;' "top findbar close button cancels base pull-up"
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

assert_contains "$APPEARANCE" ':is(#urlbar-background, .urlbar-background)' "urlbar surface covers current id and class"
assert_contains "$APPEARANCE" 'background-color: var(--uc-urlbar-background) !important;' "urlbar and search surfaces use the active palette"
assert_contains "$APPEARANCE" '--urlbar-background-border-breakout:' "expanded Nova urlbar keeps its outer border"
assert_contains "$APPEARANCE" '.urlbarView {' "urlbar result view has an explicit surface owner"
assert_contains "$APPEARANCE" 'background-color: transparent !important;' "urlbar result view preserves rounded background clipping"
assert_contains "$APPEARANCE" 'margin-inline: var(--uc-nova-urlbar-row-gutter, 6px) !important;' "urlbar rows retain their Nova inset"
assert_contains "$STANDARDS" '--tab-background-color-selected: var(--uc-nova-tab-active-surface) !important;' "selected native tabs use Nova palette semantics"
assert_contains "$STANDARDS" '--tab-border-color-accent: var(--uc-nova-selected-border) !important;' "native tabs export the shared selected border"
assert_contains "$APPEARANCE" '--tab-min-height: var(--uc-nova-tab-row-height, 32px) !important;' "vertical native tabs retain Nova row geometry"
assert_regex_count "$APPEARANCE" '--tab-selected-background:[[:space:]]*red' 0 "native tabs contain no debug selected color"

printf 'All %d urlbar/findbar state checks passed.\n' "$checks"
