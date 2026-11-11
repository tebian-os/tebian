// Tebian dock — a Mac-style app dock, optional and off by default. Run by
// `tebian-dock run` (from config.user while the dock is on):
//   quickshell -p <this file>
//
// Its own Quickshell instance, not part of shell.qml: the panels daemon only
// runs beside the Modern bar and is restarted with it on every sway reload,
// while the dock has to work under the Classic bar too and stay put through
// reloads. Sharing this directory lets it use the panels' theme (Commons/)
// and UI kit (Ui/), so both follow the active Tebian theme the same way.
//
// Settings: ~/.config/tebian/dock.conf (position=bottom|left|right,
// autohide=on|off), read live. Pins: ~/.config/tebian/pinned-apps.conf, the
// Mod+D list. Both are written by tebian-dock, never from here directly.
//
// The dock is ported from Omarchy 4 (MIT, (c) David Heinemeier Hansson — see
// LICENSE-omarchy), reworked for sway's window list.
import QtQuick
import Quickshell
import "dock"

ShellRoot {
  Dock { id: theDock }

  // A dock on every output, each showing every app
  Variants {
    model: Quickshell.screens
    delegate: Component {
      DockWindow {
        required property var modelData
        screen: modelData
        dock: theDock
      }
    }
  }
}
