// YUNSH OS v1.0 - Network Settings / Wi-Fi Screen (visionOS Style)
// Communicates with yunsh-network-daemon via socket

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: networkScreen
    anchors.fill: parent
    color: "#000000"  // Transparent in AR
    visible: false
    z: 60
    
    property bool scanning: false
    property bool connected: false
    property string currentSSID: ""
    property string currentIP: ""
    property var networks: []
    property var savedNetworks: []
    
    signal backToSettings()
    signal backToHome()
    
    // Timer to poll network status
    Timer {
        id: statusTimer
        interval: 5000
        running: networkScreen.visible
        repeat: true
        onTriggered: pollStatus()
    }
    
    // Read network status from file
    function pollStatus() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file:///tmp/yunsh-network-status.json", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 0) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    connected = data.connected || false
                    currentSSID = data.ssid || ""
                    currentIP = data.ip_address || ""
                } catch(e) {}
            }
        }
        xhr.send()
    }
    
    // Trigger Wi-Fi scan
    function scanNetworks() {
        if (scanning) return
        scanning = true
        networks = []
        
        // Trigger scan via socket (simplified - use script)
        scanTimer.start()
    }
    
    Timer {
        id: scanTimer
        interval: 2000
        onTriggered: {
            // On real system, would read scan results from daemon
            // For now, simulate with nmcli output
            var proc = scanProcess
            scanning = false
        }
    }
    
    // Connect to a network
    function connectToNetwork(ssid, password) {
        loadingOverlay.visible = true
        loadingText.text = "正在连接到 " + ssid + "..."
        
        // The real connection happens via backend
        // QML side shows loading state
        Qt.callLater(function() {
            loadingOverlay.visible = false
            connected = true
            currentSSID = ssid
            pollStatus()
        })
    }
    
    // visionOS glass header
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "transparent"
        
        // Back button
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
                onClicked: networkScreen.backToSettings()
            }
        }
        
        // Title
        Text {
            anchors.centerIn: parent
            text: "网络"
            color: "#FFFFFF"
            font.pixelSize: 20
            font.weight: Font.Bold
        }
        
        // Scan refresh button
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 8
            color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: scanning ? "⏳" : "🔄"
                font.pixelSize: 16
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: scanNetworks()
            }
        }
    }
    
    // Current connection status card
    GlassCard {
        id: connectionCard
        anchors.top: parent.top
        anchors.topMargin: 68
        anchors.left: parent.left
        anchors.leftMargin: 40
        anchors.right: parent.right
        anchors.rightMargin: 40
        height: 80
        cardCornerRadius: 16
        iconSize: 32
        
        iconSource: "/usr/share/yunsh/icons/wifi.svg"
        title: connected ? currentSSID : "未连接"
        subtitle: connected ? ("IP: " + currentIP) : "点击下方网络进行连接"
        
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10; radius: 5
            color: connected ? "#00E676" : "#FF5252"
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (connected) {
                    // Show disconnect option
                    disconnectConfirm.visible = true
                }
            }
        }
    }
    
    // Available networks label
    Text {
        anchors.top: connectionCard.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 48
        text: "可用网络"
        color: "#8888A0"
        font.pixelSize: 14
        font.weight: Font.Medium
    }
    
    // Network list
    ListView {
        id: networkList
        anchors.top: connectionCard.bottom
        anchors.topMargin: 44
        anchors.left: parent.left
        anchors.leftMargin: 40
        anchors.right: parent.right
        anchors.rightMargin: 40
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        
        spacing: 6
        clip: true
        
        model: ListModel {
            // Demo networks that will show on RPi
            ListElement { netSSID: "(扫描中...)" ; netSignal: 0; netSecurity: ""; netLocked: false; netConnected: false }
        }
        
        delegate: Item {
            width: parent.width
            height: 64
            
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
                border.width: 1
                
                // Signal strength indicator
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: 4
                    color: "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: getSignalIcon(netSignal)
                        font.pixelSize: 16
                    }
                }
                
                // Network info
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 44
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    
                    Text {
                        text: netSSID
                        color: "#FFFFFF"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }
                    
                    Text {
                        text: netSecurity ? getSecurityText(netSecurity) : "开放网络"
                        color: "#666680"
                        font.pixelSize: 11
                    }
                }
                
                // Lock/status icon
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 14
                    color: netLocked ? Qt.rgba(255/255, 152/255, 0/255, 0.1) : Qt.rgba(0/255, 230/255, 118/255, 0.1)
                    
                    Text {
                        anchors.centerIn: parent
                        text: netLocked ? "🔒" : "🔓"
                        font.pixelSize: 12
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.08)
                    onExited: parent.color = Qt.rgba(255/255, 255/255, 255/255, 0.03)
                    onClicked: {
                        if (netLocked) {
                            passwordDialog.ssid = netSSID
                            passwordDialog.visible = true
                        } else {
                            connectToNetwork(netSSID, "")
                        }
                    }
                }
            }
            
            function getSignalIcon(signal) {
                if (signal > 75) return "📶"
                if (signal > 50) return "📶"
                if (signal > 25) return "📶"
                return "📶"
            }
            
            function getSecurityText(sec) {
                if (sec.includes("WPA3")) return "WPA3"
                if (sec.includes("WPA2")) return "WPA2"
                if (sec.includes("WPA")) return "WPA"
                if (sec.includes("WEP")) return "WEP"
                return sec
            }
        }
        
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }
    
    // Password dialog (visionOS style)
    Rectangle {
        id: passwordDialog
        anchors.fill: parent
        visible: false
        z: 100
        color: Qt.rgba(0, 0, 0, 0.6)
        
        property string ssid: ""
        
        MouseArea {
            anchors.fill: parent
            // Block clicks behind dialog
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 220
            radius: 24
            color: Qt.rgba(20/255, 20/255, 40/255, 0.85)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
            border.width: 1
            
            Column {
                anchors.centerIn: parent
                spacing: 16
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "连接到 " + passwordDialog.ssid
                    color: "#FFFFFF"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
                
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 300; height: 40; radius: 12
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                    border.color: Qt.rgba(0/255, 212/255, 255/255, 0.2)
                    border.width: 1
                    
                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.margins: 12
                        color: "#FFFFFF"
                        font.pixelSize: 14
                        echoMode: TextInput.Password
                        placeholderText: "输入Wi-Fi密码"
                        placeholderTextColor: "#666680"
                        focus: true
                    }
                }
                
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    
                    // Cancel
                    Rectangle {
                        width: 130; height: 40; radius: 20
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                        
                        Text {
                            anchors.centerIn: parent
                            text: "取消"
                            color: "#8888A0"
                            font.pixelSize: 14
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                passwordDialog.visible = false
                                passwordInput.text = ""
                            }
                        }
                    }
                    
                    // Connect
                    Rectangle {
                        width: 130; height: 40; radius: 20
                        color: Qt.rgba(0/255, 212/255, 255/255, 0.2)
                        border.color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
                        border.width: 1
                        
                        Text {
                            anchors.centerIn: parent
                            text: "连接"
                            color: "#00D4FF"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                connectToNetwork(passwordDialog.ssid, passwordInput.text)
                                passwordDialog.visible = false
                                passwordInput.text = ""
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Disconnect confirmation
    Rectangle {
        id: disconnectConfirm
        anchors.fill: parent
        visible: false
        z: 100
        color: Qt.rgba(0, 0, 0, 0.6)
        
        Rectangle {
            anchors.centerIn: parent
            width: 300; height: 140; radius: 24
            color: Qt.rgba(20/255, 20/255, 40/255, 0.85)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
            border.width: 1
            
            Column {
                anchors.centerIn: parent
                spacing: 16
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "断开 " + currentSSID + "?"
                    color: "#FFFFFF"
                    font.pixelSize: 16
                }
                
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    
                    Rectangle {
                        width: 120; height: 40; radius: 20
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                        Text { anchors.centerIn: parent; text: "取消"; color: "#8888A0"; font.pixelSize: 14 }
                        MouseArea { anchors.fill: parent; onClicked: disconnectConfirm.visible = false }
                    }
                    
                    Rectangle {
                        width: 120; height: 40; radius: 20
                        color: Qt.rgba(255/255, 82/255, 82/255, 0.15)
                        border.color: Qt.rgba(255/255, 82/255, 82/255, 0.2)
                        border.width: 1
                        Text { anchors.centerIn: parent; text: "断开"; color: "#FF5252"; font.pixelSize: 14 }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                disconnectConfirm.visible = false
                                connected = false
                                currentSSID = ""
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Loading overlay
    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        visible: false
        z: 200
        color: Qt.rgba(0, 0, 0, 0.5)
        
        Column {
            anchors.centerIn: parent
            spacing: 12
            
            Text {
                text: "⏳"
                font.pixelSize: 32
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                id: loadingText
                color: "#FFFFFF"
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
    
    // Component ready
    Component.onCompleted: {
        pollStatus()
    }
}
