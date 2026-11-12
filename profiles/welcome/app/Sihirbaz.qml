// Hoş Geldin design 1 "Adım adım" (WELCOME-02): one question per page with two large picture cards, a step bar and a
// summary page with a live preview before anything is applied. 960x720. Geri/İleri, "Şimdilik geç" on every page.
import QtQuick
import QtQuick.Window

Window {
    id: win
    required property var backend
    property int adim: 0                       // 0 tema, 1 görünüm, 2 görev çubuğu, 3 özet
    width: 960; height: 720
    minimumWidth: 960; maximumWidth: 960
    minimumHeight: 720; maximumHeight: 720
    visible: true
    title: "Hoş Geldin"
    color: "#11171c"

    Mantik { id: m; backend: win.backend }

    readonly property var adimlar: ["Tema", "Görünüm", "Görev çubuğu", "Hazır"]
    readonly property var sorular: ["Hangi temayı istersin?", "Pencereler nasıl görünsün?",
        "Görev çubuğundaki simgeler nerede dursun?", "Her şey hazır"]
    readonly property var aciklamalar: ["Duvar kağıdı ve kilit ekranı bu temayı kullanır.",
        "Glass saydam ve bulanıktır, ekran kartı hızlandırması ister.",
        "Başlat düğmesi her zaman simgelerin başında durur.",
        "Seçimlerine son kez bak. Hepsini sonra Sistem Ayarları'ndan değiştirebilirsin."]

    function git(n) {
        adim = n;
        m.mesaj = "";
        odakTimer.restart();
    }
    Timer {
        id: odakTimer
        interval: 0
        onTriggered: {
            var ilk = [tema1, gor1, cub1, uygulaBtn][win.adim];
            if (ilk) ilk.forceActiveFocus();
        }
    }
    Component.onCompleted: odakTimer.restart()

    Item {
        anchors.fill: parent
        anchors.topMargin: 32; anchors.bottomMargin: 32
        anchors.leftMargin: 44; anchors.rightMargin: 44

        // Header: mark, title; step bar on the right.
        Row {
            id: baslik
            spacing: 16
            Image {
                source: "mark.png"
                width: 52; height: Math.round(52 * sourceSize.height / Math.max(1, sourceSize.width))
                smooth: true; mipmap: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.StyledText
                text: "alpbah<font color=\"#00aeef\">OS</font>'a hoş geldin"
                color: "#f4f8fb"
                font.family: "Inter Variable"; font.pixelSize: 24; font.bold: true
            }
        }
        Row {
            id: adimCubugu
            anchors.right: parent.right
            anchors.verticalCenter: baslik.verticalCenter
            spacing: 8
            Repeater {
                model: win.adimlar
                Row {
                    id: a
                    required property string modelData
                    required property int index
                    spacing: 8
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: a.index === win.adim ? "#00aeef" : "transparent"
                        border.width: 2
                        border.color: a.index <= win.adim ? "#00aeef" : "#29404f"
                        Text {
                            anchors.centerIn: parent
                            text: a.index < win.adim ? "✓" : (a.index + 1)
                            color: a.index === win.adim ? "#0b1014" : (a.index < win.adim ? "#54d6ff" : "#8ea2af")
                            font.family: "Inter Variable"; font.pixelSize: 13; font.bold: true
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: a.modelData
                        color: a.index === win.adim ? "#f4f8fb" : "#8ea2af"
                        font.family: "Inter Variable"; font.pixelSize: 13
                        font.weight: a.index === win.adim ? Font.DemiBold : Font.Normal
                    }
                    Rectangle {
                        visible: a.index < 3
                        width: 18; height: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: a.index < win.adim ? "#00aeef" : "#29404f"
                    }
                }
            }
        }

        Column {
            id: soru
            anchors.top: baslik.bottom; anchors.topMargin: 34
            width: parent.width
            spacing: 6
            Text {
                text: win.sorular[win.adim]
                color: "#f4f8fb"
                font.family: "Inter Variable"; font.pixelSize: 28; font.bold: true
            }
            Text {
                text: win.aciklamalar[win.adim]
                color: "#a9bac6"
                font.family: "Inter Variable"; font.pixelSize: 15
            }
        }

        Item {
            id: icerik
            anchors.top: soru.bottom; anchors.topMargin: 26
            anchors.bottom: cizgi.top; anchors.bottomMargin: 20
            width: parent.width

            // Step 1: theme
            Row {
                visible: win.adim === 0
                spacing: 24
                BuyukKart {
                    id: tema1
                    objectName: "tema_alpbahos"
                    width: (icerik.width - 24) / 2; onizlemeYukseklik: 290
                    baslik: "alpbahOS"; metin: "Dağ ve terminal, lacivert ve camgöbeği tonlar"
                    secili: m.tema === "alpbahos"
                    onSecildi: m.tema = "alpbahos"
                    onizleme: Component { Image { source: m.buyukResim("alpbahos"); fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 840 } }
                }
                BuyukKart {
                    objectName: "tema_ataturk"
                    width: (icerik.width - 24) / 2; onizlemeYukseklik: 290
                    baslik: "Atatürk"; metin: "Atatürk duvar kağıdı ve kilit ekranı"
                    secili: m.tema === "ataturk"
                    onSecildi: m.tema = "ataturk"
                    onizleme: Component { Image { source: m.buyukResim("ataturk"); fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 840 } }
                }
            }
            // Step 2: look
            Row {
                visible: win.adim === 1
                spacing: 24
                BuyukKart {
                    id: gor1
                    objectName: "gorunum_solid"
                    width: (icerik.width - 24) / 2; onizlemeYukseklik: 290
                    baslik: "Solid"; metin: "Opak yüzeyler. Her bilgisayarda hızlı."
                    secili: m.gorunum === "solid"
                    onSecildi: m.gorunumSec("solid")
                    onizleme: Component { MasaustuOnizleme { resim: m.buyukResim(m.tema); gorunum: "solid"; cubuk: m.cubuk } }
                }
                BuyukKart {
                    objectName: "gorunum_glass"
                    enabled: m.glassOk
                    width: (icerik.width - 24) / 2; onizlemeYukseklik: 290
                    baslik: "Glass"
                    metin: m.glassOk ? "Saydam yüzeyler. Ekran kartı hızlandırması ister." : "Kullanılamaz: " + m.glassNeden + "."
                    secili: m.gorunum === "glass"
                    onSecildi: m.gorunumSec("glass")
                    onizleme: Component { MasaustuOnizleme { resim: m.buyukResim(m.tema); gorunum: "glass"; cubuk: m.cubuk } }
                }
            }
            // Step 3: taskbar
            Row {
                visible: win.adim === 2
                spacing: 24
                BuyukKart {
                    id: cub1
                    objectName: "cubuk_sol"
                    width: (icerik.width - 24) / 2; onizlemeYukseklik: 290
                    baslik: "Solda"; metin: "Başlat düğmesi ve simgeler sol köşede"
                    secili: m.cubuk === "sol"
                    onSecildi: m.cubuk = "sol"
                    onizleme: Component { MasaustuOnizleme { resim: m.buyukResim(m.tema); gorunum: m.gorunum; cubuk: "sol"; pencere: false } }
                }
                BuyukKart {
                    objectName: "cubuk_orta"
                    width: (icerik.width - 24) / 2; onizlemeYukseklik: 290
                    baslik: "Ortada"; metin: "Başlat düğmesi ve simgeler çubuğun ortasında"
                    secili: m.cubuk === "orta"
                    onSecildi: m.cubuk = "orta"
                    onizleme: Component { MasaustuOnizleme { resim: m.buyukResim(m.tema); gorunum: m.gorunum; cubuk: "orta"; pencere: false } }
                }
            }
            // Step 4: summary with the live preview
            Row {
                visible: win.adim === 3
                spacing: 28
                Rectangle {
                    width: 520; height: 293
                    color: "#29404f"; radius: 12
                    MasaustuOnizleme {
                        anchors.fill: parent; anchors.margins: 2
                        resim: m.buyukResim(m.tema); gorunum: m.gorunum; cubuk: m.cubuk
                    }
                }
                Column {
                    width: icerik.width - 520 - 28
                    spacing: 14
                    Repeater {
                        model: [
                            { ad: "Tema", deger: m.temaAdi[m.tema], adim: 0, nesne: "degistir_tema" },
                            { ad: "Görünüm", deger: m.gorunumAdi[m.gorunum], adim: 1, nesne: "degistir_gorunum" },
                            { ad: "Görev çubuğu", deger: m.cubukAdi[m.cubuk], adim: 2, nesne: "degistir_cubuk" }
                        ]
                        Rectangle {
                            id: ozet
                            required property var modelData
                            width: parent.width; height: 76; radius: 12
                            color: "#16232d"; border.color: "#29404f"; border.width: 1
                            Column {
                                anchors.left: parent.left; anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text { text: ozet.modelData.ad; color: "#a9bac6"; font.family: "Inter Variable"; font.pixelSize: 13 }
                                Text { text: ozet.modelData.deger; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 17; font.weight: Font.DemiBold }
                            }
                            Dugme {
                                objectName: ozet.modelData.nesne
                                anchors.right: parent.right; anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 104; implicitHeight: 38
                                label: "Değiştir"
                                onActivated: win.git(ozet.modelData.adim)
                            }
                        }
                    }
                }
            }
        }

        Rectangle { id: cizgi; anchors.bottom: alt.top; anchors.bottomMargin: 20; width: parent.width; height: 1; color: "#29404f" }
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
            Text {
                objectName: "mesaj"
                anchors.centerIn: parent
                width: 320
                horizontalAlignment: Text.AlignHCenter
                text: m.mesaj
                color: "#ffc45d"
                font.family: "Inter Variable"; font.pixelSize: 13
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Row {
                anchors.right: parent.right
                spacing: 12
                Dugme {
                    objectName: "geri"
                    visible: win.adim > 0
                    label: "Geri"
                    enabled: !m.mesgul
                    onActivated: win.git(win.adim - 1)
                }
                Dugme {
                    objectName: "ileri"
                    visible: win.adim < 3
                    filled: true
                    label: "İleri"
                    onActivated: win.git(win.adim + 1)
                }
                Dugme {
                    id: uygulaBtn
                    objectName: "uygula"
                    visible: win.adim === 3
                    filled: true
                    label: "Uygula ve başla"
                    enabled: !m.mesgul
                    onActivated: m.uygula()
                }
            }
        }
    }
}
