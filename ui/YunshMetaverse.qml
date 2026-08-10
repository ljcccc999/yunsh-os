// YUNSH META Universe — persistent system world layer.
// This is part of the shell and must never be presented as a normal app.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: world
    anchors.fill: parent
    signal backToHome()
    property string systemLanguage: "简体中文"
    readonly property bool useSimplifiedChinese: systemLanguage === "简体中文"
    readonly property bool useTraditionalChinese: systemLanguage === "繁體中文"

    function localized(simplified, traditional, english) {
        return useSimplifiedChinese ? simplified : (useTraditionalChinese ? traditional : english)
    }

    Component.onCompleted: {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return
            try { world.systemLanguage = JSON.parse(xhr.responseText || "{}").language || "简体中文" }
            catch (_error) {}
        }
        xhr.send(JSON.stringify({action: "system_settings"}))
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.76
        height: parent.height * 0.72
        radius: 48
        color: Qt.rgba(250/255, 254/255, 1, 0.96)
        border.width: 1
        border.color: "#FFFFFF"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 45
            color: "transparent"
            border.width: 1
            border.color: "#D9F6FF"
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 120
            spacing: 22

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "/usr/share/yunsh/logo/logo-128.png"
                width: 82; height: 82
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "YUNSH META Universe"
                color: "#101820"
                font.pixelSize: 34
                font.weight: Font.DemiBold
                font.letterSpacing: -0.9
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.78
                text: world.localized(
                    "一个内置于操作系统的持续世界。身份、空间、人与体验不会随着单个窗口关闭而消失。",
                    "一個內建於作業系統的持續世界。身分、空間、人與體驗不會隨單一視窗關閉而消失。",
                    "A persistent world built into the operating system — identity, spaces, people, and experiences continue beyond any single window.")
                color: "#5E6C77"
                font.pixelSize: 15
                lineHeight: 1.35
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Repeater {
                    model: [
                        {title: world.localized("持续身份", "持續身分", "Persistent Identity"), subtitle: world.localized("你的身份始终相随", "你的身分始終相隨", "Your presence follows you")},
                        {title: world.localized("生长的空间", "成長的空間", "Living Spaces"), subtitle: world.localized("空间会记忆并演进", "空間會記憶並演進", "Spaces remember and evolve")},
                        {title: world.localized("彼此连接", "彼此連結", "Connected People"), subtitle: world.localized("共同存在于同一世界", "共同存在於同一世界", "Share the same world")}
                    ]
                    Rectangle {
                        width: 220
                        height: 112
                        radius: 24
                        color: "#FFFFFF"
                        border.width: 1
                        border.color: "#DCECF1"
                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 30
                            spacing: 7
                            Text {
                                width: parent.width
                                text: modelData.title
                                color: "#14202A"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                width: parent.width
                                text: modelData.subtitle
                                color: "#71808B"
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 260
                height: 48
                radius: 24
                color: "#E7F9FE"
                border.width: 1
                border.color: "#BCEFFF"
                Row {
                    anchors.centerIn: parent
                    spacing: 9
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: "#34C759"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "WORLD FOUNDATION IS RUNNING"
                        color: "#08728E"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.1
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160
                height: 44
                radius: 22
                color: backMouse.pressed ? "#35DDFF" : "#00D4FF"
                Text {
                    anchors.centerIn: parent
                    text: "Return to YUNSH OS"
                    color: "#00191F"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    onClicked: world.backToHome()
                }
            }
        }
    }
}
