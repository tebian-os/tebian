// Portions from Omarchy (MIT), (c) David Heinemeier Hansson — see ../LICENSE-omarchy
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.I3
import qs.Commons

// Layer-shell popup for a click- and keyboard-driven panel.
//
// Omarchy anchors this to a bar icon inside its own QML bar. Tebian's bar is
// Waybar — a separate program — so there is no icon item to measure. The card
// instead drops down from the bar's edge (`bar.position`, from
// TEBIAN_BAR_POSITION exported by tebian-bar) at the right-hand end, where
// Waybar keeps the network/audio/power buttons, on the output sway has focused
// (the one the user just clicked on).
//
// Kept from Omarchy: full-screen overlay surface with outside-click
// dismissal, the brief WlrKeyboardFocus.Exclusive prime then OnDemand so the
// panel takes keys the moment it opens, fade animation, and transparent twins
// on other outputs so a click there closes the panel too. The bar strip is
// left out of the input region, so clicking another Waybar button still
// reaches Waybar while a panel is open.
PanelWindow {
  id: root

  required property QtObject bar
  property var owner: null
  property int margin: Style.gapsOut
  property int padding: Style.spacing.popupPadding
  property int contentWidth: Style.space(280)
  property int contentHeight: Style.space(200)
  property var borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
  property bool open: false
  property int gap: Style.gapsOut  // distance between bar edge and panel
  property bool focusPrimed: false
  property Item focusTarget: null

  default property alias contentItem: contentHolder.children

  readonly property string barPos: bar ? bar.position : "top"
  readonly property int barH: bar ? bar.barSize : 30

  function close() {
    if (owner && "close" in owner) owner.close()
    else root.open = false
  }

  function beginFocusPrime() {
    if (open && backingWindowVisible) focusPrimeTimer.restart()
  }

  // --- screen + lifetime ---------------------------------------------------

  // The focused sway output, falling back to the first screen
  function focusedScreen() {
    var name = I3.focusedMonitor ? I3.focusedMonitor.name : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === name) return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  property var targetScreen: null
  screen: targetScreen
  visible: open || card.opacity > 0
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  WlrLayershell.namespace: "tebian-panel"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open
    ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : WlrKeyboardFocus.None

  onBackingWindowVisibleChanged: beginFocusPrime()

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  readonly property real screenW: screen ? screen.width : 0
  readonly property real screenH: screen ? screen.height : 0
  // The bar strip, kept out of the input region below
  readonly property real barStrip: barH

  mask: Region {
    x: 0
    y: root.barPos === "bottom" ? 0 : root.barStrip
    width: root.screenW
    height: Math.max(0, root.screenH - root.barStrip)
  }

  readonly property real availableCardWidth: screenW > 0 ? Math.max(120, screenW - margin * 2) : 0
  readonly property real availableCardHeight: screenH > 0 ? Math.max(120, screenH - barH - gap - margin) : 0
  readonly property real verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)

  function fittedContentWidth(width, cap) {
    var desired = Math.max(1, Number(width) || 1)
    var maxWidth = root.availableCardWidth > 0 ? root.availableCardWidth : desired
    if (cap !== undefined && Number(cap) > 0) maxWidth = Math.min(maxWidth, Number(cap))
    return Math.round(Math.min(desired, maxWidth))
  }

  function fittedContentHeight(implicitHeight, cap) {
    var desired = Math.max(root.verticalContentInset, (Number(implicitHeight) || 0) + root.verticalContentInset)
    var maxHeight = root.availableCardHeight > 0 ? root.availableCardHeight : desired
    if (cap !== undefined && Number(cap) > 0) maxHeight = Math.min(maxHeight, Number(cap))
    return Math.round(Math.min(desired, maxHeight))
  }

  // Right-aligned against the screen edge, just off the bar — where
  // Waybar's status icons sit. centerOnBar centres it instead (the clock).
  property bool centerOnBar: false
  readonly property point cardOrigin: {
    var x = centerOnBar ? Math.round((screenW - contentWidth) / 2) : screenW - contentWidth - margin
    var y = barPos === "bottom" ? screenH - barH - contentHeight - gap : barH + gap
    x = Math.max(margin, x)
    y = Math.max(margin, Math.min(y, screenH - contentHeight - margin))
    return Qt.point(Math.round(x), Math.round(y))
  }

  onOpenChanged: {
    if (open) {
      targetScreen = focusedScreen()
      focusPrimed = false
      beginFocusPrime()
      if (focusTarget) Qt.callLater(function() {
        if (root.open && root.focusTarget) root.focusTarget.forceActiveFocus()
      })
    } else {
      focusPrimeTimer.stop()
      focusPrimed = false
    }
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: if (root.open) root.focusPrimed = true
  }

  // --- outside-click dismissal --------------------------------------------

  MouseArea {
    anchors.fill: parent
    enabled: root.open
    acceptedButtons: Qt.AllButtons
    onClicked: root.close()
  }

  // Transparent twins on every other output: a click there closes the panel
  Variants {
    model: root.open ? Quickshell.screens : []

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        visible: root.open && !!root.screen && modelData.name !== root.screen.name
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "tebian-panel-dismiss"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
          onPressed: root.close()
        }
      }
    }
  }

  // --- card ----------------------------------------------------------------

  BorderSurface {
    id: card
    x: root.cardOrigin.x
    y: root.cardOrigin.y
    width: root.contentWidth
    height: root.contentHeight
    color: Color.popups.background
    borderSpec: root.borderSpec
    padding: root.padding
    radius: Style.cornerRadius
    opacity: root.open ? 1.0 : 0

    Behavior on opacity {
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    // Swallow clicks on the card so they don't reach the dismissal area
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    Item {
      id: contentHolder
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
    }
  }
}
