// YUNSH SpaceCapsule — exportable and restorable spatial workspaces.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: capsuleScreen
    anchors.fill: parent

    property var capsules: []
    property string statusText: ""
    property bool busy: false
    property bool reduceMotion: false

    signal backToHome()
    signal workspaceExportRequested(string name)
    signal restoreRequested(var capsule)

    function refreshCapsules() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8591/api/space-capsules", true)
        xhr.timeout = 1500
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var data = JSON.parse(xhr.responseText)
                if (data.success)
                    capsules = data.capsules || []
                else
                    statusText = data.error || "无法读取空间胶囊"
            } catch (error) {
                statusText = "无法连接本地空间胶囊服务"
            }
        }
        xhr.send()
    }

    function exportWorkspace(snapshot, name) {
        if (busy)
            return
        busy = true
        statusText = "正在打包当前工作空间…"
        snapshot.action = "export"
        snapshot.name = name
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/space-capsules", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 2500
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            busy = false
            try {
                var data = JSON.parse(xhr.responseText)
                if (data.success) {
                    statusText = "已导出到 Downloads，可转发 " + data.filename
                    capsuleName.text = ""
                    refreshCapsules()
                } else {
                    statusText = data.error || "导出失败"
                }
            } catch (error) {
                statusText = "无法连接本地空间胶囊服务"
            }
        }
        xhr.send(JSON.stringify(snapshot))
    }

    function loadCapsule(filename) {
        if (busy)
            return
        busy = true
        statusText = "正在验证空间胶囊…"
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/space-capsules", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 2000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            busy = false
            try {
                var data = JSON.parse(xhr.responseText)
                if (data.success) {
                    statusText = "正在恢复 " + data.capsule.name
                    capsuleScreen.restoreRequested(data.capsule)
                } else {
                    statusText = data.error || "无法恢复空间胶囊"
                }
            } catch (error) {
                statusText = "空间胶囊格式无效"
            }
        }
        xhr.send(JSON.stringify({action: "load", filename: filename}))
    }

    Component.onCompleted: refreshCapsules()
    onVisibleChanged: {
        if (visible)
            refreshCapsules()
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        Row {
            width: parent.width
            height: 36

            Rectangle {
                width: 82
                height: 32
                radius: 16
                color: backArea.pressed
                    ? Qt.rgba(0/255, 212/255, 255/255, 0.22)
                    : Qt.rgba(0/255, 212/255, 255/255, 0.11)
                Text {
                    anchors.centerIn: parent
                    text: "← 返回"
                    color: "#00D4FF"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    onClicked: capsuleScreen.backToHome()
                }
            }

            Item { width: parent.width - 164; height: 1 }

            Rectangle {
                width: 82
                height: 32
                radius: 16
                color: refreshArea.pressed
                    ? Qt.rgba(255/255, 255/255, 255/255, 0.10)
                    : Qt.rgba(255/255, 255/255, 255/255, 0.045)
                Text {
                    anchors.centerIn: parent
                    text: "刷新"
                    color: "#BFC0D0"
                    font.pixelSize: 13
                }
                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    onClicked: capsuleScreen.refreshCapsules()
                }
            }
        }

        Text {
            text: "SpaceCapsule"
            color: "#FFFFFF"
            font.pixelSize: 26
            font.weight: Font.DemiBold
            font.letterSpacing: -0.3
        }

        Text {
            width: parent.width
            text: "把打开的应用、窗口尺寸、空间位置和固定方式保存为一个 .yunshspace 文件。复制到另一台 YUNSH 设备的 Downloads 后即可恢复。"
            color: Qt.rgba(255/255, 255/255, 255/255, 0.50)
            font.pixelSize: 12
            lineHeight: 1.35
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent.width
            height: 72
            radius: 20
            color: Qt.rgba(255/255, 255/255, 255/255, 0.045)
            border.width: 1
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.07)

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Rectangle {
                    width: parent.width - 194
                    height: 46
                    radius: 14
                    color: Qt.rgba(0/255, 0/255, 0/255, 0.22)
                    border.width: 1
                    border.color: capsuleName.activeFocus
                        ? Qt.rgba(0/255, 212/255, 255/255, 0.55)
                        : Qt.rgba(255/255, 255/255, 255/255, 0.07)
                    EditableInput {
                        id: capsuleName
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#FFFFFF"
                        font.pixelSize: 14
                        placeholderText: "空间名称，例如：学习空间"
                        placeholderTextColor: Qt.rgba(255/255, 255/255, 255/255, 0.25)
                    }
                }

                Rectangle {
                    width: 160
                    height: 46
                    radius: 23
                    color: exportArea.pressed
                        ? Qt.rgba(0/255, 212/255, 255/255, 0.30)
                        : Qt.rgba(0/255, 212/255, 255/255, 0.17)
                    border.width: 1
                    border.color: Qt.rgba(0/255, 212/255, 255/255, 0.34)
                    Text {
                        anchors.centerIn: parent
                        text: capsuleScreen.busy ? "处理中…" : "保存并导出"
                        color: "#00D4FF"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: exportArea
                        anchors.fill: parent
                        enabled: !capsuleScreen.busy
                        onClicked: capsuleScreen.workspaceExportRequested(capsuleName.text)
                    }
                }
            }
        }

        Text {
            text: capsuleScreen.statusText
            visible: text.length > 0
            width: parent.width
            color: text.indexOf("无法") === 0 || text.indexOf("失败") >= 0
                ? "#FF8A80" : "#7BE7FF"
            font.pixelSize: 12
            elide: Text.ElideMiddle
        }

        Text {
            text: "可恢复的空间"
            color: "#8888A0"
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        ScrollView {
            width: parent.width
            height: parent.height - 258
            clip: true

            Column {
                width: capsuleScreen.width - 48
                spacing: 8

                Text {
                    width: parent.width
                    visible: capsuleScreen.capsules.length === 0
                    text: "Downloads 中还没有空间胶囊"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.30)
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 36
                }

                Repeater {
                    model: capsuleScreen.capsules

                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 76
                        radius: 18
                        color: capsuleArea.pressed
                            ? Qt.rgba(255/255, 255/255, 255/255, 0.085)
                            : Qt.rgba(255/255, 255/255, 255/255, 0.045)
                        border.width: 1
                        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.07)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 14
                                color: Qt.rgba(0/255, 212/255, 255/255, 0.13)
                                Image {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    source: "/usr/share/yunsh/icons/files.svg"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 168
                                spacing: 4
                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.windowCount + " 个窗口 · " + modelData.filename
                                    color: Qt.rgba(255/255, 255/255, 255/255, 0.35)
                                    font.pixelSize: 10
                                    elide: Text.ElideMiddle
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 82
                                height: 34
                                radius: 17
                                color: Qt.rgba(0/255, 212/255, 255/255, 0.14)
                                Text {
                                    anchors.centerIn: parent
                                    text: "恢复"
                                    color: "#00D4FF"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        MouseArea {
                            id: capsuleArea
                            anchors.fill: parent
                            enabled: !capsuleScreen.busy
                            onClicked: capsuleScreen.loadCapsule(modelData.filename)
                        }

                        Behavior on color {
                            ColorAnimation { duration: capsuleScreen.reduceMotion ? 60 : 140 }
                        }
                    }
                }
            }
        }
    }
}
