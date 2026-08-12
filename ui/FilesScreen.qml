// YUNSH OS 4.0 — native Linux Files app

import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.folderlistmodel 2.15

Rectangle {
    id: filesScreen
    anchors.fill: parent
    color: "transparent"

    property url currentFolder: "file:///home/yunsh"
    property var folderStack: []
    property string statusText: ""
    signal backToHome()
    signal androidAppInstalled()

    function installLinuxFile(url) {
        var path = decodeURIComponent(String(url).replace(/^file:\/\//, ""))
        statusText = "正在安装 Linux 应用…"
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 620000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var result = JSON.parse(xhr.responseText || "{}")
                statusText = result.status === "ok"
                    ? (result.message || "Linux 应用已处理")
                    : (result.message || "Linux 应用处理失败")
            } catch (error) {
                statusText = "无法连接 Linux 安装服务"
            }
            statusTimer.restart()
        }
        xhr.send(JSON.stringify({action: "install_linux_file", path: path}))
    }

    function enterFolder(url) {
        folderStack.push(currentFolder)
        currentFolder = url
    }

    function goUp() {
        if (folderStack.length > 0)
            currentFolder = folderStack.pop()
        else
            backToHome()
    }

    function openDownloads() {
        folderStack = []
        currentFolder = "file:///home/yunsh/Downloads"
    }

    function installApk(url) {
        var path = decodeURIComponent(String(url).replace(/^file:\/\//, ""))
        statusText = "正在安装 Android 应用…"
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 190000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var result = JSON.parse(xhr.responseText || "{}")
                statusText = result.status === "ok"
                    ? "安装完成，桌面正在刷新"
                    : (result.message || "安装失败")
                if (result.status === "ok")
                    androidAppInstalled()
            } catch (error) {
                statusText = "无法连接 Android 安装服务"
            }
            statusTimer.restart()
        }
        xhr.send(JSON.stringify({action: "install_apk", path: path}))
    }

    Timer {
        id: statusTimer
        interval: 2600
        repeat: false
        onTriggered: filesScreen.statusText = ""
    }

    FolderListModel {
        id: fileModel
        folder: filesScreen.currentFolder
        showDirsFirst: true
        showDotAndDotDot: false
        nameFilters: ["*"]
    }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Qt.rgba(250 / 255, 254 / 255, 1, 0.94)
        border.width: 1
        border.color: "#FFFFFF"
    }

    Row {
        id: toolbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 62
        spacing: 12
        padding: 16

        Button {
            text: "← 返回"
            onClicked: filesScreen.backToHome()
        }
        Button {
            text: "↑ 上一级"
            onClicked: filesScreen.goUp()
        }
        Button {
            text: "下载"
            onClicked: filesScreen.openDownloads()
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: filesScreen.currentFolder.toString().replace("file://", "")
            color: "#17212A"
            font.pixelSize: 17
            font.weight: Font.DemiBold
            elide: Text.ElideMiddle
            width: Math.max(120, toolbar.width - 190)
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: filesScreen.statusText
            color: "#00A9CC"
            font.pixelSize: 12
            elide: Text.ElideRight
            width: 220
            horizontalAlignment: Text.AlignRight
        }
    }

    ListView {
        id: fileList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 14
        clip: true
        spacing: 6
        model: fileModel

        delegate: Rectangle {
            required property int index
            width: fileList.width
            height: 52
            radius: 14
            color: itemMouse.pressed ? "#DDF8FF" : "#F5FAFC"
            border.width: 1
            border.color: "#E4F2F6"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: fileModel.isFolder(index) ? "▣" : "▤"
                color: fileModel.isFolder(index) ? "#00A9CC" : "#667783"
                font.pixelSize: 22
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 54
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: fileModel.fileName(index)
                color: "#17212A"
                font.pixelSize: 15
                elide: Text.ElideMiddle
            }
            MouseArea {
                id: itemMouse
                anchors.fill: parent
                onClicked: {
                    var url = fileModel.fileURL(index)
                    if (fileModel.isFolder(index))
                        filesScreen.enterFolder(url)
                    else if (String(fileModel.fileName(index)).toLowerCase().endsWith(".apk"))
                        filesScreen.installApk(url)
                    else if (String(fileModel.fileName(index)).toLowerCase().endsWith(".deb")
                             || String(fileModel.fileName(index)).toLowerCase().endsWith(".appimage"))
                        return
                    else
                        Qt.openUrlExternally(url)
                }
                onDoubleClicked: {
                    var name = String(fileModel.fileName(index)).toLowerCase()
                    if (!fileModel.isFolder(index)
                            && (name.endsWith(".deb") || name.endsWith(".appimage")))
                        filesScreen.installLinuxFile(fileModel.fileURL(index))
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: fileList.count === 0
            text: "此文件夹为空"
            color: "#71808A"
            font.pixelSize: 15
        }
    }
}
