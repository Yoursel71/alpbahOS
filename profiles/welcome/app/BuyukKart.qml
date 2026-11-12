// Large option card with a preview on top (Hoş Geldin designs). Selected: fill #062746, border #00aeef and a filled
// check circle, so the state is not shown by colour alone. Keyboard: Tab focus, Space/Enter select, ring #ffc45d.
import QtQuick

FocusScope {
    id: k
    property string baslik
    property string metin
    property bool secili: false
    property Component onizleme
    property int onizlemeYukseklik: 200
    signal secildi()

    implicitWidth: 400
    implicitHeight: onizlemeYukseklik + 92
    activeFocusOnTab: enabled
    opacity: enabled ? 1.0 : 0.55
    Accessible.role: Accessible.RadioButton
    Accessible.name: baslik + ". " + metin
    Accessible.checked: secili
    Keys.onSpacePressed: if (enabled) secildi()
    Keys.onReturnPressed: if (enabled) secildi()
    Keys.onEnterPressed: if (enabled) secildi()

    Rectangle {
        anchors.fill: parent; anchors.margins: -4; radius: 18
        color: "transparent"; border.width: 2; border.color: "#ffc45d"
        visible: k.activeFocus
    }
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: k.secili ? "#062746" : (ma.containsMouse && k.enabled ? "#1d2c38" : "#16232d")
        border.width: 2
        border.color: k.secili ? "#00aeef" : "#29404f"

        Item {
            id: alan
            x: 12; y: 12
            width: parent.width - 24
            height: k.onizlemeYukseklik
            clip: true
            Loader { anchors.fill: parent; sourceComponent: k.onizleme }
        }
        Column {
            anchors.left: parent.left; anchors.leftMargin: 18
            anchors.right: isaret.left; anchors.rightMargin: 12
            anchors.top: alan.bottom; anchors.topMargin: 14
            spacing: 4
            Text {
                width: parent.width
                text: k.baslik
                color: "#f4f8fb"
                font.family: "Inter Variable"; font.pixelSize: 17; font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: k.metin
                color: "#a9bac6"
                font.family: "Inter Variable"; font.pixelSize: 13
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
            }
        }
        Rectangle {
            id: isaret
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.top: alan.bottom; anchors.topMargin: 18
            width: 28; height: 28; radius: 14
            color: k.secili ? "#00aeef" : "transparent"
            border.width: 2
            border.color: k.secili ? "#00aeef" : "#53636d"
            Text {
                anchors.centerIn: parent
                visible: k.secili
                text: "✓"; color: "#0b1014"
                font.pixelSize: 16; font.weight: Font.Bold
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: k.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { k.forceActiveFocus(); k.secildi(); }
    }
}
