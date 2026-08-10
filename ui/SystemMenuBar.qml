// Global YUNSH system menu bar. It remains above apps and the world layer.

import QtQuick 2.15

Rectangle {
    id: menuBar
    height: 70
    color: "transparent"
    border.width: 0

    property bool orbitConfigured: false
    property bool orbitBusy: false
    property bool orbitAwaitingApproval: false
    property bool orbitApprovalCanAlways: false
    property bool orbitVoiceActive: false
    property string orbitActivityText: ""
    property bool reduceMotion: false
    property bool recordingActive: false
    signal openSystemMenu()
    signal openWorld()
    signal openOrbit()
    signal orbitApprovalDecision(string decision)

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 112
        height: 42
        radius: 21
        color: leftMouse.pressed ? "#DDF8FF" : Qt.rgba(1, 1, 1, 0.72)
        border.width: 1
        border.color: "#FFFFFF"
        scale: leftMouse.pressed ? 0.96 : (leftMouse.containsMouse ? 1.04 : 1)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 19
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.16)
        }

        Row {
            anchors.centerIn: parent
            spacing: 8
            Image {
                source: "/usr/share/yunsh/logo/logo-32.png"
                width: 25; height: 25
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "YUNSH"
                color: "#121820"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 7; height: 7; radius: 4
                color: "#E43A45"
                visible: menuBar.recordingActive
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: leftMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: menuBar.openSystemMenu()
        }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: worldPortal
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 72
        height: 62
        radius: 28
        color: worldMouse.pressed
            ? Qt.rgba(221/255, 248/255, 255/255, 0.90)
            : (worldMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.82) : Qt.rgba(1, 1, 1, 0.72))
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.94)
        scale: worldMouse.pressed ? 0.94 : (worldMouse.containsMouse ? 1.06 : 1)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 27
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.24)
        }

        Column {
            anchors.centerIn: parent
            spacing: 2
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 30
                height: 30
                radius: 15
                color: Qt.rgba(1, 1, 1, 0.88)
                Image {
                    anchors.centerIn: parent
                    source: "/usr/share/yunsh/logo/logo-32.png"
                    width: 20; height: 20
                    fillMode: Image.PreserveAspectFit
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "METAVERSE"
                color: "#17212A"
                font.pixelSize: 7
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }
        }
        MouseArea {
            id: worldMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: menuBar.openWorld()
        }
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    Rectangle {
        id: orbitEntry
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: orbitAwaitingApproval ? 330 : (orbitBusy ? 202 : 50)
        height: 50
        radius: 25
        color: orbitMouse.pressed ? "#DDF8FF" : Qt.rgba(1, 1, 1, 0.72)
        border.width: 1
        border.color: "#FFFFFF"
        scale: orbitMouse.pressed ? 0.96 : (orbitMouse.containsMouse ? 1.04 : 1)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 23
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.16)
        }

        Item {
            // The icon never moves: the status island grows leftward from this
            // original round Orbit control, which stays pinned at the right.
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 31
            height: 31
            opacity: orbitVoiceActive ? 0 : 1
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#101010"
            }
            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                color: "#F7F9FA"
            }
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 10
                color: "#F7F9FA"
            }
        }
        // Speaking/listening state: a restrained, original wave glyph replaces
        // the idle O while voice chat is active.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: 31
            height: 24
            spacing: 3
            opacity: orbitVoiceActive ? 1 : 0
            // Item has a uniform `scale` property only. Keep the intended
            // vertical wave reveal with a Scale transform; `scaleY` would
            // prevent main.qml from loading on Qt 6.
            transform: Scale {
                origin.x: parent.width / 2
                origin.y: parent.height
                yScale: orbitVoiceActive ? 1 : 0.05
                Behavior on yScale { NumberAnimation { duration: menuBar.reduceMotion ? 80 : 280; easing.type: Easing.OutCubic } }
            }
            z: 3
            Repeater {
                model: 5
                delegate: Rectangle {
                    width: 3
                    height: 10 + index * 3
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: index === 2 ? "#00A9C8" : "#1B5E76"
                    SequentialAnimation on height {
                        loops: Animation.Infinite
                        running: orbitVoiceActive && !menuBar.reduceMotion
                        NumberAnimation { to: 8 + ((index + 2) % 4) * 5; duration: 220 + index * 35; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 10 + index * 3; duration: 220 + index * 35; easing.type: Easing.InOutSine }
                    }
                }
            }
            Behavior on opacity { NumberAnimation { duration: menuBar.reduceMotion ? 80 : 180; easing.type: Easing.OutCubic } }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 58
            anchors.verticalCenter: parent.verticalCenter
            text: orbitAwaitingApproval ? "等待确认" : (orbitActivityText || "Orbit 正在执行")
            color: "#162029"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            visible: orbitBusy && !orbitAwaitingApproval
        }
        MouseArea {
            id: orbitMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: menuBar.openOrbit()
        }
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            visible: orbitAwaitingApproval
            z: 4

            Repeater {
                model: orbitApprovalCanAlways ? ["拒绝", "本次允许", "始终允许"]
                                               : ["拒绝", "本次允许"]
                delegate: Rectangle {
                    width: modelData === "本次允许" ? 66 : (modelData === "始终允许" ? 66 : 42)
                    height: 30
                    radius: 15
                    color: modelData === "拒绝"
                        ? Qt.rgba(0.92, 0.95, 0.97, 0.78)
                        : (modelData === "始终允许"
                           ? Qt.rgba(0.05, 0.45, 0.58, 0.92)
                           : Qt.rgba(0.10, 0.76, 0.88, 0.92))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.8)
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: modelData === "拒绝" ? "#17232B" : "white"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: parent.scale = 0.95
                        onReleased: parent.scale = 1
                        onCanceled: parent.scale = 1
                        onClicked: menuBar.orbitApprovalDecision(
                            modelData === "拒绝" ? "deny"
                            : (modelData === "始终允许" ? "always" : "once"))
                    }
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                }
            }
        }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Behavior on width {
            enabled: !menuBar.reduceMotion
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }
}
