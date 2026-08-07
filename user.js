/*///////////////////////////////////////////////////////////////////////////////////////\

┏┓┏┓  ┳┳┓ ┏┳┓┳┳┳┓┏┓
┣ ┣   ┃┃┃  ┃ ┃┃┃┃┣┫
┻ ┻   ┗┛┗┛ ┻ ┻┛ ┗┛┗

FF Ultima:         https://github.com/soulhotel/FF-ULTIMA
Wiki:              https://ff-ultima.github.io/docs/getting-started
Latest Version:    https://github.com/soulhotel/FF-ULTIMA/releases/latest
License:           https://github.com/soulhotel/FF-ULTIMA/blob/main/LICENSE MPL 2.0

\////////////////////////////////////////////////////////////////////////////////////////*/

/* color schemes */
user_pref("user.theme.0.default", true);
user_pref("user.theme.catppuccin", false);
user_pref("user.theme.catppuccin-frappe", false);
user_pref("user.theme.catppuccin-mocha", false);
user_pref("user.theme.catppuccin-mocha-variant", false);
user_pref("user.theme.gruvbox", false);
user_pref("user.theme.kanagawa-wave", false);
user_pref("user.theme.midnight", false);
user_pref("user.theme.midnight.animated.background", false);
user_pref("user.theme.scarlet", false);
user_pref("user.theme.fluent", false);
user_pref("user.theme.fluent.thinkpad", false);
user_pref("user.theme.brave", false);
user_pref("user.theme.ayu", false);
user_pref("user.theme.rose-pine", false);
user_pref("user.theme.noctalia", false);
// Legacy alias: existing profiles with Pywalfox enabled still load Noctalia. Prefer user.theme.noctalia for new setups.
user_pref("user.theme.pywalfox", false);
user_pref("user.theme.xtras.color-scheme.force.consistency", false);
// Style modifiers layer on top of exactly one user.theme.* color scheme.
user_pref("user.theme.style.colourful", false);
user_pref("user.theme.style.glass", false); // also enable browser.tabs.allow_transparent_browser manually
// Firefox 154 Nova is the required visual and structural foundation. user.theme.* prefs select colors; user.theme.style.* prefs modify their presentation.
user_pref("browser.nova.enabled", true);

/* nav bar */
user_pref("ultima.navbar.autohide", false);
user_pref("ultima.navbar.float", false);
user_pref("ultima.navbar.float.fullsize", false);
user_pref("ultima.navbar.position", "top"); // top or bottom
user_pref("ultima.navbar.hide.buttons", false);
user_pref("ultima.navbar.bookmarks.autohide", false);
user_pref("ultima.navbar.bookmarks.compact", false);
user_pref("ultima.navbar.bookmarks.position", "left"); // left right center
user_pref("ultima.navbar.bookmarks.scrollable", false);
user_pref("ultima.navbar.bookmarks.float", false);
user_pref("ultima.navbar.bookmarks.hide.icons", false);
user_pref("ultima.navbar.bookmarks.edit.url", false);
user_pref("ultima.navbar.windowcontrols.carl", false);
user_pref("ultima.navbar.windowcontrols.trafficlights", false);
user_pref("ultima.navbar.windowcontrols.whiteout", false);
user_pref("ultima.navbar.windowcontrols.fluent", false);
user_pref("ultima.navbar.theme.extensionspanel", false);
user_pref("ultima.disable.windowcontrols.button", false);
user_pref("ultima.navbar.update.ready.label", false);
user_pref("ultima.navbar.text.for.icons", false);
user_pref("ultima.navbar.bookmarks.tab.indicator", false);
user_pref("ultima.navbar.bookmarks.focus.blur", false);

/* url bar */
user_pref("ultima.urlbar.animate.open", false);
user_pref("ultima.urlbar.animate.options", false);
user_pref("ultima.urlbar.hide.searchsuggestions", false);
user_pref("ultima.urlbar.centered", false);
user_pref("ultima.urlbar.hide.buttons", false);
user_pref("ultima.urlbar.transparent", false);
user_pref("ultima.urlbar.float", false);
user_pref("ultima.urlbar.drags.window", false);
user_pref("ultima.urlbar.scrollable", false);
user_pref("ultima.urlbar.focus.blur", false);
user_pref("ultima.urlbar.focus.blur.all", false);
user_pref("ultima.urlbar.focus.text.aligns.left", false);
user_pref("ultima.urlbar.hide.buttons.in.edge", false);
user_pref("ultima.urlbar.extension.label.fullwidth", false);
user_pref("ultima.urlbar.extension.label.hidden", false);
user_pref("ultima.urlbar.hide.trackingprotection.icon", false);

