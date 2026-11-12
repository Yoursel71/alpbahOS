// Segmented choice (two or three options in one bar). Each option is a radio button: Tab focus, Space/Enter select,
// a check mark next to the selected label (not colour alone), focus ring #ffc45d. A disabled option is dimmed and
// cannot be chosen. objectName of an option: <onEk>_<deger> (tests).
import QtQuick

Rectangle {
    id: seg
    property var secenekler: []      // [{ deger, baslik, etkin (default true) }]
    property string secilen
    property string onEk
    signal secildi(string deger)

    implicitHeight: 46
    implicitWidth: 320
    radius: 11
    color: "#0b1014"
    border.color: "#29404f"; border.width: 1

    Row {
        id: row
        anchors.fill: parent; anchors.margins: 4
        spacing: 4
        Repeater {
            model: seg.secenekler
            delegate: FocusScope {
                id: s
                required property var modelData
                readonly property bool etkin: modelData.etkin !== false
                readonly property bool isaretli: seg.secilen === modelData.deger
                objectName: seg.onEk + "_" + modelData.deger
                width: (row.width - (seg.secenekler.length - 1) * row.spacing) / seg.secenekler.length
                height: row.height
                activeFocusOnTab: etkin
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.baslik
                Accessible.checked: isaretli
                Keys.onSpacePressed: if (etkin) seg.secildi(modelData.deger)
                Keys.onReturnPressed: if (etkin) seg.secildi(modelData.deger)
                Keys.onEnterPressed: if (etkin) seg.secildi(modelData.deger)

                Rectangle {
                    anchors.fill: parent; radius: 8
                    color: s.isaretli ? "#062746" : (ma.containsMouse && s.etkin ? "#16232d" : "transparent")
                    border.width: s.isaretli ? 1 : 0
                    border.color: "#00aeef"
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        visible: s.isaretli
                        text: "✓"; color: "#54d6ff"
                        font.pixelSize: 15; font.weight: Font.Bold
                    }
                    Text {
                        text: s.modelData.baslik
                        color: s.isaretli ? "#f4f8fb" : (s.etkin ? "#d4e0e8" : "#53636d")
                        font.family: "Inter Variable"; font.pixelSize: 14
                        font.weight: s.isaretli ? Font.DemiBold : Font.Normal
                    }
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: -3; radius: 10
                    color: "transparent"; border.width: 2; border.color: "#ffc45d"
                    visible: s.activeFocus
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: s.etkin ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (s.etkin) { s.forceActiveFocus(); seg.secildi(s.modelData.deger); }
                }
            }
        }
    }
}
