// YUNSH OS v1.0.1 - Glass Background Component (visionOS Ultimate)
// Full-screen frosted glass background layer
// Used as the base for ALL YUNSH screens

import QtQuick 2.15

Rectangle {
    id: glassBg
    anchors.fill: parent

    // === Customizable Properties ===
    property real tintOpacity: 0.65       // Base glass darkness
    property real cornerRadius: 0         // Full-screen = 0, panels = 28
    property bool showTopHighlight: true  // visionOS edge light
    property bool showBorder: false       // Subtle edge border
    property bool showDropShadow: false   // Deep floating shadow
    property bool showFrost: true         // Frost overlay layer
    property color tintColor: Qt.rgba(12/255, 12/255, 25/255, tintOpacity)
    property color accentColor: Qt.rgba(0/255, 212/255, 255/255, 0.0) // Subtle accent glow

    radius: cornerRadius
    color: tintColor

    // Frost overlay (simulates blurred background)
    Rectangle {
        anchors.fill: parent
        radius: cornerRadius
        color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
        visible: showFrost
    }

    // Secondary frost layer (depth)
    Rectangle {
        anchors.fill: parent
        radius: cornerRadius
        color: Qt.rgba(255/255, 255/255, 255/255, 0.015)
        visible: showFrost
    }

    // Top highlight (visionOS signature edge light)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left; anchors.leftMargin: 24
        anchors.right: parent.right; anchors.rightMargin: 24
        height: 1
        radius: 1
        color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
        visible: showTopHighlight
    }

    // Bottom shadow gradient
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.right: parent.right; anchors.rightMargin: 12
        height: 3
        radius: 1.5
        color: Qt.rgba(0/255, 0/255, 0/255, 0.15)
    }

    // Subtle accent glow at bottom (liquid glass effect)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0/255, 212/255, 255/255, 0.015) }
        }
        visible: accentColor.a > 0
    }

    // Subtle accent glow at top (liquid glass effect)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0/255, 100/255, 255/255, 0.02) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        visible: accentColor.a > 0
    }

    // Border
    border.color: showBorder ? Qt.rgba(255/255, 255/255, 255/255, 0.04) : "transparent"
    border.width: showBorder ? 1 : 0

    // Deep drop shadow (floating depth) — disabled for full-screen
    layer.enabled: showDropShadow
    layer.effect: DropShadowEffect {
        radius: 48
        samples: 96
        color: Qt.rgba(0/255, 0/255, 0/255, 0.4)
        horizontalOffset: 0
        verticalOffset: 16
    }
}
