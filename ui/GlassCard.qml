// YUNSH OS v1.0 - Glass Card Component (visionOS Enhanced - Apple Style)
// iOS Settings-style list item card with glass effect

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: glassCard
    
    // === Properties ===
    property string iconSource: ""
    property real iconSize: 20
    // Empty by default.  "Title" was a placeholder, but it was rendered in
    // cards that provide their own content and ended up overlapping the real
    // installation/update text below it.
    property string title: ""
    property string subtitle: ""
    property real cardCornerRadius: 14
    property bool showArrow: false
    property color accentColor: "transparent"
    property color titleColor: "#17212A"
    property bool isToggle: false
    property bool toggleState: false
    property alias contentItem: customContent.data
    
    signal clicked()
    signal toggled(bool state)
    
    width: parent ? parent.width : 400
    height: subtitle ? 64 : 52
    radius: cardCornerRadius
    
    // Glass background
    color: Qt.rgba(248/255, 252/255, 255/255, 0.66)
    
    // Hover/press state
    property bool pressed: false
    
    // Subtle border
    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.86)
    border.width: 1

    Item {
        id: customContent
        anchors.fill: parent
        z: 5
    }
    
    // Left accent line (iOS-style)
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top; anchors.topMargin: 10
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        width: 3
        radius: 1.5
        color: accentColor.a > 0 ? accentColor : "transparent"
        visible: accentColor.a > 0
    }
    
    // Icon (circular container like iOS)
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: iconSize + 12
        height: iconSize + 12
        radius: (iconSize + 12) / 2
        color: Qt.rgba(220/255, 245/255, 255/255, 0.52)
        visible: iconSource.length > 0
        
        Image {
            anchors.centerIn: parent
            source: iconSource
            width: iconSize
            height: iconSize
            sourceSize.width: iconSize * 2
            sourceSize.height: iconSize * 2
            fillMode: Image.PreserveAspectFit
        }
    }
    
    // Text content
    Column {
        id: textColumn
        anchors.left: parent.left
        anchors.leftMargin: iconSource.length > 0 ? 56 : 18
        anchors.right: parent.right
        anchors.rightMargin: isToggle ? 76 : (showArrow ? 44 : 18)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        visible: title.length > 0 || subtitle.length > 0
        
        Text {
            width: parent.width
            text: title
            color: titleColor
            font.pixelSize: 15
            font.weight: Font.Medium
            elide: Text.ElideRight
            visible: title.length > 0
        }
        
        Text {
            width: parent.width
            text: subtitle
            color: "#61707C"
            font.pixelSize: 12
            visible: subtitle.length > 0
            elide: Text.ElideRight
        }
    }
    
    // Arrow indicator (iOS-style)
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        color: "#53616C"
        font.pixelSize: 20
        font.weight: Font.Light
        visible: showArrow
    }
    
    // Toggle switch (iOS UISwitch style)
    Rectangle {
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 48; height: 28; radius: 14
        color: toggleState ? Qt.rgba(0/255, 200/255, 83/255, 0.78) : Qt.rgba(90/255, 108/255, 122/255, 0.24)
        visible: isToggle
        
        // Toggle knob
        Rectangle {
            x: toggleState ? parent.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24; radius: 12
            color: "#FFFFFF"
            
            Behavior on x {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                toggleState = !toggleState
                glassCard.toggled(toggleState)
            }
        }
    }
    
    // Click area
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.color = Qt.rgba(225/255, 248/255, 255/255, 0.82)
        onExited: parent.color = Qt.rgba(248/255, 252/255, 255/255, 0.66)
        onClicked: {
            if (glassCard.isToggle) {
                glassCard.toggleState = !glassCard.toggleState
                glassCard.toggled(glassCard.toggleState)
            } else {
                glassCard.clicked()
            }
        }
        onPressed: parent.color = Qt.rgba(205/255, 243/255, 255/255, 0.92)
        onReleased: parent.color = Qt.rgba(225/255, 248/255, 255/255, 0.82)
    }
    
    // Hover scale effect
    Behavior on scale {
        NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
    }
}
