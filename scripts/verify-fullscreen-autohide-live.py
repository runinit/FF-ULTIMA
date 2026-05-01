#!/usr/bin/env python3
"""Live FF Ultima fullscreen/autohide parity proof.

This script launches a disposable Firefox profile with the repository theme installed,
controls it through Marionette, enters browser fullscreen and DOM fullscreen, and
prints auditable chrome/content geometry evidence for S03.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Callable

REPO_ROOT = Path(__file__).resolve().parents[1]
FIREFOX_BIN = os.environ.get("FF_ULTIMA_FIREFOX_BIN", "firefox")
DOM_FIXTURE = REPO_ROOT / "scripts" / "fixtures" / "dom-fullscreen.html"
ELEMENT_KEY = "element-6066-11e4-a52e-4f735466cecf"

CHROME_STATE_SCRIPT = r"""
const label = arguments[0] || "state";
const root = document.documentElement;

function prefValue(name, fallback = null) {
  try {
    switch (Services.prefs.getPrefType(name)) {
      case Services.prefs.PREF_BOOL:
        return Services.prefs.getBoolPref(name);
      case Services.prefs.PREF_STRING:
        return Services.prefs.getStringPref(name);
      case Services.prefs.PREF_INT:
        return Services.prefs.getIntPref(name);
      default:
        return fallback;
    }
  } catch (error) {
    return fallback;
  }
}

function roundedRect(rect) {
  return {
    top: Math.round(rect.top * 100) / 100,
    right: Math.round(rect.right * 100) / 100,
    bottom: Math.round(rect.bottom * 100) / 100,
    left: Math.round(rect.left * 100) / 100,
    width: Math.round(rect.width * 100) / 100,
    height: Math.round(rect.height * 100) / 100,
  };
}

function styleFor(selector) {
  const element = document.querySelector(selector);
  if (!element) {
    return {selector, exists: false};
  }

  const cs = getComputedStyle(element);
  const rect = element.getBoundingClientRect();
  return {
    selector,
    exists: true,
    tag: element.localName,
    id: element.id || "",
    rect: roundedRect(rect),
    display: cs.display,
    visibility: cs.visibility,
    opacity: cs.opacity,
    position: cs.position,
    top: cs.top,
    bottom: cs.bottom,
    margin: cs.margin,
    marginTop: cs.marginTop,
    marginRight: cs.marginRight,
    marginBottom: cs.marginBottom,
    marginLeft: cs.marginLeft,
    paddingTop: cs.paddingTop,
    paddingRight: cs.paddingRight,
    paddingBottom: cs.paddingBottom,
    paddingLeft: cs.paddingLeft,
    borderTopWidth: cs.borderTopWidth,
    borderRightWidth: cs.borderRightWidth,
    borderBottomWidth: cs.borderBottomWidth,
    borderLeftWidth: cs.borderLeftWidth,
    borderTopStyle: cs.borderTopStyle,
    borderRightStyle: cs.borderRightStyle,
    borderBottomStyle: cs.borderBottomStyle,
    borderLeftStyle: cs.borderLeftStyle,
    borderTopColor: cs.borderTopColor,
    borderRightColor: cs.borderRightColor,
    borderBottomColor: cs.borderBottomColor,
    borderLeftColor: cs.borderLeftColor,
    borderTopLeftRadius: cs.borderTopLeftRadius,
    borderTopRightRadius: cs.borderTopRightRadius,
    borderBottomRightRadius: cs.borderBottomRightRadius,
    borderBottomLeftRadius: cs.borderBottomLeftRadius,
    boxShadow: cs.boxShadow,
    outlineStyle: cs.outlineStyle,
    outlineWidth: cs.outlineWidth,
    outlineColor: cs.outlineColor,
    backgroundColor: cs.backgroundColor,
    ucContentMargins: cs.getPropertyValue("--uc-content-margins").trim(),
    ucContentRadius: cs.getPropertyValue("--uc-content-border-radius").trim(),
    ucSidebarRadius: cs.getPropertyValue("--uc-sidebar-border-radius").trim(),
    ucNavbarEdgeSeam: cs.getPropertyValue("--uc-navbar-autohide-edge-seam").trim(),
  };
}

