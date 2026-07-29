// YUNSH OS v1.0 - Status Bar (iOS/visionOS Style)
// Floating status bar with Control Center trigger, time, status icons

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: statusBar
    height: 48
    
    property string currentTime: "00:00"
    property string batteryLevel: "—"
    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool stereoEnabled: false
    property bool headTrackingConnected: false
    property real tintOpacity: 1.0
    property bool showControlCenterHint: false  // subtle drag hint
    
    signal screenshotTriggered()
    signal openControlCenter()

    function refreshStatus() {
        var networkRequest = new XMLHttpRequest()
        networkRequest.open("GET", "http://127.0.0.1:8591/api/network-status", true)
        networkRequest.onreadystatechange = function() {
            if (networkRequest.readyState === XMLHttpRequest.DONE && networkRequest.status === 200) {
                try {
                    var network = JSON.parse(networkRequest.responseText)
                    wifiOn = network.enabled === true
                } catch (error) {}
            }
        }
        networkRequest.send()

        var bluetoothRequest = new XMLHttpRequest()
        bluetoothRequest.open("GET", "http://127.0.0.1:8591/api/bluetooth-status", true)
        bluetoothRequest.onreadystatechange = function() {
            if (bluetoothRequest.readyState === XMLHttpRequest.DONE && bluetoothRequest.status === 200) {
                try {
                    bluetoothOn = JSON.parse(bluetoothRequest.responseText).powered === true
                } catch (error) {}
            }
        }
        bluetoothRequest.send()

        var glassesRequest = new XMLHttpRequest()
        glassesRequest.open("GET", "http://127.0.0.1:8591/api/glasses-status", true)
        glassesRequest.onreadystatechange = function() {
            if (glassesRequest.readyState === XMLHttpRequest.DONE && glassesRequest.status === 200) {
                try {
                    var glasses = JSON.parse(glassesRequest.responseText)
                    if (glasses.connected && typeof glasses.battery === "number") {
                        batteryLevel = "眼镜 " + glasses.battery + "%"
                    } else {
                        refreshHostPower()
                    }
                } catch (error) {
                    refreshHostPower()
                }
            }
        }
        glassesRequest.send()
    }

    function refreshHostPower() {
        var powerRequest = new XMLHttpRequest()
        powerRequest.open("GET", "http://127.0.0.1:8591/api/power-status", true)
        powerRequest.onreadystatechange = function() {
            if (powerRequest.readyState === XMLHttpRequest.DONE && powerRequest.status === 200) {
                try {
                    var power = JSON.parse(powerRequest.responseText)
                    batteryLevel = power.available && typeof power.battery === "number"
                        ? "主机 " + power.battery + "%" : "外接电源"
                } catch (error) {
                    batteryLevel = "—"
                }
            }
        }
        powerRequest.send()
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date()
            currentTime = d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
        }
    }

    Timer {
        interval: 5000
        running: statusBar.visible
        repeat: true
        onTriggered: statusBar.refreshStatus()
    }

    Component.onCompleted: refreshStatus()
    
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
            font.letterSpacing: 1.5
        }
    }
    
    // Right: Control Center drag handle + system icons
    Row {
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            width: stereoLabel.width + 14
            height: 24
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: stereoEnabled
                ? Qt.rgba(0, 212/255, 1, 0.1)
                : Qt.rgba(1, 1, 1, 0.035)
            border.width: 1
            border.color: stereoEnabled
                ? Qt.rgba(0, 212/255, 1, 0.2)
                : Qt.rgba(1, 1, 1, 0.05)

            Text {
                id: stereoLabel
                anchors.centerIn: parent
                text: stereoEnabled ? "SBS" : "MONO"
                color: stereoEnabled ? "#00D4FF" : "#8E8EA8"
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 0.8
            }
        }

        Rectangle {
            width: trackingLabel.width + 14
            height: 24
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: headTrackingConnected
                ? Qt.rgba(0, 230/255, 118/255, 0.09)
                : Qt.rgba(1, 1, 1, 0.035)

            Text {
                id: trackingLabel
                anchors.centerIn: parent
                text: headTrackingConnected ? "3DoF" : "3DoF —"
                color: headTrackingConnected ? "#72E6A2" : "#666680"
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }
        }
        
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
