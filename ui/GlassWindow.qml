// YUNSH OS v1.0 - Glass Window Frame (visionOS style)
// Floating glass panel that wraps overlay screens

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: glassWindow
    anchors.fill: parent
    color: "transparent"

    // Ambient dark backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
    }

    // Floating glass panel (not full screen — inset like visionOS windows)
    Rectangle {
        id: windowPanel
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1400)
        height: Math.min(parent.height - 80, 900)

        // Corner radius (visionOS generous corner)
        radius: 32

        // Glass background
        color: Qt.rgba(12/255, 12/255, 28/255, 0.7)

        // Frost layer
        Rectangle {
            anchors.fill: parent; radius: 32
            color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
        }

        // Border
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
        border.width: 1

        // Top rim highlight (visionOS signature edge light)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.right: parent.right; anchors.rightMargin: 20
            height: 1
            radius: 1
            color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
        }

        // Bottom rim shadow
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.right: parent.right; anchors.rightMargin: 20
            height: 1
            radius: 1
            color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
        }

        // Deep drop shadow (floating depth)
        layer.enabled: true
        layer.effect: DropShadowEffect {
            radius: 48
            samples: 96
            color: Qt.rgba(0/255, 0/255, 0/255, 0.4)
            horizontalOffset: 0
            verticalOffset: 12
        }

        // Content area (with padding)
        Item {
            id: contentArea
            anchors.fill: parent
            anchors.margins: 0  // content manages its own padding
        }
    }

    // Public alias so we can parent content into it
    alias contentParent: contentArea

    // Window drag handle (visionOS-style grabber at top)
    Rectangle {
        anchors.horizontalCenter: windowPanel.horizontalCenter
        anchors.top: windowPanel.top; anchors.topMargin: 8
        width: 40; height: 4; radius: 2
        color: Qt.rgba(255/255, 255/255, 255/255, 0.12)
        z: 100
    }
}
