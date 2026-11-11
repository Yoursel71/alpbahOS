// alpbahOS KSplash (2026-11-11, user request): the session start screen is the brand wallpaper with a real loading bar.
// Same layout as branding/alpbahos-brand/tools/build_brand_wallpaper.py (logo_box): background gradient, glow and logo
// (images/brand-center.png, scaled to the logo height), and under the logo, where the wallpaper used to have a static
// orange/cyan line, a bar of the same size that fills with the session start stages (KSplash `stage`, 1..6). When
// full it looks like the old line (first 20 % orange, rest cyan); the desktop then fades in without it.
// Measurements come from the generated BrandGeometry.qml. "Masaüstü hazırlanıyor" 56 px above the bottom edge.
import QtQuick

Rectangle {
    id: root
    property int stage
    readonly property BrandGeometry g: BrandGeometry {}

    // logo_box() of the wallpaper generator, for this screen
    readonly property int logoH: Math.min(Math.round(height * g.logoHeightFraction), g.logoNativeHeight)
    readonly property int logoW: Math.round(g.logoNativeWidth * logoH / g.logoNativeHeight)
    readonly property int lineT: Math.max(2, Math.round(height / 540))
    readonly property int gap: Math.round(height * g.gapFraction)
    readonly property int logoTop: Math.floor((height - (logoH + gap + lineT)) / 2)
    readonly property int logoX: Math.floor((width - logoW) / 2)
    readonly property real k: logoH / g.refLogoHeight
    readonly property int lineW: Math.round(width * g.accentWidthFraction)
    readonly property real progress: Math.max(0, Math.min(stage, 6)) / 6

    gradient: Gradient {
        GradientStop { position: 0.0; color: root.g.gradientTop }
        GradientStop { position: 1.0; color: root.g.gradientBottom }
    }

    Image {
        source: "images/brand-center.png"
        x: root.logoX - root.g.refLogoXInImage * root.k
        y: root.logoTop - root.g.refLogoYInImage * root.k
        width: root.g.centreImageWidth * root.k
        height: root.g.centreImageHeight * root.k
        smooth: true
        mipmap: true
    }

    Item {
        id: bar
        x: Math.floor((root.width - root.lineW) / 2)
        y: root.logoTop + root.logoH + root.gap
        width: root.lineW
        height: root.lineT
        property real fill: width * root.progress
        Behavior on fill { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

        Rectangle { anchors.fill: parent; color: root.g.cyan; opacity: 0.22 }   // track
        Rectangle {                                                              // filled part, cyan
            height: parent.height
            width: bar.fill
            color: root.g.cyan
        }
        Rectangle {                                                              // orange start of the bar
            height: parent.height
            width: Math.min(bar.fill, Math.max(1, Math.round(bar.width * root.g.accentOrangeFraction)))
            color: root.g.orange
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Masaüstü hazırlanıyor"
        color: "#8ea2af"
        font.family: "JetBrains Mono"
        font.pixelSize: 14
    }
}
