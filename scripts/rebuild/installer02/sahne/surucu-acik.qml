// Drivers page picture for "Ek sürücü yok" (INSTALLER-02): everything already in the image. 1200x640.
import QtQuick
import QtQuick.Window

Window {
    width: 1200; height: 640
    flags: Qt.FramelessWindowHint
    x: 0; y: 0
    visible: true
    color: "#0b1014"
    readonly property string ikon: "file:///usr/share/icons/breeze-dark/"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0d2338" }
            GradientStop { position: 1.0; color: "#0b1014" }
        }
    }
    Row {
        x: 64; y: 56
        spacing: 22
        Rectangle {
            width: 72; height: 72; radius: 36
            color: "#0f3d2b"; border.color: "#35d07f"; border.width: 3
            Text { anchors.centerIn: parent; text: "✓"; color: "#35d07f"; font.pixelSize: 40; font.bold: true }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text { text: "Hepsi hazır"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 44; font.bold: true }
            Text { text: "Açık kaynak sürücüler alpbahOS'ta yüklü. İnternet gerekmez."; color: "#a9bac6"; font.family: "Inter Variable"; font.pixelSize: 24 }
        }
    }
    Grid {
        x: 64; y: 210
        columns: 4
        columnSpacing: 20; rowSpacing: 20
        Repeater {
            model: [
                { ad: "Ekran kartı", alt: "AMD · Intel · NVIDIA (nouveau)", i: "devices/64/video-display.svg" },
                { ad: "Ses", alt: "Hoparlör, mikrofon, HDMI", i: "devices/64/audio-card.svg" },
                { ad: "Wi‑Fi", alt: "Kablosuz ağ", i: "devices/22/network-wireless.svg" },
                { ad: "Bluetooth", alt: "Kulaklık, fare", i: "preferences/32/preferences-system-bluetooth.svg" },
                { ad: "Dokunmatik", alt: "Ekran ve kalem", i: "devices/64/input-touchscreen.svg" },
                { ad: "Kamera", alt: "Dahili ve USB", i: "devices/64/camera-web.svg" },
                { ad: "Yazıcı", alt: "USB ve ağ yazıcıları", i: "devices/64/printer.svg" },
                { ad: "USB ve diskler", alt: "Bellek, harici disk", i: "devices/64/drive-removable-media-usb.svg" }
            ]
            Rectangle {
                required property var modelData
                width: 253; height: 150; radius: 16
                color: "#16232d"; border.color: "#29404f"; border.width: 2
                Image {
                    x: 22; y: 22; width: 52; height: 52
                    source: ikon + parent.modelData.i
                    sourceSize.width: 104; sourceSize.height: 104
                }
                Text {
                    x: 22; y: 88; width: parent.width - 44
                    text: parent.modelData.ad; color: "#f4f8fb"
                    font.family: "Inter Variable"; font.pixelSize: 23; font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    x: 22; y: 118; width: parent.width - 44
                    text: parent.modelData.alt; color: "#a9bac6"
                    font.family: "Inter Variable"; font.pixelSize: 17
                    elide: Text.ElideRight
                }
            }
        }
    }
}
