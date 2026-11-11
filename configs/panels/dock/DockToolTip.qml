// The app's name beside a hovered dock icon, on the inward side.
//
// A popup surface of its own rather than a Qt ToolTip: the dock's surface is
// only as thick as its strip, so a tooltip drawn inside it would be clipped.
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

PopupWindow {
  id: root

  property Item anchorItem: null
  property string position: "bottom"
  property string text: ""
  property bool shown: false
  readonly property int gap: Style.spacing.md

  // A short delay, so sweeping across the dock doesn't flash every name
  Timer {
    id: delay
    interval: 350
    onTriggered: root.visible = root.shown
  }
  onShownChanged: shown ? delay.restart() : (delay.stop(), visible = false)

  visible: false
  color: "transparent"
  anchor.item: anchorItem
  anchor.edges: position === "left" ? Edges.Right : position === "right" ? Edges.Left : Edges.Top
  anchor.gravity: anchor.edges

  implicitWidth: label.implicitWidth + gap
  implicitHeight: label.implicitHeight + gap

  BorderSurface {
    id: label
    // The spare `gap` goes between the label and the dock
    x: root.position === "left" ? root.gap : root.position === "right" ? 0 : Math.round(root.gap / 2)
    y: root.position === "bottom" ? 0 : Math.round(root.gap / 2)
    implicitWidth: text.implicitWidth + Style.spacing.controlPaddingX * 2
    implicitHeight: text.implicitHeight + Style.spacing.controlPaddingY * 2
    width: implicitWidth
    height: implicitHeight
    radius: Style.cornerRadius
    color: Color.tooltip.background
    borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, Style.normalBorderWidth)

    Text {
      id: text
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: root.text
      color: Color.tooltip.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }
}
