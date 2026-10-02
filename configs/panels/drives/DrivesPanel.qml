// Portions from Omarchy (MIT), (c) David Heinemeier Hansson — see ../LICENSE-omarchy
//
// Tebian's Drives panel: USB drives at a glance, opened from the drive icon
// the Modern bar shows while one is plugged in. No Omarchy original — built
// from the ported panel kit so it reads like the other panels: hero over
// sections, small-caps headers, bordered buttons, keyboard cursor.
//
// Data and actions come from tebian-panel-drives, which mounts through Drive
// Doctor (so a drive with filesystem errors still gets its repair offer) and
// ejects safely (unmount + power off).
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "tebian.drives"
  ipcTarget: "tebian.drives"
  manageIpc: false

  // Secondary text by transparency, not Qt.darker: darkening only dims
  // light-on-dark themes and made a light theme's muted text darker still
  function dim(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  property var drives: []
  property bool loaded: false
  property bool cursorActive: false
  // Keyboard cursor: one entry per button, in reading order
  property int cursorIndex: 0
  property string busyDev: ""

  readonly property int partCount: {
    var n = 0
    for (var i = 0; i < drives.length; i++) n += drives[i].parts.length
    return n
  }

  // Flat list of the buttons, so j/k/h/l and Enter have one order to walk:
  // per filesystem [Open|Mount], per drive [Eject], then the footer
  readonly property var actions: {
    var list = []
    for (var i = 0; i < drives.length; i++) {
      var d = drives[i]
      for (var j = 0; j < d.parts.length; j++) {
        var p = d.parts[j]
        list.push({ kind: p.mount ? "open" : "mount", target: p.mount || p.dev, key: p.dev })
      }
      list.push({ kind: "eject", target: d.disk, key: d.disk })
    }
    list.push({ kind: "settings", target: "", key: "settings" })
    return list
  }

  function actionIndex(kind, key) {
    for (var i = 0; i < actions.length; i++)
      if (actions[i].kind === kind && actions[i].key === key) return i
    return -1
  }

  function run(action) {
    if (!action) return
    if (action.kind === "settings") {
      root.close()
      Quickshell.execDetached(["tebian-settings", "--menu", "drives"])
      return
    }
    if (action.kind === "open") {
      root.close()
      Quickshell.execDetached(["tebian-panel-drives", "open", action.target])
      return
    }
    // Mount may ask (repair offer) in a fuzzel prompt: get out of its way
    if (action.kind === "mount") root.close()
    root.busyDev = action.key
    actionProc.command = ["tebian-panel-drives", action.kind, action.target]
    if (!actionProc.running) actionProc.running = true
  }

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function open() {
    refresh()
    cursorActive = false
    cursorIndex = 0
    root.controller.show()
  }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root, direction)
    return false
  }

  IpcHandler {
    target: "tebian.drives"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Process {
    id: listProc
    command: ["tebian-panel-drives", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "[]"))
          root.drives = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          root.drives = []
        }
        root.loaded = true
        if (root.cursorIndex > root.actions.length - 1) root.cursorIndex = root.actions.length - 1
      }
    }
  }

  Process {
    id: actionProc
    onExited: { root.busyDev = ""; root.refresh() }
  }

  Timer { interval: 3000; running: root.opened; repeat: true; onTriggered: root.refresh() }

  KeyboardPanel {
    id: panel
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        var step = dy !== 0 ? dy : dx
        root.cursorIndex = Math.max(0, Math.min(root.actions.length - 1, root.cursorIndex + step))
      }
      onActivateRequested: if (root.cursorActive) root.run(root.actions[root.cursorIndex])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: column.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: column
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // ---------- Hero ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              textFormat: Text.PlainText
              text: "\u{f0553}"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Drives"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                text: (!root.loaded ? "Looking…"
                       : root.drives.length === 0 ? "No USB drives"
                       : root.drives.length === 1 ? "1 drive connected"
                       : root.drives.length + " drives connected").toUpperCase()
                color: root.dim(root.bar.foreground, 0.7)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }
            }
          }

          // ---------- One section per drive ----------
          Repeater {
            model: root.drives

            Column {
              id: driveBlock
              required property var modelData
              width: column.width
              spacing: Style.space(10)

              PanelSeparator { foreground: root.bar.foreground }

              Item {
                width: parent.width
                implicitHeight: Math.max(driveHeader.implicitHeight, ejectButton.implicitHeight)

                PanelSectionHeader {
                  id: driveHeader
                  text: (driveBlock.modelData.name + "  ·  " + driveBlock.modelData.size).toUpperCase()
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  anchors.left: parent.left
                  anchors.right: ejectButton.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Button {
                  id: ejectButton
                  readonly property int flat: root.actionIndex("eject", driveBlock.modelData.disk)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "\u{f01e8}"
                  text: root.busyDev === driveBlock.modelData.disk ? "Ejecting…" : "Eject"
                  fontSize: Style.font.caption
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  horizontalPadding: Style.spacing.sm + Style.space(4)
                  verticalPadding: Style.spacing.controlPaddingY
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === flat
                  onClicked: root.run(root.actions[flat])
                  onHovered: function(h) { if (h) { root.cursorActive = true; root.cursorIndex = flat } }
                }
              }

              Text {
                visible: driveBlock.modelData.parts.length === 0
                text: "No readable filesystem — format it from Drive settings below."
                color: root.dim(root.bar.foreground, 0.7)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                width: parent.width
              }

              Repeater {
                model: driveBlock.modelData.parts

                Item {
                  id: partRow
                  required property var modelData
                  readonly property bool mounted: modelData.mount !== ""
                  readonly property int flat: root.actionIndex(mounted ? "open" : "mount", modelData.dev)
                  width: driveBlock.width
                  implicitHeight: partInfo.implicitHeight + Style.space(4)

                  Text {
                    id: partIcon
                    text: partRow.mounted ? "\u{f02ca}" : "\u{f0a0c}"
                    color: root.bar.foreground
                    opacity: partRow.mounted ? 1.0 : 0.55
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.title
                    width: Style.space(22)
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: Style.space(2)
                  }

                  Column {
                    id: partInfo
                    anchors.left: partIcon.right
                    anchors.leftMargin: Style.space(8)
                    anchors.right: partButton.left
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(4)

                    Text {
                      textFormat: Text.PlainText
                      text: partRow.modelData.label || partRow.modelData.dev.replace("/dev/", "")
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: partRow.modelData.size + "  ·  " + partRow.modelData.fstype
                            + (partRow.mounted ? (partRow.modelData.used >= 0 ? "  ·  " + partRow.modelData.used + "% used" : "")
                                               : "  ·  not mounted")
                      color: root.dim(root.bar.foreground, 0.7)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    // Usage rail, like the battery bar
                    Rectangle {
                      visible: partRow.mounted && partRow.modelData.used >= 0
                      width: parent.width
                      height: Style.space(5)
                      radius: height / 2
                      color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)

                      Rectangle {
                        width: Math.max(parent.height, parent.width * Math.min(1, partRow.modelData.used / 100))
                        height: parent.height
                        radius: parent.radius
                        color: partRow.modelData.used >= 90 ? Color.urgent
                               : Style.selectedStateColor(root.bar.foreground, Color.accent)
                      }
                    }
                  }

                  Button {
                    id: partButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: partRow.mounted ? "\u{f0770}" : "\u{f0b9e}"
                    text: root.busyDev === partRow.modelData.dev ? "Mounting…" : (partRow.mounted ? "Open" : "Mount")
                    fontSize: Style.font.caption
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    horizontalPadding: Style.spacing.sm + Style.space(4)
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    hasCursor: root.cursorActive && root.cursorIndex === partRow.flat
                    onClicked: root.run(root.actions[partRow.flat])
                    onHovered: function(h) { if (h) { root.cursorActive = true; root.cursorIndex = partRow.flat } }
                  }
                }
              }
            }
          }

          // ---------- Footer ----------
          PanelSeparator { foreground: root.bar.foreground }

          Button {
            id: settingsButton
            readonly property int flat: root.actionIndex("settings", "settings")
            width: parent.width
            iconText: "\u{f0493}"
            text: "Drive settings — format, automount, repair"
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
            bordered: true
            hasCursor: root.cursorActive && root.cursorIndex === flat
            onClicked: root.run(root.actions[flat])
            onHovered: function(h) { if (h) { root.cursorActive = true; root.cursorIndex = flat } }
          }
        }
      }
    }
  }
}
