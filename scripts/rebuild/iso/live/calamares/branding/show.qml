/* AlpbahOS BETA installer slideshow (Calamares slideshow API 2). */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1d2a3a"
            Text {
                anchors.centerIn: parent
                color: "#ffffff"
                font.pixelSize: 28
                text: "AlpbahOS 13.1 BETA\nInstalling the system from the live image."
            }
        }
    }
}
