// Hoş Geldin design 3 "Kompakt" (WELCOME-02): a small window with three segmented rows and no pictures, so it opens
// at once and uses little memory on old PCs (D135). 640x430.
import QtQuick
import QtQuick.Window

Window {
    id: win
    required property var backend
    width: 640; height: 430
    minimumWidth: 640; maximumWidth: 640
    minimumHeight: 430; maximumHeight: 430
    visible: true
    title: "Hoş Geldin"
    color: "#11171c"

    Mantik { id: m; backend: win.backend }

    Item {
        anchors.fill: parent
        anchors.margins: 32

        Row {
            id: baslik
            spacing: 14
            Image {
                source: "mark.png"
                width: 44; height: Math.round(44 * sourceSize.height / Math.max(1, sourceSize.width))
                smooth: true; mipmap: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    textFormat: Text.StyledText
                    text: "alpbah<font color=\"#00aeef\">OS</font>'a hoş geldin"
                    color: "#f4f8fb"
                    font.family: "Inter Variable"; font.pixelSize: 22; font.bold: true
                }
                Text {
                    text: "Üç seçim, bir tık. Sonra Sistem Ayarları'ndan değişir."
                    color: "#a9bac6"
                    font.family: "Inter Variable"; font.pixelSize: 13
                }
            }
        }

        Column {
            anchors.top: baslik.bottom; anchors.topMargin: 30
            width: parent.width
            spacing: 16
            Repeater {
                model: 3
                Item {
                    id: satir
                    required property int index
                    width: parent.width; height: 46
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: ["Tema", "Görünüm", "Görev çubuğu"][satir.index]
                            color: "#f4f8fb"
                            font.family: "Inter Variable"; font.pixelSize: 15; font.weight: Font.DemiBold
                        }
                        Text {
                            text: ["Duvar kağıdı ve kilit ekranı", m.glassOk ? "Pencere ve panel yüzeyleri" : "Glass: " + m.glassNeden,
                                   "Simgelerin yeri"][satir.index]
                            color: "#8ea2af"
                            font.family: "Inter Variable"; font.pixelSize: 12
                            width: 200; elide: Text.ElideRight
                        }
                    }
                    Segment {
                        anchors.right: parent.right
                        width: 340
                        onEk: ["tema", "gorunum", "cubuk"][satir.index]
                        secilen: [m.tema, m.gorunum, m.cubuk][satir.index]
                        secenekler: [
                            [{ deger: "alpbahos", baslik: "alpbahOS" }, { deger: "ataturk", baslik: "Atatürk" }],
                            [{ deger: "solid", baslik: "Solid" }, { deger: "glass", baslik: "Glass", etkin: m.glassOk }],
                            [{ deger: "sol", baslik: "Solda" }, { deger: "orta", baslik: "Ortada" }]
                        ][satir.index]
                        onSecildi: (d) => {
                            if (satir.index === 0) m.tema = d;
                            else if (satir.index === 1) m.gorunumSec(d);
                            else m.cubuk = d;
                        }
                    }
                }
            }
        }

        Text {
            objectName: "mesaj"
            anchors.bottom: cizgi.top; anchors.bottomMargin: 12
            width: parent.width
            text: m.mesaj
            color: "#ffc45d"
            font.family: "Inter Variable"; font.pixelSize: 13
            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
        }
        Rectangle { id: cizgi; anchors.bottom: alt.top; anchors.bottomMargin: 18; width: parent.width; height: 1; color: "#29404f" }
        Item {
            id: alt
            anchors.bottom: parent.bottom
            width: parent.width; height: 44
            Dugme {
                objectName: "gec"
                anchors.left: parent.left
                label: "Şimdilik geç"
                enabled: !m.mesgul
                onActivated: m.gec()
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
