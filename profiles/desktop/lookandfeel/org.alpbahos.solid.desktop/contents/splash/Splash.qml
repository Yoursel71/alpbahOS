// alpbahOS KSplash (master task E3): the same look as the Plymouth boot splash (PLYMOUTH-01): background #0b1014,
// mark, 24 px, wordmark, 48 px, 280x4 bar (track #1d2c38, fill #00aeef) that follows the session start stages,
// "Masaüstü hazırlanıyor" 56 px above the bottom edge. Images: branding/plymouth-theme/alpbahos (mark.png, wordmark.png).
import QtQuick

Rectangle {
    id: root
    color: "#0b1014"
    property int stage

    Column {
        anchors.centerIn: parent
        spacing: 0
        Image { source: "images/mark.png"; anchors.horizontalCenter: parent.horizontalCenter }
        Item { width: 1; height: 24 }
        Image { source: "images/wordmark.png"; anchors.horizontalCenter: parent.horizontalCenter }
        Item { width: 1; height: 48 }
        Rectangle {
            id: track
            width: 280; height: 4; radius: 2
            color: "#1d2c38"
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                height: 4; radius: 2
                color: "#00aeef"
                width: Math.max(4, track.width * Math.min(root.stage, 6) / 6)
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            }
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
