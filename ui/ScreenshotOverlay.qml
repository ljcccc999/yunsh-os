// YUNSH OS v1.0 - Screenshot Region Selector
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: screenshotOverlay
    anchors.fill: parent
    visible: false
    
    signal regionSelected(int x, int y, int w, int h)
    signal cancelled()
    
    // Semi-transparent dark overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
    }
    
    // Selection rectangle
    Rectangle {
        id: selectionRect
        color: Qt.rgba(0, 212, 255, 0.05)
        border.color: "#00D4FF"
        border.width: 2
        visible: false
        
        Rectangle {
            anchors.fill: parent; anchors.margins: -1
            color: "transparent"
            border.color: Qt.rgba(255, 255, 255, 0.3); border.width: 1; border.style: Qt.DashLine
        }
        
        // Size indicator
        Text {
            anchors.bottom: parent.top; anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(parent.width) + " × " + Math.round(parent.height)
            color: "#00D4FF"; font.pixelSize: 12
        }
    }
    
    // Bottom toolbar
    Rectangle {
        id: toolbar
        anchors.bottom: parent.bottom; anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        width: 260; height: 52; radius: 26
        color: Qt.rgba(20, 20, 30, 0.6)
        border.color: Qt.rgba(255, 255, 255, 0.1); border.width: 1
        
        Row {
            anchors.centerIn: parent; spacing: 20
            
            Rectangle {
                width: 100; height: 36; radius: 18
                color: Qt.rgba(0, 212, 255, 0.2)
                border.color: Qt.rgba(0, 212, 255, 0.3); border.width: 1
                Text { anchors.centerIn: parent; text: "📷 截图"; color: "#00D4FF"; font.pixelSize: 13 }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if(selectionRect.visible) {
                            screenshotOverlay.regionSelected(
                                selectionRect.x, selectionRect.y,
                                selectionRect.width, selectionRect.height
                            )
                        }
                    }
                }
            }
            
            Rectangle {
                width: 80; height: 36; radius: 18
                color: Qt.rgba(255, 60, 60, 0.1)
                border.color: Qt.rgba(255, 60, 60, 0.2); border.width: 1
                Text { anchors.centerIn: parent; text: "取消"; color: "#FF6B6B"; font.pixelSize: 13 }
                MouseArea {
                    anchors.fill: parent
                    onClicked: screenshotOverlay.cancelled()
                }
            }
        }
    }
    
    // Mouse area for region selection
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        
        onPressed: {
            selectionRect.x = mouse.x
            selectionRect.y = mouse.y
            selectionRect.width = 0
            selectionRect.height = 0
            selectionRect.visible = true
        }
        
        onMouseXChanged: if(pressed) { selectionRect.width = mouse.x - selectionRect.x }
        onMouseYChanged: if(pressed) { selectionRect.height = mouse.y - selectionRect.y }
        onPositionChanged: {
            if(pressed) {
                // Handle negative width/height
                if(mouse.x < selectionRect.x) {
                    selectionRect.x = mouse.x
                    selectionRect.width = pressedX - mouse.x
                }
            }
        }
    }
}
