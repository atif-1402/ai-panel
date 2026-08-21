pragma ComponentBehavior: Bound

import "../../../../services"
import "../../../common"
import "../../../common/widgets"
import "../../../common/functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    // These are needed on the parent loader
    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ({})
    property var segmentLang: "txt"
    property var messageData: {}
    property bool isCommandRequest: segmentLang === "command"
    property var displayLang: (isCommandRequest ? "bash" : segmentLang)

    property real codeBlockBackgroundRounding: Appearance.rounding.small
    property real codeBlockHeaderPadding: 3
    property real codeBlockComponentSpacing: 2

    property var highlighterPalette: ({
        keyword: Theme.magenta,
        string: Theme.green,
        comment: ColorUtils.mix(Theme.foreground, Theme.muted, 0.35),
        lineNumber: ColorUtils.mix(Theme.foreground, Theme.muted, 0.5),
        number: Theme.yellow,
        function: Theme.cyan,
        type: Theme.accent,
        variable: Theme.foreground
    })
    readonly property string highlightedCode: SyntaxHighlighterEngine.highlight(segmentContent, root.isCommandRequest ? "bash" : root.segmentLang, root.highlighterPalette)
    readonly property bool useHighlighting: renderMarkdown && !editing && !(messageData && messageData.thinking)

    spacing: codeBlockComponentSpacing

    Rectangle { // Code background
        Layout.fillWidth: true
        topLeftRadius: codeBlockBackgroundRounding
        topRightRadius: codeBlockBackgroundRounding
        bottomLeftRadius: Appearance.rounding.unsharpen
        bottomRightRadius: Appearance.rounding.unsharpen
        color: Appearance.colors.colLayer2
        implicitHeight: codeBlockTitleBarRowLayout.implicitHeight + codeBlockHeaderPadding * 2

        RowLayout { // Language and buttons
            id: codeBlockTitleBarRowLayout
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: codeBlockHeaderPadding
            anchors.rightMargin: codeBlockHeaderPadding
            spacing: 5

            StyledText {
                id: codeBlockLanguage
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: false
                Layout.topMargin: 7
                Layout.bottomMargin: 7
                Layout.leftMargin: 10
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer2
                text: root.displayLang ? root.displayLang : "plain"
            }

            Item { Layout.fillWidth: true }

            ButtonGroup {
                AiMessageControlButton {
                    id: copyCodeButton
                    buttonIcon: activated ? "inventory" : "content_copy"

                    onClicked: {
                        Quickshell.clipboardText = segmentContent
                        copyCodeButton.activated = true
                        copyIconTimer.restart()
                    }

                    Timer {
                        id: copyIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: {
                            copyCodeButton.activated = false
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Copy code")
                    }
                }
                AiMessageControlButton {
                    id: saveCodeButton
                    buttonIcon: activated ? "check" : "save"

                    onClicked: {
                        const downloadPath = FileUtils.trimFileProtocol(Directories.downloads)
                        const safeLang = StringUtils.shellSingleQuoteEscape(String(segmentLang || "txt").replace(/[^a-zA-Z0-9_.-]/g, "-"))
                        Quickshell.execDetached(["bash", "-c",
                            `printf '%s\\n' '${StringUtils.shellSingleQuoteEscape(segmentContent)}' > '${downloadPath}/code.${safeLang}'`
                        ])
                        Quickshell.execDetached(["notify-send", 
                            Translation.tr("Code saved to file"), 
                            Translation.tr("Saved to %1").arg(`${downloadPath}/code.${safeLang}`),
                            "-a", "Shell"
                        ])
                        saveCodeButton.activated = true
                        saveIconTimer.restart()
                    }

                    Timer {
                        id: saveIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: {
                            saveCodeButton.activated = false
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Save to Downloads")
                    }
                }
            }
        }
    }

    Rectangle { // Code background
        Layout.fillWidth: true
        topLeftRadius: Appearance.rounding.unsharpen
            bottomLeftRadius: Appearance.rounding.unsharpen
            topRightRadius: Appearance.rounding.unsharpen
            bottomRightRadius: codeBlockBackgroundRounding
            color: Appearance.colors.colLayer2
            implicitHeight: codeColumnLayout.implicitHeight

            ColumnLayout {
                id: codeColumnLayout
                anchors.fill: parent
                spacing: 0
                ScrollView {
                    id: codeScrollView
                    Layout.fillWidth: true
                    // Layout.fillHeight: true
                    implicitWidth: parent.width
                    implicitHeight: codeTextArea.implicitHeight
                    contentWidth: codeTextArea.width - 1
                    // contentHeight: codeTextArea.contentHeight
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                    
                    ScrollBar.horizontal: ScrollBar {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        anchors.left: parent.left
                        anchors.right: parent.right
                        padding: 5
                        policy: ScrollBar.AsNeeded
                        opacity: visualSize == 1 ? 0 : 1
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                        
                        contentItem: Rectangle {
                            implicitHeight: 6
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2Active
                        }
                    }

                    TextEdit { // Code
                        id: codeTextArea
                        Layout.fillWidth: true
                        readOnly: !editing
                        selectByMouse: enableMouseSelection || editing
                        renderType: Text.NativeRendering
                        font.family: Appearance.font.family.monospace
                        font.hintingPreference: Font.PreferNoHinting // Prevent weird bold text
                        font.pixelSize: Appearance.font.pixelSize.small
                        selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                        selectionColor: Appearance.colors.colSecondaryContainer
                        // wrapMode: TextEdit.Wrap
                        color: (messageData && messageData.thinking) ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                        topPadding: 6
                        bottomPadding: 4

                        text: root.useHighlighting ? root.highlightedCode : segmentContent
                        textFormat: root.useHighlighting ? TextEdit.RichText : TextEdit.PlainText
                        onTextChanged: {
                            if (root.editing) segmentContent = text
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Tab) {
                                // Insert 4 spaces at cursor
                                const cursor = codeTextArea.cursorPosition;
                                codeTextArea.insert(cursor, "    ");
                                codeTextArea.cursorPosition = cursor + 4;
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_C) && event.modifiers == Qt.ControlModifier) {
                                codeTextArea.copy();
                                event.accepted = true;
                            }
                        }

                        }
                }
                Loader {
                    active: root.isCommandRequest && root.messageData.functionPending
                    visible: active
                    Layout.fillWidth: true
                    Layout.margins: 6
                    Layout.topMargin: 0
                    sourceComponent: RowLayout {
                        Item { Layout.fillWidth: true }
                        ButtonGroup {
                            GroupButton {
                                contentItem: StyledText {
                                    text: Translation.tr("Reject")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer2
                                }
                                onClicked: Ai.rejectCommand(root.messageData)
                            }
                            GroupButton {
                                toggled: true
                                contentItem: StyledText {
                                    text: Translation.tr("Approve")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnPrimary
                                }
                                onClicked: Ai.approveCommand(root.messageData)
                            }
                        }
                    }
                }
            }

            // MouseArea to block scrolling
            // MouseArea {
            //     id: codeBlockMouseArea
            //     anchors.fill: parent
            //     acceptedButtons: editing ? Qt.NoButton : Qt.LeftButton
            //     cursorShape: (enableMouseSelection || editing) ? Qt.IBeamCursor : Qt.ArrowCursor
            //     onWheel: (event) => {
            //         event.accepted = false
            //     }
            // }
        }
}