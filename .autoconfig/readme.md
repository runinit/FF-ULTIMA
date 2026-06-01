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

For users who want the extended userchromejs usage, you can use this folder and the [setup documentation](https://ff-ultima.github.io/docs/settings/userchrome-and-autoconfig/setup) to get started. Included is a collection of scripts tested in FF Ultima.

## Locked distro preferences

Some distro Firefox packages install locked default preferences under the Firefox application directory. If those files lock `browser.newtabpage.enabled` or Activity Stream feed prefs, the Firefox wordmark, search box, shortcuts, and Customize controls can disappear from `about:newtab`. FF Ultima CSS and a profile `user.js` cannot override locked application prefs; remove or disable the vendor preference source first, then restart Firefox.
