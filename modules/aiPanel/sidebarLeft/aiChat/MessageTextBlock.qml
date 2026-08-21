pragma ComponentBehavior: Bound

import "../../../.."
import "../../../../services"
import "../../../common"
import "../../../common/widgets"
import "../../../common/functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

ColumnLayout {
    id: root
    // These are needed on the parent loader
    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ({})
    property var messageData: {}
    property bool done: true
    property bool forceDisableChunkSplitting: false
    property bool messageDone: root.messageData?.done ?? true
    property string shownText: ""

    /**
     * Removes resource-embedding constructs (markdown images, HTML media
     * tags) from provider-controlled markdown before it is rendered. The
     * text editor fetches referenced URLs automatically, so without this a
     * response could make the shell UI contact arbitrary hosts. Raw content
     * is untouched: editing still shows the original text.
     */
    function sanitizeForDisplay(markdown: string): string {
        let s = String(markdown);
        s = s.replace(/!\[[^\]]*\]\(\s*[^)]*\)/g, "");                      // ![alt](url)
        s = s.replace(/!\[[^\]]*\]\[\s*[^\]]*\]/g, "");                     // ![alt][ref]
        s = s.replace(/<\s*img\b[^>]*\/?>/gi, "");                          // <img>
        s = s.replace(/<\s*(iframe|object|embed|video|audio|source|track)\b[\s\S]*?(?:<\/\s*\1\s*>|\/?>)/gi, "");
        return s;
    }

    property list<string> shownTextBlocks: root.fadeChunkSplitting ? root.shownText.split(/\n\n(?= {0,2})|\n(?= {0,2}[-\*])/g).filter(line => line.trim() !== "") : [root.shownText]
    property bool fadeChunkSplitting: !forceDisableChunkSplitting && !editing && !/\n\|/.test(shownText) && Config.options.sidebar.ai.textFadeIn

    Layout.fillWidth: true

    onEditingChanged: {
        if (editing) {
            // console.log("Editing mode enabled", segmentContent)
            root.shownText = segmentContent
        } else if (segmentContent) {
            root.shownText = root.sanitizeForDisplay(segmentContent)
        }
    }

    onSegmentContentChanged: {
        // console.log("Segment content changed: " + segmentContent);
        if (!root.editing && segmentContent) {
            root.shownText = root.sanitizeForDisplay(segmentContent);
        }
    }

    spacing: 0
    Repeater {
        id: textLinesRepeater
        property list<real> textLineOpacities: []
        model: root.shownTextBlocks
        onModelChanged: {
            while (textLinesRepeater.textLineOpacities.length < root.shownTextBlocks.length) {
                textLinesRepeater.textLineOpacities.push(root.messageDone ? 1 : 0);
            }
        }
        delegate: TextArea {
            id: textArea
            required property int index
            required property string modelData

            // Fade in animation
            visible: opacity > 0
            opacity: fadeChunkSplitting ? (textLinesRepeater.textLineOpacities[index] ?? (root.messageDone ? 1 : 0)) : 1
            onVisibleChanged: {
                if (root.messageDone) textLinesRepeater.textLineOpacities[textArea.index] = 1
            }
            Connections {
                target: root
                function onMessageDoneChanged() {
                    if (root.messageDone) textLinesRepeater.textLineOpacities[textArea.index] = 1
                }
                function onShownTextBlocksChanged() {
                    if (root.shownTextBlocks.length > textArea.index + 1)
                        textLinesRepeater.textLineOpacities[textArea.index] = 1
                }
            }
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            Layout.fillWidth: true
            readOnly: !editing
            selectByMouse: enableMouseSelection || editing
            renderType: Text.NativeRendering
            font.family: Appearance.font.family.reading
            font.hintingPreference: Font.PreferNoHinting // Prevent weird bold text
            font.pixelSize: Appearance.font.pixelSize.small
            selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
            selectionColor: Appearance.colors.colSecondaryContainer
            wrapMode: TextEdit.Wrap
            color: root.messageData?.thinking ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
            textFormat: renderMarkdown ? TextEdit.MarkdownText : TextEdit.PlainText
            text: modelData
            background: null

            property bool _underlineApplied: false

            function applyLinkUnderline() {
                if (_underlineApplied) return
                _underlineApplied = true
                Qt.callLater(function() {
                    try {
                        var tdoc = textArea.textDocument
                        if (!tdoc) return
                        var doc = tdoc.textDocument !== undefined ? tdoc.textDocument : tdoc.document
                        if (!doc) return
                        var col = Appearance.colors.colPrimary
                        var html = doc.html !== undefined ? String(doc.html) : (doc.toHtml ? doc.toHtml() : "")
                        if (html.length === 0 || html.indexOf('underline') !== -1) return
                        html = html.replace(/<a\s/g, '<a style="text-decoration:underline;color:' + col + ';" ')
                        if (doc.setHtml) doc.setHtml(html)
                        else doc.html = html
                    } catch (e) { console.log("Link error:", e) }
                })
            }

            Connections {
                target: root
                function onMessageDoneChanged() {
                    if (root.messageDone) textArea.applyLinkUnderline()
                }
            }

            onTextChanged: {
                if (!root.editing) return
                segmentContent = text
            }

            onLinkActivated: (link) => {
                Qt.openUrlExternally(link)
                GlobalStates.sidebarLeftOpen = false
            }

            MouseArea { // Pointing hand for links
                anchors.fill: parent
                acceptedButtons: Qt.NoButton // Only for hover
                hoverEnabled: true
                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : 
                    (enableMouseSelection || editing) ? Qt.IBeamCursor : Qt.ArrowCursor
            }

            // Rectangle {
            //     anchors.fill: parent
            //     color: "#22786378"
            //     border.width: 1
            //     border.color: "#7E7E7E"
            // }
        }
    }
}
