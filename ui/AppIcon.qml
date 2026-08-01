// YUNSH OS v1.0 - App Icon Component (visionOS Style)
// visionOS-style circular liquid-glass icon with gaze/pointer depth feedback.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: appIcon

    property string appName: ""
    property string iconSource: ""
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
                color: Qt.rgba(1, 1, 1, 0.16)
                border.color: Qt.rgba(1, 1, 1, 0.38)
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
                color: Qt.rgba(0.93, 0.97, 1, 0.84)
                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.96)
                border.width: 1

                // White liquid-glass material that stays visible optically.
                Rectangle {
                    anchors.fill: parent; radius: 32
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.40)
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.62
                    height: 9
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.34)
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
                    source: appIcon.iconSource
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
            width: 72
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
