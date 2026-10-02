pragma Singleton
// Portions from Omarchy (MIT), (c) David Heinemeier Hansson — see ../LICENSE-omarchy
import QtQuick
import Quickshell
import Quickshell.Io
import "BorderGeometry.js" as Geometry

// Colour surfaces for Tebian's panels. The palette is the active theme's sway
// palette (~/.config/sway/theme, `set $name #hex`) — the same source the
// Modern bar's CSS is generated from — so every Tebian theme styles the
// panels with no per-theme files. Watched, so a theme switch restyles an open
// panel live.
//
// Omarchy layered per-surface overrides from a shell.toml on top of the
// palette; Tebian has no such file, so `shellValues` stays empty and every
// surface falls back to the foundational palette below.
QtObject {
  id: root

  readonly property string home: Quickshell.env("HOME")

  property color foreground: "#cdd6f4"
  property color background: "#1e1e2e"
  property color accent: "#b4befe"
  property color urgent: "#f38ba8"
  property color muted: "#6c7086"
  property color surface: "#313244"
  property color success: "#a6e3a1"

  property var shellValues: ({})

  function pick(key, fallback) {
    var v = shellValues[key]
    return (typeof v === "string" && v.length > 0) ? v : fallback
  }

  function pickAlpha(key, fallback) {
    var v = shellValues[key]
    if (typeof v !== "string" || v.length === 0) return fallback
    var n = Number(v)
    if (!isFinite(n)) return fallback
    return Util.clampAlpha(n)
  }

  function flatColor(value, fallback) {
    var role = String(value || "").replace(/^\s+|\s+$/g, "").toLowerCase()
    if (role === "foreground" || role === "text") return root.foreground
    if (role === "accent") return root.accent
    if (role === "urgent") return root.urgent
    if (role === "muted") return root.muted
    if (role === "background") return root.background
    if (role === "transparent") return Qt.rgba(0, 0, 0, 0)
    var color = Geometry.canonicalColor(value, 1)
    if (typeof color === "string" && color === value && String(value).charAt(0) !== "#") return fallback
    return color
  }

  function composed(colorKey, alphaKey, colorFallback, alphaFallback) {
    return Util.alpha(flatColor(pick(colorKey, colorFallback), colorFallback), pickAlpha(alphaKey, alphaFallback))
  }

  readonly property QtObject bar: QtObject {
    property color background: root.background
    property color text: root.foreground
    property color active: root.urgent
  }
  readonly property QtObject popups: QtObject {
    property color background: root.background
    property color text: root.foreground
    property color border: root.accent
  }
  readonly property QtObject tooltip: QtObject {
    property color background: root.surface
    property color text: root.foreground
    property color border: Util.alpha(root.foreground, 0.25)
  }

  // Sway theme files: `set $base #1e1e2e`. Tebian's names map onto the
  // roles the panel kit uses.
  function loadSwayTheme(raw) {
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*set\s+\$([A-Za-z0-9_]+)\s+(#[0-9A-Fa-f]{6})/)
      if (!m) continue
      if (m[1] === "base") background = m[2]
      else if (m[1] === "text") foreground = m[2]
      else if (m[1] === "accent") accent = m[2]
      else if (m[1] === "red") urgent = m[2]
      else if (m[1] === "overlay0") muted = m[2]
      else if (m[1] === "surface0") surface = m[2]
      else if (m[1] === "green") success = m[2]
    }
  }

  property FileView themeFile: FileView {
    path: root.home + "/.config/sway/theme"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadSwayTheme(text())
    onFileChanged: reload()
  }
}
