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
    
    // Drag start position (stored on press for proper normalization)
    property real startX: 0
    property real startY: 0
    
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
                            var nx = selectionRect.x
                            var ny = selectionRect.y
                            var nw = selectionRect.width
                            var nh = selectionRect.height
                            // Normalize in case drag didn't update the rect (tiny selection edge case)
                            if (nw < 0) { nx = selectionRect.x + nw; nw = -nw }
                            if (nh < 0) { ny = selectionRect.y + nh; nh = -nh }
                            // Treat tiny click as full-screen
                            if (nw < 10 && nh < 10) {
                                nx = 0; ny = 0
                                nw = screenshotOverlay.width
                                nh = screenshotOverlay.height
                            }
                            screenshotOverlay.regionSelected(nx, ny, nw, nh)
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
            startX = mouse.x
            startY = mouse.y
            selectionRect.x = startX
            selectionRect.y = startY
            selectionRect.width = 0
            selectionRect.height = 0
            selectionRect.visible = true
        }

        onPositionChanged: {
            if(pressed) {
                // Normalize coordinates: handle dragging in any direction
                var x1 = Math.min(startX, mouse.x)
                var y1 = Math.min(startY, mouse.y)
                var x2 = Math.max(startX, mouse.x)
                var y2 = Math.max(startY, mouse.y)
                selectionRect.x = x1
                selectionRect.y = y1
                selectionRect.width = x2 - x1
                selectionRect.height = y2 - y1
            }
        }
    }
}
