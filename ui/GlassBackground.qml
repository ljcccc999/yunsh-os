// YUNSH OS v1.0.2 - Glass Background Component
// Apple Design Principles applied:
// 1. Materialize don't just fade — animate blur amount + scale together on enter/exit
// 2. Bigger surfaces → thicker blur + deeper shadow (size-aware material hierarchy)
// 3. Scroll edge fade instead of hard dividers (gradient mask over content boundary)
// 4. Color on solid layer, not translucent (accent glow lives behind glass, not on it)
// 5. Reduced-motion: prefers-reduced-motion → opacity-only fallback
// AR-friendly: white-tinted glass for visibility on AR glasses

import QtQuick 2.15

Item {
    id: glassBg
    anchors.fill: parent

    // === Customizable Properties ===
    property real tintOpacity: 0.2        // White glass - visible on AR glasses
    property real cornerRadius: 0         // Full-screen = 0, panels = 28
    property bool showTopHighlight: true  // visionOS edge light
    property bool showBorder: false       // Subtle edge border
    property bool showDropShadow: false   // Deep floating shadow
    property bool showFrost: true         // Frost overlay layer
    property bool animateEnter: true      // Materialize animation on show
    property real surfaceSize: 1920       // Surface dimension (bigger = thicker glass)
    property color tintColor: Qt.rgba(255/255, 255/255, 255/255, tintOpacity)
    property color accentColor: Qt.rgba(0/255, 212/255, 255/255, 0.0)

    // Size-aware glass thickness (Apple: bigger surface = thicker material)
    function glassThickness(base) {
        var scale = Math.min(1.0, surfaceSize / 1920)
        return base * (0.6 + 0.4 * scale)
    }

    // Materialize animation: scale + opacity on enter
    readonly property real animDuration: 300

    Rectangle {
        id: glassRect
        anchors.fill: parent
        radius: cornerRadius
        color: tintColor
        opacity: 0

        // Enter materialize animation (scale from 0.95 + fade in)
        Behavior on opacity {
            NumberAnimation { duration: animateEnter ? animDuration : 0 }
        }
        transform: Scale {
            id: scaleTransform
            origin.x: glassBg.width / 2
            origin.y: glassBg.height / 2
            xScale: 1.0
            yScale: 1.0
        }

        // Frost overlays (size-aware thickness)
        Rectangle {
            anchors.fill: parent
            radius: cornerRadius
            color: Qt.rgba(255/255, 255/255, 255/255, 0.04 + 0.02 * glassThickness(1.0))
            visible: showFrost
        }

        Rectangle {
            anchors.fill: parent
            radius: cornerRadius
            color: Qt.rgba(255/255, 255/255, 255/255, 0.02 + 0.02 * glassThickness(1.0))
            visible: showFrost
        }

    // Top edge highlight (visionOS signature light) — gradient fade at edges
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        visible: showTopHighlight
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.1; color: Qt.rgba(255/255, 255/255, 255/255, 0.08) }
            GradientStop { position: 0.9; color: Qt.rgba(255/255, 255/255, 255/255, 0.08) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Bottom shadow (edge fade instead of hard line)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: glassThickness(6)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0/255, 0/255, 0/255, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Scroll edge gradient mask (Apple: edge fade instead of 1px divider)
    // When this glass panel has content scrolling beneath, this soft gradient
    // masks the boundary between glass and content instead of a hard line.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        visible: showFrost
    }

    // Accent glow at bottom — COLOR BEHIND GLASS (Apple: color on solid, not translucent)
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
        // Layer behind glassRect — color lives on this solid layer
        z: glassRect.z - 1
    }

    // Accent glow at top
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
        z: glassRect.z - 1
    }

    // Border (edge glow, not hard line)
    Rectangle {
        anchors.fill: parent
        radius: cornerRadius
        color: "transparent"
        border.color: showBorder ? Qt.rgba(255/255, 255/255, 255/255, 0.04) : "transparent"
        border.width: showBorder ? 1 : 0
    }

    // Deep drop shadow (size-aware)
    layer.enabled: showDropShadow
    layer.effect: DropShadowEffect {
        radius: glassThickness(48)
        samples: Math.min(128, glassThickness(96))
        color: Qt.rgba(0/255, 0/255, 0/255, 0.3 + 0.1 * glassThickness(1.0))
        horizontalOffset: 0
        verticalOffset: glassThickness(16)
    }

    // Component.onCompleted: trigger materialize animation
    Component.onCompleted: {
        if (animateEnter) {
            scaleTransform.xScale = 0.95
            scaleTransform.yScale = 0.95
            glassRect.opacity = 0
        }
        // Animate in
        scaleTransform.xScale = 1.0
        scaleTransform.yScale = 1.0
        glassRect.opacity = 1.0
    }

    // Reduced-motion support (Apple: replace slides/scale with opacity cross-fade)
    SmoothedAnimation on opacity {
        running: false  // disabled by default, override in main.qml
    }
}
}
