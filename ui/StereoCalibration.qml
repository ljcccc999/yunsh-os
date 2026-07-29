// Binocular alignment target rendered inside the shared logical scene.

import QtQuick 2.15

Item {
    id: calibration

    property real ipdMm: 63
    property real eyeShiftPx: 0
    property real fieldOfView: 50
    signal closeRequested()

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    Repeater {
        model: 17
        Rectangle {
            x: index * calibration.width / 16
            width: 1
            height: calibration.height
            color: index === 8
                ? Qt.rgba(0, 212/255, 1, 0.7)
                : Qt.rgba(1, 1, 1, index % 4 === 0 ? 0.22 : 0.08)
        }
    }

    Repeater {
        model: 10
        Rectangle {
            y: index * calibration.height / 9
            width: calibration.width
            height: 1
            color: index === 4 || index === 5
                ? Qt.rgba(0, 212/255, 1, 0.28)
                : Qt.rgba(1, 1, 1, index % 3 === 0 ? 0.22 : 0.08)
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.42
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: "#FFFFFF"

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.55
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: "#00D4FF"
        }

        Rectangle {
            anchors.centerIn: parent
            width: 80
            height: 2
            color: "#FF3B30"
        }

        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: 80
            color: "#FF3B30"
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 42
        anchors.horizontalCenter: parent.horizontalCenter
        width: calibrationTitle.width + 56
        height: 54
        radius: 27
        color: Qt.rgba(18/255, 18/255, 32/255, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)

        Text {
            id: calibrationTitle
            anchors.centerIn: parent
            text: "双目校准 · 让左右眼中心图形舒适重合"
            color: "#FFFFFF"
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 42
        anchors.horizontalCenter: parent.horizontalCenter
        width: calibrationInfo.width + 60
        height: 62
        radius: 22
        color: Qt.rgba(18/255, 18/255, 32/255, 0.92)
        border.width: 1
        border.color: Qt.rgba(0, 212/255, 1, 0.3)

        Text {
            id: calibrationInfo
            anchors.centerIn: parent
            text: "IPD " + ipdMm.toFixed(1) + " mm   ·   融合偏移 "
                  + eyeShiftPx.toFixed(0) + " px   ·   FOV "
                  + fieldOfView.toFixed(0) + "°"
            color: "#DDEEFF"
            font.pixelSize: 15
            font.weight: Font.Medium
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 36
        anchors.top: parent.top
        anchors.topMargin: 36
        width: 96
        height: 42
        radius: 21
        color: closeMouse.pressed
            ? Qt.rgba(0, 212/255, 1, 0.3)
            : Qt.rgba(0, 212/255, 1, 0.16)
        border.width: 1
        border.color: Qt.rgba(0, 212/255, 1, 0.35)

        Text {
            anchors.centerIn: parent
            text: "完成"
            color: "#00D4FF"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            onClicked: calibration.closeRequested()
        }
    }
}
