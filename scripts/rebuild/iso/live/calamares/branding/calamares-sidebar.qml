/* alpbahOS installer sidebar (INSTALLER-02; branding.desc "sidebar: qml"). Based on Calamares 3.3's
   calamares-sidebar.qml (GPL-3.0-or-later, Adriaan de Groot, Anke Boersma). The steps are numbered; a finished step
   shows a check mark, the current one a cyan bar and a filled circle, so the state is not shown by colour alone.
   Calamares gives the sidebar a fixed width (the same as the widget sidebar). */
import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick 2.15

Rectangle {
    id: sideBar
    color: "#0b1014"
    anchors.fill: parent

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#1d2c38" }

    Image {
        id: logo
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        width: Math.min(parent.width - 48, 132)
        height: width * 0.62
        fillMode: Image.PreserveAspectFit
        source: "file://" + Branding.imagePath(Branding.ProductLogo)
        sourceSize.width: 264
        smooth: true; mipmap: true
    }

    Column {
        id: adimlar
        anchors.top: logo.bottom; anchors.topMargin: 18
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 2

        Repeater {
            model: ViewManager
            Item {
                id: satir
                required property int index
                required property string display
                readonly property bool simdi: index === ViewManager.currentStepIndex
                readonly property bool bitti: index < ViewManager.currentStepIndex
                width: adimlar.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    radius: 8
                    color: satir.simdi ? "#062746" : "transparent"
                }
                Rectangle {
                    visible: satir.simdi
                    x: 8; width: 3; radius: 1.5
                    height: parent.height - 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#00aeef"
                }
                Rectangle {
                    id: daire
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22; radius: 11
                    color: satir.simdi ? "#00aeef" : "transparent"
                    border.width: 2
                    border.color: satir.simdi || satir.bitti ? "#00aeef" : "#29404f"
                    Text {
                        anchors.centerIn: parent
                        text: satir.bitti ? "✓" : (satir.index + 1)
                        color: satir.simdi ? "#0b1014" : (satir.bitti ? "#54d6ff" : "#8ea2af")
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
                Text {
                    anchors.left: daire.right; anchors.leftMargin: 10
                    anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: satir.display
                    elide: Text.ElideRight
                    color: satir.simdi ? "#f4f8fb" : (satir.bitti ? "#d4e0e8" : "#8ea2af")
                    font.pixelSize: 13
                    font.weight: satir.simdi ? Font.DemiBold : Font.Normal
                }
            }
        }
    }

    Row {
        id: hakkinda
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        spacing: 7
        visible: typeof debug !== "undefined"
        Rectangle {
            width: 15; height: 15; radius: 7.5
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"; border.width: 1.5
            border.color: hma.containsMouse ? "#54d6ff" : "#8ea2af"
            Text { anchors.centerIn: parent; text: "i"; color: parent.border.color; font.pixelSize: 10; font.bold: true }
        }
        Text {
            text: qsTr("About")
            color: hma.containsMouse ? "#54d6ff" : "#8ea2af"
            font.pixelSize: 12
        }
    }
    MouseArea {
        id: hma
        anchors.fill: hakkinda; anchors.margins: -6
        visible: hakkinda.visible
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: debug.about()
    }
}
