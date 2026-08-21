import QtQuick

import "modules/aiPanel/sidebarLeft"
import "modules/easteregg"

// Omarchy plugin entry point. The host shell instantiates this file and calls
// open()/close() on summon/dismiss. Windows (SidebarLeft's PanelWindow and the
// DvdOverlay) live inside this Item — Quickshell attaches them to the layer
// tree regardless of visual-parent position.
Item {
    id: root

    // Optional properties the host injects when present.
    property var shell
    property var manifest
    property string omarchyPath
    property var barWidgetRegistry
    property var pluginRegistry

    readonly property bool opened: GlobalStates.sidebarLeftOpen

    function open(payloadJson) {
        GlobalStates.sidebarLeftOpen = true
    }

    function close() {
        GlobalStates.sidebarLeftOpen = false
    }

    SidebarLeft {
        id: sidebarLeftItem
    }

    DvdOverlay {
        id: dvdOverlay
    }
}