/* sidebar */
user_pref("ultima.sidebar.seperator", false);
user_pref("ultima.sidebar.hide.header", false);
user_pref("ultima.sidebar.revamped.hide.when.horizontal", false);
user_pref("ultima.sidebar.splitter.indicator", false);
// user_pref("ultima.sidebar.compact.treeviews", false);

/* sidebery */
user_pref("ultima.sidebery.autohide", false);
user_pref("ultima.sidebery.expandon.inactive.windows", false);
user_pref("ultima.sidebery.indent.mode", "standard"); // dense, compact, or standard
user_pref("user.theme.xtension.sidebery", true);

/* findbar */
user_pref("ultima.findbar.position.top", false);
user_pref("ultima.findbar.disable.background.image", false);

/* tabs related settings */
user_pref("ultima.spacing.compact.tabs", false);
user_pref("ultima.tabs.disable.update.dot", false);
user_pref("ultima.tabs.belowURLbar", false);
user_pref("ultima.tabs.hide.splitter", false);
user_pref("ultima.tabs.not.a.progress.bar", false);
user_pref("ultima.tabs.newtabbutton.ontop.1", false);
user_pref("ultima.tabs.newtabbutton.ontop.2", false);
user_pref("ultima.tabs.multiline.labels", false);
user_pref("ultima.tabs.closetabbutton.on.icon", false);
user_pref("ultima.tabs.pinned.always.visible", false);
user_pref("ultima.tabs.pinned.collapsed.grid", true);
user_pref("ultima.tabs.pinned.collapsed.stack", false);
user_pref("ultima.tabs.pinned.transparent.background", false);
user_pref("ultima.tabs.tabbar.autohide+compact", false);
user_pref("ultima.tabs.tabbar.autohide", false);
user_pref("ultima.tabs.tabbar.disabled", false);
user_pref("ultima.tabs.tabbar.hide.buttonstrip", false);
user_pref("ultima.tabs.tabgroups.label.1", false);
user_pref("ultima.tabs.tabgroups.label.2", false);
user_pref("ultima.tabs.tabgroups.label.3", false);
user_pref("ultima.tabs.tabgroups.label.tthornton", false);
user_pref("ultima.tabs.tabgroups.background.1", false);
user_pref("ultima.tabs.tabgroups.background.2", false);
user_pref("ultima.tabs.tabgroups.background.3", false);
user_pref("ultima.tabs.disable.scrollbar", false);
user_pref("ultima.tabs.horizontal.under.navbar", false);
user_pref("ultima.tabs.horizontal.fullwidth", false);
user_pref("ultima.tabs.focus.blur", false);
user_pref("ultima.tabs.tabCounter", false);
user_pref("ultima.tabs.splitview.tab.seperator", false);
user_pref("ultima.tabs.splitview.focus.opacity", false);
user_pref("ultima.tabs.splitview.focus.shrink", false);
user_pref("ultima.tabs.splitview.gradient.background", false);
user_pref("ultima.tabs.tab.outline", ""); // full, top, none
user_pref("ultima.tabs.tab.outline.color", ""); // red blue green pink black white gradient none

/* Firefox owns horizontal/vertical tab and native-sidebar layout defaults. */

/* context menus */
user_pref("ultima.spacing.compact.menus", false);
user_pref("ultima.spacing.compact.contextmenu", false);
user_pref("ultima.spacing.relaxed.contextmenu", false);
user_pref("ultima.contextmenu.no.icons", false);
user_pref("ultima.contextmenu.no.navigation.icons", false);
user_pref("ultima.contextmenu.reduce.options", false);
user_pref("ultima.contextmenu.hide.separators", false);
user_pref("ultima.contextmenu.restore.unload.tab", false);

