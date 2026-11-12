// Hoş Geldin design 5 "Vitrin" (WELCOME-02): the chosen wallpaper fills the window and changes as soon as a theme
// card is picked; the look and taskbar choices sit on a dark panel at the bottom. 960x720.
import QtQuick
import QtQuick.Window

Window {
    id: win
    required property var backend
    width: 960; height: 720
    minimumWidth: 960; maximumWidth: 960
    minimumHeight: 720; maximumHeight: 720
    visible: true
    title: "Hoş Geldin"
    color: "#0b1014"

    Mantik { id: m; backend: win.backend }

    Image {
        anchors.fill: parent
        source: m.buyukResim(m.tema)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 960
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#d90b1014" }
            GradientStop { position: 0.45; color: "#8c0b1014" }
            GradientStop { position: 1.0; color: "#f20b1014" }
        }
    }

    Column {
        id: ust
        anchors.horizontalCenter: parent.horizontalCenter
        y: 38
        spacing: 8
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "mark.png"
            width: 56; height: Math.round(56 * sourceSize.height / Math.max(1, sourceSize.width))
            smooth: true; mipmap: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.StyledText
            text: "alpbah<font color=\"#00aeef\">OS</font>'a hoş geldin"
            color: "#f4f8fb"
            font.family: "Inter Variable"; font.pixelSize: 32; font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Bir tema seç: arka plan hemen değişir."
            color: "#d4e0e8"
            font.family: "Inter Variable"; font.pixelSize: 15
        }
    }

    Row {
        id: temalar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: ust.bottom; anchors.topMargin: 24
        spacing: 26
        Repeater {
            model: [{ k: "alpbahos", ad: "alpbahOS", metin: "Dağ ve terminal" }, { k: "ataturk", ad: "Atatürk", metin: "Atatürk duvar kağıdı" }]
            FocusScope {
                id: kart
                required property var modelData
                readonly property bool secili: m.tema === modelData.k
                objectName: "tema_" + modelData.k
                width: 330; height: 222
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.ad + " teması"
                Accessible.checked: secili
                Keys.onSpacePressed: m.tema = modelData.k
                Keys.onReturnPressed: m.tema = modelData.k
                Keys.onEnterPressed: m.tema = modelData.k
                Rectangle {
                    anchors.fill: parent; anchors.margins: -5; radius: 18
                    color: "transparent"; border.width: 2; border.color: "#ffc45d"
                    visible: kart.activeFocus
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: kart.secili ? "#062746" : "#cc16232d"
                    border.width: kart.secili ? 3 : 2
                    border.color: kart.secili ? "#00aeef" : (kma.containsMouse ? "#54d6ff" : "#29404f")
                    Item {
                        x: 10; y: 10; width: parent.width - 20; height: 152
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: m.buyukResim(kart.modelData.k)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 620
                        }
                    }
                    Column {
                        x: 16; y: 172
                        spacing: 2
                        Text { text: kart.modelData.ad; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: kart.modelData.metin; color: "#a9bac6"; font.family: "Inter Variable"; font.pixelSize: 12 }
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 14
                        y: 180
                        width: 26; height: 26; radius: 13
                        color: kart.secili ? "#00aeef" : "transparent"
                        border.width: 2; border.color: kart.secili ? "#00aeef" : "#53636d"
                        Text { anchors.centerIn: parent; visible: kart.secili; text: "✓"; color: "#0b1014"; font.pixelSize: 15; font.weight: Font.Bold }
                    }
                }
                MouseArea {
                    id: kma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { kart.forceActiveFocus(); m.tema = kart.modelData.k; }
                }
            }
        }
    }

    // Bottom panel
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 28
        height: 196
        radius: 16
        color: "#e611171c"
        border.width: 1; border.color: "#29404f"

        Row {
            id: alanlar
            x: 28; y: 24
            width: parent.width - 56
            spacing: 28
            Column {
                width: (alanlar.width - alanlar.spacing) / 2
                spacing: 8
                Text { text: "Görünüm"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 15; font.weight: Font.DemiBold }
                Segment {
                    width: parent.width
                    onEk: "gorunum"
                    secilen: m.gorunum
                    secenekler: [{ deger: "solid", baslik: "Solid" }, { deger: "glass", baslik: "Glass", etkin: m.glassOk }]
                    onSecildi: (d) => m.gorunumSec(d)
                }
                Text {
                    width: parent.width
                    text: m.glassOk ? "Glass saydamdır, ekran kartı hızlandırması ister." : "Glass kullanılamaz: " + m.glassNeden + "."
                    color: "#8ea2af"; font.family: "Inter Variable"; font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
            Column {
                width: (alanlar.width - alanlar.spacing) / 2
                spacing: 8
                Text { text: "Görev çubuğu"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 15; font.weight: Font.DemiBold }
                Segment {
                    width: parent.width
                    onEk: "cubuk"
                    secilen: m.cubuk
                    secenekler: [{ deger: "sol", baslik: "Solda" }, { deger: "orta", baslik: "Ortada" }]
                    onSecildi: (d) => m.cubuk = d
                }
                Text {
                    width: parent.width
                    text: "Başlat düğmesi simgelerin başında durur."
                    color: "#8ea2af"; font.family: "Inter Variable"; font.pixelSize: 12
                }
            }
        }
        Item {
            x: 28
            anchors.bottom: parent.bottom; anchors.bottomMargin: 22
            width: parent.width - 56; height: 44
            Dugme {
                objectName: "gec"
                anchors.left: parent.left
                label: "Şimdilik geç"
                enabled: !m.mesgul
                onActivated: m.gec()
            }
            Text {
                objectName: "mesaj"
                anchors.centerIn: parent
                width: 360
                horizontalAlignment: Text.AlignHCenter
                text: m.mesaj
                color: "#ffc45d"
                font.family: "Inter Variable"; font.pixelSize: 13
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Dugme {
                objectName: "uygula"
                anchors.right: parent.right
                filled: true
                label: "Uygula ve başla"
                enabled: !m.mesgul
                onActivated: m.uygula()
            }
        }
    }
}
