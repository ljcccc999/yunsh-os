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
    property string searchText: ""
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
        color: "#F5F7FA"
        border.width: 1
        border.color: "#DCE3EA"
    }

    // Finder-style sidebar: stable places are always one click away.
    Rectangle {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 190
        radius: 24
        color: "#EEF2F6"
        clip: true

        Text { x: 22; y: 24; text: "位置"; color: "#73808C"; font.pixelSize: 12; font.bold: true }
        Column {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.topMargin: 52
            spacing: 4
            Repeater {
                model: [
                    {label: "主文件夹", icon: "⌂", path: "file:///home/yunsh"},
                    {label: "桌面", icon: "▦", path: "file:///home/yunsh/Desktop"},
                    {label: "下载", icon: "↓", path: "file:///home/yunsh/Downloads"},
                    {label: "图片", icon: "▧", path: "file:///home/yunsh/Pictures"}
                ]
                delegate: Rectangle {
                    width: sidebar.width - 20; height: 38; radius: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: String(filesScreen.currentFolder) === modelData.path
                        ? "#D7F5FC" : "transparent"
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; color: "#008EAA"; font.pixelSize: 17 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "#23313C"; font.pixelSize: 13 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { folderStack = []; currentFolder = modelData.path } }
                }
            }
        }
    }

    Row {
        id: toolbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 62
        spacing: 12
        padding: 16
        anchors.leftMargin: sidebar.width

        GlassButton {
            width: 70; height: 34
            bgColor: Qt.rgba(1, 1, 1, 0.78)
            onClicked: filesScreen.backToHome()
            Text { anchors.centerIn: parent; text: "←"; color: "#344552"; font.pixelSize: 18 }
        }
        GlassButton {
            width: 70; height: 34
            bgColor: Qt.rgba(1, 1, 1, 0.78)
            onClicked: filesScreen.goUp()
            Text { anchors.centerIn: parent; text: "↑"; color: "#344552"; font.pixelSize: 18 }
        }
        GlassButton {
            width: 78; height: 34
            bgColor: Qt.rgba(0, 212/255, 1, 0.18)
            onClicked: filesScreen.openDownloads()
            Text { anchors.centerIn: parent; text: "下载"; color: "#007E9A"; font.pixelSize: 12 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: filesScreen.currentFolder.toString().replace("file://", "")
            color: "#17212A"
            font.pixelSize: 17
            font.weight: Font.DemiBold
            elide: Text.ElideMiddle
            width: Math.max(120, toolbar.width - 430)
        }
        Rectangle {
            width: 160; height: 30; radius: 15
            anchors.verticalCenter: parent.verticalCenter
            color: "#E8EDF2"
            TextInput {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: "#23313C"; font.pixelSize: 12
                clip: true; text: filesScreen.searchText
                onTextChanged: filesScreen.searchText = text
                Text { anchors.verticalCenter: parent.verticalCenter; text: "搜索"; color: "#94A0AA"; visible: parent.text.length === 0 }
            }
        }
    }

    // Keep the status label outside the Row.  A right anchor on a Row child
    // makes Qt Quick discard the Row's layout and produced a warning on the
    // real framebuffer path.
    Text {
        id: statusLabel
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 23
        text: filesScreen.statusText
        color: "#00A9CC"
        font.pixelSize: 12
        elide: Text.ElideRight
        width: 220
        horizontalAlignment: Text.AlignRight
    }

    ListView {
        id: fileList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 14
        anchors.leftMargin: sidebar.width + 14
        clip: true
        spacing: 6
        model: fileModel

        delegate: Rectangle {
            required property int index
            readonly property string itemName: String(fileModel.get(index, "fileName"))
            readonly property url itemUrl: fileModel.get(index, "fileUrl")
            readonly property bool itemIsFolder: fileModel.isFolder(index)
            width: fileList.width
            height: filesScreen.searchText.length > 0 &&
                    itemName.toLowerCase().indexOf(filesScreen.searchText.toLowerCase()) < 0 ? 0 : 58
            radius: 12
            color: itemMouse.pressed ? "#DDF8FF" : "#FFFFFF"
            border.width: 1
            border.color: "#E1E7EC"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: itemIsFolder ? "▰" : "▤"
                color: itemIsFolder ? "#00A9CC" : "#667783"
                font.pixelSize: 20
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 52
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: itemName
                color: "#17212A"
                font.pixelSize: 14
                elide: Text.ElideMiddle
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: itemIsFolder ? "文件夹" : "文件"
                color: "#8B98A3"; font.pixelSize: 11
            }
            MouseArea {
                id: itemMouse
                anchors.fill: parent
                onClicked: {
                    var url = itemUrl
                    if (itemIsFolder)
                        filesScreen.enterFolder(url)
                    else if (itemName.toLowerCase().endsWith(".apk"))
                        filesScreen.installApk(url)
                    else if (itemName.toLowerCase().endsWith(".deb")
                             || itemName.toLowerCase().endsWith(".appimage"))
                        return
                    else
                        Qt.openUrlExternally(url)
                }
                onDoubleClicked: {
                    var name = itemName.toLowerCase()
                    if (!itemIsFolder
                            && (name.endsWith(".deb") || name.endsWith(".appimage")))
                        filesScreen.installLinuxFile(itemUrl)
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
