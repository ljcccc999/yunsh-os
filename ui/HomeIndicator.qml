// YUNSH OS v3.1.6 - Home Indicator
// Bottom screen pill for mouse gesture: swipe up → Task Switcher
// Like iPhone home bar, but for mouse

import QtQuick 2.15

Item {
    id: homeIndicator
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter

    property int pillWidth: 124
    property int pillHeight: 5
    // The visible pill is intentionally small, but the gesture target must be
    // easy to hit on a large display (especially the 5K panel).  Keep a broad
    // transparent target above it so a short mouse swipe cannot miss.
    property int hitZoneHeight: 84  // Detection zone above the pill
    property bool isDragging: false
    property real dragThreshold: 24  // Pixels to trigger task switcher
    property bool reduceMotion: false

    signal swipeUpTriggered()
    signal clicked()

    width: pillWidth + 40
    height: hitZoneHeight + pillHeight + 8

    // === Mouse detection zone ===
    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        property real pressY: 0

        onPressed: function(mouse) {
            pressY = mouse.y
            isDragging = false
            pill.opacity = 0.92
        }

        onPositionChanged: function(mouse) {
            // Detect swipe up
            if (pressed && (pressY - mouse.y > dragThreshold)) {
                isDragging = true
                pill.opacity = 0.56
                homeIndicator.swipeUpTriggered()
                // Reset to prevent repeated triggers
                pressY = mouse.y + 100
            }

            // Hover effect
            if (!pressed) {
                pill.opacity = containsMouse ? 0.90 : 0.72
                pill.scale = containsMouse ? 1.15 : 1.0
            }
        }

        onReleased: {
            isDragging = false
            pill.opacity = containsMouse ? 0.90 : 0.72
            pill.scale = containsMouse ? 1.15 : 1.0

            // If it wasn't a drag, it's a click
            if (Math.abs(pressY - mouse.y) < dragThreshold) {
                homeIndicator.clicked()
            }
        }

        onExited: {
            pill.opacity = 0.72
            pill.scale = 1.0
        }
    }

    // === Home Pill (visionOS glass) ===
    Rectangle {
        id: pill
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter

        width: pillWidth
        height: pillHeight
        radius: pillHeight / 2

        color: Qt.rgba(248/255, 252/255, 255/255, 0.84)
        opacity: 0.72

        // Inner glow
        Rectangle {
            anchors.fill: parent
            radius: pillHeight / 2
            color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
        }

        Behavior on opacity { NumberAnimation { duration: homeIndicator.reduceMotion ? 60 : 100 } }
        Behavior on scale { NumberAnimation { duration: homeIndicator.reduceMotion ? 60 : 80; easing.type: Easing.OutCubic } }
    }

    // === Pill backdrop glow (subtle) ===
    Rectangle {
        anchors.centerIn: pill
        width: pillWidth + 20
        height: pillHeight + 12
        radius: (pillHeight + 12) / 2
        color: Qt.rgba(0/255, 212/255, 255/255, 0.03)
        opacity: pill.opacity * 0.5
    }
}
