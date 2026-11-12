/* alpbahOS installer slideshow (Calamares slideshow API 2; INSTALLER-02). Shown while the system is copied to the
   disk. The background fills the whole slideshow area (Calamares places each Slide in the middle 90 % x 70 %, so
   anything drawn only inside a slide left a white frame before). Six slides, 11 s each, no running animations:
   the copy runs on 4 GiB machines too. Facts only: every app, command and shortcut named here is in the image
   (shortcuts: Plasma's own defaults, profiles/shortcuts/shortcuts.json). */
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation
    textColor: "#d4e0e8"
    fontFamily: "Inter Variable"

    readonly property string ikon: "file:///usr/share/icons/"

    Timer {
        id: zamanlayici
        interval: 11000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }
    function onActivate() { presentation.currentSlide = 0; }
    function onLeave() { }

    // Full-area background and the brand line; under the slides (they are drawn later, on top).
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0d2338" }
            GradientStop { position: 1.0; color: "#0b1014" }
        }
        Rectangle {
            x: parent.width * 0.06; y: parent.height - 34
            width: parent.width * 0.16; height: 2; color: "#00aeef"
            Rectangle { width: parent.width * 0.22; height: 2; color: "#f5a623" }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: parent.width * 0.06
            y: parent.height - 39
            spacing: 8
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    width: index === presentation.currentSlide ? 20 : 8; height: 8; radius: 4
                    color: index === presentation.currentSlide ? "#00aeef" : "#29404f"
                }
            }
        }
    }

    component Baslik: Text {
        width: parent.width
        color: "#f4f8fb"
        font.family: "Inter Variable"; font.bold: true
        font.pixelSize: Math.max(20, presentation.height * 0.062)
        wrapMode: Text.WordWrap
    }
    component Metin: Text {
        width: parent.width
        color: "#a9bac6"
        font.family: "Inter Variable"
        font.pixelSize: Math.max(13, presentation.height * 0.034)
        wrapMode: Text.WordWrap
        lineHeight: 1.15
    }
    component Etiket: Text {
        color: "#54d6ff"
        font.family: "Inter Variable"; font.weight: Font.DemiBold
        font.pixelSize: Math.max(11, presentation.height * 0.026)
        font.letterSpacing: 1.5
    }
    component Uygulama: Column {
        property string ad
        property string resim
        width: presentation.width * 0.105
        spacing: 6
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(56, presentation.height * 0.11); height: width
            source: parent.resim
            sourceSize.width: 96; sourceSize.height: 96
            smooth: true
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: parent.ad
            color: "#d4e0e8"
            font.family: "Inter Variable"
            font.pixelSize: Math.max(11, presentation.height * 0.027)
            elide: Text.ElideRight
        }
    }
    component Tus: Row {
        property string tus
        property string ne
        spacing: 14
        Rectangle {
            width: Math.max(96, tusYazi.implicitWidth + 22); height: tusYazi.implicitHeight + 12
            radius: 7
            color: "#16232d"; border.color: "#29404f"; border.width: 1
            Text {
                id: tusYazi
                anchors.centerIn: parent
                text: parent.parent.tus
                color: "#f4f8fb"
                font.family: "JetBrains Mono"
                font.pixelSize: Math.max(12, presentation.height * 0.03)
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.ne
            color: "#d4e0e8"
            font.family: "Inter Variable"
            font.pixelSize: Math.max(13, presentation.height * 0.032)
        }
    }

    Slide {
        Column {
            anchors.fill: parent
            spacing: presentation.height * 0.03
            Image {
                source: "logo.png"
                height: presentation.height * 0.2
                fillMode: Image.PreserveAspectFit
                sourceSize.height: 256
                smooth: true; mipmap: true
            }
            Baslik { text: "alpbahOS diskine kuruluyor" }
            Metin {
                text: "Bu birkaç dakika sürer; bilgisayarın hızına göre değişir. Bu sırada bilgisayarı kapatma. " +
                      "Kurulum bitince yeniden başlatıp kendi hesabınla giriş yapacaksın."
            }
        }
    }

    Slide {
        Column {
            anchors.fill: parent
            spacing: presentation.height * 0.035
            Etiket { text: "HAZIR GELİR" }
            Baslik { text: "Günlük işler için uygulamalar yüklü" }
            Grid {
                columns: 7
                spacing: presentation.width * 0.012
                Uygulama { ad: "Firefox"; resim: "file:///usr/share/pixmaps/firefox.png" }
                Uygulama { ad: "LibreOffice"; resim: presentation.ikon + "hicolor/48x48/apps/libreoffice-main.png" }
                Uygulama { ad: "VLC"; resim: presentation.ikon + "hicolor/48x48/apps/vlc.png" }
                Uygulama { ad: "Dolphin"; resim: presentation.ikon + "hicolor/scalable/apps/org.kde.dolphin.svg" }
                Uygulama { ad: "Okular"; resim: presentation.ikon + "breeze-dark/apps/48/org.kde.okular.svg" }
                Uygulama { ad: "Gwenview"; resim: presentation.ikon + "breeze-dark/apps/48/org.kde.gwenview.svg" }
                Uygulama { ad: "Kate"; resim: presentation.ikon + "hicolor/48x48/apps/kate.png" }
            }
            Metin {
                text: "Word ve Excel dosyalarını LibreOffice açar; PDF'ler Okular'da, fotoğraflar Gwenview'da, " +
                      "videolar VLC'de açılır."
            }
        }
    }

    Slide {
        Column {
            anchors.fill: parent
            spacing: presentation.height * 0.035
            Etiket { text: "YENİ UYGULAMA" }
            Baslik { text: "Bir uygulama mı lazım? alp bulur" }
            Rectangle {
                width: parent.width; height: terminal.implicitHeight + 28
                radius: 10
                color: "#0b1014"; border.color: "#29404f"; border.width: 1
                Column {
                    id: terminal
                    x: 18; y: 14
                    spacing: 6
                    Text { text: "<font color=\"#54d6ff\">$</font> alp install gimp"; textFormat: Text.StyledText; color: "#f4f8fb"; font.family: "JetBrains Mono"; font.pixelSize: Math.max(12, presentation.height * 0.032) }
                    Text { text: "GIMP (org.gimp.GIMP) Flathub'dan kurulsun mu? [E/h] e"; color: "#d4e0e8"; font.family: "JetBrains Mono"; font.pixelSize: Math.max(12, presentation.height * 0.032) }
                    Text { text: "Kuruldu: GIMP (org.gimp.GIMP), Flathub."; color: "#35d07f"; font.family: "JetBrains Mono"; font.pixelSize: Math.max(12, presentation.height * 0.032) }
                }
            }
            Metin {
                text: "alp önce alpbahOS paketlerine, sonra Flathub uygulamalarına, en son Debian kutusuna bakar. " +
                      "\"apt install\" yazarsan da doğru alp komutunu gösterir."
            }
        }
    }

    Slide {
        Column {
            anchors.fill: parent
            spacing: presentation.height * 0.03
            Etiket { text: "WINDOWS'TAN GELİYORSAN" }
            Baslik { text: "Alıştığın tuşlar burada da çalışır" }
            Column {
                spacing: presentation.height * 0.022
                Tus { tus: "Win"; ne: "Başlat menüsü" }
                Tus { tus: "Win + E"; ne: "Dosyalar (Dolphin)" }
                Tus { tus: "Win + D"; ne: "Masaüstünü göster" }
                Tus { tus: "Alt + Tab"; ne: "Pencereler arasında geç" }
                Tus { tus: "Alt + F4"; ne: "Pencereyi kapat" }
            }
        }
    }

    Slide {
        Column {
            anchors.fill: parent
            spacing: presentation.height * 0.035
            Etiket { text: "SÜRÜCÜLER" }
            Baslik { text: "Donanımın kendiliğinden tanınır" }
            Metin {
                text: "AMD ve Intel ekran kartı, ses, Wi‑Fi, Bluetooth, dokunmatik ekran, kamera ve yazıcı sürücüleri " +
                      "alpbahOS'ta zaten var. Ağdaki yazıcılar kendiliğinden bulunur."
            }
            Metin {
                text: "NVIDIA sürücüsünü seçtiysen ilk açılışta internetten kurulur; bitince yeniden başlatman istenir."
                color: "#d4e0e8"
            }
        }
    }

    Slide {
        Column {
            anchors.fill: parent
            spacing: presentation.height * 0.035
            Etiket { text: "İLK GİRİŞ" }
            Baslik { text: "Hoş Geldin penceresi seni bekliyor" }
            Metin {
                text: "İlk girişte temayı (alpbahOS ya da Atatürk), pencere görünümünü ve görev çubuğundaki simgelerin " +
                      "yerini seçersin. Hepsini sonra Sistem Ayarları'ndan değiştirebilirsin."
            }
        }
    }
}
