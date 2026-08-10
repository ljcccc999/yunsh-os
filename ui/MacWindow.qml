// YUNSH OS v1.0.1 - macOS-style Floating Window (visionOS glass)
// Rounded frosted glass window with traffic light buttons

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: macWindow
    width: 880
    height: 640
    // Apple-style large continuous corner; all window surfaces inherit it.
    radius: 28

    // === Public API ===
    property string appTitle: ""
    property alias appTitleText: titleLabel.text
    property alias windowOpacity: windowGlass.color.a
    property real windowWidth: 880
    property real windowHeight: 640
    property bool isFullscreen: false
    property bool isMinimized: false
    property bool reduceMotion: false
    property bool reduceTransparency: false
    property bool highContrast: false
    property bool focusDimmed: false
    readonly property int motionDuration: reduceMotion ? 80 : 280

    // ─── Pin/Hover Mode ────────────────────────────────
    // "pinned"  = fixed in space (drag to position, stays there)
    // "following" = follows user's gaze (always in view)
    property string pinMode: "pinned"

    // ─── Spatial window placement (3DoF) ─────────────────
    // These are view-relative presets: they create a readable 2.5D desktop
    // on the existing single-display pipeline.  They are not world anchors;
    // stable room anchoring needs a future 6DoF visual tracking system.
    property string spatialPlacement: "front" // front, left, right, far
    property real spatialYaw: spatialPlacement === "left" ? -20
                            : spatialPlacement === "right" ? 20 : 0
    property real spatialOffsetX: spatialPlacement === "left" ? -300
                                : spatialPlacement === "right" ? 300 : 0
    property real spatialScale: spatialPlacement === "far" ? 0.76
                               : spatialPlacement === "left" || spatialPlacement === "right" ? 0.88 : 1.0
    property bool placementMenuVisible: false

    function cycleSpatialPlacement() {
        if (spatialPlacement === "front") spatialPlacement = "left"
        else if (spatialPlacement === "left") spatialPlacement = "right"
        else if (spatialPlacement === "right") spatialPlacement = "far"
        else spatialPlacement = "front"
    }

    function setSpatialPlacement(placement) {
        spatialPlacement = placement
        placementMenuVisible = false
    }

    // ─── 3DoF Head Tracking ───────────────────────────────
    // Current head rotation (set by main.qml from IMU daemon)
    property real headYaw: 0.0
    property real headPitch: 0.0
    property real headRoll: 0.0
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

    signal closeClicked()
    signal minimizeClicked()
    signal fullscreenClicked()
    signal mouseEntered()
    signal togglePinMode()
    signal activated()

    PointHandler {
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            if (active)
                macWindow.activated()
        }
    }

    // ─── Materialize Animation (Apple: glass surfaces materialize, don't just fade) ──
    property bool animateEnter: true
    property bool isClosing: false
    property real entranceScale: 1.0

    Behavior on opacity {
        NumberAnimation {
            duration: macWindow.reduceMotion ? 80 : 220
            easing.type: Easing.OutCubic
        }
    }

    // Window open: scale 0.95 + fade in
    transform: [
        Scale {
            id: winScale
            origin.x: macWindow.width / 2
            origin.y: macWindow.height / 2
            xScale: macWindow.spatialScale * macWindow.entranceScale
            yScale: macWindow.spatialScale * macWindow.entranceScale
            Behavior on xScale { NumberAnimation { duration: macWindow.motionDuration; easing.type: Easing.OutCubic } }
            Behavior on yScale { NumberAnimation { duration: macWindow.motionDuration; easing.type: Easing.OutCubic } }
        },
        Rotation {
            id: spatialRotation
            origin.x: macWindow.width / 2
            origin.y: macWindow.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: macWindow.spatialYaw
            Behavior on angle { NumberAnimation { duration: macWindow.motionDuration; easing.type: Easing.OutCubic } }
        },
        Rotation {
            origin.x: macWindow.width / 2
            origin.y: macWindow.height / 2
            axis { x: 0; y: 0; z: 1 }
            angle: -(macWindow.pinMode === "pinned"
                     ? macWindow.headRoll : macWindow.headRoll * 0.08)
            Behavior on angle {
                NumberAnimation { duration: macWindow.motionDuration; easing.type: Easing.OutCubic }
            }
        },
        Translate {
            x: macWindow.computeHeadOffsetX() + macWindow.spatialOffsetX
            y: macWindow.computeHeadOffsetY()
        }
    ]

    // Open animation (replaces original translate transform)
    Component.onCompleted: {
        if (animateEnter && !reduceMotion) {
            macWindow.entranceScale = 0.95
            macWindow.opacity = 0
        }
        // Animate in immediately
        macWindow.entranceScale = 1.0
        macWindow.opacity = 1.0
    }

    onVisibleChanged: {
        if (!visible)
            return
        isClosing = false
        if (animateEnter && !reduceMotion) {
            entranceScale = 0.95
            opacity = 0
            Qt.callLater(function() {
                macWindow.entranceScale = 1.0
                macWindow.opacity = 1.0
            })
        } else {
            entranceScale = 1.0
            opacity = 1.0
        }
    }

    // Animate out before destroying (call before destroying)
    function animateOut(callback) {
        if (isClosing) return
        isClosing = true
        macWindow.entranceScale = 0.92
        macWindow.opacity = 0
        closeAnimCallback = callback || function(){}
    }

    // Re-opening a window while its exit is in flight must continue from the
    // current presentation state instead of waiting for a stale timer.
    function cancelCloseAnimation() {
        if (!isClosing) return
        isClosing = false
        closeAnimCallback = function(){}
        entranceScale = 1.0
        opacity = 1.0
    }

    property var closeAnimCallback: function(){}

    // Close animation timer
    Timer {
        interval: macWindow.reduceMotion ? 80 : 250
        repeat: false
        running: isClosing
        onTriggered: closeAnimCallback()
    }

    default property alias content: contentArea.data

    // Window frame glass
    color: "transparent"

    // Shadow (drop shadow via layered rectangles)
    Rectangle {
        x: 0; y: 12
        width: parent.width
        height: parent.height
        radius: macWindow.radius + 4
        color: Qt.rgba(0, 0, 0, 0.3)
    }
    Rectangle {
        x: 0; y: 6
        width: parent.width
        height: parent.height
        radius: macWindow.radius + 2
        color: Qt.rgba(0, 0, 0, 0.15)
    }

    // Main glass panel
    Rectangle {
        id: windowGlass
        anchors.fill: parent
        radius: macWindow.radius
        clip: true
        // AR optical displays treat black as transparent. All app windows use
        // a bright white liquid-glass base so they remain visible in glasses.
        color: macWindow.reduceTransparency
            ? Qt.rgba(248/255, 252/255, 255/255, 0.98)
            : Qt.rgba(248/255, 252/255, 255/255, 0.88)
        opacity: macWindow.focusDimmed ? 0.22 : 1.0
        border.width: macWindow.highContrast ? 2 : 1
        border.color: macWindow.highContrast
            ? Qt.rgba(1, 1, 1, 0.48)
            : Qt.rgba(1, 1, 1, 0.92)

        Behavior on opacity {
            NumberAnimation {
                duration: macWindow.reduceMotion ? 80 : 180
                easing.type: Easing.OutCubic
            }
        }

        // Frost overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(255/255, 255/255, 255/255, 0.18)
        }

        // Secondary frost depth
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(190/255, 225/255, 255/255, 0.10)
        }

        // Top edge highlight (visionOS light)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left; anchors.leftMargin: 24
            anchors.right: parent.right; anchors.rightMargin: 24
            height: 1
            radius: 1
            color: Qt.rgba(255/255, 255/255, 255/255, 0.48)
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
        z: 2
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
                    width: 18; height: 18; radius: 9
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
                    width: 18; height: 18; radius: 9
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
                    width: 18; height: 18; radius: 9
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

            // Spatial placement selector: front → left → right → far.
            Rectangle {
                id: spatialButton
                anchors.right: pinButton.left; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32; radius: 8
                color: spatialButtonMouse.containsMouse
                    ? Qt.rgba(0/255, 212/255, 255/255, 0.18)
                    : Qt.rgba(1, 1, 1, 0.58)
                border.color: macWindow.spatialPlacement === "front"
                    ? Qt.rgba(1, 1, 1, 0.84)
                    : Qt.rgba(0/255, 212/255, 255/255, 0.32)

                Text {
                    anchors.centerIn: parent
                    text: macWindow.spatialPlacement === "left" ? "◀"
                        : macWindow.spatialPlacement === "right" ? "▶"
                        : macWindow.spatialPlacement === "far" ? "◌" : "▣"
                    color: macWindow.spatialPlacement === "front" ? "#26343E" : "#008EAA"
                    font.pixelSize: 14
                }
                MouseArea {
                    id: spatialButtonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: parent.scale = 0.94
                    onReleased: parent.scale = 1.0
                    onCanceled: parent.scale = 1.0
                    onClicked: macWindow.placementMenuVisible = !macWindow.placementMenuVisible
                }
                Text {
                    anchors.top: parent.bottom; anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: macWindow.spatialPlacement === "front" ? "空间位置：正前"
                        : macWindow.spatialPlacement === "left" ? "空间位置：左侧"
                        : macWindow.spatialPlacement === "right" ? "空间位置：右侧" : "空间位置：远处"
                    color: Qt.rgba(23/255, 33/255, 42/255, 0.58)
                    font.pixelSize: 10
                    visible: spatialButtonMouse.containsMouse && !macWindow.placementMenuVisible
                }

                Rectangle {
                    anchors.top: parent.bottom
                    anchors.topMargin: 10
                    anchors.right: parent.right
                    width: 272
                    height: 72
                    radius: 18
                    color: macWindow.reduceTransparency
                        ? "#F8FCFF" : Qt.rgba(248/255, 252/255, 255/255, 0.92)
                    border.width: macWindow.highContrast ? 2 : 1
                    border.color: macWindow.highContrast
                        ? Qt.rgba(75/255, 91/255, 103/255, 0.48)
                        : Qt.rgba(1, 1, 1, 0.92)
                    visible: macWindow.placementMenuVisible
                    z: 100

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Repeater {
                            model: [
                                { id: "front", label: "正前", icon: "▣" },
                                { id: "left", label: "左侧", icon: "◀" },
                                { id: "right", label: "右侧", icon: "▶" },
                                { id: "far", label: "远处", icon: "◌" }
                            ]

                            Rectangle {
                                width: 58
                                height: 52
                                radius: 13
                                color: macWindow.spatialPlacement === modelData.id
                                    ? Qt.rgba(0, 212/255, 1, 0.2)
                                    : (placementMouse.pressed
                                       ? Qt.rgba(210/255, 244/255, 255/255, 0.82)
                                       : Qt.rgba(1, 1, 1, 0.58))
                                border.width: 1
                                border.color: macWindow.spatialPlacement === modelData.id
                                    ? Qt.rgba(0, 212/255, 1, 0.4)
                                    : Qt.rgba(1, 1, 1, 0.86)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon
                                        color: macWindow.spatialPlacement === modelData.id
                                            ? "#008EAA" : "#26343E"
                                        font.pixelSize: 15
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: "#52616C"
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                }

                                MouseArea {
                                    id: placementMouse
                                    anchors.fill: parent
                                    onClicked: macWindow.setSpatialPlacement(modelData.id)
                                }
                            }
                        }
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
                    : Qt.rgba(1, 1, 1, 0.58)
                border.color: macWindow.pinMode === "following"
                    ? Qt.rgba(0/255, 212/255, 255/255, 0.3)
                    : Qt.rgba(1, 1, 1, 0.84)

                // Pushpin icon (simple geometric)
                Rectangle {
                    anchors.centerIn: parent
                    width: 14; height: 18
                    radius: 3
                    color: "transparent"
                    border.width: 2
                    border.color: macWindow.pinMode === "following"
                        ? "#00D4FF"
                        : Qt.rgba(23/255, 33/255, 42/255, 0.52)

                    // Pin head (circle at bottom)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: -4
                        width: 6; height: 6; radius: 3
                        color: macWindow.pinMode === "following"
                            ? "#00D4FF"
                            : Qt.rgba(23/255, 33/255, 42/255, 0.52)
                    }

                    // Line from pin head to top
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top; anchors.topMargin: 3
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                        width: 2
                        color: macWindow.pinMode === "following"
                            ? "#00D4FF"
                            : Qt.rgba(23/255, 33/255, 42/255, 0.52)
                    }
                }

                // Animated glow ring (following mode)
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
                    visible: macWindow.pinMode === "following" && !macWindow.reduceMotion

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
                        : Qt.rgba(225/255, 248/255, 255/255, 0.84)
                    onExited: parent.color = macWindow.pinMode === "following"
                        ? Qt.rgba(0/255, 212/255, 255/255, 0.15)
                        : Qt.rgba(1, 1, 1, 0.58)
                    onClicked: {
                        macWindow.togglePinMode()
                    }
                }

                // Tooltip
                Text {
                    id: pinTooltip
                    anchors.top: parent.bottom; anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: macWindow.pinMode === "following" ? "松开固定" : "视线跟随"
                    color: Qt.rgba(23/255, 33/255, 42/255, 0.56)
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
                color: Qt.rgba(23/255, 33/255, 42/255, 0.72)
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
                color: Qt.rgba(1, 1, 1, 0.72)
            }
        }

        // ─── Drag to move (title bar area) ────────────
    MouseArea {
        id: dragArea
            parent: titleBar
            anchors.fill: parent
            z: -1
            drag.target: macWindow
            drag.axis: Drag.XAndYAxis
            cursorShape: Qt.OpenHandCursor
            onPressed: {
                if (macWindow.state === "fullscreen") {
                    macWindow.state = "normal"
                    macWindow.isFullscreen = false
                }
                macWindow.z = 1000
                cursorShape = Qt.ClosedHandCursor
                if (!macWindow.reduceMotion)
                    macWindow.entranceScale = 0.992
            }
            onReleased: {
                cursorShape = Qt.OpenHandCursor
                macWindow.entranceScale = 1.0
                macWindow.settleIntoBounds()
            }
            onCanceled: {
                cursorShape = Qt.OpenHandCursor
                macWindow.entranceScale = 1.0
                macWindow.settleIntoBounds()
            }
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
            PropertyChanges {
                target: macWindow
                x: 0
                y: 0
                width: macWindow.parent ? macWindow.parent.width : 1920
                height: macWindow.parent ? macWindow.parent.height : 1080
            }
            PropertyChanges { target: macWindow; radius: 0 }
        },
        State {
            name: "normal"
            PropertyChanges { target: macWindow; radius: 28 }
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

    function settleIntoBounds() {
        if (!parent || state === "fullscreen")
            return
        var safeMargin = 28
        var targetX = Math.max(safeMargin - width * 0.75,
                               Math.min(x, parent.width - safeMargin - width * 0.25))
        var targetY = Math.max(18, Math.min(y, parent.height - 70))
        if (reduceMotion) {
            x = targetX
            y = targetY
            return
        }
        settleX.to = targetX
        settleY.to = targetY
        settleX.start()
        settleY.start()
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
        duration: macWindow.reduceMotion ? 80 : 400
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: followAnimY
        target: macWindow; property: "y"
        duration: macWindow.reduceMotion ? 80 : 400
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: settleX
        target: macWindow
        property: "x"
        duration: 320
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: settleY
        target: macWindow
        property: "y"
        duration: 320
        easing.type: Easing.OutCubic
    }
}
