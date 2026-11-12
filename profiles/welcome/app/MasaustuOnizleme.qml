// Drawn preview of the alpbahOS desktop for the Hoş Geldin designs: the chosen wallpaper, one window and the bottom
// taskbar (D115) in the chosen look (Solid: opaque surfaces; Glass: see-through surfaces with a light edge) and with
// the icons on the left or in the middle. Plain rectangles only (no shader effects), so it draws the same with
// software rendering on old PCs. Sizes scale with the width (s = 1 at 480 px).
import QtQuick

Rectangle {
    id: o
    property url resim
    property string gorunum: "solid"
    property string cubuk: "sol"
    property bool pencere: true
    readonly property real s: width / 480
    readonly property bool cam: gorunum === "glass"

    color: "#0b1014"
    clip: true

    Image {
        anchors.fill: parent
        source: o.resim
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 960
        smooth: true
    }

    // One window: title bar with three dots, a few text lines.
    Rectangle {
        visible: o.pencere
        x: parent.width * 0.17; y: parent.height * 0.13
        width: parent.width * 0.52; height: parent.height * 0.55
        radius: 6 * o.s
        color: o.cam ? "#8c16232d" : "#16232d"
        border.width: Math.max(1, o.s)
        border.color: o.cam ? "#9954d6ff" : "#29404f"
        Rectangle {
            visible: o.cam
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Math.max(1, o.s)
            height: parent.height * 0.35; radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: "#33ffffff" }
                GradientStop { position: 1; color: "#00ffffff" }
            }
        }
        Row {
            x: 10 * o.s; y: 8 * o.s
            spacing: 5 * o.s
            Repeater {
                model: ["#ff6575", "#ffc45d", "#35d07f"]
                Rectangle { required property string modelData; width: 7 * o.s; height: width; radius: width / 2; color: modelData }
            }
        }
        Column {
            x: 14 * o.s; y: 28 * o.s
            spacing: 7 * o.s
            Repeater {
                model: [0.70, 0.55, 0.62, 0.40]
                Rectangle {
                    required property real modelData
                    width: o.width * 0.52 * modelData; height: 5 * o.s; radius: height / 2
                    color: o.cam ? "#99f4f8fb" : "#4d8ea2af"
                }
            }
        }
    }

    // Taskbar: start button, four pinned apps, tray and clock.
    Rectangle {
        id: bar
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: Math.max(10, 26 * o.s)
        color: o.cam ? "#a60b1014" : "#16232d"
        Rectangle { anchors.top: parent.top; width: parent.width; height: Math.max(1, o.s); color: o.cam ? "#6654d6ff" : "#29404f" }
        Row {
            id: ikonlar
            anchors.verticalCenter: parent.verticalCenter
            x: o.cubuk === "orta" ? (parent.width - width) / 2 : 8 * o.s
            spacing: 6 * o.s
            Repeater {
                model: ["#00aeef", "#54d6ff", "#f5a623", "#35d07f", "#d4e0e8"]
                Rectangle {
                    required property string modelData
                    required property int index
                    width: bar.height * 0.58; height: width
                    radius: index === 0 ? width / 2 : 3 * o.s
                    color: modelData
                    opacity: index === 0 ? 1 : 0.85
                }
            }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 8 * o.s
            anchors.verticalCenter: parent.verticalCenter
            visible: o.width >= 160
            text: "14:05"
            color: "#d4e0e8"
            font.family: "Inter Variable"; font.pixelSize: Math.max(7, 10 * o.s)
        }
    }
}
