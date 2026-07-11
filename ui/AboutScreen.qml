// YUNSH OS v1.0 - About Screen (visionOS Style)

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

GlassPanel {
    id: aboutScreen
    anchors.fill: parent
    visible: false
    glassOpacity: 0.3
    cornerRadius: 28
    blurRadius: 28
    shadowDepth: 16
    shadowOpacity: 0.5
    
    signal backToHome()
    
    // Header
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "transparent"
        
        // Back button (capsule pill)
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 80; height: 32; radius: 16
            color: Qt.rgba(0/255, 212/255, 255/255, 0.1)
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: "← 返回"
                color: "#00D4FF"
                font.pixelSize: 14
                font.weight: Font.Medium
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.2)
                onExited: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.1)
                onClicked: aboutScreen.backToHome()
            }
        }
        
        // Title
        Text {
            anchors.centerIn: parent
            text: "关于本机"
            color: "#FFFFFF"
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }
    
    Flickable {
        anchors.top: parent.top
        anchors.topMargin: 60
        anchors.left: parent.left
        anchors.leftMargin: 40
        anchors.right: parent.right
        anchors.rightMargin: 40
        anchors.bottom: parent.bottom
        
        contentHeight: aboutColumn.height + 40
        clip: true
        
        Column {
            id: aboutColumn
            width: parent.width
            spacing: 20
            
            // Logo - center (visionOS circular container)
            Item {
                width: parent.width
                height: 120
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 100; height: 100; radius: 50
                    color: Qt.rgba(18/255, 18/255, 32/255, 0.5)
                    border.color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
                    border.width: 1
                    
                    // Glow effect
                    Rectangle {
                        anchors.fill: parent; radius: 50
                        anchors.margins: -8
                        color: "transparent"
                        border.color: Qt.rgba(0/255, 212/255, 255/255, 0.04)
                        border.width: 1
                    }
                    
                    Image {
                        id: yunshLogo
                        anchors.centerIn: parent
                        source: "/usr/share/yunsh/logo/logo-256.png"
                        width: 72
                        height: 72
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectFit
                    }
                }
            }
            
            // Product name
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "YUNSH V1"
                color: "#FFFFFF"
                font.pixelSize: 30
                font.weight: Font.Bold
                letterSpacing: 2
            }
            
            // OS version
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "YUNSH OS v1.0.1"
                color: "#8888A0"
                font.pixelSize: 15
                font.weight: Font.Medium
            }
            
            // Spacer
            Item { width: 1; height: 8 }
            
            // Divider (visionOS style)
            Rectangle {
                width: parent.width * 0.4
                height: 1
                color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            // Info cards - visionOS style
            Repeater {
                model: [
                    { label: "设备名称", value: "YUNSH V1" },
                    { label: "型号", value: "YS-V1-001" },
                    { label: "系统版本", value: "YUNSH OS 1.0.0" },
                    { label: "内核版本", value: "Linux 6.6.58" },
                    { label: "处理器", value: "BCM2712 (Cortex-A76)" },
                    { label: "内存", value: "4GB LPDDR4" },
                    { label: "存储", value: "32GB" },
                    { label: "显示", value: "1920×1080" },
                    { label: "序列号", value: "YS25" + Math.floor(Math.random()*1000000).toString().padStart(6,'0') }
                ]
                
                Rectangle {
                    width: parent.width * 0.5
                    height: 36
                    radius: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16
                        
                        Text {
                            text: modelData.label
                            color: "#8888A0"
                            font.pixelSize: 13
                            width: 80
                        }
                        
                        Text {
                            text: modelData.value
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }
                }
            }
            
            // Spacer
            Item { width: 1; height: 16 }
            
            // Copyright
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "© 2024 YUNSH Technology"
                color: Qt.rgba(255/255, 255/255, 255/255, 0.25)
                font.pixelSize: 11
            }
        }
    }
}
