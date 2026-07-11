// YUNSH OS v1.0.1 - Task Switcher (visionOS Ultimate)
// iOS-style app switcher with horizontal cards
// Trigger: mouse swipe up from home indicator / Ctrl+Up

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: taskSwitcher
    anchors.fill: parent
    visible: false
    z: 400

    // === Properties ===
    property var openApps: []   // List of { appId, name, icon, color, visible }
    property real cardWidth: 320
    property real cardHeight: 440
    property int currentIndex: 0

    signal switchToApp(string appId)
    signal closeApp(string appId)
    signal dismissSwitcher()

    // === Dark blurred backdrop ===
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0/255, 0/255, 0/255, 0.7)
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        // Click to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: dismissSwitcher()
        }
    }

    // === Header ===
    Text {
        id: switcherHeader
        anchors.top: parent.top; anchors.topMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        text: "App Switcher"
        color: Qt.rgba(255/255, 255/255, 255/255, 0.15)
        font.pixelSize: 13
        font.weight: Font.Medium
        letterSpacing: 3
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // === Close hint ===
    Text {
        id: closeHint
        anchors.top: switcherHeader.bottom; anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        text: "↑ 向上滑动关闭应用 · 点击切换"
        color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
        font.pixelSize: 11
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // === Horizontal App Cards ===
    Flickable {
        id: cardsFlick
        anchors.top: parent.top; anchors.topMargin: 80
        anchors.bottom: parent.bottom; anchors.bottomMargin: 60
        anchors.left: parent.left
        anchors.right: parent.right
        contentWidth: cardsRow.width + 100
        contentHeight: cardsFlick.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        interactive: true

        opacity: 0
        Behavior on opacity {
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }

        Row {
            id: cardsRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: -80  // Overlapping like visionOS

            Repeater {
                id: cardsRepeater
                model: openApps

                // === Individual App Card ===
                Item {
                    width: taskSwitcher.cardWidth
                    height: taskSwitcher.cardHeight

                    property bool isClosing: false
                    property var appData: modelData

                    // Glass card
                    Rectangle {
                        id: appCard
                        anchors.centerIn: parent
                        width: taskSwitcher.cardWidth - 20
                        height: taskSwitcher.cardHeight - 20

                        radius: 32
                        color: Qt.rgba(14/255, 14/255, 32/255, 0.65)

                        // Frost layer
                        Rectangle {
                            anchors.fill: parent; radius: 32
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
                        }

                        // Top highlight
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left; anchors.leftMargin: 20
                            anchors.right: parent.right; anchors.rightMargin: 20
                            height: 1; radius: 1
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                        }

                        // Border
                        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        border.width: 1

                        // === App Preview (gradient background) ===
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * 0.65

                            radius: 32
                            radiusTopLeft: 32
                            radiusTopRight: 32
                            radiusBottomLeft: 0
                            radiusBottomRight: 0

                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(
                                        parseInt(appData.color.substring(1,3), 16) / 255,
                                        parseInt(appData.color.substring(3,5), 16) / 255,
                                        parseInt(appData.color.substring(5,7), 16) / 255,
                                        0.12
                                    )
                                }
                                GradientStop { position: 1.0; color: Qt.rgba(10/255, 10/255, 25/255, 0.4) }
                            }

                            // Frost overlay on preview
                            Rectangle {
                                anchors.fill: parent
                                radius: 32
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
                            }

                            // App icon in preview center
                            Rectangle {
                                anchors.centerIn: parent
                                width: 64; height: 64; radius: 20
                                color: Qt.rgba(
                                    parseInt(appData.color.substring(1,3), 16) / 255,
                                    parseInt(appData.color.substring(3,5), 16) / 255,
                                    parseInt(appData.color.substring(5,7), 16) / 255,
                                    0.15
                                )
                                border.color: Qt.rgba(
                                    parseInt(appData.color.substring(1,3), 16) / 255,
                                    parseInt(appData.color.substring(3,5), 16) / 255,
                                    parseInt(appData.color.substring(5,7), 16) / 255,
                                    0.08
                                )
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: appData.name.charAt(0)
                                    color: appData.color
                                    font.pixelSize: 28
                                    font.weight: Font.Bold
                                }
                            }

                            // Subtle text pattern
                            Column {
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 20
                                anchors.left: parent.left; anchors.leftMargin: 20
                                anchors.right: parent.right; anchors.rightMargin: 20
                                spacing: 6

                                Repeater {
                                    model: 4
                                    Rectangle {
                                        width: parent.width * (0.5 + Math.random() * 0.4)
                                        height: 6; radius: 3
                                        color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
                                    }
                                }
                            }
                        }

                        // === App Info (bottom section) ===
                        Rectangle {
                            anchors.top: parent.top; anchors.topMargin: parent.height * 0.65
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            color: Qt.rgba(8/255, 8/255, 20/255, 0.3)

                            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
                            border.width: 1

                            // Top separator glass line
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
                            }

                            // App name
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                text: appData.name
                                color: "#FFFFFF"
                                font.pixelSize: 18
                                font.weight: Font.Medium
                            }

                            // Status indicator
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                text: "🟢"
                                font.pixelSize: 14
                            }
                        }

                        // === Close button (X, top-left) ===
                        Rectangle {
                            id: closeBtn
                            anchors.top: parent.top; anchors.topMargin: -8
                            anchors.left: parent.left; anchors.leftMargin: -8
                            width: 28; height: 28; radius: 14
                            color: Qt.rgba(255/255, 70/255, 70/255, 0.85)
                            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.15)
                            border.width: 1
                            z: 20

                            // Inner glow
                            Rectangle {
                                anchors.fill: parent; radius: 14
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: "#FFFFFF"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.scale = 1.2
                                onExited: parent.scale = 1.0
                                onClicked: {
                                    // Close animation
                                    isClosing = true
                                    closeAnim.start()
                                }
                            }

                            Behavior on scale {
                                NumberAnimation { duration: 100; easing.type: Easing.OutBack }
                            }
                        }

                        // === Main click area (switch to app) ===
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: 10
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                parent.scale = 1.03
                                parent.color = Qt.rgba(18/255, 18/255, 40/255, 0.7)
                            }
                            onExited: {
                                parent.scale = 1.0
                                parent.color = Qt.rgba(14/255, 14/255, 32/255, 0.65)
                            }
                            onClicked: {
                                taskSwitcher.switchToApp(appData.appId)
                            }

                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }

                        // === Close animation ===
                        SequentialAnimation {
                            id: closeAnim
                            ParallelAnimation {
                                NumberAnimation {
                                    target: appCard; property: "opacity"
                                    to: 0; duration: 200
                                }
                                NumberAnimation {
                                    target: appCard; property: "scale"
                                    to: 0.5; duration: 200
                                }
                                NumberAnimation {
                                    target: appCard; property: "height"
                                    to: 0; duration: 200
                                }
                            }
                            ScriptAction {
                                script: {
                                    taskSwitcher.closeApp(appData.appId)
                                }
                            }
                        }

                        // === Drop shadow ===
                        layer.enabled: true
                        layer.effect: DropShadowEffect {
                            radius: 32
                            samples: 64
                            color: Qt.rgba(0/255, 0/255, 0/255, 0.4)
                            horizontalOffset: 0
                            verticalOffset: 12
                        }
                    }
                }
            }
        }
    }

    // === Empty state ===
    Item {
        anchors.centerIn: parent
        visible: openApps.length === 0
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⬡"
                color: Qt.rgba(255/255, 255/255, 255/255, 0.15)
                font.pixelSize: 48
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "没有打开的应用"
                color: Qt.rgba(255/255, 255/255, 255/255, 0.2)
                font.pixelSize: 14
            }
        }
    }

    // === Home indicator (always visible in switcher) ===
    Rectangle {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: 124; height: 5; radius: 2.5
        color: Qt.rgba(255/255, 255/255, 255/255, 0.4)
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
    }

    // === Show / Hide animations ===
    function show() {
        visible = true
        backdrop.opacity = 1.0
        cardsFlick.opacity = 1.0
        switcherHeader.opacity = 1.0
        closeHint.opacity = 1.0
    }

    function hide() {
        backdrop.opacity = 0.0
        cardsFlick.opacity = 0.0
        switcherHeader.opacity = 0.0
        closeHint.opacity = 0.0

        animateOut.start()
    }

    SequentialAnimation {
        id: animateOut
        PauseAnimation { duration: 250 }
        ScriptAction {
            script: {
                taskSwitcher.visible = false
            }
        }
    }

    // Reset visibility on visible change
    onVisibleChanged: {
        if (!visible) {
            backdrop.opacity = 0
            cardsFlick.opacity = 0
            switcherHeader.opacity = 0
            closeHint.opacity = 0
        }
    }
}
