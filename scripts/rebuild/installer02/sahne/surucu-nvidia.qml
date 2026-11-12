// Drivers page picture for "NVIDIA sürücüsü" (INSTALLER-02): what happens after the install (D165, D166). 1200x640.
// No NVIDIA logo (trademark); plain text only.
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
            width: 72; height: 72; radius: 18
            color: "#16232d"; border.color: "#76b900"; border.width: 3
            Image {
                anchors.centerIn: parent; width: 46; height: 46
                source: ikon + "devices/64/video-display.svg"
                sourceSize.width: 92; sourceSize.height: 92
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text { text: "NVIDIA sürücüsü"; color: "#f4f8fb"; font.family: "Inter Variable"; font.pixelSize: 44; font.bold: true }
            Text { text: "RTX 20 serisi ve sonrası · 3D, Vulkan, CUDA, video hızlandırma"; color: "#a9bac6"; font.family: "Inter Variable"; font.pixelSize: 24 }
        }
    }
    Row {
        x: 64; y: 230
        spacing: 0
        Repeater {
            model: [
                { n: "1", ad: "Kurulum biter", alt: "Bu ekrandaki seçim kaydedilir" },
                { n: "2", ad: "İlk açılış", alt: "İnternet varsa NVIDIA'dan indirilir" },
                { n: "3", ad: "Derlenir", alt: "Bilgisayarında, birkaç dakika" },
                { n: "4", ad: "Yeniden başlat", alt: "Bildirim seni uyarır" }
            ]
            Item {
                id: adim
                required property var modelData
                required property int index
                width: 268; height: 250
                Rectangle {
                    visible: adim.index < 3
                    x: 64; y: 31; width: 204; height: 3
                    color: "#29404f"
                }
                Rectangle {
                    width: 64; height: 64; radius: 32
                    color: adim.index === 3 ? "#f5a623" : "#00aeef"
                    Text { anchors.centerIn: parent; text: adim.modelData.n; color: "#0b1014"; font.family: "Inter Variable"; font.pixelSize: 28; font.bold: true }
                }
                Text {
                    y: 88; width: 240
                    text: adim.modelData.ad; color: "#f4f8fb"
                    font.family: "Inter Variable"; font.pixelSize: 25; font.weight: Font.DemiBold
                }
                Text {
                    y: 124; width: 230
                    text: adim.modelData.alt; color: "#a9bac6"
                    font.family: "Inter Variable"; font.pixelSize: 19
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
    Text {
        x: 64; y: 560; width: 1072
        text: "NVIDIA kartı yoksa hiçbir şey kurulmaz. Sonra da kurabilirsin: sudo alp install nvidia"
        color: "#8ea2af"; font.family: "Inter Variable"; font.pixelSize: 20
    }
}
