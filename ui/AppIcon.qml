// YUNSH OS v1.0 - App Icon Component (visionOS Style)
// visionOS-style circular liquid-glass icon with gaze/pointer depth feedback.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: appIcon

    property string appName: ""
    property string appIcon: ""
    property string appPackage: ""
    property bool isSystemApp: false
    property color iconColor: Qt.rgba(20/255, 20/255, 35/255, 0.5)
    property bool hovered: false
    property bool pressedState: false

    signal clicked()

    width: 88
    height: 100

    Column {
        anchors.centerIn: parent
        spacing: 8

        // Circular system icon
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

            // Circular liquid-glass application surface.
            Rectangle {
                id: iconCircle
                anchors.centerIn: parent
                width: 64
                height: 64
                radius: 32
                anchors.verticalCenterOffset: appIcon.hovered && !appIcon.pressedState ? -5 : 0
                scale: appIcon.pressedState ? 0.96 : (appIcon.hovered ? 1.14 : 1.0)
                color: appIcon.iconColor
                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.72)
                border.width: 1

                // White liquid-glass material that stays visible optically.
                Rectangle {
                    anchors.fill: parent; radius: 32
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
                    anchors.fill: parent; radius: 32
                    color: appIcon.hovered
                        ? Qt.rgba(0/255, 212/255, 255/255, 0.13)
                        : Qt.rgba(0/255, 212/255, 255/255, 0.0)
                }

                Behavior on scale {
                    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                }
                Behavior on anchors.verticalCenterOffset {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
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
        onPressed: appIcon.pressedState = true
        onReleased: appIcon.pressedState = false
        onCanceled: appIcon.pressedState = false
        hoverEnabled: true

        onEntered: appIcon.hovered = true
        onExited: appIcon.hovered = false
    }
}
