import "modules/common"
import QtQuick
import Quickshell
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool sidebarLeftOpen: false
    property bool dvdActive: false
}