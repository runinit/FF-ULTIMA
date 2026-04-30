# Agent Notes for FF Ultima

This repository is an existing Firefox `userChrome.css` / `userContent.css` theme, not a greenfield app. Start by preserving the current theme behavior and making the smallest change that proves value.

## What to read first

1. `README.md` — product promise, install paths, supported layouts, and docs links.
2. `.github/CONTRIBUTING.md` — contribution constraints and file-placement rules.
3. `change-log.md` — current release notes and the Firefox version baseline.
4. The relevant theme file under `theme/` before editing anything.

## Current structure

- `userChrome.css` imports the browser-chrome theme modules in `theme/`.
- `userContent.css` imports website/new-tab/about-page styling plus color-scheme extensions.
- `user.js` lists preference defaults such as `ultima.*` and `user.theme.*`.
- `theme/settings-*.css` files hold configurable feature blocks, usually gated by `@media -moz-pref(...)`.
- `theme/color-schemes/` contains palette-specific CSS, previews, and readmes.
- `.autoconfig/` is optional support for extended userChromeJS setups.

## First thing to do on a new change

Do a quick baseline before planning implementation:

1. Identify the exact user-visible bug, feature, or polish target.
2. Map it to the narrowest existing file category from `.github/CONTRIBUTING.md`.
3. List the affected prefs, layouts, OS/browser variants, and extensions such as Sidebery if relevant.
4. Capture the expected before/after behavior in concrete Firefox terms.
5. Only then edit the smallest relevant CSS block and update `user.js` defaults or comments if a setting changes.

Avoid starting with broad refactors, new infrastructure, or cross-cutting cleanup unless the requested change specifically needs them.

## Verification expectations

There is no conventional unit-test suite in this repo. Verification should therefore be evidence-driven:

- Run shell syntax checks for changed scripts when applicable, e.g. `bash -n .github/packagetheme.sh .github/versionhistory.sh`.
- For CSS/theme changes, verify the relevant Firefox UI state manually or with screenshots in a profile that has `toolkit.legacyUserProfileCustomizations.stylesheets` enabled.
- Exercise the affected preference combinations, not just the default path.
- Check that imports still resolve and that the changed file remains in the existing module/category structure.

## Contribution guardrails

- Keep one subject per change.
- Prefer editing the existing feature file over creating a new file.
- Name new preferences literally and consistently with the owning file/category.
- Preserve optionality: FF Ultima is built around many user-controlled settings.
- Treat Firefox-version-specific selectors as fragile; verify against the release baseline in `change-log.md`.
