pragma Singleton
pragma ComponentBehavior: Bound

import ".."
import "../modules/common"
import "../modules/common/functions"
import Quickshell;
import Quickshell.Io;
import QtQuick;

/**
 * Stores small sensitive data (API keys) in a JSON file at
 * ~/.config/ai-panel/data.jsonc. The file is created on first save.
 */
Singleton {
    id: root

    signal dataChanged()

    property bool loaded: false
    property var keyringData: ({})

    property string dataFilePath: Directories.aiPanelDataPath

    function setNestedField(path, value) {
        if (!root.keyringData) root.keyringData = {};
        let keys = path;
        let obj = root.keyringData;
        let parents = [obj];

        // Traverse and collect parent objects
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        // Set the value at the innermost key
        obj[keys[keys.length - 1]] = value;

        // Reassign each parent object from the bottom up to trigger change notifications
        for (let i = keys.length - 2; i >= 0; --i) {
            let parent = parents[i];
            let key = keys[i];
            // Shallow clone to change object identity (spread replaced with Object.assign)
            parent[key] = Object.assign({}, parent[key]);
        }

        // Finally, reassign root.keyringData to trigger top-level change
        root.keyringData = Object.assign({}, root.keyringData);

        saveKeyringData();
    }

    function fetchKeyringData() {
        dataFile.reload()
    }

    function saveKeyringData() {
        dataFile.setText(JSON.stringify(root.keyringData, null, 2))
        root.dataChanged()
    }

    Component.onCompleted: dataFile.reload()

    FileView {
        id: dataFile
        path: root.dataFilePath
        blockLoading: true // Prevent race conditions
        printErrors: false
        watchChanges: true
        onLoaded: {
            const raw = dataFile.text().trim()
            if (raw.length === 0) {
                root.keyringData = {}
            } else {
                try {
                    root.keyringData = JSON.parse(raw)
                } catch (e) {
                    console.error("[KeyringStorage] Failed to parse data file, reinitializing.");
                    root.keyringData = {}
                }
            }
            root.loaded = true
            root.dataChanged()
        }
        onLoadFailed: {
            // First run: no file yet
            root.keyringData = {}
            root.loaded = true
            root.dataChanged()
        }
        onFileChanged: reload()
    }
}