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
     * Backslash-escapes the characters that drive markdown structure, so a
     * construct renders as its own literal text and can never be re-parsed
     * into an image/link (nothing is fetched from plain text).
     */
    function mdEscapeLiteral(t: string): string {
        return String(t).replace(/([\\`\[\]!()<>])/g, "\\$1");
    }

    /**
     * Removes resource-embedding constructs (markdown images, HTML media
     * tags) from provider-controlled markdown before it is rendered — the
     * text editor fetches referenced URLs automatically. Implemented as a
     * small scanner rather than regexes so escaped brackets, nested
     * brackets and quoted attributes cannot bypass it. Matched constructs
     * are preserved visibly as inert literal text instead of being dropped.
     * Inline code spans and properly closed fenced blocks are copied
     * verbatim (markdown is not parsed there). Raw content is untouched:
     * editing still shows the original text.
     */
    function sanitizeForDisplay(markdown: string): string {
        const s = String(markdown);
        let out = "";
        let i = 0;
        const n = s.length;

        function fenceOpenAt(pos) {
            if (!(pos === 0 || s[pos - 1] === "\n")) return null;
            let p = pos, spaces = 0;
            while (p < n && s[p] === " " && spaces < 3) { p++; spaces++; }
            if (p >= n || (s[p] !== "`" && s[p] !== "~")) return null;
            const ch = s[p];
            let count = 0;
            while (p < n && s[p] === ch) { p++; count++; }
            return count < 3 ? null : { ch: ch, count: count, after: p };
        }

        function findFenceClose(ch, count, from) {
            let ls = from;
            while (ls <= n) {
                const nl = s.indexOf("\n", ls);
                const le = nl === -1 ? n : nl;
                let p = ls, sp = 0;
                while (p < le && s[p] === " " && sp < 3) { p++; sp++; }
                let c = 0;
                while (p < le && s[p] === ch) { p++; c++; }
                if (c >= count && s.slice(p, le).trim() === "") return ls;
                if (nl === -1) break;
                ls = nl + 1;
            }
            return -1;
        }

        function findSpanClose(start, runLen) {
            const needle = "`".repeat(runLen);
            let idx = start;
            while (true) {
                idx = s.indexOf(needle, idx);
                if (idx === -1) return -1;
                const beforeOk = idx === 0 || s[idx - 1] !== "`";
                const after = idx + runLen;
                const afterOk = after >= n || s[after] !== "`";
                if (beforeOk && afterOk) return idx;
                idx++;
            }
        }

        function tryParseImage(pos) {
            let j = pos + 2;
            let depth = 1;
            while (j < n) {
                const c = s[j];
                if (c === "\\") { j += 2; continue; }
                if (c === "[") depth++;
                else if (c === "]") { depth--; if (depth === 0) break; }
                j++;
            }
            if (depth !== 0) return -1;
            let k = j + 1;
            let newlines = 0;
            while (k < n && /\s/.test(s[k])) {
                if (s[k] === "\n") { newlines++; if (newlines > 1) break; }
                k++;
            }
            if (s[k] === "(") {
                k++; let pd = 1, q = null;
                while (k < n) {
                    const c = s[k];
                    if (q) { if (c === q) q = null; }
                    else if (c === "\"" || c === "'") q = c;
                    else if (c === "(") pd++;
                    else if (c === ")") { pd--; if (pd === 0) return k + 1; }
                    k++;
                }
                return -1;
            }
            if (s[k] === "[") {
                let d = 1; k++;
                while (k < n) {
                    const c = s[k];
                    if (c === "\\") { k += 2; continue; }
                    if (c === "[") d++;
                    else if (c === "]") { d--; if (d === 0) return k + 1; }
                    k++;
                }
                return -1;
            }
            return -1;
        }

        function tryParseMediaTag(pos) {
            let j = pos + 1;
            if (j < n && s[j] === "/") j++;
            const m = /^(img|iframe|object|embed|video|audio|source|track)\b/i.exec(s.slice(j, j + 12));
            if (!m) return -1;
            j += m[1].length;
            let q = null;
            while (j < n && j - pos < 4096) {
                const c = s[j];
                if (q) { if (c === q) q = null; }
                else if (c === "\"" || c === "'") q = c;
                else if (c === ">") return j + 1;
                j++;
            }
            return -2; // media tag name matched but never terminated
        }

        while (i < n) {
            const f = fenceOpenAt(i);
            if (f) {
                const close = findFenceClose(f.ch, f.count, f.after);
                if (close !== -1) { out += s.slice(i, close); i = close; continue; }
            }
            if (s[i] === "`") {
                let rl = 0, p = i;
                while (p < n && s[p] === "`") { rl++; p++; }
                const close = findSpanClose(p, rl);
                if (close !== -1) { const end = close + rl; out += s.slice(i, end); i = end; continue; }
                out += "`"; i++; continue;
            }
            if (s[i] === "!" && i + 1 < n && s[i + 1] === "[") {
                const r = tryParseImage(i);
                if (r !== -1) { out += mdEscapeLiteral(s.slice(i, r)); i = r; continue; }
                out += "!"; i++; continue;
            }
            if (s[i] === "<") {
                const r = tryParseMediaTag(i);
                if (r === -2) { out += "&lt;"; i++; continue; }
                if (r !== -1) { out += "&lt;" + s.slice(i + 1, r - 1) + "&gt;"; i = r; continue; }
                out += "<"; i++; continue;
            }
            out += s[i]; i++;
        }
        return out;
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
