// Portions from Omarchy (MIT), (c) David Heinemeier Hansson — see ../LICENSE-omarchy
//
// The dock's right-click menu. On an app: open or new window, keep in /
// remove from the dock (the Mod+D pins), close. On the Apps button: where
// the dock sits, auto-hide, turn it off.
//
// An xdg popup with a grab, so the compositor closes it on a click anywhere
// else — sway has no Hyprland-style focus grab for layer surfaces, and the
// dock's own surface is too small to catch outside clicks itself.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PopupWindow {
  id: root

  property var dock: null
  property string position: "bottom"
  property bool autohide: false
  // The app the menu is for; null for the Apps button's menu
  property var item: null
  readonly property bool hasEntry: !!item && !!dock && !!dock.entryFor(item.key)
  readonly property int windowCount: item ? item.windows.length : 0
  readonly property int gap: Style.spacing.md

  function openFor(forItem, slot) {
    visible = false
    item = forItem
    anchor.item = slot
    returnTo = ToplevelManager.activeToplevel
    // Shown once its rows have laid out for this item: a popup that changes
    // size as it maps keeps the old size's input region on sway, and clicks
    // on the new rows fall through to the window behind
    Qt.callLater(function() { root.visible = true })
  }

  // Picking a row leaves sway with no window focused (the click lands on
  // the popup, which then goes away), so typing would go nowhere. Give focus
  // back to the window that had it, unless the action focused one itself
  // (New Window) or a click elsewhere dismissed the menu (sway focuses what
  // was clicked).
  property var returnTo: null
  onVisibleChanged: if (!visible) refocus.restart()
  Timer {
    id: refocus
    interval: 150
    onTriggered: {
      if (!ToplevelManager.activeToplevel && root.returnTo) root.returnTo.activate()
      root.returnTo = null
    }
  }

  function run(args) {
    visible = false
    Quickshell.execDetached(["tebian-dock"].concat(args))
  }

  visible: false
  grabFocus: true
  color: "transparent"
  anchor.edges: position === "left" ? Edges.Right : position === "right" ? Edges.Left : Edges.Top
  anchor.gravity: anchor.edges

  implicitWidth: card.width + gap
  implicitHeight: card.height + gap

  BorderSurface {
    id: card
    x: root.position === "left" ? root.gap : root.position === "right" ? 0 : Math.round(root.gap / 2)
    y: root.position === "bottom" ? 0 : Math.round(root.gap / 2)
    width: Math.max(Style.space(170), rows.implicitWidth) + padding * 2
    height: rows.implicitHeight + padding * 2
    radius: Style.cornerRadius
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Style.normalBorderWidth)
    padding: Style.spacing.sm

    focus: true
    Keys.onEscapePressed: root.visible = false

    Column {
      id: rows
      x: card.contentLeftInset
      y: card.contentTopInset
      width: card.width - card.contentLeftInset - card.contentRightInset

      // --- an app --------------------------------------------------------
      MenuRow {
        visible: !!root.item
        enabled: false
        text: root.dock && root.item ? root.dock.nameFor(root.item) : ""
        muted: true
      }
      MenuRow {
        visible: root.hasEntry
        text: root.windowCount > 0 ? "New Window" : "Open"
        onTriggered: { root.visible = false; root.dock.launch(root.item) }
      }
      MenuRow {
        visible: root.hasEntry
        text: root.item && root.item.pinned ? "Remove from Dock" : "Keep in Dock"
        onTriggered: { root.visible = false; root.dock.setPinned(root.item, !root.item.pinned) }
      }
      MenuRow {
        visible: root.windowCount > 0
        text: root.windowCount > 1 ? "Close " + root.windowCount + " Windows" : "Close"
        onTriggered: { root.visible = false; root.dock.closeAll(root.item) }
      }

      // --- the Apps button -------------------------------------------------
      MenuRow {
        visible: !root.item
        text: "App Drawer"
        onTriggered: { root.visible = false; root.dock.openApps() }
      }
      PositionRow { edge: "bottom"; text: "Position: Bottom" }
      PositionRow { edge: "left"; text: "Position: Left" }
      PositionRow { edge: "right"; text: "Position: Right" }
      MenuRow {
        visible: !root.item
        text: "Auto-hide (" + (root.autohide ? "ON" : "OFF") + ")"
        onTriggered: root.run(["autohide", root.autohide ? "off" : "on"])
      }
      MenuRow {
        visible: !root.item
        text: "Turn Dock Off"
        onTriggered: root.run(["off"])
      }
    }
  }

  component PositionRow: MenuRow {
    property string edge: ""
    visible: !root.item
    checked: root.position === edge
    onTriggered: root.run(["position", edge])
  }

  component MenuRow: Item {
    id: row
    property string text: ""
    property bool checked: false
    property bool muted: false
    signal triggered()

    width: parent ? parent.width : implicitWidth
    implicitWidth: label.implicitWidth + Style.spacing.controlPaddingX * 2 + Style.spacing.lg * 2
    height: visible ? Style.spacing.popupRowHeight : 0

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius - Style.spacing.sm
      color: rowMouse.containsMouse && row.enabled ? Style.hoverFill : "transparent"
    }

    // The current choice gets an accent dot, drawn rather than a font glyph
    Rectangle {
      visible: row.checked
      width: 6
      height: 6
      radius: 3
      color: Color.accent
      anchors.verticalCenter: parent.verticalCenter
      x: Style.spacing.controlPaddingX
    }

    Text {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      x: Style.spacing.controlPaddingX + Style.spacing.lg * 2
      textFormat: Text.PlainText
      text: row.text
      color: row.muted ? Color.muted : Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: row.muted
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: row.enabled
      onClicked: row.triggered()
    }
  }
}
