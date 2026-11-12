// Hoş Geldin design 2 "Canlı önizleme" (WELCOME-02): the choices on the left as segmented bars, a large live picture
// of the desktop on the right that changes with every choice. 960x720.
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

    // Left column
    Rectangle {
        id: sol
        width: 392; height: parent.height
        color: "#11171c"
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#29404f" }

        Column {
            x: 40; y: 40
            width: parent.width - 80
            spacing: 0
            Image {
                source: "mark.png"
                width: 64; height: Math.round(64 * sourceSize.height / Math.max(1, sourceSize.width))
                smooth: true; mipmap: true
            }
            Item { width: 1; height: 18 }
            Text {
                width: parent.width
                textFormat: Text.StyledText
                text: "alpbah<font color=\"#00aeef\">OS</font>'a<br>hoş geldin"
                color: "#f4f8fb"
                font.family: "Inter Variable"; font.pixelSize: 30; font.bold: true
                lineHeight: 1.1
            }
            Item { width: 1; height: 10 }
            Text {
                width: parent.width
                text: "Seç, sağda hemen gör. Hepsini sonra Sistem Ayarları'ndan değiştirebilirsin."
                color: "#a9bac6"
                font.family: "Inter Variable"; font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
            Item { width: 1; height: 34 }

            Text { text: "Tema"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 15; font.weight: Font.DemiBold }
            Item { width: 1; height: 8 }
            Segment {
                width: parent.width
                onEk: "tema"
                secilen: m.tema
                secenekler: [{ deger: "alpbahos", baslik: "alpbahOS" }, { deger: "ataturk", baslik: "Atatürk" }]
                onSecildi: (d) => m.tema = d
            }
            Item { width: 1; height: 24 }

            Text { text: "Görünüm"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 15; font.weight: Font.DemiBold }
            Item { width: 1; height: 8 }
            Segment {
                width: parent.width
                onEk: "gorunum"
                secilen: m.gorunum
                secenekler: [{ deger: "solid", baslik: "Solid" }, { deger: "glass", baslik: "Glass", etkin: m.glassOk }]
                onSecildi: (d) => m.gorunumSec(d)
            }
            Item { width: 1; height: 6 }
            Text {
                width: parent.width
                text: m.glassOk ? "Glass saydamdır, ekran kartı hızlandırması ister." : "Glass kullanılamaz: " + m.glassNeden + "."
                color: "#8ea2af"
                font.family: "Inter Variable"; font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
            Item { width: 1; height: 24 }

            Text { text: "Görev çubuğu"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 15; font.weight: Font.DemiBold }
            Item { width: 1; height: 8 }
            Segment {
                width: parent.width
                onEk: "cubuk"
                secilen: m.cubuk
                secenekler: [{ deger: "sol", baslik: "Solda" }, { deger: "orta", baslik: "Ortada" }]
                onSecildi: (d) => m.cubuk = d
            }
        }

        Column {
            x: 40
            anchors.bottom: parent.bottom; anchors.bottomMargin: 36
            width: parent.width - 80
            spacing: 12
            Text {
                objectName: "mesaj"
                width: parent.width
                text: m.mesaj
                visible: text !== ""
                color: "#ffc45d"
                font.family: "Inter Variable"; font.pixelSize: 13
                wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
            }
            Dugme {
                objectName: "uygula"
                width: parent.width
                filled: true
                label: "Uygula ve başla"
                enabled: !m.mesgul
                onActivated: m.uygula()
            }
            Dugme {
                objectName: "gec"
                width: parent.width
                label: "Şimdilik geç"
                enabled: !m.mesgul
                onActivated: m.gec()
            }
        }
    }

    // Right: live preview
    Item {
        anchors.left: sol.right; anchors.right: parent.right
        height: parent.height
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text {
                text: "ÖNİZLEME"
                color: "#54d6ff"
                font.family: "Inter Variable"; font.pixelSize: 12; font.weight: Font.DemiBold
                font.letterSpacing: 2
            }
            Rectangle {
                width: 500; height: 282
                radius: 12
                color: "#29404f"
                MasaustuOnizleme {
                    anchors.fill: parent; anchors.margins: 2
                    resim: m.buyukResim(m.tema); gorunum: m.gorunum; cubuk: m.cubuk
                }
            }
            Text {
                width: 500
                text: m.temaAdi[m.tema] + " teması  ·  " + m.gorunumAdi[m.gorunum] + "  ·  " + m.cubukAdi[m.cubuk].toLowerCase()
                color: "#d4e0e8"
                font.family: "Inter Variable"; font.pixelSize: 14
            }
            Text {
                width: 500
                text: "Kilit ekranı da aynı duvar kağıdını kullanır."
                color: "#8ea2af"
                font.family: "Inter Variable"; font.pixelSize: 13
            }
        }
    }
}
