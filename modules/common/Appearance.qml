import QtQuick
import Quickshell
import "functions"
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property QtObject m3colors
    property QtObject animation
    property QtObject animationCurves
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes
    property string syntaxHighlightingTheme

    // Transparency. The quadratic functions were derived from analysis of hand-picked transparency values.
    ColorQuantizer {
        id: wallColorQuant
        property string wallpaperPath: Config.options.background.wallpaperPath
        property bool wallpaperIsVideo: wallpaperPath.endsWith(".mp4") || wallpaperPath.endsWith(".webm") || wallpaperPath.endsWith(".mkv") || wallpaperPath.endsWith(".avi") || wallpaperPath.endsWith(".mov")
        source: Qt.resolvedUrl(wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath)
        depth: 0 // 2^0 = 1 color
        rescaleSize: 10
    }
    property real wallpaperVibrancy: (wallColorQuant.colors[0]?.hslSaturation + wallColorQuant.colors[0]?.hslLightness) / 2
    property real autoBackgroundTransparency: { // y = 0.5768x^2 - 0.759x + 0.2896
        let x = wallpaperVibrancy
        let y = 0.5768 * (x * x) - 0.759 * (x) + 0.2896
        return Math.max(0, Math.min(0.22, y)) - 0.12 * (m3colors.darkmode ? 0 : 1)
    }
    property real autoContentTransparency: 0.9
    property real backgroundTransparency: Config?.options.appearance.transparency.enable ? Config?.options.appearance.transparency.automatic ? autoBackgroundTransparency : Config?.options.appearance.transparency.backgroundTransparency : 0
    property real contentTransparency: Config?.options.appearance.transparency.automatic ? autoContentTransparency : Config?.options.appearance.transparency.contentTransparency

    m3colors: QtObject {
        // Follows the active Omarchy theme: relative luminance of the theme
        // background decides dark vs light mapping (and the syntax theme).
        property bool darkmode: (0.2126 * Theme.background.r + 0.7152 * Theme.background.g + 0.0722 * Theme.background.b) < 0.5
        property bool transparent: false
        property color m3background: Theme.background
        property color m3onBackground: Theme.foreground
        property color m3surface: Theme.background
        property color m3surfaceDim: Theme.darkBackground
        property color m3surfaceBright: Theme.lighterBackground
        property color m3surfaceContainerLowest: Theme.darkerBackground
        property color m3surfaceContainerLow: Theme.darkBackground
        property color m3surfaceContainer: Theme.lighterBackground
        property color m3surfaceContainerHigh: Theme.lighterBackground
        property color m3surfaceContainerHighest: Theme.selection
        property color m3onSurface: Theme.foreground
        property color m3surfaceVariant: Theme.muted
        property color m3onSurfaceVariant: Theme.foreground
        property color m3inverseSurface: Theme.foreground
        property color m3inverseOnSurface: Theme.background
        property color m3outline: Theme.muted
        property color m3outlineVariant: Theme.selection
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: Theme.accent
        property color m3primary: Theme.accent
        property color m3onPrimary: Theme.background
        property color m3primaryContainer: Theme.selection
        property color m3onPrimaryContainer: Theme.foreground
        property color m3inversePrimary: Theme.accent
        property color m3secondary: Theme.foreground
        property color m3onSecondary: Theme.background
        property color m3secondaryContainer: Theme.selection
        property color m3onSecondaryContainer: Theme.foreground
        property color m3tertiary: Theme.foreground
        property color m3onTertiary: Theme.background
        property color m3tertiaryContainer: Theme.selection
        property color m3onTertiaryContainer: Theme.foreground
        property color m3error: Theme.red
        property color m3onError: Theme.background
        property color m3errorContainer: Theme.red
        property color m3onErrorContainer: Theme.foreground
        property color m3primaryFixed: Theme.foreground
        property color m3primaryFixedDim: Theme.accent
        property color m3onPrimaryFixed: Theme.background
        property color m3onPrimaryFixedVariant: Theme.muted
        property color m3secondaryFixed: Theme.foreground
        property color m3secondaryFixedDim: Theme.accent
        property color m3onSecondaryFixed: Theme.background
        property color m3onSecondaryFixedVariant: Theme.muted
        property color m3tertiaryFixed: Theme.foreground
        property color m3tertiaryFixedDim: Theme.accent
        property color m3onTertiaryFixed: Theme.background
        property color m3onTertiaryFixedVariant: Theme.muted
        property color m3success: Theme.green
        property color m3onSuccess: Theme.background
        property color m3successContainer: Theme.selection
        property color m3onSuccessContainer: Theme.foreground
        property color term0: Theme.foreground
        property color term1: Theme.red
        property color term2: Theme.green
        property color term3: Theme.yellow
        property color term4: Theme.cyan
        property color term5: Theme.magenta
        property color term6: Theme.cyan
        property color term7: Theme.foreground
        property color term8: Theme.background
        property color term9: Theme.red
        property color term10: Theme.green
        property color term11: Theme.yellow
        property color term12: Theme.cyan
        property color term13: Theme.magenta
        property color term14: Theme.cyan
        property color term15: Theme.darkerBackground
    }

    colors: QtObject {
        property color colSubtext: m3colors.m3outline
        // Layer 0
        property color colLayer0Base: ColorUtils.mix(m3colors.m3background, m3colors.m3primary, Config.options.appearance.extraBackgroundTint ? 0.99 : 1)
        property color colLayer0: ColorUtils.transparentize(colLayer0Base, root.backgroundTransparency)
        property color colOnLayer0: m3colors.m3onBackground
        property color colLayer0Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.9, root.contentTransparency))
        property color colLayer0Active: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.8, root.contentTransparency))
        property color colLayer0Border: ColorUtils.mix(root.m3colors.m3outlineVariant, colLayer0, 0.4)
        // Layer 1
        property color colLayer1Base: m3colors.m3surfaceContainerLow
        property color colLayer1: ColorUtils.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - root.contentTransparency);
        property color colOnLayer1: m3colors.m3onSurfaceVariant;
        property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45);
        property color colLayer1Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.92), root.contentTransparency)
        property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.85), root.contentTransparency);
        // Layer 2
        property color colLayer2Base: m3colors.m3surfaceContainer
        property color colLayer2: ColorUtils.solveOverlayColor(colLayer1Base, colLayer2Base, 1 - root.contentTransparency)
        property color colLayer2Hover: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.90), 1 - root.contentTransparency)
        property color colLayer2Active: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.80), 1 - root.contentTransparency);
        property color colLayer2Disabled: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, m3colors.m3background, 0.8), 1 - root.contentTransparency);
        property color colOnLayer2: m3colors.m3onSurface;
        property color colOnLayer2Disabled: ColorUtils.mix(colOnLayer2, m3colors.m3background, 0.4);
        // Layer 3
        property color colLayer3Base: m3colors.m3surfaceContainerHigh
        property color colLayer3: ColorUtils.solveOverlayColor(colLayer2Base, colLayer3Base, 1 - root.contentTransparency)
        property color colLayer3Hover: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.90), 1 - root.contentTransparency)
        property color colLayer3Active: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.80), 1 - root.contentTransparency);
        property color colOnLayer3: m3colors.m3onSurface;
        // Layer 4
        property color colLayer4Base: m3colors.m3surfaceContainerHighest
        property color colLayer4: ColorUtils.solveOverlayColor(colLayer3Base, colLayer4Base, 1 - root.contentTransparency)
        property color colLayer4Hover: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.90), 1 - root.contentTransparency)
        property color colLayer4Active: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.80), 1 - root.contentTransparency);
        property color colOnLayer4: m3colors.m3onSurface;
        property color colSurfaceContainerHighest: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.08)
        property color colSurfaceContainerHighestHover: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.95)
        property color colSurfaceContainerHighestActive: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.85)
        // Primary
        property color colPrimary: m3colors.m3primary
        property color colOnPrimary: m3colors.m3onPrimary
        property color colPrimaryHover: ColorUtils.mix(colors.colPrimary, colLayer1Hover, 0.87)
        property color colPrimaryActive: ColorUtils.mix(colors.colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: m3colors.m3primaryContainer
        property color colPrimaryContainerHover: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.9)
        property color colPrimaryContainerActive: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.8)
        property color colOnPrimaryContainer: m3colors.m3onPrimaryContainer
        // Secondary
        property color colSecondary: m3colors.m3secondary
        property color colSecondaryHover: ColorUtils.mix(m3colors.m3secondary, colLayer1Hover, 0.85)
        property color colSecondaryActive: ColorUtils.mix(m3colors.m3secondary, colLayer1Active, 0.4)
        property color colOnSecondary: m3colors.m3onSecondary
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colSecondaryContainerHover: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.90)
        property color colSecondaryContainerActive: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.54)
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        // Tertiary
        property color colTertiary: m3colors.m3tertiary
        property color colTertiaryHover: ColorUtils.mix(m3colors.m3tertiary, colLayer1Hover, 0.85)
        property color colTertiaryActive: ColorUtils.mix(m3colors.m3tertiary, colLayer1Active, 0.4)
        property color colTertiaryContainer: m3colors.m3tertiaryContainer
        property color colTertiaryContainerHover: ColorUtils.mix(m3colors.m3tertiaryContainer, m3colors.m3onTertiaryContainer, 0.90)
        property color colTertiaryContainerActive: ColorUtils.mix(m3colors.m3tertiaryContainer, colLayer1Active, 0.54)
        property color colOnTertiary: m3colors.m3onTertiary
        property color colOnTertiaryContainer: m3colors.m3onTertiaryContainer
        // Surface
        property color colBackgroundSurfaceContainer: ColorUtils.transparentize(m3colors.m3surfaceContainer, root.backgroundTransparency)
        property color colSurfaceContainerLow: ColorUtils.solveOverlayColor(m3colors.m3background, m3colors.m3surfaceContainerLow, 1 - root.contentTransparency)
        property color colSurfaceContainer: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerLow, m3colors.m3surfaceContainer, 1 - root.contentTransparency)
        property color colSurfaceContainerHigh: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainer, m3colors.m3surfaceContainerHigh, 1 - root.contentTransparency)
        property color colOnSurface: m3colors.m3onSurface
        property color colOnSurfaceVariant: m3colors.m3onSurfaceVariant
        // Misc
        property color colTooltip: m3colors.m3inverseSurface
        property color colOnTooltip: m3colors.m3inverseOnSurface
        property color colScrim: ColorUtils.transparentize(m3colors.m3scrim, 0.5)
        property color colShadow: ColorUtils.transparentize(m3colors.m3shadow, 0.7)
        property color colOutline: m3colors.m3outline
        property color colOutlineVariant: m3colors.m3outlineVariant
        property color colError: m3colors.m3error
        property color colErrorHover: ColorUtils.mix(m3colors.m3error, colLayer1Hover, 0.85)
        property color colErrorActive: ColorUtils.mix(m3colors.m3error, colLayer1Active, 0.7)
        property color colOnError: m3colors.m3onError
        property color colErrorContainer: m3colors.m3errorContainer
        property color colErrorContainerHover: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.90)
        property color colErrorContainerActive: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.70)
        property color colOnErrorContainer: m3colors.m3onErrorContainer
    }

    rounding: QtObject {
        property int unsharpen: 0
        property int unsharpenmore: 0
        property int verysmall: 0
        property int small: 0
        property int normal: 0
        property int large: 0
        property int verylarge: 0
        property int full: 0
        property int screenRounding: 0
        property int windowRounding: 0
    }

    font: QtObject {
        property QtObject family: QtObject {
            property string main: "monospace"
            property string numbers: "monospace"
            property string title: "monospace"
            property string iconMaterial: "monospace"
            property string iconNerd: "monospace"
            property string monospace: "monospace"
            property string reading: "monospace"
            property string expressive: "monospace"
        }
        property QtObject variableAxes: QtObject {
            property var main: ({
                "wght": 450,
                "wdth": 100,
            })
            property var numbers: ({
                "wght": 450,
            })
            property var title: ({ // Slightly bold weight for title
                "wght": 550, // Weight (Lowered to compensate for increased grade)
            })
        }
        property QtObject pixelSize: QtObject {
            property int smallest: 9
            property int smaller: 11
            property int smallie: 12
            property int small: 13
            property int normal: 14
            property int large: 15
            property int larger: 17
            property int huge: 19
            property int hugeass: 20
            property int title: huge
        }
    }

    animationCurves: QtObject {
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1] // Default, 350ms
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1] // Default, 500ms
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1] // Default, 650ms
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1] // Default, 200ms
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedFirstHalf: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82]
        readonly property list<real> emphasizedLastHalf: [5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property real expressiveFastSpatialDuration: 350
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveSlowSpatialDuration: 650
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveSmall: QtObject {
            property int duration: animationCurves.expressiveFastSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveSmall.duration
                    easing.type: root.animation.elementMoveSmall.type
                    easing.bezierCurve: root.animation.elementMoveSmall.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveExit: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedAccel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveExit.duration
                    easing.type: root.animation.elementMoveExit.type
                    easing.bezierCurve: root.animation.elementMoveExit.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component { ColorAnimation {
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
        }

        property QtObject elementResize: QtObject {
            property int duration: 300
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasized
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementResize.duration
                    easing.type: root.animation.elementResize.type
                    easing.bezierCurve: root.animation.elementResize.bezierCurve
                }
            }
        }

        property QtObject clickBounce: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 850
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.clickBounce.duration
                easing.type: root.animation.clickBounce.type
                easing.bezierCurve: root.animation.clickBounce.bezierCurve
            }}
        }
        
        property QtObject scroll: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: root.animationCurves.standardDecel
        }

        property QtObject menuDecel: QtObject {
            property int duration: 350
            property int type: Easing.OutExpo
        }
    }

    sizes: QtObject {
        property real baseBarHeight: 40
        property real barHeight: Config.options.bar.cornerStyle === 1 ? 
            (baseBarHeight + root.sizes.hyprlandGapsOut * 2) : baseBarHeight
        property real barCenterSideModuleWidth: Config.options?.bar.verbose ? 360 : 140
        property real barCenterSideModuleWidthShortened: 280
        property real barCenterSideModuleWidthHellaShortened: 190
        property real barShortenScreenWidthThreshold: 1200 // Shorten if screen width is at most this value
        property real barHellaShortenScreenWidthThreshold: 1000 // Shorten even more...
        property real elevationMargin: 10
        property real fabShadowRadius: 5
        property real fabHoveredShadowRadius: 7
        property real hyprlandGapsOut: 5
        property real mediaControlsWidth: 440
        property real mediaControlsHeight: 160
        property real notificationPopupWidth: 410
        property real osdWidth: 180
        property real searchWidthCollapsed: 210
        property real searchWidth: 360
        property real sidebarWidth: 460
        property real sidebarWidthExtended: 750
        property real baseVerticalBarWidth: 46
        property real verticalBarWidth: Config.options.bar.cornerStyle === 1 ? 
            (baseVerticalBarWidth + root.sizes.hyprlandGapsOut * 2) : baseVerticalBarWidth
        property real wallpaperSelectorWidth: 1200
        property real wallpaperSelectorHeight: 690
        property real wallpaperSelectorItemMargins: 8
        property real wallpaperSelectorItemPadding: 6
    }

    syntaxHighlightingTheme: root.m3colors.darkmode ? "Monokai" : "ayu Light"
}
