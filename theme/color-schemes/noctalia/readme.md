```
FF ULTIMA
Noctalia Bridge
By FF ULTIMA
```

To use this color scheme:
- Install and configure Pywal / Pywalfox.
- Generate Pywal colors so `colors.json` exists.
- Use Pywalfox to fetch/apply the generated colors to Firefox.
- Navigate to `about:config`.
- Turn on `user.theme.noctalia`.

Optional wallpaper:
- Turn on `user.theme.wallpaper.noctalia` to use the animated Noctalia starfield wallpaper.
- The wallpaper is CSS-only, not an image asset; it derives its stars, nebula glow, and dark background from FF Ultima's Noctalia/wal color tokens.

Notes:
- `wal-colors.css` provides the wal palette to userContent targets such as Sidebery, where Firefox/LWT theme variables are not reliable.
- Refresh `wal-colors.css` from `~/.cache/wal/colors.json` after changing wallpapers/palettes, then restart Firefox so userChrome/userContent CSS is reloaded.
- Do not enable Pywalfox's bundled custom `userChrome.css` / `userContent.css` over FF Ultima; both systems would compete for the same Firefox profile entrypoints.
- Pywalfox should own palette generation and Firefox Theme API application. FF Ultima owns the browser chrome structure and maps the applied theme variables into its own `--uc-*` color contract.
