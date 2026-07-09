// YUNSH OS v1.0 - Metaverse (元宇宙)
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: metaverseScreen
    anchors.fill: parent
    visible: false
    
    signal backToHome()
    
    // Pure black background
    Rectangle { anchors.fill: parent; color: "#000000" }
    
    // Floating glass panel - visionOS style
    Rectangle {
        anchors.centerIn: parent
        width: 400
        height: 500
        radius: 32
        color: Qt.rgba(20, 20, 30, 0.35)
        
        // Frosted overlay
        Rectangle {
            anchors.fill: parent; radius: 32
            color: Qt.rgba(255, 255, 255, 0.03)
        }
        
        // Border glow
        Rectangle {
            anchors.fill: parent; radius: 32
            color: "transparent"
            border.color: Qt.rgba(0, 212, 255, 0.15)
            border.width: 1
            
            Rectangle {
                anchors.fill: parent; radius: 32
                color: "transparent"
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1; anchors.margins: 2
            }
        }
        
        // Deep shadow
        Rectangle {
            anchors.fill: parent; anchors.margins: -16; radius: 40
            color: "transparent"
            layer.enabled: true
            layer.effect: DropShadow {
                radius: 48; samples: 97
                color: Qt.rgba(0, 0, 0, 0.5)
                horizontalOffset: 0; verticalOffset: 12
            }
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 24
            
            // YUNSH Atomic Logo
            Rectangle {
                width: 100; height: 100; radius: 50
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(20, 20, 35, 0.6)
                border.color: Qt.rgba(0, 212, 255, 0.2); border.width: 1
                
                Image {
                    anchors.centerIn: parent
                    source: "/usr/share/yunsh/logo/logo-128.png"
                    width: 64; height: 64
                    sourceSize.width: 128; sourceSize.height: 128
                    fillMode: Image.PreserveAspectFit
                }
            }
            
            // Title
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "YUNSH Metaverse"
                color: "#FFFFFF"; font.pixelSize: 28; font.weight: Font.Bold
            }
            
            // Status badge
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160; height: 36; radius: 18
                color: Qt.rgba(255, 193, 7, 0.15)
                border.color: Qt.rgba(255, 193, 7, 0.3); border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: "🚧 正在开发中"
                    color: "#FFC107"; font.pixelSize: 14; font.weight: Font.Medium
                }
            }
            
            // Description
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "YUNSH Metaverse 即将到来\n一个全新的 AR 社交体验"
                color: "#A0A0A0"; font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
            
            // Close button (capsule pill shape)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 200; height: 44; radius: 22
                color: Qt.rgba(0, 212, 255, 0.15)
                border.color: Qt.rgba(0, 212, 255, 0.3); border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: "返回首页"; color: "#00D4FF"; font.pixelSize: 15; font.weight: Font.Medium
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = Qt.rgba(0, 212, 255, 0.25)
                    onExited: parent.color = Qt.rgba(0, 212, 255, 0.15)
                    onClicked: metaverseScreen.backToHome()
                }
            }
        }
    }
}
