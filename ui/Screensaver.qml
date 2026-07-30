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
    // Smart wake is the default: an automatic display-off can be resumed
    // immediately. Explicit locking switches this to password-required.
    property bool passwordRequired: false
    property bool unlockBusy: false
    property string unlockError: ""

    signal wake()
    signal unlocked()

    function attemptUnlock() {
        if (unlockBusy || unlockPassword.text.length === 0)
            return
        unlockBusy = true
        unlockError = ""
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/verify-boot-password", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 6000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            unlockBusy = false
            try {
                var result = JSON.parse(xhr.responseText || "{}")
                if (xhr.status === 200 && result.success) {
                    unlockPassword.text = ""
                    unlockError = ""
                    screensaver.unlocked()
                } else {
                    unlockError = result.error || "本机密码不正确"
                    unlockPassword.text = ""
                    unlockPassword.forceActiveFocus()
                }
            } catch (error) {
                unlockError = "解锁服务暂时不可用"
            }
        }
        xhr.send(JSON.stringify({password: unlockPassword.text}))
    }

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
            text: "v2.0.1"
            color: Qt.rgba(255/255, 255/255, 255/255, 0.3)
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ─── "点击唤醒" hint ─────────────────────────
    Text {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        text: passwordRequired ? "输入本机密码以解锁" : "点击唤醒"
        color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
        font.pixelSize: 11
    }

    // ─── Click to wake ────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        enabled: !passwordRequired
        onClicked: {
            screensaver.wake()
        }

    }

    // ─── Local unlock panel ──────────────────────────
    Rectangle {
        id: unlockPanel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 130
        width: 390; height: 152; radius: 28
        visible: passwordRequired
        color: Qt.rgba(1, 1, 1, 0.88)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.95)

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8
            Text {
                text: "本机已锁定"
                color: "#101820"; font.pixelSize: 16; font.weight: Font.DemiBold
            }
            Rectangle {
                width: parent.width; height: 42; radius: 13
                color: Qt.rgba(20/255, 35/255, 50/255, 0.08)
                border.width: 1
                border.color: unlockPassword.activeFocus ? "#00AEE6" : Qt.rgba(20/255, 35/255, 50/255, 0.12)
                TextInput {
                    id: unlockPassword
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                    enabled: !unlockBusy
                    focus: screensaver.visible && passwordRequired
                    color: "#101820"; font.pixelSize: 16
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    clip: true
                    onAccepted: screensaver.attemptUnlock()
                }
            }
            Row {
                width: parent.width
                spacing: 10
                Text { text: unlockError; color: "#C62828"; font.pixelSize: 12; width: 205; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: 130; height: 32; radius: 16
                    color: "#00B8E8"
                    opacity: unlockPassword.text.length > 0 && !unlockBusy ? 1 : 0.45
                    Text { anchors.centerIn: parent; text: unlockBusy ? "正在解锁…" : "解锁"; color: "#FFFFFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; enabled: unlockPassword.text.length > 0 && !unlockBusy; onClicked: screensaver.attemptUnlock() }
                }
            }
        }
    }

    Keys.onPressed: function(event) {
        if (!passwordRequired) screensaver.wake()
    }

    // ─── Show/hide animation ──────────────────────
    // Apple: prefers-reduced-motion → short opacity cross-fade, no slide/spring
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    function show() {
        if (Qt.application.layoutDirection === Qt.RightToLeft) {
            // Fallback for accessibility
        }
        opacity = 0
        visible = true
        if (passwordRequired) {
            unlockError = ""
            Qt.callLater(function() { unlockPassword.forceActiveFocus() })
        }
        // Quick fade in for reduced-motion compatibility (Apple: keep opacity/color changes)
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

    // Reduced-motion: avoid full-viewport moving backgrounds (Apple guideline)
    // Screensaver uses static clock + subtle fade, no sliding/spring/pulse
    // This is intentional — moving backgrounds trigger vestibular issues
    readonly property bool reducedMotion: true  // intrinsic to screensaver design
}
