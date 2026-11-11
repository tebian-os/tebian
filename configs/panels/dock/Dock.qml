// Portions from Omarchy (MIT), (c) David Heinemeier Hansson — see ../LICENSE-omarchy
//
// The dock's brain: which apps it shows and what clicking them does. One per
// shell; DockWindow draws it on each screen.
//
// Windows come from the Wayland foreign-toplevel list (Quickshell.Wayland's
// ToplevelManager), which sway serves: app id, title, focused, and
// activate/close, which is all a dock needs. Quickshell.I3 in 0.3.0 knows
// workspaces and outputs but not windows, and polling swaymsg would be a
// second, slower copy of the same list.
//
// Everything that writes or launches goes through `tebian-dock`, so pins land
// in the same file Mod+D reads and apps start exactly as they do from Mod+D.
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "DockModel.js" as DockModel

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property var config: DockModel.parseConfig(configFile.text())
  readonly property string position: config.position
  readonly property bool vertical: DockModel.isVertical(position)
  readonly property bool autohide: config.autohide

  // The edge sway's bar (bar-0: swaybar, or Waybar for the Modern bar)
  // holds, or "" while it doesn't reserve one (hide/invisible mode). Read at
  // start and on every change, so Settings > Bar Position applies live.
  property string barEdge: ""

  function readBar(json) {
    try {
      var bar = JSON.parse(json)
      root.barEdge = bar && bar.mode === "dock" ? String(bar.position || "") : ""
    } catch (e) {
      root.barEdge = ""
    }
  }

  Process {
    command: ["swaymsg", "-r", "-t", "get_bar_config", "bar-0"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.readBar(text) }
  }

  I3IpcListener {
    subscriptions: ["barconfig_update"]
    onIpcEvent: function(event) {
      if (event.data.indexOf('"bar-0"') >= 0) root.readBar(event.data)
    }
  }

  // Whether the dock reserves its strip, so maximised, snapped and tiled
  // windows stop short of it like a Mac dock. Only along the bottom with
  // the bar elsewhere: sway lays out reserved edges top layer first and
  // then by start order, and the bar restarts on every sway reload, so on
  // the bar's own edge (or on a side, where a reserved column would cut the
  // bar short) who ends up where would change from one reload to the next.
  // There the dock reserves nothing and sits just inside the bar instead.
  readonly property bool reserves: !autohide && position === "bottom" && barEdge !== "bottom"

  // Saved pins show at once; the file catches up when tebian-dock has
  // written it and the watcher reloads it.
  property var pendingPins: null
  readonly property var pins: pendingPins || DockModel.parsePins(pinsFile.text())

  // Most recently focused windows first, so a click on an app that isn't in
  // front brings back the window the user had, not the oldest one.
  property var recent: []
  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() {
      var t = ToplevelManager.activeToplevel
      if (!t) return
      root.recent = [t].concat(root.recent.filter(function(o) { return o !== t && o !== null })).slice(0, 64)
    }
  }

  function entryFor(key) {
    return key ? DesktopEntries.byId(DockModel.entryId(key)) : null
  }

  // The app a window belongs to: the desktop file Quickshell's matcher picks
  // for its app id (StartupWMClass, then the file name, case-insensitively),
  // or the bare app id for a window no desktop file claims, so it still
  // shows up and can be focused.
  function keyFor(appId) {
    var entry = DesktopEntries.heuristicLookup(appId)
    return entry ? DockModel.fileId(entry.id) : appId
  }

  // A pinned app that isn't installed (the default pins name every browser
  // Tebian offers) has nothing to launch, so it stays out until it is.
  readonly property var items: {
    // Re-evaluated when apps are installed or removed, not only on window changes
    var appsRevision = DesktopEntries.applications.values.length
    var pinned = root.pins.filter(function(key) { return !!root.entryFor(key) })
    var windows = []
    var toplevels = ToplevelManager.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var t = toplevels[i]
      // Dialogs ride with their parent window
      if (!t || !t.appId || t.parent) continue
      windows.push({ key: root.keyFor(t.appId), toplevel: t })
    }
    return DockModel.buildItems(pinned, windows)
  }

  readonly property var activeKey: {
    var t = ToplevelManager.activeToplevel
    return t && t.appId ? root.keyFor(t.appId) : ""
  }

  function nameFor(item) {
    var entry = item ? entryFor(item.key) : null
    return entry && entry.name ? entry.name : (item ? item.key : "")
  }

  function iconFor(item) {
    var entry = item ? entryFor(item.key) : null
    var icon = String(entry && entry.icon ? entry.icon : (item ? item.key : ""))
    if (icon.charAt(0) === "/") return Util.fileUrl(icon)
    var themed = icon ? Quickshell.iconPath(icon, true) : ""
    return themed || Quickshell.iconPath("application-x-executable", true)
  }

  // --- actions ------------------------------------------------------------

  // An app launched from the dock pulses until a new window of it appears,
  // or for ten seconds if none does
  property var launches: ({})

  function isLaunching(key) {
    return root.launches[key] !== undefined
  }

  onItemsChanged: settleLaunches()

  function settleLaunches() {
    var next = {}
    var changed = false
    var now = Date.now()
    for (var key in root.launches) {
      var item = root.itemFor(key)
      var count = item ? item.windows.length : 0
      if (count > root.launches[key].windows || now - root.launches[key].at > 10000) changed = true
      else next[key] = root.launches[key]
    }
    if (changed) root.launches = next
  }

  Timer {
    interval: 1000
    repeat: true
    running: Object.keys(root.launches).length > 0
    onTriggered: root.settleLaunches()
  }

  function itemFor(key) {
    for (var i = 0; i < root.items.length; i++) {
      if (root.items[i].key === key) return root.items[i]
    }
    return null
  }

  function launch(item) {
    if (!item || !entryFor(item.key)) return
    var next = Object.assign({}, root.launches)
    next[item.key] = { at: Date.now(), windows: item.windows.length }
    root.launches = next
    Quickshell.execDetached(["tebian-dock", "launch", item.key])
  }

  // Not running: launch. Running: bring its last window forward; already in
  // front: the next of its windows.
  function activate(item) {
    if (!item) return
    if (item.windows.length === 0) {
      root.launch(item)
      return
    }
    var index = DockModel.pickWindow(item.windows.map(function(w) {
      return { activated: w.toplevel.activated, recency: root.recent.indexOf(w.toplevel) }
    }))
    if (index >= 0) item.windows[index].toplevel.activate()
  }

  function closeAll(item) {
    if (!item) return
    var windows = item.windows.slice()
    for (var i = 0; i < windows.length; i++) windows[i].toplevel.close()
  }

  function setPinned(item, pinned) {
    if (!item || !entryFor(item.key)) return
    var current = root.pins
    root.pendingPins = pinned ? current.concat([item.key]) : current.filter(function(k) { return k !== item.key })
    Quickshell.execDetached(["tebian-dock", pinned ? "pin" : "unpin", item.key])
  }

  function openApps() {
    Quickshell.execDetached(["tebian-drawer"])
  }

  // --- state files ----------------------------------------------------------

  FileView {
    id: configFile
    path: root.home + "/.config/tebian/dock.conf"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  FileView {
    id: pinsFile
    path: root.home + "/.config/tebian/pinned-apps.conf"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.pendingPins = null
    onLoadFailed: root.pendingPins = null
  }

  // For tebian-dock and tests: what the dock shows, one app per line
  //   quickshell ipc -p <dock.qml> call tebian.dock list
  IpcHandler {
    target: "tebian.dock"

    function list(): string {
      return root.items.map(function(item) {
        var focused = item.windows.some(function(w) { return w.toplevel.activated })
        return [item.key, item.pinned ? "pinned" : "-", item.windows.length, focused ? "focused" : "-"].join("\t")
      }).join("\n")
    }
    // Same as clicking the app (launch / focus / next window)
    function click(key: string): string {
      var item = root.itemFor(key)
      if (!item) return "unknown"
      root.activate(item)
      return "ok"
    }
  }
}