/* alternate styles */
user_pref("ultima.spacing.compact", false);
user_pref("ultima.spacing.relaxed", false); 
user_pref("ultima.tabs.tabContainer.1", false);
user_pref("ultima.tabs.tabContainer.2", false);
user_pref("ultima.tabs.tabContainer.3", false);
user_pref("ultima.xstyle.private", false);              /*private browser home page*/
user_pref("ultima.spacing.compact.addonmanager", false); /*add on manager*/
user_pref("ultima.privatebrowsing.gradient.border", false);

/* extra theming */
user_pref("ultima.theme.icons", false);
user_pref("user.theme.xtension.ublock", true);
user_pref("user.theme.xtension.YT", false);
user_pref("user.theme.xtension.reddit", false);
user_pref("ultima.scrollbar.thin", false);
user_pref("user.theme.xtension.swap.addon.colors", false);

/* override wallpapers */
user_pref("user.theme.wallpaper.catppuccin", false);
user_pref("user.theme.wallpaper.catppuccin-mocha", false);
user_pref("user.theme.wallpaper.catppuccin-frappe", false);
user_pref("user.theme.wallpaper.dusky", false);
user_pref("user.theme.wallpaper.fullmoon", false);
user_pref("user.theme.wallpaper.green", false);
user_pref("user.theme.wallpaper.gruvbox", false);
user_pref("user.theme.wallpaper.gruvbox.flowers", false);
user_pref("user.theme.wallpaper.gruvbox.light", false);
user_pref("user.theme.wallpaper.kanagawa-wave", false);
user_pref("user.theme.wallpaper.rose-pine", false);
user_pref("user.theme.wallpaper.rose-pine-dawn", false);
user_pref("user.theme.wallpaper.midnight", false);
user_pref("user.theme.wallpaper.midnight2", false);
user_pref("user.theme.wallpaper.fluent.dark", false);
user_pref("user.theme.wallpaper.fluent.light", false);
user_pref("user.theme.wallpaper.ayu", false);
user_pref("user.theme.wallpaper.noctalia", false);
// Legacy alias for existing profiles. Prefer user.theme.wallpaper.noctalia for new setups.
user_pref("user.theme.wallpaper.pywalfox", false);
user_pref("user.theme.wallpaper.fluid-gradient", false);

/* extra configs */
user_pref("ultima.enable.nightly.config", false);
user_pref("ultima.enable.js.config", false);
user_pref("widget.windows.mica", true);
user_pref("widget.windows.mica.extra", true);
user_pref("widget.windows.mica.popups", 2);
user_pref("widget.windows.mica.toplevel-backdrop", 2);
user_pref("widget.macos.titlebar-blend-mode.behind-window", true);
user_pref("browser.tabs.allow_transparent_browser", false); /* user must toggle */

/* extra required */
user_pref("ultima.xstyle.highlight.aboutconfig", false);
user_pref("browser.aboutConfig.showWarning", false);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("devtools.debugger.remote-enabled", true);
user_pref("devtools.chrome.enabled", true);
user_pref("devtools.debugger.prompt-connection", false);
user_pref("svg.context-properties.content.enabled", true);
user_pref("layout.css.has-selector.enabled", true);
user_pref("widget.gtk.ignore-bogus-leave-notify", 1);
user_pref("widget.gtk.rounded-bottom-corners.enabled", true);
user_pref("widget.gtk.native-context-menus", false);

/* extra recommended */
// user_pref("browser.tabs.groups.enabled", true);
user_pref("browser.tabs.splitView.enabled", true);
// user_pref("browser.tabs.hoverPreview.enabled", true);
// user_pref("browser.tabs.groups.hoverPreview.enabled", true);
user_pref("findbar.highlightAll", true);
user_pref("browser.tabs.insertAfterCurrent", true);
user_pref("browser.search.context.loadInBackground", true);
user_pref("browser.bookmarks.openInTabClosesMenu", false);
// this animation is very inconsistent especially when compared cross-platform, better left minimal or off
user_pref("full-screen-api.transition-duration.enter", "0 0"); 
user_pref("full-screen-api.transition-duration.leave", "0 0");
user_pref("full-screen-api.warning.timeout", 0);
user_pref("general.smoothScroll", true);
user_pref("general.smoothScroll.msdPhysics.enabled", true);
