// YUNSH OS v1.0.1 - macOS-style Floating Window (visionOS glass)
// Rounded frosted glass window with traffic light buttons

import QtQuick 2.15
import QtQuick.Controls 2.15

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

    // ─── Pin/Hover Mode ────────────────────────────────
    // "pinned"  = fixed in space (drag to position, stays there)
    // "following" = follows user's gaze (always in view)
    property string pinMode: "pinned"

    // ─── 3DoF Head Tracking ───────────────────────────────
    // Current head rotation (set by main.qml from IMU daemon)
    property real headYaw: 0.0
    property real headPitch: 0.0
    property real pixelsPerDegree: 21.3   // 1920px / ~90° FOV = 21.3 px/°

    // When pinned: window stays in world space using head rotation compensation
    // When following: subtle head-aware offset (10% of pinned effect)
    function computeHeadOffsetX() {
        var degrees = pinMode === "pinned" ? headYaw : headYaw * 0.08
        return -degrees * pixelsPerDegree
    }
    function computeHeadOffsetY() {
        var degrees = pinMode === "pinned" ? headPitch : headPitch * 0.08
        return -degrees * pixelsPerDegree
    }

    transform: Translate {
        x: macWindow.computeHeadOffsetX()
        y: macWindow.computeHeadOffsetY()
    }

    signal pinModeChanged(string mode)

    signal closeClicked()
    signal minimizeClicked()
    signal fullscreenClicked()
    signal mouseEntered()
    signal togglePinMode()

    default property alias content: contentArea.data

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

            // Pin toggle button (right side, visionOS style)
            Rectangle {
                id: pinButton
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                radius: 8
                color: macWindow.pinMode === "following"
                    ? Qt.rgba(0/255, 212/255, 255/255, 0.15)
                    : Qt.rgba(1, 1, 1, 0.04)
                border.color: macWindow.pinMode === "following"
                    ? Qt.rgba(0/255, 212/255, 255/255, 0.3)
                    : Qt.rgba(1, 1, 1, 0.06)

                // Pushpin icon (simple geometric)
                Rectangle {
                    anchors.centerIn: parent
                    width: 14; height: 18
                    radius: 3
                    color: "transparent"
                    border.width: 2
                    border.color: macWindow.pinMode === "following"
                        ? "#00D4FF"
                        : Qt.rgba(1, 1, 1, 0.5)

                    // Pin head (circle at bottom)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: -4
                        width: 6; height: 6; radius: 3
                        color: macWindow.pinMode === "following"
                            ? "#00D4FF"
                            : Qt.rgba(1, 1, 1, 0.5)
                    }

                    // Line from pin head to top
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top; anchors.topMargin: 3
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                        width: 2
                        color: macWindow.pinMode === "following"
                            ? "#00D4FF"
                            : Qt.rgba(1, 1, 1, 0.5)
                    }
                }

                // Animated glow ring (following mode)
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
                    visible: macWindow.pinMode === "following"

                    NumberAnimation on opacity {
                        loops: Animation.Infinite
                        from: 0.0; to: 0.6; duration: 2000
                    }
                }

                MouseArea {
                    id: pinBtnMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.color = macWindow.pinMode === "following"
                        ? Qt.rgba(0/255, 212/255, 255/255, 0.25)
                        : Qt.rgba(1, 1, 1, 0.08)
                    onExited: parent.color = macWindow.pinMode === "following"
                        ? Qt.rgba(0/255, 212/255, 255/255, 0.15)
                        : Qt.rgba(1, 1, 1, 0.04)
                    onClicked: {
                        macWindow.togglePinMode()
                        macWindow.pinModeChanged(macWindow.pinMode)
                    }
                }

                // Tooltip
                Text {
                    id: pinTooltip
                    anchors.top: parent.bottom; anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: macWindow.pinMode === "following" ? "松开固定" : "视线跟随"
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.pixelSize: 10
                    font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                    visible: pinBtnMA.containsMouse
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
            id: dragArea
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

        // ─── Resize Handles ───────────────────────────
        // Right edge
        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top; anchors.topMargin: 48
            anchors.bottom: parent.bottom; anchors.bottomMargin: 20
            width: 8
            cursorShape: Qt.SizeHorCursor

            property real startW: 0
            property real startX: 0

            onPressed: { startW = macWindow.width; startX = mouseX }
            onPositionChanged: {
                var dx = mouseX - startX
                macWindow.width = Math.max(400, startW + dx)
            }
        }

        // Bottom edge
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.right: parent.right; anchors.rightMargin: 20
            height: 8
            cursorShape: Qt.SizeVerCursor

            property real startH: 0
            property real startY: 0

            onPressed: { startH = macWindow.height; startY = mouseY }
            onPositionChanged: {
                var dy = mouseY - startY
                macWindow.height = Math.max(300, startH + dy)
            }
        }

        // Bottom-right corner (macOS style resize grip)
        MouseArea {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 20
            height: 20
            cursorShape: Qt.SizeFDiagCursor

            property real startW: 0
            property real startH: 0
            property real startX: 0
            property real startY: 0

            onPressed: {
                startW = macWindow.width
                startH = macWindow.height
                startX = mouseX
                startY = mouseY
            }
            onPositionChanged: {
                var dx = mouseX - startX
                var dy = mouseY - startY
                macWindow.width = Math.max(400, startW + dx)
                macWindow.height = Math.max(300, startH + dy)
            }
        }

        // Left edge
        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top; anchors.topMargin: 48
            anchors.bottom: parent.bottom; anchors.bottomMargin: 20
            width: 8
            cursorShape: Qt.SizeHorCursor

            property real startW: 0
            property real startX: 0

            onPressed: { startW = macWindow.width; startX = mouseX + macWindow.x }
            onPositionChanged: {
                var dx = (mouseX + macWindow.x) - startX
                macWindow.width = Math.max(400, startW - dx)
                macWindow.x += (startW - macWindow.width)
            }
        }

        // Top edge
        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.right: parent.right; anchors.rightMargin: 20
            height: 8
            cursorShape: Qt.SizeVerCursor

            property real startH: 0
            property real startY: 0

            onPressed: { startH = macWindow.height; startY = mouseY + macWindow.y }
            onPositionChanged: {
                var dy = (mouseY + macWindow.y) - startY
                macWindow.height = Math.max(300, startH - dy)
                macWindow.y += (startH - macWindow.height)
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

    // ─── Pin mode logic ─────────────────────────────
    onTogglePinMode: {
        if (macWindow.pinMode === "pinned") {
            // Switch to follow mode: window becomes gaze-following
            macWindow.pinMode = "following"
        } else {
            // Switch to pinned mode: fix in space
            macWindow.pinMode = "pinned"
        }
    }

    // When in follow mode, window smoothly moves to center-ish position
    onPinModeChanged: {
        if (macWindow.pinMode === "following") {
            // Smoothly animate to centered position
            followAnimX.to = Math.max(50, (parent.width - macWindow.width) / 2)
            followAnimY.to = Math.max(50, (parent.height - macWindow.height) / 2.5)
            followAnimX.start()
            followAnimY.start()
        }
    }

    NumberAnimation {
        id: followAnimX
        target: macWindow; property: "x"
        duration: 600; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: followAnimY
        target: macWindow; property: "y"
        duration: 600; easing.type: Easing.OutCubic
    }
}
