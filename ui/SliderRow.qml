// Compact direct-manipulation slider used by spatial settings.

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root

    property string title: ""
    property string suffix: ""
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    signal valueEdited(real newValue)

    height: 74
    radius: 16
    color: Qt.rgba(1, 1, 1, 0.045)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.055)

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 12
        text: root.title
        color: "#FFFFFF"
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 12
        text: Number(root.value).toFixed(root.stepSize < 1 ? 1 : 0) + root.suffix
        color: "#00D4FF"
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    Slider {
        id: slider
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        from: root.from
        to: root.to
        value: root.value
        stepSize: root.stepSize
        live: true

        onMoved: root.valueEdited(value)

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 6
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.1)

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 3
                color: "#00D4FF"
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition
               * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.pressed ? 22 : 20
            height: width
            radius: width / 2
            color: "#FFFFFF"
            border.width: 2
            border.color: slider.pressed ? "#00D4FF" : Qt.rgba(0, 0, 0, 0.16)

            Behavior on width {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }
    }
}
