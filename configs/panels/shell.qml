// Tebian panels — Quickshell daemon behind the Modern bar's drop-down panels.
// Started by tebian-panels (from tebian-bar) only while Waybar runs; Waybar's
// buttons open panels over IPC:
//   quickshell ipc -p <this dir> call tebian.<network|bluetooth|audio|power> toggle
//
// The panel UI kit (Ui/, Commons/) and the panels are ported from Omarchy 4
// (MIT, (c) David Heinemeier Hansson — see LICENSE-omarchy).
import QtQuick
import Quickshell
import qs.Commons
import "network"
import "bluetooth"
import "audio"
import "power"

ShellRoot {
  id: shell

  // Bar order, for Tab / Shift+Tab inside an open panel (Omarchy's
  // switchPanel). Matches Waybar's right side: bluetooth, network, audio,
  // power (the battery/power buttons).
  readonly property var panelOrder: [bluetoothPanel, networkPanel, audioPanel, powerPanel]

  // Omarchy's panels read a handful of properties off their QML bar. Tebian's
  // bar is Waybar, so this stand-in supplies them: colours from the theme,
  // the bar edge from TEBIAN_BAR_POSITION (exported by tebian-bar) and
  // Waybar's height.
  QtObject {
    id: tebianBar
    readonly property color foreground: Color.popups.text
    readonly property color barForeground: Color.popups.text
    readonly property color background: Color.popups.background
    readonly property color urgent: Color.urgent
    readonly property string fontFamily: Style.fontFamily
    readonly property string position: Quickshell.env("TEBIAN_BAR_POSITION") === "bottom" ? "bottom" : "top"
    readonly property int barSize: 30

    function switchPanelFrom(from, direction) {
      var order = shell.panelOrder
      var i = order.indexOf(from)
      if (i < 0) return false
      var next = order[(i + (direction < 0 ? -1 : 1) + order.length) % order.length]
      from.close()
      next.open()
      return true
    }
  }

  NetworkPanel { id: networkPanel; bar: tebianBar }
  BluetoothPanel { id: bluetoothPanel; bar: tebianBar }
  AudioPanel { id: audioPanel; bar: tebianBar }
  PowerPanel { id: powerPanel; bar: tebianBar }
}
