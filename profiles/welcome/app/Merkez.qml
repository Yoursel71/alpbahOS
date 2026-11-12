// Hoş Geldin design 4 "Başlangıç merkezi" (WELCOME-02): a greeting with the user's name over the chosen wallpaper,
// the three desktop choices as segmented bars and six quick-start tiles that open the matching System Settings page
// (network, printers, display, sound, shortcuts) or Info Center. The tiles keep this window open. 960x720.
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
    color: "#11171c"

    Mantik { id: m; backend: win.backend }
    property string ad: win.backend.kullanici()
    readonly property string ikonlar: "file:///usr/share/icons/breeze-dark/"

    // Greeting over the wallpaper
    Item {
        id: ust
        width: parent.width; height: 210
        clip: true
        Image {
            anchors.fill: parent
            source: m.buyukResim(m.tema)
            fillMode: Image.PreserveAspectCrop
            verticalAlignment: Image.AlignTop      // the portrait's head and the empty sky stay in the band
            asynchronous: true
            sourceSize.width: 960
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#f20b1014" }
                GradientStop { position: 0.55; color: "#b30b1014" }
                GradientStop { position: 1.0; color: "#260b1014" }
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#29404f" }
        Column {
            x: 44; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Image {
                source: "mark.png"
                width: 48; height: Math.round(48 * sourceSize.height / Math.max(1, sourceSize.width))
                smooth: true; mipmap: true
            }
            Text {
                text: win.ad !== "" ? "Merhaba, " + win.ad + "!" : "Merhaba!"
                color: "#f4f8fb"
                font.family: "Inter Variable"; font.pixelSize: 32; font.bold: true
            }
            Text {
                textFormat: Text.StyledText
                text: "alpbah<font color=\"#00aeef\">OS</font> kullanıma hazır. Masaüstünü seç, ihtiyacın olanı buradan aç."
                color: "#d4e0e8"
                font.family: "Inter Variable"; font.pixelSize: 15
            }
        }
    }

    Item {
        anchors.top: ust.bottom; anchors.topMargin: 24
        anchors.bottom: parent.bottom; anchors.bottomMargin: 30
        anchors.left: parent.left; anchors.leftMargin: 44
        anchors.right: parent.right; anchors.rightMargin: 44

        Text {
            id: b1
            text: "Masaüstün"
            color: "#f4f8fb"
            font.family: "Inter Variable"; font.pixelSize: 17; font.weight: Font.DemiBold
        }
        Row {
            id: secimler
            anchors.top: b1.bottom; anchors.topMargin: 10
            width: parent.width
            spacing: 18
            Repeater {
                model: 3
                Column {
                    id: grup
                    required property int index
                    width: (secimler.width - 2 * secimler.spacing) / 3
                    spacing: 6
                    Text {
                        text: ["Tema", "Görünüm", "Görev çubuğu"][grup.index]
                        color: "#a9bac6"
                        font.family: "Inter Variable"; font.pixelSize: 13
                    }
                    Segment {
                        width: parent.width
                        onEk: ["tema", "gorunum", "cubuk"][grup.index]
                        secilen: [m.tema, m.gorunum, m.cubuk][grup.index]
                        secenekler: [
                            [{ deger: "alpbahos", baslik: "alpbahOS" }, { deger: "ataturk", baslik: "Atatürk" }],
                            [{ deger: "solid", baslik: "Solid" }, { deger: "glass", baslik: "Glass", etkin: m.glassOk }],
                            [{ deger: "sol", baslik: "Solda" }, { deger: "orta", baslik: "Ortada" }]
                        ][grup.index]
                        onSecildi: (d) => {
                            if (grup.index === 0) m.tema = d;
                            else if (grup.index === 1) m.gorunumSec(d);
                            else m.cubuk = d;
                        }
                    }
                }
            }
        }

        Text {
            id: b2
            anchors.top: secimler.bottom; anchors.topMargin: 24
            text: "Hızlı başlangıç"
            color: "#f4f8fb"
            font.family: "Inter Variable"; font.pixelSize: 17; font.weight: Font.DemiBold
        }
        Grid {
            id: kutular
            anchors.top: b2.bottom; anchors.topMargin: 10
            width: parent.width
            columns: 3
            spacing: 14
            Repeater {
                model: [
                    { id: "ag", baslik: "İnternet ve Wi‑Fi", metin: "Ağa bağlan", ikon: "preferences/32/preferences-system-network.svg" },
                    { id: "yazici", baslik: "Yazıcı", metin: "Yazıcı ekle veya ağda bul", ikon: "preferences/32/preferences-devices-printer.svg" },
                    { id: "ekran", baslik: "Ekran", metin: "Çözünürlük ve ölçek", ikon: "preferences/32/preferences-desktop-display.svg" },
                    { id: "ses", baslik: "Ses", metin: "Hoparlör ve mikrofon", ikon: "preferences/32/preferences-desktop-sound.svg" },
                    { id: "kisayol", baslik: "Kısayollar", metin: "Win+E, Alt+Tab ve diğerleri", ikon: "devices/64/input-keyboard.svg" },
                    { id: "bilgi", baslik: "Bu bilgisayar", metin: "Donanım ve sistem bilgisi", ikon: "actions/32/help-about.svg" }
                ]
                FocusScope {
                    id: kutu
                    required property var modelData
                    objectName: "ac_" + modelData.id
                    width: (kutular.width - 2 * kutular.spacing) / 3
                    height: 70
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.baslik + ". " + modelData.metin
                    Keys.onSpacePressed: m.ac(modelData.id)
                    Keys.onReturnPressed: m.ac(modelData.id)
                    Keys.onEnterPressed: m.ac(modelData.id)
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -4; radius: 15
                        color: "transparent"; border.width: 2; border.color: "#ffc45d"
                        visible: kutu.activeFocus
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 12
                        color: tma.containsMouse ? "#1d2c38" : "#16232d"
                        border.width: 1; border.color: "#29404f"
                        Image {
                            id: ik
                            x: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 34; height: 34
                            source: win.ikonlar + kutu.modelData.ikon
                            sourceSize.width: 68; sourceSize.height: 68
                        }
                        Column {
                            anchors.left: ik.right; anchors.leftMargin: 14
                            anchors.right: ok.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text { width: parent.width; text: kutu.modelData.baslik; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { width: parent.width; text: kutu.modelData.metin; color: "#a9bac6"; font.family: "Inter Variable"; font.pixelSize: 12; elide: Text.ElideRight }
                        }
                        Text {
                            id: ok
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"; color: "#54d6ff"
                            font.pixelSize: 22
                        }
                    }
                    MouseArea {
                        id: tma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { kutu.forceActiveFocus(); m.ac(kutu.modelData.id); }
                    }
                }
            }
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
