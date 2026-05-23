### <ins> FF Ultima Version 4.5 Release
- **⬇️ [Release Download](https://github.com/soulhotel/FF-ULTIMA/releases/download/4.5/ffultima4.5.zip)** direct link.<!--- **⬇️ [Source Download](https://github.com/soulhotel/FF-ULTIMA/archive/refs/heads/main.zip)** direct link.-->
- 🗨️ [Submit an issue](https://github.com/soulhotel/FF-ULTIMA/issues/new/choose) or ask questions not answered in [the Wiki](https://ff-ultima.github.io/docs/getting-started).
- ⚙️ [Change settings](https://ff-ultima.github.io/docs/category/settings), tab size, autohiding, spacing, and more.
- ⚙️ [How to Update](https://ff-ultima.github.io/docs/how-to/how-to-update) the theme to a new version.

### <ins> Version Notes
- ...
- Firefox 138+ required.
- User.js not required.
<!--
- User.js required.
- User.js not required.
- User.js (recommended) not required.
-->

### <ins> Change Log
- `fix • 🔴 •` Bridge Firefox 152+ toolbar/toolbox design-system and LWT color tokens through FF Ultima color-scheme variables so Firefox chrome, URL bar, FF Ultima icons, Sidebery, text selection, Firefox Settings, Profiles, and the customized Add-ons Manager share the active color scheme palette roles
- `fix • 🔴 •` Restore FF Ultima context-menu theming by keeping Linux menus on the styleable Firefox chrome path
- `fix • 🔴 •` Restore safer Linux GTK context-menu and leave-notify defaults to avoid delayed chrome click/right-click lockups
- `fix • 🔴 •` Remove inactive urlbar/bookmark blur overlay surfaces from layout to preserve right-click/navbar interaction after long sessions
- `fix • 🔴 •` Prevent Firefox's revamped native sidebar from covering active Sidebery with a blank grey strip after startup/display changes
- `fix • 🔴 •` Enforce consistent colors for sidebar tree view icons/text/expansion arrow #434 4c02620
- `fix • 🔴 •` queries for the url bars Tracking protection button (now #trust-container) #438 5591cdc
- `fix • 🔴 •` Split tab - horizontal tabs, spacing correction #440 5591cdc c5a649c
- `fix • 🔴 •` Removed the custom selected indicator for [collapsed][hasactivetab] tab groups, replaced with a subtle highlight on the default # indicator #453
- `new • 🟢 •` New `user.theme.pywalfox` bridge color scheme with solid `user.theme.wallpaper.pywalfox` support
- `new • 🟢 •` New `user.theme.wallpaper.fluid-gradient` animated Pywalfox-aware new-tab wallpaper
- `new • 🟢 •` New [`Rose Pine Color Scheme`](https://ff-ultima.github.io/docs/color-schemes/rose-pine) by @neyfua! #422 22640ef
- `new • 🟢 •` Setting `ultima.tabs.focus.unblur` reduces the visibiliy of tabs unless they are hovered, selected, playing audio, or loading.
- `new • 🟢 •` Setting `ultima.sidebar.compact.treeviews` compacts the tree view of the bookmarks/history sidebars ed9f73d
- `new • 🟢 •` Setting `ultima.urlbar.extension.label.hidden` hides the extension label in the urlbar, for extension webpages
- `new • 🟢 •` ?? Setting `ultima.tabs.tab.outline` gives the selected tab an outline, `full` for basic 4 sided outline, `top` for a proton style top-sided outline
- `qol • 🟡 •` Setting `ultima.tabs.tab.outline.color` (previously user.theme.xtras.tab.outline.color) controls the outline color above, from basic colors to `gradient`
- `qol • 🟡 •` Bookmarks toolbar default positioning changed to `left` in user.js. User's can set centered upon discovery
- `qol • 🟡 •` Bookmarks toolbar centered position now only applies when the window is 1920px in width. (ultima.navbar.bookmarks.position = centered) #447
- `qol • 🟡 •` splitview content footer styled to match CS f55dd70
- `qol • 🟡 •` multiline tabs see a minimal height adjustment 248c3ea
- `qol • 🟡 •` included the Ayu Color Scheme in wallpaper menu and override options #435 0cde2ff
- `qol • 🟡 •` Ayu Color Scheme adjustments to menu panel options on hover
- `qol • 🟡 •` extensions permission popup, downloads panel, backforward popup - added to navbar.autohide exclusion list b662b6d
- `qol • 🟡 •` With the addition of a `customChrome.css` entry for your own personal modifications, there's now also a `customContent.css` entry for userContent.css (website styles)
- `qol • 🟡 •` Added `ultima.sidebery.indent.mode` so Sidebery indentation defaults compact, can switch to dense, or return to standard in about:config

### <ins> Update Preview ??

https://github.com/user-attachments/assets/071111d0-c345-4ec5-8042-969e84844382

> FF Ultima is reaching it's maturity, additional updates to the theme will most likely only focus on bugs, patches, and fine-tuning. If you'd like to see more features added to the list, feel free to fork or push via pull request. Contributors, like always - are always welcome. Otherwise, enjoy.
