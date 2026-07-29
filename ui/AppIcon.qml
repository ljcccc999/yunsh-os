// YUNSH OS v1.0 - App Icon Component (visionOS Style)
// Apple-style rounded-square glass icon with immediate press feedback.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: appIcon

    property string appName: ""
    property string appIcon: ""
    property string appPackage: ""
    property bool isSystemApp: false
    property color iconColor: Qt.rgba(20/255, 20/255, 35/255, 0.5)

    signal clicked()

    width: 88
    height: 100

    Column {
        anchors.centerIn: parent
        spacing: 8

        // Rounded-square system icon
        Item {
            width: 72
            height: 72
            anchors.horizontalCenter: parent.horizontalCenter

            // Soft material halo
            Rectangle {
                anchors.centerIn: parent
                width: 72; height: 72; radius: 36
                color: "transparent"
                border.color: Qt.rgba(0/255, 212/255, 255/255, 0.06)
                border.width: 1
            }

            // Consistent squircle-like application tile.
            Rectangle {
                id: iconCircle
                anchors.centerIn: parent
                width: 64
                height: 64
                radius: 17
                color: appIcon.iconColor
                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.72)
                border.width: 1

                // White liquid-glass material that stays visible optically.
                Rectangle {
                    anchors.fill: parent; radius: 17
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.70)
                }

                // Top highlight (visionOS edge light)
                Rectangle {
                    anchors.top: parent.top; anchors.topMargin: 2
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.right: parent.right; anchors.rightMargin: 8
                    height: 2; radius: 1
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.92)
                }

                // Shadow at bottom
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.right: parent.right; anchors.rightMargin: 8
                    height: 2; radius: 1
                    color: Qt.rgba(0/255, 98/255, 128/255, 0.10)
                }

                // Icon image
                Image {
                    id: iconImg
                    source: appIcon
                    width: 36
                    height: 36
                    anchors.centerIn: parent
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                }

                // Glow on hover
                Rectangle {
                    id: glowEffect
                    anchors.fill: parent; radius: 17
                    color: Qt.rgba(0/255, 212/255, 255/255, 0.0)
                    visible: false
                }
            }

            // Drop shadow for depth
            layer.enabled: true
            layer.effect: DropShadowEffect {
                radius: 16
                samples: 32
                color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
                horizontalOffset: 0
                verticalOffset: 4
            }
        }

        // App name
        Text {
            text: appName
            color: "#FFFFFF"
            font.pixelSize: 11
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            elide: Text.ElideRight
            maximumLineWidth: 72
            lineHeight: 1.2
            opacity: 0.85
        }
    }

    // Click + hover
    MouseArea {
        anchors.fill: parent
        onClicked: appIcon.clicked()
        onPressed: iconCircle.scale = 0.96
        onReleased: iconCircle.scale = containsMouse ? 1.06 : 1.0
        onCanceled: iconCircle.scale = 1.0
        hoverEnabled: true

        onEntered: {
            iconCircle.scale = 1.06
            glowEffect.visible = true
            glowEffect.color = Qt.rgba(0/255, 212/255, 255/255, 0.1)
        }
        onExited: {
            iconCircle.scale = 1.0
            glowEffect.color = Qt.rgba(0/255, 212/255, 255/255, 0.0)
            glowEffect.visible = false
        }

        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }
}
