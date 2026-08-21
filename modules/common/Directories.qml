pragma Singleton
pragma ComponentBehavior: Bound

import "../../services"
import "functions"
import QtCore
import QtQuick
import Quickshell

Singleton {
    // XDG Dirs, with "file://"
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]
    readonly property string state: StandardPaths.standardLocations(StandardPaths.StateLocation)[0]
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0]
    readonly property string genericCache: StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]
    readonly property string documents: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
    readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property string music: StandardPaths.standardLocations(StandardPaths.MusicLocation)[0]
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]

    // Other dirs used by the shell, without "file://"
    // Resolved relative to this file so they work both standalone and as an
    // Omarchy plugin (Quickshell.shellPath would point at the host shell's root).
    property string assetsPath: FileUtils.trimFileProtocol(Qt.resolvedUrl("../../assets"))
    property string scriptPath: FileUtils.trimFileProtocol(Qt.resolvedUrl("../../scripts"))
    property string favicons: FileUtils.trimFileProtocol(`${Directories.cache}/media/favicons`)
    property string cliphistDecode: FileUtils.trimFileProtocol(`/tmp/quickshell/media/cliphist`)
    property string shellConfig: FileUtils.trimFileProtocol(`${Directories.config}/ai-panel`)
    property string shellConfigName: "config.json"
    property string shellConfigPath: `${Directories.shellConfig}/${Directories.shellConfigName}`
    property string aiPanelDataPath: FileUtils.trimFileProtocol(`${Directories.shellConfig}/data.jsonc`)
    property string userAiPrompts: FileUtils.trimFileProtocol(`${Directories.shellConfig}/ai/prompts`)
    property string defaultAiPrompts: FileUtils.trimFileProtocol(`${Directories.assetsPath}/prompts`)
    // Pinned to a fixed location: StandardPaths StateLocation is scoped to the
    // Quickshell instance name, which changes when running inside omarchy-shell
    // and would silently relocate the chat history.
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || FileUtils.trimFileProtocol(`${home}/.local/state`)
    property string aiChats: FileUtils.trimFileProtocol(`${stateHome}/ai-panel/ai/chats`)
    // Cleanup on init
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${shellConfig}`])
        Quickshell.execDetached(["mkdir", "-p", `${favicons}`])
        Quickshell.execDetached(["bash", "-c", `rm -rf '${cliphistDecode}'; mkdir -p '${cliphistDecode}'`])
        Quickshell.execDetached(["mkdir", "-p", `${aiChats}`])
        Quickshell.execDetached(["mkdir", "-p", `${userAiPrompts}`])
    }
}