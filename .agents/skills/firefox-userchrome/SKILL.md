---
name: firefox-userchrome
description: "Use this skill for any Firefox userChrome.css, userContent.css, or FF Ultima work: diagnosing browser-chrome regressions, adding theme settings, reviewing fragile selectors, styling Sidebery or native vertical tabs, polishing Nova/Noctalia/Pywalfox pill layouts, gaps, gutters, borders, rounding, and alignment, changing urlbar/toolbar/sidebar/tab UI, handling about:config theme prefs, or installing verified theme files into a Firefox profile. Trigger even for casual reports such as 'Firefox updated and the sidebar broke,' 'the pill spacing looks uneven,' 'fix Sidebery centering,' or 'copy this FF Ultima fix to my profile.'"
compatibility: Theme editing is cross-platform. The bundled audit script requires Bash, ripgrep, and cmp.
---

# Reliable Firefox userChrome / FF Ultima Work

Work from evidence and preserve FF Ultima's modular, preference-driven behavior. Firefox chrome markup is not a stable public API, so a plausible selector is not enough: establish which configuration layer owns the behavior, make the narrowest change, and distinguish source changes from installed and observed results.

## Choose the task mode first

Classify the request before touching files:

| Mode | Authorization | Required outcome |
| --- | --- | --- |
| Diagnose | Read-only unless the user also asks for a fix | Evidence-backed cause, affected state, and next action |
| Repository change | Edit only the project files needed for the requested behavior | Focused diff plus static verification |
| Profile installation | Only when the user explicitly asks to copy/install/sync | Exact target profile, recoverable backup, narrow copy, byte comparison |
| Live verification | Use for version-specific or stateful UI regressions; restarting or closing Firefox still needs authorization | Observed before/after UI state, not just a proposed CSS explanation |

Do not turn a diagnosis request into an implementation, treat a repository patch as an installed fix, infer a profile target from convenience, or claim live success from static checks.

## Ground the task in the actual state

Before editing:

1. Read `README.md`, `.github/CONTRIBUTING.md`, `change-log.md`, and the narrowest relevant theme file when the context is not already established.
2. Inspect `git status --short`. Preserve unrelated tracked and untracked changes, and never use cleanup commands to make the tree look clean.
3. Record the concrete before/after Firefox behavior: resting and expanded widths, hidden or visible controls, overlay versus reserved page space, focus/open state, or expected colors.
4. Record the variants that can change the result:
   - installed Firefox build and version;
   - `ultima.*`, `user.theme.*`, `sidebar.*`, and related Firefox prefs;
   - horizontal tabs, Firefox native vertical tabs, or Sidebery;
   - compact, standard, and relaxed spacing;
   - left/right placement, fullscreen/maximized state, private windows, and OS controls;
   - active add-on/LWT and color-scheme bridges.
5. Separate the three state layers:
   - repository source;
   - installed profile copy;
   - live Firefox UI after reload/restart.

For version-specific selectors, profile operations, autohide/overlay bugs, pill or gutter geometry, or multi-variant changes, read [references/reliability-checklists.md](references/reliability-checklists.md) before acting.

## Identify the owning module

Prefer an existing module and preference block:

- browser-chrome imports: `userChrome.css`
- website/about-page imports: `userContent.css`
- tabs and tab groups: `theme/settings-TABS.css`
- urlbar/searchbar: `theme/settings-urlbar.css`
- navbar/bookmarks: `theme/settings-navbar.css`
- window controls: `theme/settings-navbar-windowcontrols.css`
- Firefox sidebar/vertical tabs and Sidebery's browser-chrome container: `theme/settings-sidebar*.css` / `theme/settings-sidebar-sidebery.css`
- Sidebery extension-page variables and internal tab-tree styling: `theme/color-schemes/apply-cs-extensions.css`
- menus, panels, extensions, and icons: matching `theme/settings-*.css`
- about pages, new tab, and websites: `theme/website-*.css`
- palettes and wallpapers: `theme/color-schemes/` plus their import/bridge files
- preference defaults and comments: `user.js`

Search existing selectors, variables, prefs, and imports before proposing a new module. If more than one file appears to own the behavior, trace the cascade and import order until the owner is clear.

## Validate selector hypotheses

Use this evidence order:

1. Inspect the current owning block and nearby compatibility selectors.
2. Search the repository for the same ID, class, attribute, CSS variable, and pref.
3. Confirm the installed Firefox version and the release baseline in `change-log.md`.
4. For changed browser markup, inspect version-matched Mozilla source or the live chrome DOM/accessibility tree. Prefer Mozilla-owned source over third-party recollections.
5. Reproduce the state with the relevant prefs and layout. For autohide or positioning, capture both rest and hover/open geometry.
6. Use a controlled A/B test when multiple selectors or rules are plausible. Change one condition at a time and revert failed experiments before continuing.

Treat URL fragments, transient anonymous markup, generated class names, and accessibility labels as weak evidence unless the live target actually exposes them. When Firefox drops an attribute or changes ownership, retain a working legacy selector and add the narrowest version fallback that can be proven. Do not replace compatibility coverage merely because the new selector works on the current machine.

## Diagnose geometry and painted gaps

When the bug concerns spacing, alignment, pills, borders, or rounding, map the coordinate system before changing offsets. Treat these as distinct boxes:

