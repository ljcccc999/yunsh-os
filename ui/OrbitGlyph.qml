// Circular Orbit mark for the glasses shell.  The surrounding glass is part
// of the component so Orbit never falls back to a square application tile.
import QtQuick 2.15

Item {
    id: glyph
    property bool glassSurface: true
    width: 48
    height: 48

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: glyph.glassSurface
        color: Qt.rgba(1, 1, 1, 0.80)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.96)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.58)
        }
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 5
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.60
            height: parent.height * 0.16
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.38)
        }
    }

    Item {
        anchors.centerIn: parent
        width: parent.width * (glyph.glassSurface ? 0.58 : 0.72)
        height: width
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#101010"
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.58
            height: width
            radius: width / 2
            color: "#F7F9FA"
        }
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.13
            height: parent.height * 0.32
            color: "#F7F9FA"
        }
    }
}
