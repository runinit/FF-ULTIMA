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

## Noctalia reference template

The opt-in files in [`reference-template`](reference-template/) generate the
normal Pywal `colors.json` transport while assigning each slot a stable UI role:

| Pywal slot | FF Ultima / Firefox Nova role |
| --- | --- |
| `color0` | canvas |
| `color8` | box and toolbar |
| `color7` | raised and information box |
| `color10` | primary accent |
| `color13` | secondary and success |
| `color5` | tertiary and warning |
| `color1` | error and critical |
| `color11` | outline |
| `color12` | desaturated attention |
| `color14` | text on an accent |
| `color15` | main text |
| `color2`, `color4`, `color6`, `color9` | information, success, warning, and critical containers |

Copy `pywalfox-colors.json` to your Noctalia template directory and merge the
example TOML block into `user-templates.toml`. The template is deliberately not
installed or enabled by FF Ultima.

Optional wallpaper:
- Turn on `user.theme.wallpaper.noctalia` to use the animated Noctalia starfield wallpaper.
- The wallpaper is CSS-only, not an image asset; it derives its stars, nebula glow, and dark background from FF Ultima's Noctalia/wal color tokens.

Notes:
- `wal-colors.css` provides the wal palette to userContent targets such as Sidebery, where Firefox/LWT theme variables are not reliable.
- Existing sparse Pywal files remain supported. Missing box, outline, on-accent,
  error, attention, and status-container roles are derived from the existing
  `color0`, `color5`, `color7`, `color10`, `color13`, and `color15` values.
- Refresh `wal-colors.css` from `~/.cache/wal/colors.json` after changing wallpapers/palettes, then restart Firefox so userChrome/userContent CSS is reloaded.
- Do not enable Pywalfox's bundled custom `userChrome.css` / `userContent.css` over FF Ultima; both systems would compete for the same Firefox profile entrypoints.
- Pywalfox should own palette generation and Firefox Theme API application.
  FF Ultima consumes those values in one direction:
  generated palette or LWT inputs → Noctalia roles → Nova semantics → Firefox
  consumers.
