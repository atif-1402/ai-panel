pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Live bridge to Omarchy's clipboard history. The main shell's capture
    // pipeline persists every clipboard change to
    // ~/.local/state/omarchy/clipboard-history.json (newest first) and stores
    // binary payloads as regular files under clipboard-images/.
    //
    // Read-only, and deliberately *lazy*: the file is read once per explicit
    // loadLatest() call via a short-lived process. We intentionally avoid
    // FileView watchChanges here — the history file is rewritten frequently
    // by the main shell, and a persistent watcher would re-parse it on the
    // UI thread in lockstep with those writes.
    readonly property string historyPath: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"

    property var entries: []
    readonly property var latest: entries.length > 0 ? entries[0] : null
    property var _callback: null

    function normalizeEntry(value) {
        if (!value || typeof value !== "object") return null;
        if (value.type === "image" && typeof value.path === "string" && value.path.length > 0)
            return { type: "image", path: value.path, mime: String(value.mime || "image/png") };
        if (value.type === "text" && typeof value.text === "string" && value.text.length > 0)
            return { type: "text", text: value.text };
        return null;
    }

    function parseHistory(raw) {
        try {
            const parsed = JSON.parse(String(raw || "[]"));
            if (!Array.isArray(parsed)) return [];
            const next = [];
            for (let i = 0; i < parsed.length; i++) {
                const e = normalizeEntry(parsed[i]);
                if (e) next.push(e);
            }
            return next;
        } catch (e) {
            console.log("[OmarchyClipboard] Failed to parse clipboard history:", e);
            return [];
        }
    }

    /**
     * Reads the history file asynchronously and invokes callback(latest)
     * with the newest entry (or null). Only one request is tracked at a
     * time; the most recent call wins.
     */
    function loadLatest(callback) {
        root._callback = callback;
        readerProc.running = true;
    }

    Process {
        id: readerProc
        command: ["cat", root.historyPath]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root.parseHistory(text);
                const cb = root._callback;
                root._callback = null;
                if (cb) cb(root.latest);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Missing/unreadable history: treat as empty.
                root.entries = [];
                const cb = root._callback;
                root._callback = null;
                if (cb) cb(null);
            }
        }
    }
}