- the window body or app canvas exposed around native chrome;
- `#navigator-toolbox`, including its margins, border, radius, and clipping;
- `#browser`, including native padding, flex gap, density, and fullscreen resets;
- the outer `#sidebar-box` rail and its page-space reservation;
- the selected page's `.browserContainer` frame;
- an extension's own viewport and internal full-width bars.

Use this procedure:

1. Measure live element bounds in CSS pixels with Browser Toolbox when available, or use the accessibility tree plus screenshot scale as supporting evidence. Record start/end coordinates and derive gaps from adjacent edges; account for whether a 1px border is included in the measured box.
2. Inspect version-matched Firefox CSS before adding margins or padding. Native Nova can already own toolbox margins, browser padding, flex gaps, rounded clipping, compact exceptions, and fullscreen resets.
3. Trace the requested spacing to one shared owner. Derive child offsets only when their coordinate origin differs; do not apply the same gap independently at both parent and child layers.
4. Separate geometry from paint. If the measured gap is correct but looks absent, inspect which layer paints the exposed body/app canvas instead of widening the gap.
5. Put borders and radii on the visible block that owns the shape. Preserve verified native clipping, scope out fullscreen and DOM fullscreen, and check compact density plus popup/open states before claiming the rounding safe.
6. For Sidebery internals, confirm the installed add-on version and inspect its packaged stylesheet or live extension DOM. Tabs, pinned tabs, vertical navigation, new-tab rows, and footer bars can use different width, padding, and alignment rules; center each owning container rather than shifting every icon. In Sidebery 5.6.x horizontal inline navigation, `.main-items` owns panel items while `.static-btns` owns overflow and settings controls; `[data-type="hidden"]` is the overflow entry point. Never force both nested containers to `100vw` and center their combined row in a collapsed rail.
7. Capture before, predicted, and after geometry using the same coordinate system. A calculated result is still pending live verification until Firefox has reloaded the installed CSS.

## Make the smallest safe change

- Keep one subject per change and edit the existing owning block.
- Gate optional behavior behind the literal existing or new `-moz-pref`.
- When adding a pref, update `user.js` near related prefs and update a settings index/header if that file maintains one.
- Prefer existing `--uc-*`, LWT, and palette variables over hard-coded colors.
- Preserve a one-way color-variable flow. Do not make source palette variables depend on consumers that already derive from them.
- For shared spacing, keep one public token and derive private offsets from the actual coordinate origin instead of accumulating unrelated pixel exceptions.
- Scope selectors to the relevant component and state. Check customization mode, private windows, fullscreen, and opposite-side placement when applicable.
- Keep Sidebery and Firefox native vertical tabs separate. They may coexist in Firefox's sidebar container but do not share ownership or markup. Sidebery's outer Firefox container belongs to browser chrome; its internal tab tree is extension content loaded through `userContent.css`.
- Use `display: none !important` only when the requested result truly removes a separate UI surface and its reserved layout space; otherwise prefer a layout-preserving technique.
- Avoid broad refactors, formatting churn, JavaScript/autoconfig, or release-note changes unless the request needs them.

## Profile installation rules

Install files only when the user explicitly requests it.

1. Resolve an exact absolute profile path. The user-provided path or `about:support` Profile Directory is authoritative. A `profiles.ini` default or a profile-shaped directory name is only a candidate; process arguments and lock files may corroborate but should not silently choose the target.
2. List the exact repository files and destination files before copying.
3. Back up only destination files that will be replaced, using a timestamped sibling backup or another recoverable location. Do not replace the entire `chrome/` directory for a focused fix.
4. Copy only the changed files, preserving their relative path beneath the profile's `chrome/` directory.
5. Compare every installed file byte-for-byte with its repository source.
6. Report the backup and comparison result. A successful copy is not live verification.

Use the bundled read-only audit before and after a requested installation:

```bash
.agents/skills/firefox-userchrome/scripts/audit-firefox-state.sh \
  --profile /absolute/profile/path \
  --file theme/settings-sidebar-sidebery.css \
  --pref ultima.sidebery.autohide
```

The script never selects a profile or writes files. A mismatch before installation is expected; a mismatch afterward means installation is incomplete.

## Verification

Always run checks proportional to the change:

- `git diff --check`;
- confirm changed modules remain reachable through the CSS import graph;
- search for the changed selectors/prefs and inspect all affected branches;
- `bash -n` for changed shell scripts;
- compare requested installed copies with `cmp` or the bundled audit;
- verify the working tree still contains unrelated user changes.

Require live Firefox verification when the bug depends on a Firefox release, hover/focus/open state, animation, overlay geometry, fullscreen, sidebar side, or extension/native-sidebar interaction. Static verification is sufficient for comments, documentation, obvious variable substitutions, or changes whose live state is unavailable; say so instead of overstating completion.

For live checks, exercise the meaningful transitions rather than one screenshot: rest to hover/open to rest, focus to blur, left to right, normal to fullscreen, or compact to standard. Record observed dimensions or element presence when geometry is the bug.

## Final handoff

Keep the response concise but make status unambiguous:

- **Repository:** files changed and static checks.
- **Installed profile:** exact profile/files copied and byte comparison, or “not requested.”
- **Live Firefox:** states observed, or “not run” with the remaining manual check.
- **Compatibility:** prefs/layouts/Firefox baseline covered and any untested variant.

Never collapse these into a single “fixed” claim unless all requested layers were completed.