return {
  label,
  firefoxVersion: Services.appinfo.version,
  platform: Services.appinfo.OS,
  userAgent: navigator.userAgent,
  windowFullScreen: window.fullScreen,
  attrs: {
    id: root.id,
    sizemode: root.getAttribute("sizemode"),
    inFullscreen: root.getAttribute("inFullscreen"),
    inDOMFullscreen: root.getAttribute("inDOMFullscreen"),
    chromehidden: root.getAttribute("chromehidden"),
    sessionrestored: root.getAttribute("sessionrestored"),
  },
  prefs: {
    legacyUserChrome: prefValue("toolkit.legacyUserProfileCustomizations.stylesheets"),
    navbarAutohide: prefValue("ultima.navbar.autohide"),
    bookmarksAutohide: prefValue("ultima.navbar.bookmarks.autohide"),
    navbarPosition: prefValue("ultima.navbar.position"),
    fullscreenWarningTimeout: prefValue("full-screen-api.warning.timeout"),
  },
  rootVars: {
    ucContentMargins: getComputedStyle(root).getPropertyValue("--uc-content-margins").trim(),
    ucContentRadius: getComputedStyle(root).getPropertyValue("--uc-content-border-radius").trim(),
    ucSidebarRadius: getComputedStyle(root).getPropertyValue("--uc-sidebar-border-radius").trim(),
    ucNavbarEdgeSeam: getComputedStyle(root).getPropertyValue("--uc-navbar-autohide-edge-seam").trim(),
    ucTopbarsCombinedHeight: getComputedStyle(root).getPropertyValue("--uc-topbars-combined-height").trim(),
  },
  toolbox: styleFor("#navigator-toolbox"),
  navBar: styleFor("#nav-bar"),
  browser: styleFor("#browser"),
  tabbox: styleFor("#tabbrowser-tabbox"),
  tabpanels: styleFor("#tabbrowser-tabpanels"),
  selectedBrowser: styleFor("#tabbrowser-tabpanels browser[type]"),
};
"""

CONTENT_STATE_SCRIPT = r"""
const target = document.querySelector("#fullscreen-target");
const button = document.querySelector("#enter-fullscreen");
function roundedRect(rect) {
  return {
    top: Math.round(rect.top * 100) / 100,
    right: Math.round(rect.right * 100) / 100,
    bottom: Math.round(rect.bottom * 100) / 100,
    left: Math.round(rect.left * 100) / 100,
    width: Math.round(rect.width * 100) / 100,
    height: Math.round(rect.height * 100) / 100,
  };
}
function styleFor(element) {
  if (!element) {
    return null;
  }
  const cs = getComputedStyle(element);
  return {
    rect: roundedRect(element.getBoundingClientRect()),
    margin: cs.margin,
    borderRadius: cs.borderRadius,
    boxShadow: cs.boxShadow,
    backgroundColor: cs.backgroundColor,
  };
}
return {
  readyState: document.readyState,
  location: location.href,
  fullscreenEnabled: document.fullscreenEnabled,
  fullscreenElementId: document.fullscreenElement ? document.fullscreenElement.id : "",
  fullscreenRequest: document.documentElement.dataset.fullscreenRequest || "",
  fullscreenElementDataset: document.documentElement.dataset.fullscreenElement || "",
  hasButton: Boolean(button),
  hasTarget: Boolean(target),
  target: styleFor(target),
};
"""

HOVER_LOCK_SCRIPT = r"""
const toolbox = document.querySelector("#navigator-toolbox");
if (!toolbox) {
  return {available: false, locked: false, error: "#navigator-toolbox missing"};
}
InspectorUtils.addPseudoClassLock(toolbox, ":hover");
return {
  available: true,
  locked: InspectorUtils.hasPseudoClassLock(toolbox, ":hover"),
  matchesHover: toolbox.matches(":hover"),
};
"""

HOVER_UNLOCK_SCRIPT = r"""
const toolbox = document.querySelector("#navigator-toolbox");
if (toolbox) {
  InspectorUtils.removePseudoClassLock(toolbox, ":hover");
}
return true;
"""


class ProbeFailure(RuntimeError):
    """A verifier assertion failed."""


class MarionetteError(RuntimeError):
    """A raw Marionette command failed."""


class MarionetteClient:
    def __init__(self, host: str, port: int, timeout: float = 5.0) -> None:
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.sock.settimeout(timeout)
        self.message_id = 0
        self.hello = self._recv_packet()

    def close(self) -> None:
        try:
            self.sock.close()
        except OSError:
            pass

    def _recv_packet(self) -> Any:
        header = bytearray()
        while True:
            chunk = self.sock.recv(1)
            if not chunk:
                raise MarionetteError("Marionette socket closed while reading packet length")
            if chunk == b":":
                break
            header += chunk

        length = int(header.decode("ascii"))
        payload = bytearray()
        while len(payload) < length:
            chunk = self.sock.recv(length - len(payload))
            if not chunk:
                raise MarionetteError("Marionette socket closed while reading packet payload")
            payload += chunk
        return json.loads(payload.decode("utf-8"))

    def command(self, name: str, params: dict[str, Any] | None = None) -> Any:
        self.message_id += 1
        payload = json.dumps([0, self.message_id, name, params or {}], separators=(",", ":")).encode("utf-8")
        self.sock.sendall(str(len(payload)).encode("ascii") + b":" + payload)
        response = self._recv_packet()
        if not isinstance(response, list) or len(response) < 4:
            raise MarionetteError(f"Unexpected Marionette response for {name}: {response!r}")
        _packet_type, response_id, error, result = response
        if response_id != self.message_id:
            raise MarionetteError(f"Unexpected Marionette response id for {name}: {response_id} != {self.message_id}")
        if error:
            message = error.get("message", error) if isinstance(error, dict) else error
            stack = error.get("stacktrace", "") if isinstance(error, dict) else ""
            raise MarionetteError(f"{name} failed: {message}\n{stack}".rstrip())
        return result

    def value_command(self, name: str, params: dict[str, Any] | None = None) -> Any:
        result = self.command(name, params)
        if isinstance(result, dict) and "value" in result:
            return result["value"]
        return result

    def set_context(self, context: str) -> None:
        self.value_command("Marionette:SetContext", {"value": context})

    def execute(self, script: str, args: list[Any] | None = None, sandbox: str = "ffu-live") -> Any:
        return self.value_command(
            "WebDriver:ExecuteScript",
            {
                "script": script,
                "args": args or [],
                "newSandbox": True,
                "sandbox": sandbox,
            },
        )


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_for_port(proc: subprocess.Popen[Any], port: int, timeout: float) -> None:
    deadline = time.monotonic() + timeout
    last_error: OSError | None = None
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise ProbeFailure(f"Firefox exited before Marionette was ready; see preserved firefox-stderr.log")
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.5):
                return
        except OSError as error:
            last_error = error
            time.sleep(0.2)
    raise ProbeFailure(f"Timed out waiting for Marionette on port {port}: {last_error}")


def wait_until(description: str, predicate: Callable[[], bool], timeout: float = 10.0, interval: float = 0.2) -> None:
    deadline = time.monotonic() + timeout
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            if predicate():
                return
        except Exception as error:  # keep polling transient chrome/content states
            last_error = error
        time.sleep(interval)
    if last_error:
        raise ProbeFailure(f"Timed out waiting for {description}: last error: {last_error}")
    raise ProbeFailure(f"Timed out waiting for {description}")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ProbeFailure(message)


def parse_px(value: Any) -> float:
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    match = re.search(r"-?\d+(?:\.\d+)?", str(value))
    return float(match.group(0)) if match else 0.0


def parse_opacity(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 1.0


def color_alpha(value: str) -> float:
    if not value or value == "transparent":
        return 0.0
    match = re.match(r"rgba?\(([^)]+)\)", value)
    if not match:
        return 1.0
    parts = [part.strip() for part in match.group(1).split(",")]
    if len(parts) < 4:
        return 1.0
    try:
        return float(parts[3])
    except ValueError:
        return 1.0


def margins(style: dict[str, Any]) -> list[float]:
    return [parse_px(style.get(field)) for field in ("marginTop", "marginRight", "marginBottom", "marginLeft")]


def radii(style: dict[str, Any]) -> list[float]:
    return [
        parse_px(style.get(field))
        for field in ("borderTopLeftRadius", "borderTopRightRadius", "borderBottomRightRadius", "borderBottomLeftRadius")
    ]


def border_is_visible(style: dict[str, Any]) -> bool:
    sides = ("Top", "Right", "Bottom", "Left")
    for side in sides:
        width = parse_px(style.get(f"border{side}Width"))
        border_style = style.get(f"border{side}Style")
        alpha = color_alpha(str(style.get(f"border{side}Color", "")))
        if width > 0.5 and border_style not in ("none", "hidden") and alpha > 0.05:
            return True
    return False


def shadow_is_visible(style: dict[str, Any]) -> bool:
    shadow = str(style.get("boxShadow", "none"))
    if shadow == "none":
        return False
    if "rgba" in shadow and all(float(value) == 0.0 for value in re.findall(r"rgba\([^)]*,\s*([01](?:\.\d+)?)\)", shadow)):
        return False
    return True


def outline_is_visible(style: dict[str, Any]) -> bool:
    return parse_px(style.get("outlineWidth")) > 0.5 and style.get("outlineStyle") not in ("none", "hidden") and color_alpha(str(style.get("outlineColor", ""))) > 0.05


def element_visible(style: dict[str, Any]) -> bool:
    if not style or not style.get("exists"):
        return False
    rect = style.get("rect", {})
    return (
        style.get("display") != "none"
        and style.get("visibility") not in ("hidden", "collapse")
        and parse_opacity(style.get("opacity")) > 0.05
        and parse_px(rect.get("height")) > 1
        and parse_px(rect.get("width")) > 1
    )


def toolbox_pinned_over_content(style: dict[str, Any]) -> bool:
    if not element_visible(style):
        return False
    rect = style.get("rect", {})
    return parse_px(rect.get("bottom")) > 1 and parse_px(rect.get("top")) < 80


def assert_zero_margins(state: dict[str, Any], key: str, owner: str, selector: str, mode: str) -> None:
    style = state[key]
    require(style.get("exists"), f"{mode} {selector} missing; inspect {owner}")
    values = margins(style)
    require(
        all(abs(value) <= 0.5 for value in values),
        f"{mode} {selector} retained margin {values}; inspect {owner}",
    )


def assert_zero_radii(state: dict[str, Any], key: str, owner: str, selector: str, mode: str) -> None:
    style = state[key]
    require(style.get("exists"), f"{mode} {selector} missing; inspect {owner}")
    values = radii(style)
    require(
        all(abs(value) <= 0.5 for value in values),
        f"{mode} {selector} retained border radius {values}; inspect {owner}",
    )


def assert_no_border_shadow_outline(state: dict[str, Any], key: str, owner: str, selector: str, mode: str) -> None:
    style = state[key]
    require(style.get("exists"), f"{mode} {selector} missing; inspect {owner}")
    require(not border_is_visible(style), f"{mode} {selector} has visible border; inspect {owner}: {border_summary(style)}")
    require(not shadow_is_visible(style), f"{mode} {selector} has visible box-shadow; inspect {owner}: {style.get('boxShadow')}")
    require(not outline_is_visible(style), f"{mode} {selector} has visible outline; inspect {owner}: {style.get('outlineWidth')} {style.get('outlineStyle')} {style.get('outlineColor')}")


def rect_summary(style: dict[str, Any]) -> str:
    rect = style.get("rect", {}) if style else {}
    return f"top={rect.get('top')} bottom={rect.get('bottom')} height={rect.get('height')} width={rect.get('width')}"


def margin_summary(style: dict[str, Any]) -> str:
    return f"{style.get('marginTop')}/{style.get('marginRight')}/{style.get('marginBottom')}/{style.get('marginLeft')}"


def radius_summary(style: dict[str, Any]) -> str:
    return f"{style.get('borderTopLeftRadius')}/{style.get('borderTopRightRadius')}/{style.get('borderBottomRightRadius')}/{style.get('borderBottomLeftRadius')}"


def border_summary(style: dict[str, Any]) -> str:
    return (
        f"top={style.get('borderTopWidth')} {style.get('borderTopStyle')} {style.get('borderTopColor')}; "
        f"right={style.get('borderRightWidth')} {style.get('borderRightStyle')} {style.get('borderRightColor')}; "
        f"bottom={style.get('borderBottomWidth')} {style.get('borderBottomStyle')} {style.get('borderBottomColor')}; "
        f"left={style.get('borderLeftWidth')} {style.get('borderLeftStyle')} {style.get('borderLeftColor')}"
    )


def print_state(state: dict[str, Any]) -> None:
    label = state["label"]
    attrs = state["attrs"]
    print(
        f"{label}: root attrs sizemode={attrs.get('sizemode')} inFullscreen={attrs.get('inFullscreen')} "
        f"inDOMFullscreen={attrs.get('inDOMFullscreen')} windowFullScreen={state.get('windowFullScreen')}"
    )
    print(
        f"{label}: vars contentMargins={state['rootVars'].get('ucContentMargins')} "
        f"contentRadius={state['rootVars'].get('ucContentRadius')} sidebarRadius={state['rootVars'].get('ucSidebarRadius')} "
        f"edgeSeam={state['rootVars'].get('ucNavbarEdgeSeam')} topbars={state['rootVars'].get('ucTopbarsCombinedHeight')}"
    )
    toolbox = state["toolbox"]
    print(
        f"{label}: #navigator-toolbox {rect_summary(toolbox)} display={toolbox.get('display')} "
        f"visibility={toolbox.get('visibility')} opacity={toolbox.get('opacity')} position={toolbox.get('position')} "
        f"border={border_summary(toolbox)} shadow={toolbox.get('boxShadow')}"
    )
    for key, selector in (
        ("browser", "#browser"),
        ("tabbox", "#tabbrowser-tabbox"),
        ("tabpanels", "#tabbrowser-tabpanels"),
        ("selectedBrowser", "#tabbrowser-tabpanels browser[type]"),
    ):
        style = state[key]
        print(
            f"{label}: {selector} {rect_summary(style)} margin={margin_summary(style)} radius={radius_summary(style)} "
            f"borderVisible={border_is_visible(style)} shadow={style.get('boxShadow')} outline={style.get('outlineWidth')} {style.get('outlineStyle')}"
        )


def install_profile(profile: Path, port: int) -> None:
    chrome_dir = profile / "chrome"
    chrome_dir.mkdir(parents=True)
    for required in ("userChrome.css", "userContent.css", "user.js", "theme"):
        require((REPO_ROOT / required).exists(), f"missing repository path for disposable profile install: {required}")

    shutil.copy2(REPO_ROOT / "userChrome.css", chrome_dir / "userChrome.css")
    shutil.copy2(REPO_ROOT / "userContent.css", chrome_dir / "userContent.css")
    shutil.copytree(REPO_ROOT / "theme", chrome_dir / "theme")
    (chrome_dir / "customChrome.css").write_text("/* Placeholder for live verifier disposable profile. */\n", encoding="utf-8")
    (chrome_dir / "customContent.css").write_text("/* Placeholder for live verifier disposable profile. */\n", encoding="utf-8")

    original_user_js = (REPO_ROOT / "user.js").read_text(encoding="utf-8")
    overrides = f"""

