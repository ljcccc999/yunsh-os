// YUNSH OS v1.0 - App Icon Component (visionOS Style)
// Circular glass icon with glow effect

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: appIcon
    
    property string appName: ""
    property string appIcon: ""
    property string appPackage: ""
    property bool isSystemApp: false
    property color iconColor: Qt.rgba(20/255, 20/255, 35/255, 0.5)
    
    signal clicked()
    
    width: 88
    height: 100
    
    Column {
        anchors.centerIn: parent
        spacing: 8
        
        // visionOS circular icon with glow
        Item {
            width: 64
            height: 64
            anchors.horizontalCenter: parent.horizontalCenter
            
            // Outer glow ring
            Rectangle {
                anchors.centerIn: parent
                width: 72; height: 72; radius: 36
                color: "transparent"
                border.color: Qt.rgba(0/255, 212/255, 255/255, 0.06)
                border.width: 1
            }
            
            // Icon circle - visionOS style
            Rectangle {
                id: iconCircle
                anchors.centerIn: parent
                width: 60
                height: 60
                radius: 18
                color: Qt.rgba(18/255, 18/255, 32/255, 0.45)
                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                border.width: 1
                
                // Subtle inner glow
                Rectangle {
                    anchors.fill: parent; radius: 18
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
                }
                
                // Depth shadow inside
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: 20
                    color: "transparent"
                    border.color: Qt.rgba(0, 0, 0, 0)
                    layer.enabled: true
                    layer.effect: DropShadowEffect {
                        radius: 12
                        samples: 25
                        color: Qt.rgba(0, 0, 0, 0.3)
                        horizontalOffset: 0
                        verticalOffset: 2
                    }
                }
                
                // Icon image
                Image {
                    id: iconImg
                    source: appIcon
                    width: 32
                    height: 32
                    anchors.centerIn: parent
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                }
                
                // Glow effect on hover
                Rectangle {
                    id: glowEffect
                    anchors.fill: parent; radius: 18
                    color: Qt.rgba(0/255, 212/255, 255/255, 0.0)
                    visible: false
                }
            }
            
            // Glow animation
            PropertyAnimation {
                id: glowAnim
                target: glowEffect
                property: "color"
                duration: 200
            }
        }
        
        // App name
        Text {
            text: appName
            color: "#FFFFFF"
            font.pixelSize: 11
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            elide: Text.ElideRight
            maximumLineWidth: 72
            lineHeight: 1.2
            opacity: 0.85
        }
    }
    
    // Click handler with visionOS hover
    MouseArea {
        anchors.fill: parent
        onClicked: appIcon.clicked()
        hoverEnabled: true
        
        onEntered: {
            iconCircle.scale = 1.1
            iconCircle.color = Qt.rgba(25/255, 25/255, 45/255, 0.55)
            glowEffect.visible = true
            glowEffect.color = Qt.rgba(0/255, 212/255, 255/255, 0.08)
        }
        onExited: {
            iconCircle.scale = 1.0
            iconCircle.color = Qt.rgba(18/255, 18/255, 32/255, 0.45)
            glowEffect.color = Qt.rgba(0/255, 212/255, 255/255, 0.0)
            glowEffect.visible = false
        }
        
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }
}
