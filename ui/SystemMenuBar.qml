// Global YUNSH system menu bar. It remains above apps and the world layer.

import QtQuick 2.15

Rectangle {
    id: menuBar
    height: 62
    color: Qt.rgba(248/255, 253/255, 1, 0.94)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.92)

    property bool orbitConfigured: false
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
        color: leftMouse.pressed ? "#E4F9FF" : "transparent"

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
        }

        MouseArea {
            id: leftMouse
            anchors.fill: parent
            onClicked: menuBar.openSystemMenu()
        }
    }

    Rectangle {
        id: worldPortal
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 152
        height: 50
        radius: 25
        color: worldMouse.pressed ? "#E4F9FF" : "transparent"
        scale: worldMouse.pressed ? 0.97 : 1

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
            onClicked: menuBar.openWorld()
        }
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 110
        height: 42
        radius: 21
        color: orbitMouse.pressed ? "#E4F9FF" : "transparent"

        Row {
            anchors.centerIn: parent
            spacing: 8
            Image {
                source: "/usr/share/yunsh/icons/orbit.png"
                width: 30; height: 30
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2
                Text {
                    text: "Orbit"
                    color: "#121820"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    text: orbitConfigured ? "READY" : "SETUP"
                    color: orbitConfigured ? "#20A85A" : "#D98200"
                    font.pixelSize: 7
                    font.weight: Font.Bold
                    font.letterSpacing: 1.1
                }
            }
        }
        MouseArea {
            id: orbitMouse
            anchors.fill: parent
            onClicked: menuBar.openOrbit()
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#DCEBF0"
    }
}
