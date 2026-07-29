// YUNSH META Universe — persistent system world layer.
// This is part of the shell and must never be presented as a normal app.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: world
    anchors.fill: parent
    signal backToHome()

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
                text: "Get Ready for YUNSH META Universe"
                color: "#101820"
                font.pixelSize: 34
                font.weight: Font.DemiBold
                font.letterSpacing: -0.9
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.78
                text: "A persistent world built into the operating system — identity, spaces, people, and experiences continue beyond any single window."
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
                        {title: "Persistent Identity", subtitle: "Your presence follows you"},
                        {title: "Living Spaces", subtitle: "Spaces remember and evolve"},
                        {title: "Connected People", subtitle: "Share the same world"}
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
