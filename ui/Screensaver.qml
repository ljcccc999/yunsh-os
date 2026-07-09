// YUNSH OS v1.0 - Screensaver / Standby Screen (visionOS Style)
// Large clock, YUNSH branding, ambient glow. Click to wake.

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: screensaver
    anchors.fill: parent
    color: "#000000"  // Pure black = transparent in AR
    visible: false
    z: 400

    property string currentTime: "00:00"
    property string currentDate: ""

    signal wake()

    // ─── Clock timer ──────────────────────────────
    Timer {
        interval: 1000
        running: screensaver.visible
        repeat: true
        onTriggered: {
            var d = new Date()
            currentTime = d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
            currentDate = d.toLocaleDateString(Qt.locale("zh_CN"), "yyyy年M月d日 dddd")
        }
    }

    // ─── Ambient glow (visionOS atmospheric) ──────
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.5
        height: parent.height * 0.3
        radius: width / 2
        color: Qt.rgba(0/255, 100/255, 255/255, 0.02)
    }

    // ─── Center content ───────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 12

        // Large clock (visionOS style)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: currentTime
            color: Qt.rgba(255/255, 255/255, 255/255, 0.35)
            font.pixelSize: 96
            font.weight: Font.Light
            font.letterSpacing: 4
        }

        // Date
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: currentDate
            color: Qt.rgba(255/255, 255/255, 255/255, 0.12)
            font.pixelSize: 16
            font.weight: Font.Light
        }
    }

    // ─── YUNSH branding at bottom ────────────────
    Row {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        opacity: 0.08

        Image {
            source: "/usr/share/yunsh/logo/logo-32.png"
            width: 16; height: 16
            sourceSize.width: 32; sourceSize.height: 32
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "YUNSH OS"
            color: "#FFFFFF"
            font.pixelSize: 12
            font.letterSpacing: 2
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "v1.0.0"
            color: Qt.rgba(255/255, 255/255, 255/255, 0.3)
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ─── "点击唤醒" hint ─────────────────────────
    Text {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        text: "点击唤醒"
        color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
        font.pixelSize: 11
    }

    // ─── Click to wake ────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        onClicked: {
            screensaver.wake()
        }

        // Also wake on mouse move
        onMouseXChanged: screensaver.wake()
        onMouseYChanged: screensaver.wake()
    }

    // ─── Shortcut: any key wakes ──────────────────
    Keys.onPressed: screensaver.wake()

    // ─── Show/hide animation ──────────────────────
    Behavior on opacity {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    function show() {
        opacity = 0
        visible = true
        opacity = 1
        // Force clock update
        var d = new Date()
        currentTime = d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
        currentDate = d.toLocaleDateString(Qt.locale("zh_CN"), "yyyy年M月d日 dddd")
    }

    function hideScreen() {
        opacity = 0
        Qt.callLater(function() { visible = false })
    }
}
