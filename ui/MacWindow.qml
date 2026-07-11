// YUNSH OS v1.0.1 - macOS-style Floating Window (visionOS glass)
// Rounded frosted glass window with traffic light buttons

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: macWindow
    width: 880
    height: 640
    radius: 16

    // === Public API ===
    property string appTitle: ""
    property alias appTitleText: titleLabel.text
    property alias windowOpacity: windowGlass.color.a
    property real windowWidth: 880
    property real windowHeight: 640
    property bool isFullscreen: false
    property bool isMinimized: false

    default property alias content: contentArea.data

    signal closeClicked()
    signal minimizeClicked()
    signal fullscreenClicked()
    signal mouseEntered()

    // Window frame glass
    color: "transparent"

    // Shadow (drop shadow via layered rectangles)
    Rectangle {
        x: 0; y: 12
        width: parent.width
        height: parent.height
        radius: parent.radius + 4
        color: Qt.rgba(0, 0, 0, 0.3)
    }
    Rectangle {
        x: 0; y: 6
        width: parent.width
        height: parent.height
        radius: parent.radius + 2
        color: Qt.rgba(0, 0, 0, 0.15)
    }

    // Main glass panel
    Rectangle {
        id: windowGlass
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(12/255, 12/255, 25/255, 0.82)  // Deep glass base

        // Frost overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
        }

        // Secondary frost depth
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
        }

        // Top edge highlight (visionOS light)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left; anchors.leftMargin: 24
            anchors.right: parent.right; anchors.rightMargin: 24
            height: 1
            radius: 1
            color: Qt.rgba(255/255, 255/255, 255/255, 0.1)
        }

        // Accent glow at bottom
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0/255, 212/255, 255/255, 0.025) }
            }
        }

        // ─── Title Bar ────────────────────────────────
        Rectangle {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            color: "transparent"

            // Traffic light buttons (macOS style)
            Row {
                id: trafficLights
                anchors.left: parent.left; anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                // Close (red)
                Rectangle {
                    width: 13; height: 13; radius: 6.5
                    color: "#FF5F57"
                    border.color: Qt.darker("#FF5F57", 1.15)

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Qt.lighter("#FF5F57", 1.2)
                        onExited: parent.color = "#FF5F57"
                        onClicked: macWindow.closeClicked()
                    }
                }

                // Minimize (yellow)
                Rectangle {
                    width: 13; height: 13; radius: 6.5
                    color: "#FEBC2E"
                    border.color: Qt.darker("#FEBC2E", 1.15)

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Qt.lighter("#FEBC2E", 1.2)
                        onExited: parent.color = "#FEBC2E"
                        onClicked: macWindow.minimizeClicked()
                    }
                }

                // Fullscreen (green)
                Rectangle {
                    width: 13; height: 13; radius: 6.5
                    color: "#2BC840"
                    border.color: Qt.darker("#2BC840", 1.15)

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Qt.lighter("#2BC840", 1.2)
                        onExited: parent.color = "#2BC840"
                        onClicked: macWindow.fullscreenClicked()
                    }
                }
            }

            // Title text
            Text {
                id: titleLabel
                anchors.centerIn: parent
                text: appTitle
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: 13
                font.weight: Font.Medium
                font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
            }

            // Bottom separator
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left; anchors.leftMargin: 12
                anchors.right: parent.right; anchors.rightMargin: 12
                height: 1
                color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
            }
        }

        // ─── Drag to move (title bar area) ────────────
        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: titleBar.height + 4
            drag.target: macWindow
            drag.axis: Drag.XAndY
            cursorShape: Qt.OpenHandCursor
            onPressed: macWindow.z = 1000  // Bring to front
        }

        // ─── Content Area ────────────────────────────
        Rectangle {
            id: contentClip
            anchors.top: titleBar.bottom
            anchors.left: parent.left; anchors.leftMargin: 2
            anchors.right: parent.right; anchors.rightMargin: 2
            anchors.bottom: parent.bottom; anchors.bottomMargin: 2
            radius: parent.radius - 2
            clip: true
            color: "transparent"

            Rectangle {
                id: contentArea
                anchors.fill: parent
                anchors.margins: 0
                color: "transparent"

                // Actual app content goes here
            }
        }
    }

    // ─── Fullscreen toggle ──────────────────────────
    states: [
        State {
            name: "fullscreen"
            PropertyChanges { target: macWindow; x: 0; y: 0; width: parent.parent.width; height: parent.parent.height }
            PropertyChanges { target: macWindow; radius: 0 }
        },
        State {
            name: "normal"
            PropertyChanges { target: macWindow; radius: 16 }
        }
    ]

    onFullscreenClicked: {
        if (state === "fullscreen") {
            state = "normal"
            isFullscreen = false
        } else {
            state = "fullscreen"
            isFullscreen = true
        }
    }
}
