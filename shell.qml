import "services"
import "modules/common"
import "modules/aiPanel/sidebarLeft"
import "modules/easteregg"

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    Component.onCompleted: {
        GlobalStates.sidebarLeftOpen = true
    }

    SidebarLeft {
        id: sidebarLeftItem
    }

    DvdOverlay {
        id: dvdOverlay
    }
}