```
/*///////////////////////////////////////////////////////////////////////////////////////\

┏┓┏┓  ┳┳┓ ┏┳┓┳┳┳┓┏┓
┣ ┣   ┃┃┃  ┃ ┃┃┃┃┣┫
┻ ┻   ┗┛┗┛ ┻ ┻┛ ┗┛┗
                   
FF Ultima:         https://github.com/soulhotel/FF-ULTIMA
Wiki:              https://ff-ultima.github.io/docs/getting-started
Latest Version:    https://github.com/soulhotel/FF-ULTIMA/releases/latest                 
License:           https://github.com/soulhotel/FF-ULTIMA/blob/main/LICENSE MPL 2.0

\////////////////////////////////////////////////////////////////////////////////////////*/
```

This `.autoconfig/` folder is completely optional.

It contains two kinds of support files:

- `firefox/` — install-level autoconfig boot files copied into the Firefox application directory, for example `/opt/firefox-beta/config.js` and `/opt/firefox-beta/defaults/pref/config-prefs.js`.
- `chrome/` — profile-side scripts and utilities copied into `<firefox-profile>/chrome/`.

For extended userChromeJS usage, use this folder with the [setup documentation](https://ff-ultima.github.io/docs/settings/userchrome-and-autoconfig/setup). Included scripts are tested with FF Ultima.

For Matugen/Noctalia live color reloads, userChromeJS loads `chrome/scripts/ffu-matugen-live.uc.js` when the bundled manifest is present; autoconfig loads it directly only as the no-manifest fallback. That watcher monitors the generated `theme/color-schemes/matugen/ffu-matugen-colors.css` file and registers a live `--uc-*` override when it changes. See `theme/color-schemes/matugen/readme.md` and `scripts/install-matugen-live-reload.sh` for install and troubleshooting details.
