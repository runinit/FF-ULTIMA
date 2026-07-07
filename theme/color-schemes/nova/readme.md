# FF ULTIMA Firefox Nova Overlay

Experimental support by FF ULTIMA.

Firefox Nova is Mozilla's in-progress Firefox design refresh. This FF Ultima module is an experimental overlay meant to ride **alongside** native Nova: when Firefox's `browser.nova.enabled` is on, Nova restructures the chrome and drops FF Ultima's base-scheme styling, and this overlay restyles those surfaces. Enable it with `user.theme.nova` while another FF Ultima base color scheme remains active.

## Usage

1. Navigate to `about:config`.
2. Keep your preferred base color scheme enabled, for example `user.theme.0.default` or `user.theme.noctalia`.
3. Turn on `user.theme.nova`. If you also run Firefox's native redesign (`browser.nova.enabled=true`), enable both — they are designed to travel together.
4. Restart Firefox or reload userChrome/userContent CSS.

## Notes

- `user.theme.nova` is intentionally additive. It reshapes and remaps FF Ultima `--uc-*` tokens instead of replacing the base palette.
- The chrome **surface rescue** (urlbar/menus) is gated on `user.theme.nova` **OR** `browser.nova.enabled`, so it also activates automatically when Firefox's native Nova is detected — the two prefs are treated as a pair, not as independent layers.
- Mozilla's Nova internals are still changing, so some Nova-era selectors and CSS variables in this module remain **provisional** and should be confirmed against the live Nova DOM via the Browser Toolbox.
- This overlay does not add a Nova wallpaper. Existing base theme and user wallpaper settings continue to apply.
- Avoid enabling multiple full base color schemes at the same time; Nova is the intended extra override layer.
