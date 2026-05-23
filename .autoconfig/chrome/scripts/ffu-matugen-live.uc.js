// ==UserScript==
// @name           FF Ultima Matugen Live Reload
// @description    Live-reload FF Ultima's generated Matugen color variables without restarting Firefox.
// @include        main
// @onlyonce
// ==/UserScript==

(() => {
  if (globalThis.FFUltimaMatugenLive?.stop) {
    globalThis.FFUltimaMatugenLive.stop();
  }

  const PREF_ENABLED = "ultima.matugen.live-reload";
  const PREF_INTERVAL_MS = "ultima.matugen.live-reload.interval_ms";
  const PREF_STATUS = "ultima.matugen.live-reload.status";
  const PREF_ERROR = "ultima.matugen.live-reload.error";
  const PREF_LAST_FILE = "ultima.matugen.live-reload.file";
  const DEFAULT_INTERVAL_MS = 1000;

  const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
  const cssFile = Services.dirsvc.get("UChrm", Ci.nsIFile);
  for (const part of ["theme", "color-schemes", "matugen", "ffu-matugen-colors.css"]) {
    cssFile.append(part);
  }

  let activeURI = null;
  let lastModified = -1;
  let lastSize = -1;
  let timer = null;

  function setStatus(status) {
    try {
      Services.prefs.setCharPref(PREF_STATUS, JSON.stringify(status));
      Services.prefs.setCharPref(PREF_LAST_FILE, cssFile.path);
    } catch (_error) {}
  }

  function setError(error) {
    try {
      Services.prefs.setCharPref(PREF_ERROR, String(error?.stack || error?.message || error).slice(0, 1000));
    } catch (_prefError) {}
  }

  function ensurePrefs() {
    if (!Services.prefs.prefHasUserValue(PREF_ENABLED)) {
      Services.prefs.setBoolPref(PREF_ENABLED, true);
    }
    if (!Services.prefs.prefHasUserValue(PREF_INTERVAL_MS)) {
      Services.prefs.setIntPref(PREF_INTERVAL_MS, DEFAULT_INTERVAL_MS);
    }
  }

  function isEnabled() {
    try {
      return Services.prefs.getBoolPref(PREF_ENABLED, true);
    } catch (_error) {
      return true;
    }
  }

  function intervalMs() {
    try {
      return Math.max(250, Services.prefs.getIntPref(PREF_INTERVAL_MS, DEFAULT_INTERVAL_MS));
    } catch (_error) {
      return DEFAULT_INTERVAL_MS;
    }
  }

  function readCSS() {
    const stream = Cc["@mozilla.org/network/file-input-stream;1"].createInstance(Ci.nsIFileInputStream);
    stream.init(cssFile, 0x01, 0, 0);

    const converter = Cc["@mozilla.org/intl/converter-input-stream;1"].createInstance(Ci.nsIConverterInputStream);
    converter.init(stream, "UTF-8", 0, Ci.nsIConverterInputStream.DEFAULT_REPLACEMENT_CHARACTER);

    let css = "";
    const chunk = {};
    while (converter.readString(4096, chunk)) {
      css += chunk.value;
    }
    converter.close();
    return css;
  }

  function extractSchemeDeclarations(css, scheme) {
    const match = css.match(new RegExp(`@media\\s*\\(prefers-color-scheme:\\s*${scheme}\\)\\s*\\{\\s*:root\\s*\\{([\\s\\S]*?)\\}\\s*\\}`, "i"));
    if (!match) {
      return "";
    }

    return Array.from(match[1].matchAll(/(--uc-[\w-]+)\s*:\s*([^;]+);/g))
      .map(([, name, value]) => `    ${name}: ${value.trim()} !important;`)
      .join("\n");
  }

  function buildLiveOverrideCSS(sourceCSS) {
    const dark = extractSchemeDeclarations(sourceCSS, "dark");
    const light = extractSchemeDeclarations(sourceCSS, "light");
    const scope = `:root, #main-window, :host`;
    const blocks = [];

    if (dark) {
      blocks.push(`@media (prefers-color-scheme: dark) {\n  ${scope} {\n${dark}\n  }\n}`);
    }
    if (light) {
      blocks.push(`@media (prefers-color-scheme: light) {\n  ${scope} {\n${light}\n  }\n}`);
    }

    if (!blocks.length) {
      return sourceCSS;
    }

    return `/* FF Ultima Matugen live override: ${cssFile.lastModifiedTime}-${cssFile.fileSize}\n   Generated from: ${cssFile.path}\n   The !important custom-property declarations intentionally outrank the static userChrome import. */\n${blocks.join("\n\n")}`;
  }

  function cssValue(css, name) {
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const match = css.match(new RegExp(`${escaped}\\s*:\\s*([^;]+);`));
    return match ? match[1].trim() : null;
  }

  function makeURI(css) {
    return Services.io.newURI(`data:text/css;charset=utf-8,${encodeURIComponent(buildLiveOverrideCSS(css))}`);
  }

  function unregisterActiveSheet() {
    if (!activeURI) {
      return;
    }

    try {
      if (sss.sheetRegistered(activeURI, sss.USER_SHEET)) {
        sss.unregisterSheet(activeURI, sss.USER_SHEET);
      }
    } catch (error) {
      setError(error);
      Cu.reportError(error);
    }

    activeURI = null;
  }

  function reload(reason = "manual") {
    if (!isEnabled()) {
      unregisterActiveSheet();
      setStatus({ state: "disabled", reason, time: new Date().toISOString() });
      return false;
    }

    try {
      if (!cssFile.exists() || !cssFile.isFile()) {
        setStatus({ state: "missing", reason, path: cssFile.path, time: new Date().toISOString() });
        return false;
      }

      const modified = cssFile.lastModifiedTime;
      const size = cssFile.fileSize;
      if (activeURI && modified === lastModified && size === lastSize) {
        return false;
      }

      const css = readCSS();
      const previousURI = activeURI;
      const nextURI = makeURI(css);
      if (previousURI && sss.sheetRegistered(previousURI, sss.USER_SHEET)) {
        sss.unregisterSheet(previousURI, sss.USER_SHEET);
      }
      sss.loadAndRegisterSheet(nextURI, sss.USER_SHEET);
      activeURI = nextURI;
      lastModified = modified;
      lastSize = size;

      const status = {
        state: "reloaded",
        reason,
        path: cssFile.path,
        modified,
        size,
        browserColor: cssValue(css, "--uc-browser-color"),
        urlbarBackground: cssValue(css, "--uc-urlbar-background"),
        accent1: cssValue(css, "--uc-accent-color-1"),
        accent2: cssValue(css, "--uc-accent-color-2"),
        time: new Date().toISOString(),
      };
      setStatus(status);
      Services.console.logStringMessage(
        `[FF Ultima] Matugen colors reloaded (${reason}): ${cssFile.path}`
      );
      return true;
    } catch (error) {
      setStatus({ state: "error", reason, path: cssFile.path, time: new Date().toISOString() });
      setError(error);
      Cu.reportError(error);
      return false;
    }
  }

  function startTimer() {
    if (timer) {
      timer.cancel();
    }

    timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
    timer.initWithCallback(() => reload("watch"), intervalMs(), Ci.nsITimer.TYPE_REPEATING_SLACK);
  }

  function stop() {
    if (timer) {
      timer.cancel();
      timer = null;
    }
    Services.prefs.removeObserver(PREF_ENABLED, prefObserver);
    Services.prefs.removeObserver(PREF_INTERVAL_MS, prefObserver);
    unregisterActiveSheet();
    setStatus({ state: "stopped", time: new Date().toISOString() });
  }

  const prefObserver = {
    observe(_subject, _topic, prefName) {
      if (prefName === PREF_INTERVAL_MS) {
        startTimer();
      }
      reload("pref-change");
    },
  };

  ensurePrefs();
  if (Services.prefs.prefHasUserValue(PREF_ERROR)) {
    Services.prefs.clearUserPref(PREF_ERROR);
  }
  Services.prefs.addObserver(PREF_ENABLED, prefObserver);
  Services.prefs.addObserver(PREF_INTERVAL_MS, prefObserver);
  startTimer();
  reload("startup");

  globalThis.FFUltimaMatugenLive = {
    reload,
    stop,
    get file() {
      return cssFile.path;
    },
    get activeURI() {
      return activeURI?.spec ?? null;
    },
  };
})();
