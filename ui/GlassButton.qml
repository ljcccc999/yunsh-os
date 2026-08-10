import QtQuick 2.15

Rectangle {
    id: button
    property url iconSource: ""
    property color bgColor: Qt.rgba(248/255, 252/255, 1, 0.62)
    property color hoverBgColor: Qt.rgba(1, 1, 1, 0.78)
    property color pressedBgColor: Qt.rgba(225/255, 247/255, 1, 0.88)
    property alias contentItem: customContent.data
    signal clicked()

    radius: height / 2
    color: mouse.pressed ? pressedBgColor : (mouse.containsMouse ? hoverBgColor : bgColor)
    opacity: enabled ? 1 : 0.45
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.88)

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(210/255, 241/255, 1, 0.10)
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left; anchors.leftMargin: parent.radius * 0.45
        anchors.right: parent.right; anchors.rightMargin: parent.radius * 0.45
        height: 1
        color: Qt.rgba(1, 1, 1, 0.82)
    }

    Item {
        id: customContent
        anchors.fill: parent
        z: 2
    }

    Image {
        anchors.centerIn: parent
        width: Math.min(20, parent.width * 0.5)
        height: width
        source: button.iconSource
        fillMode: Image.PreserveAspectFit
        visible: source.toString().length > 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        onClicked: button.clicked()
    }
}
