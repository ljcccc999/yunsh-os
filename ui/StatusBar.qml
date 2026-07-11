// YUNSH OS v1.0 - Status Bar (iOS/visionOS Style)
// Floating status bar with Control Center trigger, time, status icons

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: statusBar
    height: 48
    
    property string currentTime: "00:00"
    property string batteryLevel: "100%"
    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool showControlCenterHint: false  // subtle drag hint
    
    signal screenshotTriggered()
    signal openControlCenter()
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date()
            currentTime = d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
        }
    }
    
    // Glass background (visionOS style - slight frosted bar, not edge-to-edge)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left; anchors.leftMargin: -4
        anchors.right: parent.right; anchors.rightMargin: -4
        height: parent.height + 4
        color: Qt.rgba(12/255, 12/255, 25/255, tintOpacity * 0.3)
    }
    
    // Bottom separator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.right: parent.right; anchors.rightMargin: 16
        height: 1
        color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
    }
    
    // Left: Logo
    Row {
        anchors.left: parent.left; anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        
        Image {
            source: "/usr/share/yunsh/logo/logo-32.png"
            width: 22; height: 22
            sourceSize.width: 32; sourceSize.height: 32
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
        }
        
        Text {
            text: "YUNSH"
            color: "#00D4FF"
            font.pixelSize: 13
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
            letterSpacing: 1.5
        }
    }
    
    // Right: Control Center drag handle + system icons
    Row {
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        
        // Control Center drag handle (visionOS pill)
        Rectangle {
            width: 36; height: 28; radius: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: "☰"
                color: "#8888A0"
                font.pixelSize: 12
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.1)
                onExited: parent.color = Qt.rgba(255/255, 255/255, 255/255, 0.04)
                onClicked: statusBar.openControlCenter()
            }
        }
        
        // Screenshot (SVG icon)
        Rectangle {
            width: 28; height: 28; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            color: mouseArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.1) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
            
            Image {
                anchors.centerIn: parent
                source: "/usr/share/yunsh/icons/screenshot.svg"
                width: 16; height: 16
                sourceSize.width: 32; sourceSize.height: 32
                fillMode: Image.PreserveAspectFit
            }
            
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: statusBar.screenshotTriggered()
            }
        }
        
        // Wi-Fi
        Rectangle {
            width: 24; height: 24; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: wifiOn ? Qt.rgba(0/255, 212/255, 255/255, 0.08) : Qt.rgba(255/255, 255/255, 255/255, 0.03)
            
            Image {
                anchors.centerIn: parent
                source: "/usr/share/yunsh/icons/wifi.svg"
                width: 14; height: 14
                sourceSize.width: 14; sourceSize.height: 14
                fillMode: Image.PreserveAspectFit
            }
        }
        
        // Bluetooth
        Rectangle {
            width: 24; height: 24; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: bluetoothOn ? Qt.rgba(33/255, 150/255, 243/255, 0.08) : Qt.rgba(255/255, 255/255, 255/255, 0.03)
            
            Image {
                anchors.centerIn: parent
                source: "/usr/share/yunsh/icons/bluetooth.svg"
                width: 14; height: 14
                sourceSize.width: 14; sourceSize.height: 14
                fillMode: Image.PreserveAspectFit
            }
        }
        
        // Center: Time (visionOS pill)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: timeText.width + 20
            height: 26
            radius: 13
            color: Qt.rgba(0/255, 0/255, 0/255, 0.15)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
            border.width: 1
            
            Text {
                id: timeText
                anchors.centerIn: parent
                text: currentTime
                color: "#FFFFFF"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
        
        // Battery
        Text {
            text: batteryLevel
            color: "#00D4FF"
            font.pixelSize: 11
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
