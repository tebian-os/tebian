// Portions from Omarchy (MIT), (c) David Heinemeier Hansson — see ../LICENSE-omarchy
//
// The dock's state that does not need Quickshell: where it sits, which apps
// it shows, and which window a click brings forward. Kept free of QML so the
// rules can be read (and checked) on their own.

var POSITIONS = ["bottom", "left", "right"]

// ~/.config/tebian/dock.conf: `key=value` lines, `#` comments. Anything
// unknown or malformed falls back to the default, so a hand-edit can't stop
// the dock from coming up.
function parseConfig(raw) {
  var config = { position: "bottom", autohide: false }
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*([a-z]+)\s*=\s*(\S*)\s*$/)
    if (!m) continue
    if (m[1] === "position" && POSITIONS.indexOf(m[2]) >= 0) config.position = m[2]
    else if (m[1] === "autohide") config.autohide = m[2] === "on"
  }
  return config
}

function isVertical(position) {
  return position === "left" || position === "right"
}

// The Mod+D pin list (~/.config/tebian/pinned-apps.conf): one desktop id per
// line, "kitty.desktop". Read the way tebian-menu reads it — trailing space
// and CR trimmed, comments and repeats skipped.
function parsePins(raw) {
  var ids = []
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var id = lines[i].replace(/\s+$/, "")
    if (!id || id.charAt(0) === "#" || ids.indexOf(id) >= 0) continue
    ids.push(id)
  }
  return ids
}

// Quickshell names an entry by its file name without ".desktop"; Tebian's
// pins and launcher keep the suffix (an id like org.telegram.desktop only
// resolves with it). The dock keys everything by the file name.
function entryId(key) {
  var id = String(key || "")
  return id.slice(-8) === ".desktop" ? id.slice(0, -8) : id
}

function fileId(id) {
  return String(id || "") + ".desktop"
}

// Pinned apps come first, in pin order, whether or not they run; running
// apps that are not pinned follow in the order their first window appeared.
// Each window is { key, ... } where key is the desktop file of the app that
// claims it (or, with no desktop file, its app id).
function buildItems(pinned, windows) {
  var items = []
  var byKey = {}

  function itemFor(key, isPinned) {
    if (!byKey[key]) {
      byKey[key] = { key: key, pinned: isPinned, windows: [] }
      items.push(byKey[key])
    }
    return byKey[key]
  }

  for (var i = 0; i < (pinned || []).length; i++) {
    if (pinned[i]) itemFor(pinned[i], true)
  }
  for (var j = 0; j < (windows || []).length; j++) {
    if (windows[j] && windows[j].key) itemFor(windows[j].key, false).windows.push(windows[j])
  }
  return items
}

// The window a click on an app brings forward, as an index into its windows
// (in the order they opened), or -1 for none. Not focused yet: the one the
// user had last (recency, lower is more recent; -1 never focused). Focused
// already: the next one, so clicking again walks through them.
function pickWindow(windows) {
  var list = windows || []
  if (list.length === 0) return -1
  for (var i = 0; i < list.length; i++) {
    if (list[i].activated) return (i + 1) % list.length
  }
  var best = 0
  for (var j = 1; j < list.length; j++) {
    var r = list[j].recency
    var b = list[best].recency
    if (r >= 0 && (b < 0 || r < b)) best = j
  }
  return best
}

if (typeof module !== "undefined") {
  module.exports = {
    parseConfig: parseConfig,
    isVertical: isVertical,
    parsePins: parsePins,
    entryId: entryId,
    fileId: fileId,
    buildItems: buildItems,
    pickWindow: pickWindow
  }
}
