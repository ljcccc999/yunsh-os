// YUNSH OS v1.0 - System Information Screen (visionOS Style)
// Shows detailed system info: OS version, memory, storage, CPU, display

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: systemInfoScreen
    anchors.fill: parent
    color: "transparent"
    visible: false
    z: 60

    property string osVersion: "YUNSH OS v1.0.1"
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

    // Read a text file synchronously via file://
    function readFile(path) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + path, false)  // synchronous
        try {
            xhr.send()
            if (xhr.status === 0 || xhr.status === 200) {
                return xhr.responseText
            }
        } catch(e) {}
        return ""
    }

    function humanSize(bytes) {
        if (bytes < 0) return "?"
        var units = ["B", "KB", "MB", "GB", "TB"]
        var i = 0
        var size = bytes
        while (size >= 1024 && i < units.length - 1) {
            size /= 1024
            i++
        }
        return size.toFixed(i > 0 ? 1 : 0) + " " + units[i]
    }

    function loadSystemInfo() {
        // Version config
        var versionText = readFile("/etc/yunsh/version.conf")
        if (versionText) {
            var lines = versionText.split('\n')
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (line.indexOf('VERSION=') === 0) {
                    osVersion = "YUNSH OS " + line.substring(8)
                } else if (line.indexOf('BUILD=') === 0) {
                    buildNumber = line.substring(6)
                }
            }
        }

        // Device model
        var model = readFile("/proc/device-tree/model")
        if (model) {
            deviceModel = model.replace(/\0/g, '').trim()
        }

        // CPU info
        var cpuText = readFile("/proc/cpuinfo")
        if (cpuText) {
            var cpuName = ""
            var coreCount = 0
            var cpuLines = cpuText.split('\n')
            for (var j = 0; j < cpuLines.length; j++) {
                var cl = cpuLines[j].trim()
                if (cl.indexOf("model name") === 0 || cl.indexOf("Processor") === 0) {
                    cpuName = cl.split(':')[1].trim()
                }
                if (cl.indexOf("processor") === 0) {
                    coreCount++
                }
                if (cl.indexOf("Hardware") === 0 && !cpuName) {
                    cpuName = cl.split(':')[1].trim()
                }
            }
            cpuInfo = cpuName + " × " + coreCount
        }

        // Memory
        var memText = readFile("/proc/meminfo")
        if (memText) {
            var memTotalKb = 0
            var memAvailKb = 0
            var memLines = memText.split('\n')
            for (var k = 0; k < memLines.length; k++) {
                var ml = memLines[k].trim()
                if (ml.indexOf("MemTotal:") === 0) {
                    memTotalKb = parseInt(ml.split(/\s+/)[1]) || 0
                }
                if (ml.indexOf("MemAvailable:") === 0) {
                    memAvailKb = parseInt(ml.split(/\s+/)[1]) || 0
                }
            }
            var memTotalBytes = memTotalKb * 1024
            var memUsedBytes = (memTotalKb - memAvailKb) * 1024
            memoryTotal = humanSize(memTotalBytes)
            memoryUsed = humanSize(memUsedBytes)
            memoryPct = memTotalKb > 0 ? (memTotalKb - memAvailKb) / memTotalKb : 0
        }

        // Storage (read from disk-helper JSON)
        var diskJson = readFile("/tmp/yunsh-disk-usage.json")
        if (diskJson) {
            try {
                var diskData = JSON.parse(diskJson)
                storageTotal = humanSize(diskData.total_bytes)
                storageUsed = humanSize(diskData.used_bytes)
                storagePct = diskData.used_pct / 100.0
            } catch(e) {}
        }
        // Fallback: read block device size
        if (!storageTotal) {
            var sizeStr = readFile("/sys/block/mmcblk0/size") || readFile("/sys/block/mmcblk1/size") || readFile("/sys/block/nvme0n1/size") || ""
            if (sizeStr) {
                var totalBytes = parseInt(sizeStr.trim()) * 512
                storageTotal = humanSize(totalBytes)
            }
        }

        // Kernel version
        var verText = readFile("/proc/version")
        if (verText) {
            var parts = verText.split(' ')
            // "Linux version 6.6.31+rpi-rpi-v8 ..."
            kernelVersion = parts[2] || ""
        }

        // Timer to refresh periodically
        refreshTimer.running = true
    }

    Timer {
        id: refreshTimer
        interval: 10000  // refresh every 10s
        running: false
        repeat: true
        onTriggered: {
            // Only refresh memory (fast to read)
            var mem = readFile("/proc/meminfo")
            if (mem) {
                var mt = 0, ma = 0
                var mlines = mem.split('\n')
                for (var i = 0; i < mlines.length; i++) {
                    var l = mlines[i].trim()
                    if (l.indexOf("MemTotal:") === 0) mt = parseInt(l.split(/\s+/)[1]) || 0
                    if (l.indexOf("MemAvailable:") === 0) ma = parseInt(l.split(/\s+/)[1]) || 0
                }
                if (mt > 0) {
                    memoryUsed = humanSize((mt - ma) * 1024)
                    memoryPct = (mt - ma) / mt
                }
            }
        }
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
            color: "#FFFFFF"; font.pixelSize: 20; font.weight: Font.Bold
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
                color: Qt.rgba(255/255, 255/255, 255/255, 0.06)

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
                color: Qt.rgba(255/255, 255/255, 255/255, 0.06)

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
        color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
        border.width: 1

        property alias title: titleText.text
        property alias value: valueText.text

        Text {
            id: titleText
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(255/255, 255/255, 255/255, 0.6)
            font.pixelSize: 14
        }

        Text {
            id: valueText
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: "#FFFFFF"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
}
