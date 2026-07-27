import QtQuick 2.15

Rectangle {
    id: button
    property url iconSource: ""
    property color bgColor: Qt.rgba(1, 1, 1, 0.12)
    property color hoverBgColor: Qt.lighter(bgColor, 1.2)
    property color pressedBgColor: Qt.darker(hoverBgColor, 1.15)
    property alias contentItem: customContent.data
    signal clicked()

    radius: height / 2
    color: mouse.pressed ? pressedBgColor : (mouse.containsMouse ? hoverBgColor : bgColor)
    opacity: enabled ? 1 : 0.45
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.15)

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
