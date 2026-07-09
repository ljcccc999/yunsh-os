// YUNSH OS v1.0 - Glass Panel Component (visionOS Enhanced - Apple Level)
// Floating glass panel with heavy blur, deep shadows, frost effect
// Used as base for all YUNSH UI panels

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: glassPanel
    anchors.fill: parent
    
    // === Customizable Properties ===
    property real glassOpacity: 0.35  // Base opacity (higher = less transparent)
    property real cornerRadius: 24    // Large radius for visionOS feel
    property real blurRadius: 36     // Heavy gaussian-like blur
    property real shadowDepth: 24    // Shadow spread in pixels
    property real shadowOpacity: 0.6 // Shadow darkness
    property color glassTint: Qt.rgba(0.45, 0.5, 0.7, 0.08) // Slight blue tint
    property bool showBorder: true
    
    // Apple-style large corner radius
    radius: cornerRadius
    
    // Main glass background - deep translucent with blue tint
    color: Qt.rgba(12/255, 12/255, 25/255, glassOpacity * 0.7)
    
    // Frosted overlay layer (simulates blurred background)
    Rectangle {
        anchors.fill: parent
        radius: cornerRadius
        color: glassTint
    }
    
    // Second frosting layer for depth
    Rectangle {
        anchors.fill: parent
        radius: cornerRadius
        color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
    }
    
    // Top highlight (visionOS signature light edge)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.right: parent.right; anchors.rightMargin: 12
        height: 1
        radius: 1
        color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
    }
    
    // Bottom shadow gradient
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.leftMargin: 8
        anchors.right: parent.right; anchors.rightMargin: 8
        height: 4
        radius: 2
        color: Qt.rgba(0/255, 0/255, 0/255, 0.15)
    }
    
    // Subtle border (like visionOS glass edge)
    Rectangle {
        anchors.fill: parent
        radius: cornerRadius
        color: "transparent"
        border.color: Qt.rgba(255/255, 255/255, 255/255, showBorder ? 0.05 : 0)
        border.width: 1
        visible: showBorder
    }
    
    // Drop shadow (deep floating effect)
    DropShadowEffect {
        anchors.fill: parent
        radius: shadowDepth
        samples: 32
        color: Qt.rgba(0/255, 0/255, 0/255, shadowOpacity)
        source: glassPanel
        transparentBorder: true
    }
    
    // Floating hover animation (subtle)
    Behavior on y {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
}
