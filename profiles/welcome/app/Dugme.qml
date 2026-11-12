// Button of the Hoş Geldin designs: filled (cyan, the main action) or outline. Keyboard: Tab focus, Space/Enter,
// focus ring #ffc45d. Width follows the label unless the design sets it.
import QtQuick

FocusScope {
    id: d
    property string label
    property bool filled: false
    signal activated()

    implicitWidth: Math.max(132, txt.implicitWidth + 44)
    implicitHeight: 44
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: label
    Keys.onSpacePressed: if (enabled) activated()
    Keys.onReturnPressed: if (enabled) activated()
    Keys.onEnterPressed: if (enabled) activated()

    Rectangle {
        anchors.fill: parent; anchors.margins: -4; radius: 13
        color: "transparent"; border.width: 2; border.color: "#ffc45d"
        visible: d.activeFocus
    }
    Rectangle {
        anchors.fill: parent; radius: 10
        color: d.filled ? (ma.containsMouse ? "#33c2f5" : "#00aeef") : (ma.containsMouse ? "#1d2c38" : "transparent")
        border.width: d.filled ? 0 : 1
        border.color: "#29404f"
        opacity: d.enabled ? 1 : 0.55
    }
    Text {
        id: txt
        anchors.centerIn: parent
        text: d.label
        color: d.filled ? "#0b1014" : "#d4e0e8"
        font.family: "Inter Variable"; font.pixelSize: 15; font.weight: Font.DemiBold
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: d.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { d.forceActiveFocus(); d.activated(); }
    }
}
