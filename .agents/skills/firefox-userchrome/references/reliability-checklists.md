# Firefox Theme Reliability Checklists

Read only the sections relevant to the current task. These checklists support the workflow in `../SKILL.md`; they do not expand authorization.

## Selector regression checklist

Use when a Firefox update breaks an existing rule.

1. Record the exact Firefox version and FF Ultima release baseline.
2. Find the existing selector and every pref-gated branch that uses it.
3. Determine whether the element disappeared, moved to a different container, lost an attribute, or merely changed state timing.
4. Verify candidate selectors against version-matched Mozilla source or live browser-chrome state.
5. Preserve the old selector when it still represents supported Firefox versions or extension behavior.
6. Scope the fallback by the owning pref, layout, and component state so it cannot style unrelated native UI.
7. Test both the state that originally failed and the adjacent state most likely to regress.

Evidence strength, strongest first:

1. live Browser Toolbox DOM/computed style for the affected element;
2. version-matched Mozilla source and selectors;
3. live accessibility tree plus measured geometry;
4. current repository conventions;
5. screenshots and visual inference;
6. guessed URL, generated class, or third-party snippet.

Use weaker evidence to form a hypothesis, not to declare success.

## Pill, inset, and surface geometry checklist

Use when chrome blocks look uneven, a gap appears missing, or controls are off-center.

| Box | Establish |
| --- | --- |
| Window body/app canvas | Which surface paints native outer margins and transparent corners |
| `#navigator-toolbox` | Physical margins, border extents, full radius, and verified overflow behavior |
| `#browser` | Padding, flex gap, coordinate origin, density branches, and fullscreen resets |
| `#sidebar-box` | Collapsed/expanded bounds, outer inset, inner gap, and page reservation |
| `.browserContainer` | Page-frame border, rounded clipping, and visible content origin |
| Extension viewport | Viewport width plus the padding/alignment owners for tabs, navigation, new-tab, and footer rows |

1. Record the Firefox and extension versions, active prefs, density, sidebar side, window state, and screenshot/device scale.
2. Measure exact live bounds with Browser Toolbox when possible. The accessibility tree plus a scaled screenshot can corroborate geometry; a screenshot alone cannot prove the owning box.
3. Calculate each gap from adjacent edges and state whether borders are included. Measure both sides and the block-start/block-end pair instead of inferring symmetry.
4. Inspect version-matched native Firefox CSS and the theme cascade. Account for native margin, padding, and flex gap exactly once.
5. Trace equal spacing back to one shared token. Add a derived offset only when an absolutely positioned child starts from a different box than the visible app canvas.
6. If the physical gap is correct but visually disappears, inspect the body/app-canvas paint beneath it before changing geometry.
7. Apply borders and radii to the visible chrome block, preserve verified native clipping, and retain compact, fullscreen, DOM-fullscreen, popup, and open-urlbar behavior.
8. For Sidebery, keep its outer Firefox container separate from its extension content. Confirm the installed XPI version/classes, then inspect tab rows and full-width navigation/new-tab/footer containers independently. Sidebery 5.6.x horizontal inline navigation splits panel items into `.main-items` and overflow/settings controls into `.static-btns`; the overflow control is `[data-type="hidden"]`. In a 38–40px rail, making both nested containers `100vw` and centering the parent produces clipped 30px controls rather than a centered button.
9. Record before, predicted, and post-reload coordinates. Do not present predicted or installed geometry as live success.

## Autohide, overlay, and positioning checklist

Capture these states when the change can affect geometry:

| State | Verify |
| --- | --- |
| Rest | Collapsed width, hidden native controls, page-content origin, and only the intended gutter |
| Hover/open | Remembered expanded width, correct z-index, page content remains stationary when overlay is intended |
| Pointer leaves | Returns to the intended collapsed state without trapping focus |
| Left/right | Insets, transform origin, splitter, borders, and shadows follow the selected side |
| Fullscreen/maximized | Existing exclusions and offsets still apply |
| Compact/standard/relaxed | Size variables remain owned by the selected spacing mode |

For Sidebery, inspect the extension sidebar, Firefox's sidebar container, the native launcher, and their splitters separately. Hiding or resizing the extension frame does not prove that Firefox's launcher stopped reserving space.

## Active profile checklist

Resolve profile ownership before any copy:

- Prefer an explicit user path or `about:support` Profile Directory.
- An explicit Firefox `-profile` process argument is strong corroboration.
- A live lock file can corroborate that a candidate is open but does not communicate user intent.
- `installs.ini`, `profiles.ini`, and directory names enumerate candidates; they do not override an explicit target.
- If multiple candidates remain and installation was requested, stop and ask which profile to use.

Before copying:

- Confirm the target contains the expected Firefox profile files.
- Confirm the destination is beneath `<profile>/chrome/`.
- List the exact source/destination pairs.
- Preserve any unrelated custom files in the profile.

After copying:

- Compare source and destination byte-for-byte.
- Keep the backup until live verification succeeds.
- Report installed state separately from live state.

## Compatibility matrix

Choose rows that can materially change the requested behavior:

| Dimension | Common variants |
| --- | --- |
| Tabs | horizontal, Firefox vertical tabs, Sidebery, tab bar disabled/autohide |
| Sidebar | closed/open, launcher visible/hidden, extension/native panel, left/right |
| Window | normal, maximized, fullscreen, customization mode, private |
| Density | compact, standard, relaxed |
| Interaction | rest, hover, focus, open, drag, popup visible |
| Theme | system/LWT, dark/light, static palette, Pywalfox/Noctalia bridge |
| Platform | Linux, Windows controls, macOS controls |

Do not test every cell mechanically. Select the primary state, the state that failed, and the nearest variant that shares the changed selector or variable.

## Controlled A/B procedure

1. Capture the starting source, installed file checksum, prefs, and UI geometry.
2. Form one selector or cascade hypothesis.
3. Change only the rule needed to distinguish that hypothesis.
4. Copy only the affected file when profile installation is authorized.
5. Reload/restart and capture the same state.
6. If the hypothesis fails, remove it before testing the next one.
7. Once proven, implement the smallest compatibility-safe version in the repository and rerun the matrix.

This prevents failed experiments from accumulating into a rule set whose apparent success cannot be attributed.
