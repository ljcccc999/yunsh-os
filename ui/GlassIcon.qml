import QtQuick 2.15

Item {
    property url source: ""
    property color iconColor: "#FFFFFF"
    property int size: 20
    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: iconColor
    }

    Text {
        anchors.centerIn: parent
        text: source.toString().indexOf("exclamation") >= 0 ? "!" : "✓"
        color: iconColor
        font.pixelSize: Math.max(10, size * 0.65)
        font.bold: true
    }
}
