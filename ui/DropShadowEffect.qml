import QtQuick 2.15

Rectangle {
    property var source
    property real samples: 32
    property real horizontalOffset: 0
    property real verticalOffset: 8
    property bool transparentBorder: true

    x: horizontalOffset
    y: verticalOffset
    radius: Math.max(1, Math.min(width, height) * 0.04)
    color: Qt.rgba(0, 0, 0, 0.28)
    opacity: source && source.visible ? 1 : 0
    z: -1
}
