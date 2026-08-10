// Minimal independent recovery surface for a failed YUNSH shell launch.
// It intentionally uses only QtQuick and Controls, which are validated by
// yunsh-firstboot before the desktop service is allowed to start.
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

ApplicationWindow {
    visible: true
    visibility: Window.FullScreen
    width: 1920
    height: 1080
    color: "#000000"
    title: "YUNSH OS Recovery"

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 920)
        height: 460
        radius: 32
        color: Qt.rgba(248/255, 252/255, 255/255, 0.94)
        border.color: "#FFFFFF"
        border.width: 2

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 29
            color: Qt.rgba(205/255, 239/255, 255/255, 0.10)
            border.width: 1
            border.color: "#BDEFFF"
        }

        Column {
            anchors.fill: parent
            anchors.margins: 52
            spacing: 18

            Text {
                text: "YUNSH OS needs attention"
                color: "#101820"
                font.pixelSize: 42
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: "The spatial desktop did not start. Your system and files have not been reset."
                color: "#4D5B66"
                wrapMode: Text.WordWrap
                font.pixelSize: 24
            }
            Rectangle { width: parent.width; height: 1; color: "#C9D7DE" }
            Text {
                width: parent.width
                text: "To diagnose: connect a USB keyboard, press Ctrl + Alt + F2, then run:\n\nsudo tail -n 100 /var/log/yunsh-ui.log\nsudo tail -n 100 /var/log/yunsh-weston.log"
                color: "#17242C"
                wrapMode: Text.WordWrap
                font.pixelSize: 22
                lineHeight: 1.35
            }
            Item { height: 1; width: 1 }
            Text {
                text: "Restarting the device will try the desktop again."
                color: "#007E99"
                font.pixelSize: 21
            }
        }
    }
}
