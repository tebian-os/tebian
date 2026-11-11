// Portions from Omarchy (MIT), (c) David Heinemeier Hansson — see ../LICENSE-omarchy
//
// One screen's dock: a strip of app icons on a rounded plate along one edge.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
  id: window

  property var dock: null

  readonly property string position: dock ? dock.position : "bottom"
  readonly property bool vertical: dock ? dock.vertical : false
  readonly property bool autohide: dock ? dock.autohide : false

  readonly property int iconSize: Math.round(36 * Style.fontScale)
  readonly property int iconInset: Style.spacing.md
  readonly property int slotSize: iconSize + iconInset * 2
  readonly property int platePadding: Style.spacing.sm
  // Gap between the plate and the screen edge (or the bar, when they share it)
  readonly property int edgeGap: Style.gapsOut
  readonly property int thickness: edgeGap + slotSize + platePadding * 2

  // Auto-hide: the plate waits past the edge until the pointer touches the
  // edge strip, and stays while the pointer or a menu still needs it
  property bool revealed: false
  readonly property bool menuOpen: menu.visible
  readonly property bool tucked: autohide && !revealed && !menuOpen

  color: "transparent"
  WlrLayershell.namespace: "tebian-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  // Normal exclusion keeps the dock clear of space the bar reserved, so on
  // the bar's own edge it sits just inside the bar instead of under it.
  // Whether it reserves its own strip: see Dock.reserves.
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: dock && dock.reserves ? thickness : 0

  // Bottom: a full-width strip. Left/right: a full-height column.
  anchors {
    bottom: true
    left: window.position !== "right"
    right: window.position !== "left"
    top: window.vertical
  }
  implicitWidth: window.vertical ? window.thickness : 0
  implicitHeight: window.vertical ? 0 : window.thickness

  // Only the plate takes clicks; the rest of the strip lets them through to
  // the windows behind. Tucked away, only the edge strip that calls it back.
  mask: Region { item: window.tucked ? edgeTrigger : plate }

  onAutohideChanged: revealed = false

  Timer {
    id: hideTimer
    interval: 400
    onTriggered: if (!plateHover.hovered && !edgeHover.hovered && !window.menuOpen) window.revealed = false
  }

  Item {
    id: edgeTrigger
    readonly property int depth: Math.max(2, Style.spacing.xxs)
    x: window.position === "right" ? window.width - depth : window.position === "left" ? 0 : plate.x
    y: window.vertical ? plate.y : window.height - depth
    width: window.vertical ? depth : plate.width
    height: window.vertical ? plate.height : depth

    HoverHandler {
      id: edgeHover
      onHoveredChanged: hovered ? window.revealed = true : hideTimer.restart()
    }
  }

  BorderSurface {
    id: plate

    // How far the plate is slid past its edge while tucked
    property real tuck: window.tucked ? window.thickness : 0
    Behavior on tuck { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    width: strip.implicitWidth + window.platePadding * 2
    height: strip.implicitHeight + window.platePadding * 2
    x: window.position === "left" ? window.edgeGap - tuck
      : window.position === "right" ? window.width - width - window.edgeGap + tuck
      : Math.round((window.width - width) / 2)
    y: window.vertical ? Math.round((window.height - height) / 2)
      : window.height - height - window.edgeGap + tuck

    radius: Style.cornerRadius + window.platePadding
    // The Modern bar's own backdrop (alpha(@base, 0.92)) and the panels' border
    color: Util.alpha(Color.bar.background, 0.92)
    borderSpec: Border.surfaceSpec("popups", "border", Util.alpha(Color.popups.border, 0.35), Style.normalBorderWidth)

    HoverHandler {
      id: plateHover
      onHoveredChanged: if (!hovered && window.autohide) hideTimer.restart()
    }

    Grid {
      id: strip
      x: window.platePadding
      y: window.platePadding
      columns: window.vertical ? 1 : 1000

      // Apps | pinned | running but not pinned
      AppsSlot {}
      Divider {}
      Repeater {
        model: window.dock ? window.dock.items.filter(function(item) { return item.pinned }) : []
        delegate: AppSlot {}
      }
      Divider {
        visible: unpinned.count > 0 && unpinned.count < (window.dock ? window.dock.items.length : 0)
      }
      Repeater {
        id: unpinned
        model: window.dock ? window.dock.items.filter(function(item) { return !item.pinned }) : []
        delegate: AppSlot {}
      }
    }
  }

  // --- slots ----------------------------------------------------------------

  component Divider: Item {
    width: window.vertical ? window.slotSize : Style.spacing.lg
    height: window.vertical ? Style.spacing.lg : window.slotSize
    Rectangle {
      anchors.centerIn: parent
      width: window.vertical ? window.slotSize - window.iconInset * 2 : 1
      height: window.vertical ? 1 : window.slotSize - window.iconInset * 2
      color: Util.alpha(Color.foreground, 0.2)
    }
  }

  component Slot: Item {
    id: slot
    property alias mouse: mouse
    readonly property bool hovered: mouse.containsMouse
    property string tip: ""

    width: window.slotSize
    height: window.slotSize

    // Hover lights the slot the way the bar's pills light up
    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.spacing.xxs
      radius: Style.cornerRadius
      color: slot.hovered || mouse.pressed ? Style.hoverFill : "transparent"
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    }

    DockToolTip {
      anchorItem: slot
      position: window.position
      text: slot.tip
      shown: slot.hovered && !window.menuOpen && !window.tucked && slot.tip !== ""
    }
  }

  // Opens the App Drawer (Mod+A). Right-click: the dock's own settings.
  component AppsSlot: Slot {
    id: appsSlot
    tip: "Apps"

    mouse.onClicked: function(event) {
      if (event.button === Qt.RightButton) menu.openFor(null, appsSlot)
      else window.dock.openApps()
    }

    // A grid of squares reads as "all apps" in any icon theme
    Grid {
      readonly property int square: Math.round(window.iconSize * 0.2)
      anchors.centerIn: parent
      columns: 3
      spacing: Math.round(window.iconSize * 0.1)
      Repeater {
        model: 9
        delegate: Rectangle {
          width: parent.square
          height: parent.square
          radius: Math.max(1, Math.round(parent.square * 0.25))
          color: Color.foreground
        }
      }
    }
  }

  component AppSlot: Slot {
    id: appSlot

    required property var modelData
    readonly property var item: modelData
    readonly property int windowCount: item ? item.windows.length : 0
    readonly property bool focused: !!window.dock && windowCount > 0 && window.dock.activeKey === item.key
    readonly property bool launching: !!window.dock && window.dock.isLaunching(item.key)

    tip: {
      var name = window.dock ? window.dock.nameFor(item) : ""
      return windowCount > 1 ? name + "  (" + windowCount + " windows)" : name
    }

    mouse.onClicked: function(event) {
      if (event.button === Qt.RightButton) menu.openFor(appSlot.item, appSlot)
      else if (event.button === Qt.MiddleButton) window.dock.launch(appSlot.item)
      else window.dock.activate(appSlot.item)
    }

    Image {
      id: icon
      anchors.centerIn: parent
      width: window.iconSize
      height: window.iconSize
      sourceSize: Qt.size(window.iconSize * 2, window.iconSize * 2)
      source: window.dock ? window.dock.iconFor(appSlot.item) : ""
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      mipmap: true
      scale: appSlot.mouse.pressed ? 0.92 : 1
      Behavior on scale { NumberAnimation { duration: 90 } }

      // Starting up: breathes until its window shows
      SequentialAnimation on opacity {
        running: appSlot.launching
        loops: Animation.Infinite
        onRunningChanged: if (!running) icon.opacity = 1
        NumberAnimation { to: 0.45; duration: 500; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
      }
    }

    // Running indicator on the edge side: one dot per window, up to three;
    // the app in front gets the accent colour
    Row {
      visible: !window.vertical && appSlot.windowCount > 0
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 1
      spacing: 3
      Repeater {
        model: Math.min(3, appSlot.windowCount)
        delegate: Dot { focused: appSlot.focused }
      }
    }
    Column {
      visible: window.vertical && appSlot.windowCount > 0
      anchors.verticalCenter: parent.verticalCenter
      x: window.position === "left" ? 1 : parent.width - width - 1
      spacing: 3
      Repeater {
        model: Math.min(3, appSlot.windowCount)
        delegate: Dot { focused: appSlot.focused }
      }
    }
  }

  component Dot: Rectangle {
    property bool focused: false
    width: 4
    height: 4
    radius: 2
    color: focused ? Color.accent : Util.alpha(Color.foreground, 0.7)
  }

  // --- right-click menu ---------------------------------------------------------

  DockMenu {
    id: menu
    dock: window.dock
    position: window.position
    autohide: window.autohide
    onVisibleChanged: if (!visible && window.autohide) hideTimer.restart()
  }
}
