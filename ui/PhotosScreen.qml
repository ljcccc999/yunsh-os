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
    property bool showGrid: true
    property string currentPhoto: ""
    
    signal backToHome()

    function deleteCurrentPhoto() {
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
                    headerText.text = "相册"
                }
            } catch (error) {}
        }
        xhr.send(JSON.stringify({
            action: "delete_screenshot",
            path: currentPhoto
        }))
    }
    
    // ─── Header ────────────────────────────────────
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
            anchors.centerIn: parent; text: "相册"
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
            folder: photosDir
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
                        headerText.text = "预览"
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
            anchors.bottom: parent.bottom
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
                    text: "删除"
                    font.pixelSize: 14
                    color: "#FF5252"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        onClicked: photosScreen.deleteCurrentPhoto()
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
}
