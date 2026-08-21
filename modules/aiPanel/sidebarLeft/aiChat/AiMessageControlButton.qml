import "../../../common"
import "../../../common/widgets"
import "../../../../services"
import QtQuick

GroupButton {
    id: button
    property string buttonIcon
    property bool activated: false
    toggled: activated
    baseWidth: height
    colBackgroundHover: "transparent"
    colBackgroundActive: "transparent"
    colBackgroundToggled: "transparent"
    colBackgroundToggledHover: "transparent"
    colBackgroundToggledActive: "transparent"

    contentItem: NerdSymbol {
        horizontalAlignment: Text.AlignHCenter
        iconSize: Appearance.font.pixelSize.larger
        iconName: buttonIcon
        color: button.activated ? Appearance.m3colors.m3onPrimary :
            button.enabled ? Appearance.m3colors.m3onSurface :
            Appearance.colors.colOnLayer1Inactive

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}
