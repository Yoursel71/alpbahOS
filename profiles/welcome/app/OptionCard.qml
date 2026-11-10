// One option card of the Welcome window (master task D3): 104 px high, fill #16232d, 2 px border #29404f,
// radius 12; selected: fill #062746, border #00aeef and a check mark (#54d6ff), so the state is not shown by colour
// alone. Keyboard: Tab focus, Space/Enter select, focus ring #ffc45d.
import QtQuick

FocusScope {
    id: card
    property string title
    property string text
    property bool selected: false
    property Component preview
    signal chosen()

    implicitHeight: 104
    activeFocusOnTab: enabled
    opacity: enabled ? 1.0 : 0.55
    Accessible.role: Accessible.RadioButton
    Accessible.name: title + ". " + text
    Accessible.checked: selected

    Keys.onSpacePressed: if (enabled) chosen()
    Keys.onReturnPressed: if (enabled) chosen()
    Keys.onEnterPressed: if (enabled) chosen()

    Rectangle {
        id: focusRing
        anchors.fill: parent
        anchors.margins: -4
        radius: 15
        color: "transparent"
        border.width: 2
        border.color: "#ffc45d"
        visible: card.activeFocus
    }
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: card.selected ? "#062746" : "#16232d"
        border.width: 2
        border.color: card.selected ? "#00aeef" : "#29404f"

        Loader {
            id: prev
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 84
            height: 60
            sourceComponent: card.preview
        }
        Column {
            anchors.left: prev.right
            anchors.leftMargin: 16
            anchors.right: check.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                width: parent.width
                text: card.title
                color: "#f4f8fb"
                font.family: "Inter Variable"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: card.text
                color: "#a9bac6"
                font.family: "Inter Variable"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
        Text {
            id: check
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            text: card.selected ? "✓" : ""
            color: "#54d6ff"
            font.pixelSize: 22
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: card.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: { card.forceActiveFocus(); card.chosen(); }
    }
}