/* FF Ultima S03 live fullscreen verifier overrides. */
user_pref("marionette.port", {port});
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("ultima.navbar.autohide", true);
user_pref("ultima.navbar.bookmarks.autohide", true);
user_pref("ultima.navbar.position", "top");
user_pref("ultima.navbar.float", false);
user_pref("ultima.navbar.float.fullsize", false);
user_pref("ultima.urlbar.float", false);
user_pref("full-screen-api.transition-duration.enter", "0 0");
user_pref("full-screen-api.transition-duration.leave", "0 0");
user_pref("full-screen-api.warning.timeout", 0);
user_pref("full-screen-api.approval-required", false);
user_pref("full-screen-api.allow-trusted-requests-only", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.startup.page", 0);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("app.normandy.enabled", false);
"""
    (profile / "user.js").write_text(original_user_js.rstrip() + overrides, encoding="utf-8")


def launch_firefox(profile: Path, port: int) -> tuple[subprocess.Popen[Any], Any]:
    stderr_path = profile / "firefox-stderr.log"
    stderr_handle = stderr_path.open("w", encoding="utf-8")
    command = [
        FIREFOX_BIN,
        "-no-remote",
        "-profile",
        str(profile),
        "-marionette",
        "-remote-allow-system-access",
        "about:blank",
    ]
    print(f"launch: {' '.join(command)}")
    proc = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=stderr_handle, text=True)
    return proc, stderr_handle


def stop_firefox(proc: subprocess.Popen[Any] | None, stderr_handle: Any | None) -> None:
    if proc and proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=8)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=8)
    if stderr_handle:
        stderr_handle.close()


def collect_chrome(client: MarionetteClient, label: str) -> dict[str, Any]:
    client.set_context("chrome")
    return client.execute(CHROME_STATE_SCRIPT, [label])


def collect_content(client: MarionetteClient) -> dict[str, Any]:
    client.set_context("content")
    return client.execute(CONTENT_STATE_SCRIPT)


def assert_browser_fullscreen(state: dict[str, Any], hover_state: dict[str, Any]) -> None:
    attrs = state["attrs"]
    require(
        attrs.get("sizemode") == "fullscreen" and attrs.get("inFullscreen") == "true",
        "browser-fullscreen #main-window did not expose sizemode=fullscreen/inFullscreen=true; inspect theme/ffu-global-positioning.css :root[inFullscreen=\"true\"]",
    )
    require(
        state["prefs"].get("legacyUserChrome") is True and state["prefs"].get("navbarAutohide") is True,
        "browser-fullscreen disposable profile did not force userChrome/navbar autohide prefs; inspect scripts/verify-fullscreen-autohide-live.py profile setup",
    )
    require(
        state["rootVars"].get("ucNavbarEdgeSeam") == "3px",
        "browser-fullscreen FF Ultima CSS variables were not loaded; inspect disposable chrome install and userChrome.css imports",
    )
    assert_zero_margins(state, "browser", "theme/ffu-special-configs.css fullscreen #browser guard", "#browser", "browser-fullscreen")
    assert_zero_margins(state, "selectedBrowser", "theme/ffu-global-positioning.css #main-window[sizemode=\"fullscreen\"] compacting", "#tabbrowser-tabpanels browser[type]", "browser-fullscreen")
    assert_zero_radii(state, "selectedBrowser", "theme/ffu-global-positioning.css #main-window[sizemode=\"fullscreen\"] compacting", "#tabbrowser-tabpanels browser[type]", "browser-fullscreen")
    assert_no_border_shadow_outline(state, "selectedBrowser", "theme/ffu-global-positioning.css browser fullscreen content cleanup", "#tabbrowser-tabpanels browser[type]", "browser-fullscreen")
    require(
        hover_state.get("available") and hover_state.get("locked") and element_visible(hover_state.get("toolbox", {})),
        "browser-fullscreen navbar hover reveal could not be evidenced with InspectorUtils :hover lock; inspect theme/settings-navbar.css autohide popup/hover contract",
    )


def assert_dom_fullscreen(state: dict[str, Any], content_state: dict[str, Any]) -> None:
    attrs = state["attrs"]
    require(
        attrs.get("sizemode") == "fullscreen" and attrs.get("inFullscreen") == "true" and attrs.get("inDOMFullscreen") == "true",
        "DOM fullscreen #main-window did not expose sizemode=fullscreen/inFullscreen=true/inDOMFullscreen=true; inspect theme/ffu-global-positioning.css DOM fullscreen selectors",
    )
    require(
        content_state.get("fullscreenElementId") == "fullscreen-target" and content_state.get("fullscreenRequest") == "ok",
        f"DOM fullscreen fixture did not enter requestFullscreen target; inspect scripts/fixtures/dom-fullscreen.html (state={content_state})",
    )
    for key, selector in (
        ("browser", "#browser"),
        ("tabbox", "#tabbrowser-tabbox"),
        ("tabpanels", "#tabbrowser-tabpanels"),
        ("selectedBrowser", "#tabbrowser-tabpanels browser[type]"),
    ):
        assert_zero_margins(state, key, "theme/ffu-global-positioning.css #main-window[inDOMFullscreen=\"true\"][inFullscreen=\"true\"]", selector, "DOM fullscreen")
        assert_zero_radii(state, key, "theme/ffu-global-positioning.css #main-window[inDOMFullscreen=\"true\"][inFullscreen=\"true\"]", selector, "DOM fullscreen")
        assert_no_border_shadow_outline(state, key, "theme/ffu-global-positioning.css #main-window[inDOMFullscreen=\"true\"][inFullscreen=\"true\"]", selector, "DOM fullscreen")
    require(
        not toolbox_pinned_over_content(state["toolbox"]),
        f"DOM fullscreen #navigator-toolbox appears pinned over fullscreen content ({rect_summary(state['toolbox'])}); inspect theme/settings-navbar.css autohide and theme/ffu-global-positioning.css DOM fullscreen cleanup",
    )


def main() -> int:
    require(DOM_FIXTURE.exists(), f"missing DOM fullscreen fixture: {DOM_FIXTURE}")
    port = find_free_port()
    profile = Path(tempfile.mkdtemp(prefix="ff-ultima-s03-fullscreen-"))
    keep_profile = os.environ.get("FF_ULTIMA_KEEP_PROFILE") == "1"
    proc: subprocess.Popen[Any] | None = None
    stderr_handle: Any | None = None
    client: MarionetteClient | None = None
    success = False

    print("FF Ultima S03 live fullscreen/autohide proof")
    print(f"repo: {REPO_ROOT}")
    print(f"profile: {profile} (disposable; default profile is not mutated)")
    print(f"fixture: {DOM_FIXTURE}")

    try:
        install_profile(profile, port)
        proc, stderr_handle = launch_firefox(profile, port)
        wait_for_port(proc, port, timeout=30.0)
        client = MarionetteClient("127.0.0.1", port, timeout=10.0)
        print(f"marionette: hello={client.hello}")
        session = client.command("WebDriver:NewSession", {"capabilities": {"alwaysMatch": {}}})
        capabilities = session.get("capabilities", {}) if isinstance(session, dict) else {}
        print(
            f"environment: firefox={capabilities.get('browserVersion')} platform={capabilities.get('platformName')} "
            f"headless={capabilities.get('moz:headless')} process={capabilities.get('moz:processID')}"
        )
        mac_evidence = "captured" if sys.platform == "darwin" else "skipped-not-macos"
        print(f"macOS fullscreen evidence: {mac_evidence}")

        client.set_context("chrome")
        try:
            client.value_command("WebDriver:SetWindowRect", {"x": 40, "y": 40, "width": 1280, "height": 900})
        except MarionetteError as error:
            print(f"notice: SetWindowRect skipped: {error}")
        wait_until(
            "FF Ultima chrome CSS variables to load",
            lambda: collect_chrome(client, "startup")["rootVars"].get("ucNavbarEdgeSeam") == "3px",
            timeout=15.0,
        )

        client.set_context("chrome")
        client.execute("window.fullScreen = true; return window.fullScreen;")
        wait_until(
            "browser fullscreen attrs",
            lambda: (lambda state: state["attrs"].get("sizemode") == "fullscreen" and state["attrs"].get("inFullscreen") == "true")(collect_chrome(client, "browser-fullscreen-wait")),
            timeout=15.0,
        )
        time.sleep(0.6)
        browser_state = collect_chrome(client, "browser-fullscreen")
        print_state(browser_state)

        client.set_context("chrome")
        hover_lock = client.execute(HOVER_LOCK_SCRIPT)
        time.sleep(0.4)
        hover_state = collect_chrome(client, "browser-fullscreen-hover-reveal")
        hover_lock["toolbox"] = hover_state["toolbox"]
        print(
            f"browser-fullscreen-hover-reveal: InspectorUtils.locked={hover_lock.get('locked')} "
            f"matchesHover={hover_lock.get('matchesHover')} toolbox {rect_summary(hover_state['toolbox'])} "
            f"display={hover_state['toolbox'].get('display')} visibility={hover_state['toolbox'].get('visibility')} opacity={hover_state['toolbox'].get('opacity')}"
        )
        client.execute(HOVER_UNLOCK_SCRIPT)
        assert_browser_fullscreen(browser_state, hover_lock)

        client.set_context("chrome")
        client.execute("window.fullScreen = false; return window.fullScreen;")
        wait_until(
            "exit browser fullscreen attrs",
            lambda: collect_chrome(client, "exit-browser-fullscreen")["attrs"].get("sizemode") != "fullscreen",
            timeout=15.0,
        )

        client.set_context("content")
        client.value_command("WebDriver:Navigate", {"url": DOM_FIXTURE.as_uri()})
        wait_until(
            "DOM fullscreen fixture ready",
            lambda: (lambda state: state.get("readyState") == "complete" and state.get("hasButton") and state.get("hasTarget"))(collect_content(client)),
            timeout=15.0,
        )
        element = client.value_command("WebDriver:FindElement", {"using": "css selector", "value": "#enter-fullscreen"})
        element_id = element.get(ELEMENT_KEY) if isinstance(element, dict) else None
        require(bool(element_id), f"DOM fullscreen button element id missing from Marionette response: {element}")
        client.value_command("WebDriver:ElementClick", {"id": element_id})
        wait_until(
            "DOM requestFullscreen target",
            lambda: collect_content(client).get("fullscreenElementId") == "fullscreen-target",
            timeout=10.0,
        )
        wait_until(
            "DOM fullscreen chrome attrs",
            lambda: (lambda state: state["attrs"].get("inDOMFullscreen") == "true" and state["attrs"].get("inFullscreen") == "true")(collect_chrome(client, "dom-fullscreen-wait")),
            timeout=10.0,
        )
        time.sleep(0.4)
        dom_content_state = collect_content(client)
        dom_state = collect_chrome(client, "DOM-fullscreen")
        print(
            f"DOM-fullscreen-content: readyState={dom_content_state.get('readyState')} fullscreenEnabled={dom_content_state.get('fullscreenEnabled')} "
            f"fullscreenElementId={dom_content_state.get('fullscreenElementId')} request={dom_content_state.get('fullscreenRequest')} "
            f"targetRect={dom_content_state.get('target', {}).get('rect')} targetMargin={dom_content_state.get('target', {}).get('margin')} "
            f"targetRadius={dom_content_state.get('target', {}).get('borderRadius')}"
        )
        print_state(dom_state)
        assert_dom_fullscreen(dom_state, dom_content_state)

        client.set_context("content")
        client.execute("if (document.fullscreenElement) { document.exitFullscreen(); } return true;")
        client.set_context("chrome")
        client.execute("window.fullScreen = false; return window.fullScreen;")
        client.value_command("WebDriver:DeleteSession", {})
        success = True
        print("All live fullscreen autohide checks passed.")
        return 0
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        if not keep_profile:
            print(f"diagnostic: preserving failed disposable profile for inspection: {profile}", file=sys.stderr)
        return 1
    finally:
        if client:
            client.close()
        stop_firefox(proc, stderr_handle)
        if success and not keep_profile:
            shutil.rmtree(profile, ignore_errors=True)
            print("cleanup: removed disposable profile after successful proof")
        elif keep_profile:
            print(f"cleanup: FF_ULTIMA_KEEP_PROFILE=1, retained disposable profile: {profile}")


if __name__ == "__main__":
    raise SystemExit(main())
