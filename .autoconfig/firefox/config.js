// skip 1st line
try {
  var Cc = Components.classes;
  var Ci = Components.interfaces;
  var Cu = Components.utils;

  function getService(contractId, iface) {
    return Cc[contractId].getService(iface);
  }

  function safeString(value) {
    try {
      return String(value).slice(0, 1000);
    } catch (_stringError) {
      return '<unstringifiable>';
    }
  }

  function reportError(error) {
    try {
      Cu.reportError(error);
    } catch (_reportError) {}
  }

  var Services = this.Services || {
    appinfo: getService('@mozilla.org/xre/app-info;1', Ci.nsIXULAppInfo),
    console: getService('@mozilla.org/consoleservice;1', Ci.nsIConsoleService),
    dirsvc: getService('@mozilla.org/file/directory_service;1', Ci.nsIProperties),
    io: getService('@mozilla.org/network/io-service;1', Ci.nsIIOService),
    obs: getService('@mozilla.org/observer-service;1', Ci.nsIObserverService),
    prefs: getService('@mozilla.org/preferences-service;1', Ci.nsIPrefBranch),
    scriptloader: getService('@mozilla.org/moz/jssubscript-loader;1', Ci.mozIJSSubScriptLoader),
    scriptSecurityManager: getService('@mozilla.org/scriptsecuritymanager;1', Ci.nsIScriptSecurityManager),
    sysinfo: getService('@mozilla.org/system-info;1', Ci.nsIPropertyBag2),
    wm: getService('@mozilla.org/appshell/window-mediator;1', Ci.nsIWindowMediator),
  };

  this.Services = Services;

  function mark(stage) {
    try {
      Services.prefs.setCharPref('ultima.autoconfig.stage', stage);
      Services.console.logStringMessage('[FF Ultima] autoconfig stage: ' + stage);
    } catch (_markError) {}
  }

  function markError(stage, error) {
    const message = stage + ': ' + safeString(error && (error.stack || error.message || error));
    try {
      Services.prefs.setCharPref('ultima.autoconfig.error', message);
      Services.console.logStringMessage('[FF Ultima] autoconfig error: ' + message);
    } catch (_markError) {}
    reportError(error);
  }

  mark('start');

  lockPref('xpinstall.signatures.required', false);
  lockPref('extensions.install_origins.enabled', false);
  mark('prefs-locked');

  const cmanifest = Services.dirsvc.get('UChrm', Ci.nsIFile);
  cmanifest.append('utils');
  cmanifest.append('chrome.manifest');
  try {
    Services.prefs.setCharPref('ultima.autoconfig.chrome_manifest', cmanifest.path);
  } catch (_prefError) {}
  mark(cmanifest.exists() ? 'manifest-found' : 'manifest-missing');

  let userChromeScriptsLoaded = false;
  if (cmanifest.exists()) {
    try {
      Components.manager.QueryInterface(Ci.nsIComponentRegistrar).autoRegister(cmanifest);
      mark('manifest-registered');
    } catch (registerError) {
      markError('manifest-register', registerError);
    }

    try {
      Services.scriptloader.loadSubScript('chrome://userchromejs/content/BootstrapLoader.js');
      mark('bootstrap-loader-loaded');
    } catch (bootstrapError) {
      markError('bootstrap-loader', bootstrapError);
    }

    try {
      Services.scriptloader.loadSubScript('chrome://userchromejs/content/userChrome.js');
      mark('userchrome-loaded');
      userChromeScriptsLoaded = true;
    } catch (userChromeError) {
      markError('userchrome', userChromeError);
    }
  }

  try {
    const liveScript = Services.dirsvc.get('UChrm', Ci.nsIFile);
    liveScript.append('scripts');
    liveScript.append('ffu-matugen-live.uc.js');
    Services.prefs.setCharPref('ultima.autoconfig.matugen_live_script', liveScript.path);

    if (liveScript.exists() && !userChromeScriptsLoaded) {
      Services.scriptloader.loadSubScript(Services.io.newFileURI(liveScript).spec);
      mark('matugen-live-loaded');
    } else if (liveScript.exists()) {
      mark('matugen-live-userchromejs');
    } else {
      mark('matugen-live-missing');
    }
  } catch (liveError) {
    markError('matugen-live', liveError);
  }
} catch (ex) {
  try {
    if (typeof markError === 'function') {
      markError('top-level', ex);
    } else {
      Components.utils.reportError(ex);
    }
  } catch (_reportError) {}
}
