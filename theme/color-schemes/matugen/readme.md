# FF Ultima Matugen color scheme

This scheme is for users who generate FF Ultima colors directly from a Matugen-style template, including shells such as Noctalia that accept Matugen-compatible templates.

## Files

- `ffu-colorscheme.css` is the static FF Ultima color-scheme loader. Do **not** generate or overwrite this file.
- `ffu-matugen-colors.template.css` is the template to install in your Matugen/shell theme flow.
- `ffu-matugen-colors.css` is generated locally beside `ffu-colorscheme.css` and is intentionally gitignored.

## Expected generated output

Write the rendered template to:

```text
<firefox-profile>/chrome/theme/color-schemes/matugen/ffu-matugen-colors.css
```

For repo/profile testing, the same generated file can also be written to:

```text
theme/color-schemes/matugen/ffu-matugen-colors.css
```

Do not point Matugen/Noctalia at:

```text
<firefox-profile>/chrome/theme/color-schemes/matugen/ffu-colorscheme.css
```

That file is only the static import loader.

## Enable the scheme

Enable Matugen and disable other FF Ultima color schemes so only one scheme owns the `--uc-*` contract:

```js
user_pref("user.theme.0.default", false);
user_pref("user.theme.pywalfox", false);
user_pref("user.theme.matugen", true);
```

## Live reload

Firefox does not continuously re-read `userChrome.css`, `userContent.css`, or imported files from disk. Firefox Color-style updates need a live transport.

FF Ultima's Matugen live path uses optional Firefox autoconfig:

1. Firefox install-level autoconfig boots from `<firefox-install>/config.js`.
2. That boot file lets userChromeJS load `<firefox-profile>/chrome/scripts/ffu-matugen-live.uc.js`, or loads it directly when the userChromeJS manifest is not installed.
3. The watcher polls `<firefox-profile>/chrome/theme/color-schemes/matugen/ffu-matugen-colors.css`.
4. When the file changes, it parses generated `--uc-*` declarations and registers a stronger live stylesheet override on `:root`, `#main-window`, and `:host`.

The live override intentionally writes `--uc-*` custom properties with `!important`; registering the generated file as-is can reload successfully but still lose the cascade to static imports.

Install or update the live reload support with:

```bash
./scripts/install-matugen-live-reload.sh
```

Useful targeted modes:

```bash
# Install only the root-owned Firefox autoconfig boot files.
./scripts/install-matugen-live-reload.sh --boot-only --firefox-dir /opt/firefox-beta

# Update only profile-side files after editing the watcher/template/loader.
./scripts/install-matugen-live-reload.sh --profile-only --profile ~/.mozilla/firefox/<profile>
```

Enable live reload prefs:

```js
user_pref("ultima.matugen.live-reload", true);
user_pref("ultima.matugen.live-reload.interval_ms", 1000);
```

## Runtime diagnostics

A successful reload logs in Browser Console:

```text
[FF Ultima] Matugen colors reloaded (watch): <profile>/chrome/theme/color-schemes/matugen/ffu-matugen-colors.css
```

The autoconfig and watcher also write diagnostic prefs:

```text
ultima.autoconfig.stage
ultima.autoconfig.error
ultima.autoconfig.chrome_manifest
ultima.autoconfig.matugen_live_script
ultima.matugen.live-reload.status
ultima.matugen.live-reload.error
ultima.matugen.live-reload.file
```

Expected healthy values after restart:

```text
ultima.autoconfig.stage = matugen-live-loaded
ultima.matugen.live-reload.status contains "state":"reloaded"
```
