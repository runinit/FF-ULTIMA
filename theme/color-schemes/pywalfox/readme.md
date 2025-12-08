# Pywalfox Color Scheme

A dynamic color scheme designed for use with [Pywalfox](https://github.com/Frewacom/pywalfox).

## Overview

This theme automatically adapts to colors from your system's pywal colorscheme. Pywalfox dynamically injects CSS variables into Firefox, and this theme is configured to use those variables for seamless integration with your desktop environment.

## Requirements

1. **Pywal** - Generate colorschemes from your wallpaper: https://github.com/dylanaraps/pywal
2. **Pywalfox Extension** - Firefox extension that applies pywal colors: https://addons.mozilla.org/en-US/firefox/addon/pywalfox/
3. **Pywalfox Native App** - Required for communication between pywal and Firefox

## Installation

1. Install Pywal and generate a colorscheme:
   ```bash
   wal -i /path/to/your/wallpaper.jpg
   ```

2. Install the Pywalfox Firefox extension from Mozilla Add-ons

3. Install the Pywalfox native messaging app:
   ```bash
   pip install pywalfox
   pywalfox install
   ```

4. Enable the theme in `about:config`:
   ```
   user.theme.pywalfox = true
   ```
   (Make sure to disable other FF Ultima themes)

5. Click the Pywalfox extension icon and press "Fetch Pywal Colors"

## Features

- **Dynamic Colors**: All UI colors adapt to your pywal colorscheme
- **No Wallpaper**: Uses solid background color that blends with your theme
- **Full FF Ultima Support**: All FF Ultima features work with this theme

## Optional: GNOME Integration

For GNOME desktop users, you can enable additional GNOME-style UI refinements:

```
ultima.xstyle.gnome = true
```

This provides:
- GNOME-style rounded menus and popups
- Consistent button and control styling
- Dialog box refinements
- Form control enhancements

## How It Works

The theme uses Firefox's `--lwt-*` CSS variables which Pywalfox overrides at runtime:
- `--lwt-accent-color` - Background/base color
- `--lwt-text-color` - Text color
- `--lwt-tab-line-color` - Accent/highlight color

FF Ultima's color variables (`--uc-*`) are derived from these Pywalfox variables, ensuring consistent theming throughout the browser.

## Troubleshooting

**Colors not updating?**
- Make sure Pywalfox native app is running
- Click "Fetch Pywal Colors" in the extension popup
- Run `pywalfox update` from terminal

**Theme looks wrong?**
- Ensure only `user.theme.pywalfox` is set to `true` in `about:config`
- Disable any other FF Ultima color schemes
