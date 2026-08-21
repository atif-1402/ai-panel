import ".."
import "nerd-icons.js" as NerdIcons
import QtQuick

StyledText {
    id: root
    property string iconName: ""
    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    renderType: Text.NativeRendering
    font {
        hintingPreference: Font.PreferNoHinting
        family: Appearance?.font.family.iconNerd ?? "JetBrains Mono NF"
        pixelSize: iconSize
    }

    text: NerdIcons.nerdIcon(root.iconName)
}