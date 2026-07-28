# FF Ultima Nova Foundation

Firefox 154 Nova is FF Ultima's required structural and visual baseline.
`browser.nova.enabled` lets Firefox own the default chrome and New Tab layout;
the selected `user.theme.*` palette continues to own colors.

`user.theme.nova` remains retired. Nova is a design system, not a selectable
color scheme.

## Pinned source

The initial baseline is Firefox Developer Edition 154.0b2:

- tag: `FIREFOX_154_0b2_RELEASE`;
- Git commit: `946dc6c3467a2a952e0bc3c8a8808cdbcb2acae6`;
- Mozilla SourceStamp: `b7b1868f2e31da0d089ccb869ec773fa5d9fd9ac`;
- BuildID: `20260725024243`.

Mozilla's 20 `*.nova.tokens.json` files contain 307 overrides. Their generated,
versioned snapshot is stored at
`.github/nova-tokens/firefox-154.0b2.json`.

Regenerate it from an exact Firefox source checkout:

```sh
node .github/extract-nova-tokens.mjs \
  --source /path/to/firefox-source \
  --output .github/nova-tokens/firefox-154.0b2.json
```

The extractor refuses a different commit/tag, unexpected source-file count, or
unexpected token count. A Firefox baseline upgrade therefore requires an
intentional source and snapshot review.

## Ownership and cascade

The runtime order is:

1. active `--uc-*` palette sources;
2. private `--uc-nova-*` semantic tokens;
3. Firefox 153/154 compatibility aliases;
4. native/shared appearance consumers;
5. optional feature modules;
6. custom CSS.

Palette sources flow one way into consumers. No shared semantic or Firefox
output token may write back into a palette source. Noctalia and the legacy
Pywalfox preference remain narrow LWT-backed source adapters.

Mozilla's fixed gray, violet, and categorical ramps are preserved in the
snapshot for provenance, but they are not imported into FF Ultima. Instead:

- existing browser, toolbar, URL-bar, sidebar, panel, tab, and context-menu
  surfaces retain their palette owners;
- accent 1 supplies focus, primary actions, and the leading selected-tab border;
- accent 2 supplies the trailing selected-tab border and hover hue;
- hover uses a 25% translucent accent surface;
- active/open uses a 40% translucent accent surface;
- selected tabs retain `--uc-tab-selected` and `--uc-tab-selected-text`.

## Source-derived presentation

The shared foundation follows Firefox 154 Nova:

- 4px, 8px, 12px, 16px, and 24px radius tiers;
- 24px tabs, controls, menu rows, and URL results;
- 16px panels, cards, and popups; chrome blocks retain Firefox's platform radius;
- an 8px FF Ultima outer chrome gap, 8px toolbar padding, and 6px tab block margins;
- 32px standard URL-result and vertical-tab rows;
- 2px focus treatment and native Nova elevation recipes.

Inherently circular controls remain circular. The temporary
`ultima.theme.corner.radius` preference has been removed; an old profile value
is harmless and inert.

## Surface and layout contract

Firefox owns the resting toolbar, tab, native-sidebar, content, and New Tab
layout. FF Ultima supplies shared appearance semantics to browser chrome,
Sidebery, about pages, supported extensions, YouTube, Reddit, and the existing
in-tree website modules.

Optional `ultima.*` features continue to own only their named behavior,
including hidden/autohide tabs, Sidebery autohide, floating bars, spacing modes,
tab groups, split view, and window-control styles. The wallpaper layer remains
independent.

Repository validation, profile installation, and live Firefox verification are
separate states. This source change does not install into or restart a profile.
