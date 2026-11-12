// alpbahOS Hoş Geldin window (WELCOME-01, D121; master task D3). Fixed 960x720, surface #11171c,
// padding 36 px top/bottom and 44 px sides. Values from profiles/desktop/tokens.json. All text Turkish (D120).
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 960; height: 720
    minimumWidth: 960; maximumWidth: 960
    minimumHeight: 720; maximumHeight: 720
    visible: true
    title: "Hoş Geldin"
    color: "#11171c"

    required property var backend
    property var st: backend.durum()
    property string tema: st.tema || "alpbahos"
    property string gorunum: (st.gorunum === "glass" && st.glass_kullanilabilir) ? "glass" : "solid"
    property string cubuk: st.cubuk || "sol"
    property bool glassOk: st.glass_kullanilabilir === true
    property string glassWhy: st.glass_neden || ""
    property string message: ""
    property bool busy: false

    function previewOf(key) {
        return st.onizleme && st.onizleme[key] ? "file://" + st.onizleme[key] : "";
    }
    function apply() {
        busy = true;
        message = "Uygulanıyor…";
        var r = backend.uygula(tema, gorunum, cubuk);
        busy = false;
        if (r.kod === 0) { Qt.quit(); }
        else { message = r.hata !== "" ? r.hata : "Seçimler uygulanamadı."; }
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: 36; anchors.bottomMargin: 36
        anchors.leftMargin: 44; anchors.rightMargin: 44

        // Header: mark 96 px wide, title with "OS" in cyan, subtitle.
        Row {
            id: header
            spacing: 22
            Image {
                source: "mark.png"
                width: 96
                height: Math.round(96 * sourceSize.height / sourceSize.width)
                smooth: true; mipmap: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    textFormat: Text.StyledText
                    text: "alpbah<font color=\"#00aeef\">OS</font>'a hoş geldin"
                    color: "#f4f8fb"
                    font.family: "Inter Variable"; font.pixelSize: 30; font.bold: true
                }
                Text {
                    width: 650
                    text: "Masaüstünü kendine göre ayarla. Hepsini sonra Sistem Ayarları'ndan değiştirebilirsin."
                    color: "#a9bac6"
                    font.family: "Inter Variable"; font.pixelSize: 15
                    wrapMode: Text.WordWrap
                }
            }
        }

        Column {
            id: rows
            anchors.top: header.bottom; anchors.topMargin: 44
            anchors.left: parent.left; anchors.right: parent.right
            spacing: 30

            // ---- Tema
            Row {
                width: parent.width; spacing: 16
                Column {
                    width: 150; spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Tema"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { width: 150; text: "Duvar kağıdı ve kilit ekranı"; color: "#a9bac6"; font.family: "Inter Variable"; font.pixelSize: 13; wrapMode: Text.WordWrap }
                }
                OptionCard {
                    id: firstCard
                    width: (parent.width - 150 - 32) / 2
                    focus: true
                    title: "alpbahOS"; text: "Dağ ve terminal, lacivert tonlar"
                    selected: win.tema === "alpbahos"
                    onChosen: win.tema = "alpbahos"
                    preview: Component { Image { source: win.previewOf("alpbahos"); fillMode: Image.PreserveAspectCrop; clip: true; sourceSize.width: 168 } }
                }
                OptionCard {
                    width: (parent.width - 150 - 32) / 2
                    title: "Atatürk"; text: "Atatürk duvar kağıdı ve kilit ekranı"
                    selected: win.tema === "ataturk"
                    onChosen: win.tema = "ataturk"
                    preview: Component { Image { source: win.previewOf("ataturk"); fillMode: Image.PreserveAspectCrop; clip: true; sourceSize.width: 168 } }
                }
            }

            // ---- Görünüm
            Row {
                width: parent.width; spacing: 16
                Column {
                    width: 150; spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Görünüm"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { width: 150; text: "Pencere ve panel yüzeyleri"; color: "#a9bac6"; font.family: "Inter Variable"; font.pixelSize: 13; wrapMode: Text.WordWrap }
                }
                OptionCard {
                    width: (parent.width - 150 - 32) / 2
                    title: "Solid"; text: "Opak yüzeyler. Eski bilgisayarlarda hızlı."
                    selected: win.gorunum === "solid"
                    onChosen: win.gorunum = "solid"
                    preview: Component {
                        Rectangle {
                            color: "#0b1014"; border.color: "#29404f"; border.width: 1
                            Rectangle { x: 10; y: 8; width: 54; height: 30; color: "#16232d"; border.color: "#29404f" }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 10; color: "#16232d" }
                        }
                    }
                }
                OptionCard {
                    width: (parent.width - 150 - 32) / 2
                    enabled: win.glassOk
                    title: "Glass"
                    text: win.glassOk ? "Saydam ve bulanık. Ekran kartı hızlandırması ister."
                                      : "Kullanılamaz: " + win.glassWhy + "."
                    selected: win.gorunum === "glass"
                    onChosen: win.gorunum = "glass"
                    preview: Component {
                        Rectangle {
                            gradient: Gradient { GradientStop { position: 0; color: "#1e5a8a" } GradientStop { position: 1; color: "#062746" } }
                            border.color: "#29404f"; border.width: 1
                            Rectangle { x: 10; y: 8; width: 54; height: 30; color: "#6654d6ff"; border.color: "#9954d6ff" }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 10; color: "#8016232d" }
                        }
                    }
                }
            }

            // ---- Görev çubuğu
            Row {
                width: parent.width; spacing: 16
                Column {
                    width: 150; spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Görev çubuğu"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { width: 150; text: "Simgelerin yeri"; color: "#a9bac6"; font.family: "Inter Variable"; font.pixelSize: 13; wrapMode: Text.WordWrap }
                }
                OptionCard {
                    width: (parent.width - 150 - 32) / 2
                    title: "Solda"; text: "Başlat düğmesi sol köşede"
                    selected: win.cubuk === "sol"
                    onChosen: win.cubuk = "sol"
                    preview: Component { TaskbarPreview { centered: false } }
                }
                OptionCard {
                    width: (parent.width - 150 - 32) / 2
                    title: "Ortada"; text: "Simgeler çubuğun ortasında"
                    selected: win.cubuk === "orta"
                    onChosen: win.cubuk = "orta"
                    preview: Component { TaskbarPreview { centered: true } }
                }
            }
        }

        // Footer above a 1 px line: "Şimdilik geç" (outline, left), "Uygula ve başla" (cyan fill, right).
        Rectangle { id: line; anchors.bottom: footer.top; anchors.bottomMargin: 20; width: parent.width; height: 1; color: "#29404f" }
        Item {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width; height: 44
            FooterButton {
                anchors.left: parent.left
                label: "Şimdilik geç"; filled: false
                enabled: !win.busy
                onActivated: { backend.gec(); Qt.quit(); }
            }
            Text {
                anchors.centerIn: parent
                width: 380
                horizontalAlignment: Text.AlignHCenter
                text: win.message
                color: "#ffc45d"
                font.family: "Inter Variable"; font.pixelSize: 13
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            FooterButton {
                anchors.right: parent.right
                label: "Uygula ve başla"; filled: true
                enabled: !win.busy
                onActivated: win.apply()
            }
        }
    }

    component TaskbarPreview: Rectangle {
        property bool centered: false
        color: "#0b1014"; border.color: "#29404f"; border.width: 1
        Rectangle {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 1
            x: 1; width: parent.width - 2; height: 14; color: "#16232d"
            Row {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                x: parent.parent.centered ? (parent.width - 3 * 8 - 2 * 4) / 2 : 4
                Repeater { model: 3; Rectangle { width: 8; height: 8; radius: 2; color: index === 0 ? "#00aeef" : "#54d6ff" } }
            }
        }
    }

    component FooterButton: FocusScope {
        id: fb
        property string label
        property bool filled: false
        signal activated()
        width: Math.max(150, txt.implicitWidth + 44); height: 44
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onSpacePressed: if (enabled) activated()
        Keys.onReturnPressed: if (enabled) activated()
        Keys.onEnterPressed: if (enabled) activated()
        Rectangle {
            anchors.fill: parent; anchors.margins: -4; radius: 13
            color: "transparent"; border.width: 2; border.color: "#ffc45d"
            visible: fb.activeFocus
        }
        Rectangle {
            anchors.fill: parent; radius: 10
            color: fb.filled ? "#00aeef" : "transparent"
            border.width: fb.filled ? 0 : 1
            border.color: "#29404f"
            opacity: fb.enabled ? 1 : 0.6
        }
        Text {
            id: txt
            anchors.centerIn: parent
            text: fb.label
            color: fb.filled ? "#0b1014" : "#d4e0e8"
            font.family: "Inter Variable"; font.pixelSize: 15; font.weight: Font.DemiBold
        }
        MouseArea { anchors.fill: parent; enabled: fb.enabled; cursorShape: Qt.PointingHandCursor; onClicked: { fb.forceActiveFocus(); fb.activated(); } }
    }
}
