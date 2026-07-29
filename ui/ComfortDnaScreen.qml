// YUNSH Comfort DNA — optional onboarding and settings experience.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: comfortDna
    anchors.fill: parent

    property bool onboarding: false
    property bool reduceMotion: false
    property string selectedProfile: "balanced"
    property string statusText: ""
    property bool busy: false

    signal backRequested()
    signal profileApplied(var data)
    signal setupSkipped()

    readonly property var profiles: [
        {
            id: "steady",
            name: "稳定",
            summary: "更强平滑、更窄视野、减少大幅动效",
            detail: "适合初次使用空间显示或容易感到画面晃动的人"
        },
        {
            id: "balanced",
            name: "平衡",
            summary: "舒适度、响应速度与视野之间保持平衡",
            detail: "推荐作为大多数人的起点"
        },
        {
            id: "responsive",
            name: "灵敏",
            summary: "更快头部响应与更开阔的显示范围",
            detail: "适合已经习惯头戴显示并偏好即时反馈的人"
        }
    ]

    function loadProfile() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8591/api/comfort-dna", true)
        xhr.timeout = 1200
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return
            try {
                var data = JSON.parse(xhr.responseText)
                if (data.success && data.profile)
                    selectedProfile = data.profile
            } catch (error) {
                console.log("YUNSH: Could not load Comfort DNA")
            }
        }
        xhr.send()
    }

    function saveProfile(profile) {
        if (busy)
            return
        busy = true
        statusText = "正在保存舒适指纹…"
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/comfort-dna", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 2500
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            busy = false
            try {
                var data = JSON.parse(xhr.responseText)
                if (data.success) {
                    statusText = "舒适指纹已应用"
                    comfortDna.profileApplied(data)
                } else {
                    statusText = data.error || "无法保存舒适指纹"
                }
            } catch (error) {
                statusText = "无法连接本地设置服务"
            }
        }
        xhr.send(JSON.stringify({action: "apply", profile: profile}))
    }

    function skipSetup() {
        if (busy)
            return
        busy = true
        statusText = ""
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/comfort-dna", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 1500
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            busy = false
            // This step is optional. A local-service error must not trap the
            // user in activation; defaults remain active.
            comfortDna.setupSkipped()
        }
        xhr.send(JSON.stringify({action: "skip"}))
    }

    Component.onCompleted: loadProfile()

    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 680)
        height: Math.min(parent.height - 36, 610)
        radius: 32
        color: Qt.rgba(15/255, 15/255, 32/255, 0.52)
        border.width: 1
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.07)

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 180
            radius: 32
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0/255, 212/255, 255/255, 0.07) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 14

            Row {
                width: parent.width
                height: 34

                Rectangle {
                    width: 82
                    height: 32
                    radius: 16
                    visible: !comfortDna.onboarding
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
                        onClicked: comfortDna.backRequested()
                    }
                }

                Item { width: parent.width - 164; height: 1 }

                Text {
                    width: 82
                    text: "可随时修改"
                    horizontalAlignment: Text.AlignRight
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.32)
                    font.pixelSize: 11
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Comfort DNA"
                color: "#FFFFFF"
                font.pixelSize: 28
                font.weight: Font.DemiBold
                font.letterSpacing: -0.4
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 40
                text: "选择一个舒适起点。它只调整本机的头追平滑、视野与动效，不上传运动数据。"
                color: Qt.rgba(255/255, 255/255, 255/255, 0.55)
                font.pixelSize: 13
                lineHeight: 1.35
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                width: parent.width
                spacing: 9

                Repeater {
                    model: comfortDna.profiles

                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 82
                        radius: 18
                        color: comfortDna.selectedProfile === modelData.id
                            ? Qt.rgba(0/255, 212/255, 255/255, 0.13)
                            : Qt.rgba(255/255, 255/255, 255/255, profileArea.pressed ? 0.08 : 0.045)
                        border.width: 1
                        border.color: comfortDna.selectedProfile === modelData.id
                            ? Qt.rgba(0/255, 212/255, 255/255, 0.45)
                            : Qt.rgba(255/255, 255/255, 255/255, 0.07)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                                radius: 12
                                color: comfortDna.selectedProfile === modelData.id
                                    ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.07)
                                Text {
                                    anchors.centerIn: parent
                                    text: comfortDna.selectedProfile === modelData.id ? "✓" : ""
                                    color: "#001018"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 42
                                spacing: 3
                                Text {
                                    text: modelData.name + " · " + modelData.summary
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.detail
                                    color: Qt.rgba(255/255, 255/255, 255/255, 0.42)
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        MouseArea {
                            id: profileArea
                            anchors.fill: parent
                            onPressed: comfortDna.selectedProfile = modelData.id
                            onClicked: comfortDna.selectedProfile = modelData.id
                        }

                        Behavior on color {
                            ColorAnimation { duration: comfortDna.reduceMotion ? 60 : 140 }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: comfortDna.statusText
                visible: text.length > 0
                color: text.indexOf("无法") === 0 ? "#FF8A80" : "#7BE7FF"
                font.pixelSize: 12
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Rectangle {
                    width: 150
                    height: 44
                    radius: 22
                    visible: comfortDna.onboarding
                    color: skipArea.pressed
                        ? Qt.rgba(255/255, 255/255, 255/255, 0.10)
                        : Qt.rgba(255/255, 255/255, 255/255, 0.045)
                    border.width: 1
                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: "以后再设置"
                        color: "#B5B5C5"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: skipArea
                        anchors.fill: parent
                        enabled: !comfortDna.busy
                        onClicked: comfortDna.skipSetup()
                    }
                }

                Rectangle {
                    width: 190
                    height: 44
                    radius: 22
                    color: applyArea.pressed
                        ? Qt.rgba(0/255, 212/255, 255/255, 0.30)
                        : Qt.rgba(0/255, 212/255, 255/255, 0.17)
                    border.width: 1
                    border.color: Qt.rgba(0/255, 212/255, 255/255, 0.34)
                    Text {
                        anchors.centerIn: parent
                        text: comfortDna.busy ? "正在保存…" : "应用舒适指纹"
                        color: "#00D4FF"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: applyArea
                        anchors.fill: parent
                        enabled: !comfortDna.busy
                        onClicked: comfortDna.saveProfile(comfortDna.selectedProfile)
                    }
                }
            }
        }
    }
}
