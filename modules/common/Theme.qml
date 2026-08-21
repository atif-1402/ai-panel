pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "file:/usr/share/omarchy/shell/Commons" as OC

// Theming facade over the real omarchy Color singleton (qs.Commons) — the same
// source plugins like furmware.cloud consume. The core palette and per-surface
// roles come straight from OC.Color. The omarchy singleton only tracks the
// foundational five (foreground/background/accent/urgent/muted), so the extra
// layer tokens the M3 mapping needs (selection, layered backgrounds, ANSI
// colors) are parsed here from the same colors.toml.
//
// omarchy replaces theme files atomically on theme switches, which breaks the
// inotify watch, so the standalone process re-polls and forwards the raw text
// into OC.Color's own loaders to keep the singleton live too.
QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateHome: home + "/.local/state"
    readonly property string currentThemePath: stateHome + "/omarchy/current/theme"

    // Core palette — straight from the omarchy Color singleton.
    property color background: OC.Color.background
    property color foreground: OC.Color.foreground
    property color accent: OC.Color.accent
    property color urgent: OC.Color.urgent
    property color muted: OC.Color.muted

    // Per-surface roles — the same objects the shell exposes.
    readonly property QtObject bar: OC.Color.bar
    readonly property QtObject popups: OC.Color.popups
    readonly property QtObject menu: OC.Color.menu
    readonly property QtObject tooltip: OC.Color.tooltip
    readonly property QtObject notifications: OC.Color.notifications

    // Extra layer tokens (not exposed by the omarchy singleton).
    property color selection: "#3a3f45"
    property color darkBackground: "#0b0d0f"
    property color darkerBackground: "#08090b"
    property color lighterBackground: "#191c1f"
    property color red: "#a55555"
    property color green: "#a3be8c"
    property color cyan: "#88c0d0"
    property color yellow: "#d8a657"
    property color magenta: "#d3869b"

    function loadColors(raw) {
        var lines = String(raw || "").split("\n")
        var color0Value = ""
        var color4Value = ""
        var color7Value = ""
        var color8Value = ""
        var foundAccent = false
        var foundMuted = false
        var loadedForeground = false
        var loadedBackground = false
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
            if (!m) continue
            switch (m[1]) {
                case "background": root.background = m[2]; loadedBackground = true; break
                case "foreground": root.foreground = m[2]; loadedForeground = true; break
                case "accent": root.accent = m[2]; foundAccent = true; break
                case "muted": root.muted = m[2]; foundMuted = true; break
                case "selection": root.selection = m[2]; break
                case "dark_background": root.darkBackground = m[2]; break
                case "darker_background": root.darkerBackground = m[2]; break
                case "lighter_background": root.lighterBackground = m[2]; break
                case "red": root.red = m[2]; root.urgent = m[2]; break
                case "green": root.green = m[2]; break
                case "cyan": root.cyan = m[2]; break
                case "yellow": root.yellow = m[2]; break
                case "magenta": root.magenta = m[2]; break
                case "color0": color0Value = m[2]; break
                case "color4": color4Value = m[2]; break
                case "color7": color7Value = m[2]; break
                case "color8": color8Value = m[2]; break
            }
        }
        if (!loadedBackground && color0Value.length > 0) root.background = color0Value
        if (!loadedForeground && color7Value.length > 0) root.foreground = color7Value
        if (!foundAccent && color4Value.length > 0) root.accent = color4Value
        if (!foundMuted) root.muted = color8Value.length > 0 ? color8Value : root.foreground
    }

    // Reads the same two files the omarchy shell watches, parses the extras
    // here, and forwards the raw payload to the real Color singleton so it
    // follows live theme switches in this standalone process.
    property FileView themeFile: FileView {
        id: themeFile
        path: root.currentThemePath + "/colors.toml"
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.loadColors(text())
            OC.Color.loadColors(text())
        }
        onFileChanged: reload()
        onLoadFailed: OC.Color.loadColors("")
    }

    property FileView shellFile: FileView {
        id: shellFile
        path: root.currentThemePath + "/shell.toml"
        watchChanges: true
        printErrors: false
        onLoaded: OC.Color.loadShell(text())
        onFileChanged: reload()
        onLoadFailed: OC.Color.loadShell("")
    }

    property FileView userShellFile: FileView {
        id: userShellFile
        path: root.home + "/.config/omarchy/shell.toml"
        watchChanges: true
        printErrors: false
        onLoaded: OC.Color.loadUserShell(text())
        onFileChanged: reload()
        onLoadFailed: OC.Color.loadUserShell("")
    }

    // omarchy replaces theme files atomically on theme switches, which breaks
    // the inotify watch. Re-poll so the panel follows theme changes live.
property Timer themePollTimer: Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            themeFile.reload()
            shellFile.reload()
            userShellFile.reload()
        }
    }
}