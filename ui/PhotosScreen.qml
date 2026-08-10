// YUNSH OS v1.0 - Photos Screen (visionOS style)
// iOS Photos-like grid, full-screen viewer, glass UI

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.folderlistmodel 2.15

Rectangle {
    id: photosScreen
    anchors.fill: parent
    color: "transparent"
    z: 60
    
    property string photosDir: "file:///home/yunsh/Pictures/Screenshots"
    property string activeFolder: photosDir
    property string activeAlbum: "photos" // photos, albums, deleted, hidden
    property bool showGrid: true
    property string currentPhoto: ""
    property bool deleteConfirmationVisible: false
    property bool hiddenUnlockVisible: false
    property string hiddenUnlockError: ""
    
    signal backToHome()

    function manageCurrentPhoto(mode) {
        if (currentPhoto.length === 0)
            return
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var result = JSON.parse(xhr.responseText)
                if (result.status === "ok") {
                    currentPhoto = ""
                    showGrid = true
                    headerText.text = activeAlbum === "deleted" ? "最近删除" : (activeAlbum === "hidden" ? "隐藏" : "照片")
                }
            } catch (error) {}
        }
        xhr.send(JSON.stringify({
            action: "delete_screenshot",
            path: currentPhoto,
            mode: mode
        }))
    }

    function openAlbum(name) {
        if (name === "hidden") {
            hiddenUnlockError = ""
            hiddenUnlockVisible = true
            Qt.callLater(function() { hiddenPassword.forceActiveFocus() })
            return
        }
        activeAlbum = name
        showGrid = true
        if (name === "deleted") {
            activeFolder = photosDir + "/.RecentlyDeleted"
            headerText.text = "最近删除"
        } else if (name === "hidden") {
            activeFolder = photosDir + "/.Hidden"
            headerText.text = "隐藏"
        } else {
            activeFolder = photosDir
            headerText.text = "照片"
        }
    }

    function verifyHiddenUnlock() {
        if (!hiddenPassword.text.length)
            return
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/verify-boot-password", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var result = JSON.parse(xhr.responseText || "{}")
                if (xhr.status === 200 && result.success) {
                    hiddenUnlockVisible = false
                    hiddenPassword.text = ""
                    activeAlbum = "hidden"
                    activeFolder = photosDir + "/.Hidden"
                    showGrid = true
                    headerText.text = "隐藏"
                    return
                }
                hiddenUnlockError = result.error || "本机密码不正确"
                hiddenPassword.selectAll()
                hiddenPassword.forceActiveFocus()
            } catch (error) {
                hiddenUnlockError = "解锁服务暂时不可用"
            }
        }
        xhr.send(JSON.stringify({password: hiddenPassword.text}))
    }
    
    // ─── Header ────────────────────────────────────
    Rectangle {
        anchors.fill: parent; z: 110
        visible: hiddenUnlockVisible
        color: Qt.rgba(0, 0, 0, 0.48)
        Rectangle {
            anchors.centerIn: parent; width: 430; height: 230; radius: 30
            color: Qt.rgba(250/255, 254/255, 1, 0.98); border.width: 1; border.color: "#FFFFFF"
            Column {
                anchors.fill: parent; anchors.margins: 24; spacing: 14
                Text { text: "隐藏相册已锁定"; color: "#17212A"; font.pixelSize: 19; font.weight: Font.DemiBold }
                Text { text: "请输入本机密码后查看隐藏照片"; color: "#61707C"; font.pixelSize: 13 }
                TextInput {
                    id: hiddenPassword
                    width: parent.width; height: 42
                    echoMode: TextInput.Password; passwordCharacter: "●"
                    color: "#17212A"; font.pixelSize: 16
                    verticalAlignment: TextInput.AlignVCenter
                    onAccepted: photosScreen.verifyHiddenUnlock()
                }
                Text { text: hiddenUnlockError; color: "#C62828"; font.pixelSize: 12 }
                Row { spacing: 12; anchors.right: parent.right
                    Text { text: "取消"; color: "#61707C"; font.pixelSize: 14; MouseArea { anchors.fill: parent; onClicked: hiddenUnlockVisible = false } }
                    Text { text: "解锁"; color: "#00A9CC"; font.pixelSize: 14; MouseArea { anchors.fill: parent; onClicked: photosScreen.verifyHiddenUnlock() } }
                }
            }
        }
    }

    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "transparent"
        z: 10

        // Back button
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
                onClicked: {
                    if (!showGrid) {
                        showGrid = true
                        headerText.text = "相册"
                    } else {
                        backToHome()
                    }
                }
            }
        }

        Text {
            id: headerText
            anchors.centerIn: parent; text: "照片"
            color: "#17212A"; font.pixelSize: 20; font.weight: Font.Bold
        }

        // Photo count
        Text {
            anchors.right: parent.right; anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: gridView.count + " 张"
            color: Qt.rgba(23/255, 33/255, 42/255, 0.46)
            font.pixelSize: 13
        }
    }

    // ─── Photo Grid ────────────────────────────────
    GridView {
        id: gridView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        visible: showGrid

        cellWidth: width / 5
        cellHeight: cellWidth * 1.1
        clip: true
        interactive: true

        model: FolderListModel {
            id: folderModel
            folder: activeFolder
            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp"]
            sortField: FolderListModel.Time
            sortReversed: true
        }

        delegate: Item {
            width: gridView.cellWidth - 8
            height: gridView.cellHeight - 8

            // Glass frame
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Qt.rgba(255/255, 255/255, 255/255, 0.64)
                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.88)
                border.width: 1

                // Thumbnail
                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: folderModel.get(index, "filePath") || ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 320
                    sourceSize.height: 320
                    asynchronous: true
                    cache: true
                    clip: true
                }

                // Top highlight
                Rectangle {
                    anchors.top: parent.top; anchors.topMargin: 4
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.right: parent.right; anchors.rightMargin: 8
                    height: 1; radius: 1
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                }

                // Hover overlay
                Rectangle {
                    anchors.fill: parent; radius: 12
                    color: Qt.rgba(0/255, 212/255, 255/255, 0.0)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.08)
                    onExited: parent.color = Qt.rgba(255/255, 255/255, 255/255, 0.64)
                    onClicked: {
                        currentPhoto = folderModel.get(index, "filePath") || ""
                        showGrid = false
                        headerText.text = activeAlbum === "deleted" ? "最近删除" : (activeAlbum === "hidden" ? "隐藏" : "预览")
                    }
                }
            }
        }

        // Empty state
        Text {
            anchors.centerIn: parent
            text: "暂无照片\n截图后在这里查看"
            horizontalAlignment: Text.AlignHCenter
            color: Qt.rgba(23/255, 33/255, 42/255, 0.44)
            font.pixelSize: 16
            lineHeight: 1.5
            visible: gridView.count === 0
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            rightPadding: 2
            contentItem: Rectangle {
                radius: 2
                color: Qt.rgba(255/255, 255/255, 255/255, 0.15)
            }
        }
    }

    // ─── Full-screen Photo Viewer ──────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        visible: !showGrid && currentPhoto.length > 0
        z: 5

        // Photo
        Image {
            anchors.fill: parent
            anchors.margins: 40
            source: currentPhoto
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        // Glass toolbar at bottom
        Rectangle {
        anchors.bottom: bottomLiquidBar.top
            anchors.bottomMargin: 32
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200; height: 44; radius: 22
            color: Qt.rgba(248/255, 252/255, 255/255, 0.84)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.92)
            border.width: 1
            z: 2

            // Frost
            Rectangle {
                anchors.fill: parent; radius: 22
                color: Qt.rgba(205/255, 239/255, 255/255, 0.12)
            }

            Row {
                anchors.centerIn: parent
                spacing: 28

                Text {
                    text: activeAlbum === "deleted" ? "彻底删除" : "删除"
                    font.pixelSize: 14
                    color: "#FF5252"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        onClicked: deleteConfirmationVisible = true
                    }
                }
                Text {
                    text: activeAlbum === "deleted" ? "恢复" : (activeAlbum === "hidden" ? "取消隐藏" : "隐藏")
                    font.pixelSize: 14
                    color: "#00A9CC"
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -10
                        onClicked: photosScreen.manageCurrentPhoto(activeAlbum === "deleted" ? "restore" : (activeAlbum === "hidden" ? "unhide" : "hide"))
                    }
                }
                Text {
                    text: "返回"
                    font.pixelSize: 14
                    color: "#00D4FF"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        onClicked: {
                            showGrid = true
                            headerText.text = "相册"
                        }
                    }
                }
            }
        }

        // Tap anywhere to go back
        MouseArea {
            anchors.fill: parent
            z: 1
            onClicked: {
                showGrid = true
                headerText.text = "相册"
            }
        }
    }

    // Album landing page. The English product nouns remain concise while the
    // descriptions follow the Simplified Chinese system UI.
    Column {
        anchors.centerIn: parent
        spacing: 16
        visible: showGrid && activeAlbum === "albums"
        Repeater {
            model: [
                {key: "deleted", title: "最近删除", subtitle: "删除的照片保留在这里，彻底删除需再次确认"},
                {key: "hidden", title: "隐藏", subtitle: "隐藏照片不会出现在照片流中"}
            ]
            Rectangle {
                width: 560; height: 92; radius: 26
                color: Qt.rgba(248/255, 252/255, 255/255, 0.94)
                border.width: 1; border.color: "#FFFFFF"
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 24; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                    Text { text: modelData.title; color: "#17212A"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Text { text: modelData.subtitle; color: "#61707C"; font.pixelSize: 12 }
                }
                Text { anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: "#53616C"; font.pixelSize: 28 }
                MouseArea { anchors.fill: parent; onClicked: photosScreen.openAlbum(modelData.key) }
            }
        }
    }

    Rectangle {
        id: bottomLiquidBar
        anchors.bottom: parent.bottom; anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: 300; height: 54; radius: 27; z: 40
        color: Qt.rgba(248/255, 253/255, 255/255, 0.96)
        border.width: 1; border.color: "#FFFFFF"
        visible: showGrid
        Row {
            anchors.centerIn: parent; spacing: 8
            Repeater {
                model: [{key: "photos", label: "照片"}, {key: "albums", label: "相簿"}]
                Rectangle {
                    width: 132; height: 40; radius: 20
                    color: (activeAlbum === modelData.key || (modelData.key === "albums" && (activeAlbum === "deleted" || activeAlbum === "hidden"))) ? Qt.rgba(0, 0.83, 1, 0.22) : "transparent"
                    Text { anchors.centerIn: parent; text: modelData.label; color: "#17212A"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.key === "photos") photosScreen.openAlbum("photos")
                            else { activeAlbum = "albums"; showGrid = true; headerText.text = "相簿" }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent; z: 100
        visible: deleteConfirmationVisible
        color: Qt.rgba(0, 0, 0, 0.48)
        Rectangle {
            anchors.centerIn: parent; width: 430; height: 210; radius: 30
            color: Qt.rgba(250/255, 254/255, 1, 0.98); border.width: 1; border.color: "#FFFFFF"
            Column {
                anchors.centerIn: parent; spacing: 18
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: activeAlbum === "deleted" ? "确定彻底删除这张照片？" : "确定删除这张照片？"; color: "#17212A"; font.pixelSize: 18; font.weight: Font.DemiBold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: activeAlbum === "deleted" ? "此操作无法撤销" : "照片将移到最近删除"; color: "#61707C"; font.pixelSize: 13 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 14
                    Rectangle { width: 150; height: 42; radius: 21; color: "#EDF4F6"; Text { anchors.centerIn: parent; text: "取消"; color: "#17212A" } MouseArea { anchors.fill: parent; onClicked: deleteConfirmationVisible = false } }
                    Rectangle { width: 150; height: 42; radius: 21; color: "#FF5F57"; Text { anchors.centerIn: parent; text: "删除"; color: "white" } MouseArea { anchors.fill: parent; onClicked: { deleteConfirmationVisible = false; photosScreen.manageCurrentPhoto(activeAlbum === "deleted" ? "permanent" : "trash") } } }
                }
            }
        }
    }
}
