// YUNSH OS v1.0 - App Icon Component (visionOS Style)
// Perfect circle + glassmorphism + hover glow

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

        // Glass circle icon
        Item {
            width: 72
            height: 72
            anchors.horizontalCenter: parent.horizontalCenter

            // Outer glow ring
            Rectangle {
                anchors.centerIn: parent
                width: 72; height: 72; radius: 36
                color: "transparent"
                border.color: Qt.rgba(0/255, 212/255, 255/255, 0.06)
                border.width: 1
            }

            // Perfect circle with glassmorphism
            Rectangle {
                id: iconCircle
                anchors.centerIn: parent
                width: 60
                height: 60
                radius: 30  // perfect circle
                color: Qt.rgba(18/255, 18/255, 32/255, 0.55)
                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                border.width: 1

                // Frost layer
                Rectangle {
                    anchors.fill: parent; radius: 30
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
                }

                // Top highlight (visionOS edge light)
                Rectangle {
                    anchors.top: parent.top; anchors.topMargin: 2
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.right: parent.right; anchors.rightMargin: 6
                    height: 1; radius: 1
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                }

                // Shadow at bottom
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.leftMargin: 4
                    anchors.right: parent.right; anchors.rightMargin: 4
                    height: 2; radius: 1
                    color: Qt.rgba(0/255, 0/255, 0/255, 0.15)
                }

                // Icon image
                Image {
                    id: iconImg
                    source: appIcon
                    width: 28
                    height: 28
                    anchors.centerIn: parent
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                }

                // Glow on hover
                Rectangle {
                    id: glowEffect
                    anchors.fill: parent; radius: 30
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
        hoverEnabled: true

        onEntered: {
            iconCircle.scale = 1.1
            iconCircle.color = Qt.rgba(25/255, 25/255, 45/255, 0.65)
            glowEffect.visible = true
            glowEffect.color = Qt.rgba(0/255, 212/255, 255/255, 0.1)
        }
        onExited: {
            iconCircle.scale = 1.0
            iconCircle.color = Qt.rgba(18/255, 18/255, 32/255, 0.55)
            glowEffect.color = Qt.rgba(0/255, 212/255, 255/255, 0.0)
            glowEffect.visible = false
        }

        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }
}
