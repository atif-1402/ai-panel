import "../../../services"
import "../../common"
import "../../common/widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property var tabButtonList: [
        ...(root.aiChatEnabled ? [{"icon": "neurology", "name": Translation.tr("Intelligence")}] : [])
    ]
    property int tabCount: swipeView.count

    Keys.onPressed: (event) => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                swipeView.incrementCurrentIndex()
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                swipeView.decrementCurrentIndex()
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: swipeView.implicitWidth
            implicitHeight: swipeView.implicitHeight
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            SwipeView { // Content pages
                id: swipeView
                anchors.fill: parent
                spacing: 10
                currentIndex: 0

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: swipeView.width
                        height: swipeView.height
                        radius: Appearance.rounding.small
                    }
                }

                contentChildren: [
                    ...(root.aiChatEnabled ? [aiChat.createObject()] : []),
                    ...(root.tabButtonList.length === 0 ? [placeholder.createObject()] : [])
                ]
            }
        }

        Component {
            id: aiChat
            AiChat {}
        }
        Component {
            id: placeholder
            Item {
                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Enjoy your empty sidebar...")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}