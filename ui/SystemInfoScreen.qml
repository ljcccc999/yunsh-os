// YUNSH OS v1.0 - System Information Screen (visionOS Style)
// Shows detailed system info: OS version, memory, storage, CPU, display

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: systemInfoScreen
    anchors.fill: parent
    color: "transparent"
    visible: true
    z: 60

    property string osVersion: "YUNSH OS v3.1.2"
    property string buildNumber: ""
    property string deviceModel: ""
    property string cpuInfo: ""
    property string memoryTotal: ""
    property string memoryUsed: ""
    property real memoryPct: 0
    property string storageTotal: ""
    property string storageUsed: ""
    property real storagePct: 0
    property string displayRes: "1920 × 1080"
    property string displayRefresh: "60 Hz"
    property string kernelVersion: ""

    signal backToSettings()

    function loadSystemInfo() {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 3000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return
            try {
                var values = JSON.parse(xhr.responseText || "{}")
                osVersion = "YUNSH OS " + (values.version || "v3.1.2")
                buildNumber = values.build || ""
                deviceModel = values.model || "Raspberry Pi"
                cpuInfo = values.cpu || "ARM processor"
                memoryTotal = values.memoryTotal || "?"
                memoryUsed = values.memoryUsed || "?"
                memoryPct = values.memoryPct || 0
                storageTotal = values.storageTotal || "?"
                storageUsed = values.storageUsed || "?"
                storagePct = values.storagePct || 0
                kernelVersion = values.kernel || ""
            } catch (_error) {}
        }
        xhr.send(JSON.stringify({action: "system_info"}))
        refreshTimer.running = true
    }

    Timer {
        id: refreshTimer
        interval: 10000  // refresh every 10s
        running: false
        repeat: true
        onTriggered: loadSystemInfo()
    }

    Component.onCompleted: loadSystemInfo()

    // Header
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "transparent"

        // Back capsule
        Rectangle {
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 80; height: 32; radius: 16
            color: Qt.rgba(0/255, 212/255, 255/255, 0.1)
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
            border.width: 1

            Text {
                anchors.centerIn: parent; text: "← 返回"
                color: "#00D4FF"; font.pixelSize: 14; font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.2)
                onExited: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.1)
                onClicked: systemInfoScreen.backToSettings()
            }
        }

        Text {
            anchors.centerIn: parent; text: "关于本机"
            color: "#17212A"; font.pixelSize: 20; font.weight: Font.Bold
        }
    }

    // Scrollable content
    Flickable {
        anchors.top: parent.top; anchors.topMargin: 60
        anchors.left: parent.left; anchors.leftMargin: 40
        anchors.right: parent.right; anchors.rightMargin: 40
        anchors.bottom: parent.bottom; anchors.bottomMargin: 16
        contentHeight: infoColumn.height + 32
        clip: true

        Column {
            id: infoColumn
            width: parent.width
            spacing: 2

            // ── Section: YUNSH OS ──
            Text {
                text: "YUNSH OS"
                color: "#8888A0"; font.pixelSize: 13; font.weight: Font.Medium
                leftPadding: 16; bottomPadding: 6; topPadding: 12
            }

            InfoRow { title: "系统名称"; value: "YUNSH OS" }
            InfoRow { title: "版本"; value: osVersion }
            InfoRow { title: "版本号"; value: buildNumber }
            InfoRow { title: "内核版本"; value: kernelVersion }

            // ── Section: 设备 ──
            Text {
                text: "设备"
                color: "#8888A0"; font.pixelSize: 13; font.weight: Font.Medium
                leftPadding: 16; bottomPadding: 6; topPadding: 20
            }

            InfoRow { title: "型号"; value: deviceModel }
            InfoRow { title: "处理器"; value: cpuInfo }

            // ── Section: 内存 ──
            Text {
                text: "内存"
                color: "#8888A0"; font.pixelSize: 13; font.weight: Font.Medium
                leftPadding: 16; bottomPadding: 6; topPadding: 20
            }

            InfoRow { title: "总内存"; value: memoryTotal }
            InfoRow { title: "已用内存"; value: memoryUsed }

            // Memory usage bar
            Rectangle {
                width: parent.width - 32
                height: 6; radius: 3
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(70/255, 88/255, 102/255, 0.18)

                Rectangle {
                    width: parent.width * Math.min(memoryPct, 1.0)
                    height: parent.height; radius: 3
                    color: memoryPct > 0.8 ? "#FF453A" : (memoryPct > 0.6 ? "#FFD60A" : "#00D4FF")
                }
            }

            // ── Section: 存储 ──
            Text {
                text: "存储"
                color: "#8888A0"; font.pixelSize: 13; font.weight: Font.Medium
                leftPadding: 16; bottomPadding: 6; topPadding: 20
            }

            InfoRow { title: "总容量"; value: storageTotal }
            InfoRow { title: "已使用"; value: storageUsed }

            // Storage bar
            Rectangle {
                width: parent.width - 32
                height: 6; radius: 3
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(70/255, 88/255, 102/255, 0.18)

                Rectangle {
                    width: parent.width * Math.min(storagePct, 1.0)
                    height: parent.height; radius: 3
                    color: storagePct > 0.8 ? "#FF453A" : (storagePct > 0.6 ? "#FFD60A" : "#00E676")
                }
            }

            // ── Section: 显示 ──
            Text {
                text: "显示"
                color: "#8888A0"; font.pixelSize: 13; font.weight: Font.Medium
                leftPadding: 16; bottomPadding: 6; topPadding: 20
            }

            InfoRow { title: "分辨率"; value: displayRes }
            InfoRow { title: "刷新率"; value: displayRefresh }
            InfoRow { title: "输出"; value: "HDMI (AR Glasses)" }

            // ── Section: 法律信息 ──
            Text {
                text: "法律信息"
                color: "#8888A0"; font.pixelSize: 13; font.weight: Font.Medium
                leftPadding: 16; bottomPadding: 6; topPadding: 20
            }

            InfoRow { title: "许可证"; value: "GPL v3 / Proprietary" }
            InfoRow { title: "版权"; value: "© 2026 YUNSH" }

            // Bottom padding
            Item { width: 1; height: 24 }
        }
    }

    // ── Reusable Info Row Component ──
    component InfoRow: Rectangle {
        width: parent.width
        height: 48
        radius: 12
        color: Qt.rgba(255/255, 255/255, 255/255, 0.62)
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.86)
        border.width: 1

        property alias title: titleText.text
        property alias value: valueText.text

        Text {
            id: titleText
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: "#61707C"
            font.pixelSize: 14
        }

        Text {
            id: valueText
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: "#17212A"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }

}
