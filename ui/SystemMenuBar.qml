// Global YUNSH system menu bar. It remains above apps and the world layer.

import QtQuick 2.15

Rectangle {
    id: menuBar
    height: 70
    color: "transparent"
    border.width: 0

    property bool orbitConfigured: false
    property bool recordingActive: false
    signal openSystemMenu()
    signal openWorld()
    signal openOrbit()

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 112
        height: 42
        radius: 21
        color: leftMouse.pressed ? "#DDF8FF" : Qt.rgba(1, 1, 1, 0.91)
        border.width: 1
        border.color: "#FFFFFF"
        scale: leftMouse.pressed ? 0.96 : (leftMouse.containsMouse ? 1.04 : 1)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 19
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.16)
        }

        Row {
            anchors.centerIn: parent
            spacing: 8
            Image {
                source: "/usr/share/yunsh/logo/logo-32.png"
                width: 25; height: 25
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "YUNSH"
                color: "#121820"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 7; height: 7; radius: 4
                color: "#E43A45"
                visible: menuBar.recordingActive
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: leftMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: menuBar.openSystemMenu()
        }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: worldPortal
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 152
        height: 50
        radius: 25
        color: worldMouse.pressed ? "#DDF8FF" : Qt.rgba(1, 1, 1, 0.92)
        border.width: 1
        border.color: "#FFFFFF"
        scale: worldMouse.pressed ? 0.96 : (worldMouse.containsMouse ? 1.04 : 1)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 23
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.18)
        }

        Column {
            anchors.centerIn: parent
            spacing: -1
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Image {
                    source: "/usr/share/yunsh/logo/logo-32.png"
                    width: 20; height: 20
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    text: "YUNSH"
                    color: "#111820"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.4
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "METAVERSE"
                color: "#00A9CC"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 2.2
            }
        }
        MouseArea {
            id: worldMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: menuBar.openWorld()
        }
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 50
        height: 50
        radius: 25
        color: orbitMouse.pressed ? "#DDF8FF" : Qt.rgba(1, 1, 1, 0.91)
        border.width: 1
        border.color: "#FFFFFF"
        scale: orbitMouse.pressed ? 0.96 : (orbitMouse.containsMouse ? 1.04 : 1)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 23
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.16)
        }

        Item {
            anchors.centerIn: parent
            width: 31
            height: 31
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#101010"
            }
            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                color: "#F7F9FA"
            }
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 10
                color: "#F7F9FA"
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 2
            anchors.bottomMargin: 2
            width: 9
            height: 9
            radius: 5
            color: orbitConfigured ? "#34C759" : "#FF9F0A"
            border.width: 1
            border.color: "#FFFFFF"
        }
        MouseArea {
            id: orbitMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: menuBar.openOrbit()
        }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    }
}
