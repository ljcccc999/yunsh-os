// YUNSH OS v1.0 - Home Screen (visionOS / iOS-style)
// Floating app grid, dock, status bar, app library access, floating screenshot button

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: homeScreen
    anchors.fill: parent
    
    property bool showDock: true
    property bool showStatusBar: true
    
    signal openSettings()
    signal openAbout()
    signal openAppStore()
    signal openFileManager()
    signal openBrowser()
    signal openMetaverse()
    signal openSystemUpdateUI()
    signal openNetwork()
    signal openBluetooth()
    signal openAppLibrary()
    signal showControlCenter()
    signal takeScreenshot()
    
    // Pure black background (transparent in AR glasses)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }
    
    // Subtle ambient glow (visionOS atmospheric effect)
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.6
        height: parent.height * 0.4
        radius: width / 2
        color: Qt.rgba(0/255, 100/255, 255/255, 0.02)
    }
    
    // Status Bar
    StatusBar {
        id: statusBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: showStatusBar
        z: 100
        
        onScreenshotTriggered: homeScreen.takeScreenshot()
    }
    
    // Main content - centered app area
    Item {
        id: mainContent
        anchors.top: statusBar.bottom
        anchors.bottom: dockArea.top
        anchors.left: parent.left
        anchors.right: parent.right
        
        // Page indicator dots
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            spacing: 8
            z: 10
            
            Rectangle {
                width: 8; height: 8; radius: 4
                color: "#00D4FF"
            }
            Rectangle {
                width: 6; height: 6; radius: 3
                color: Qt.rgba(255/255, 255/255, 255/255, 0.15)
            }
        }
        
        // App grid
        Grid {
            anchors.centerIn: parent
            spacing: 28
            columns: 5
            
            AppIcon {
                appName: "设置"
                appIcon: "/usr/share/yunsh/icons/settings.svg"
                iconColor: Qt.rgba(0/255, 212/255, 255/255, 0.5)
                onClicked: homeScreen.openSettings()
            }
            
            AppIcon {
                appName: "Browser"
                appIcon: "/usr/share/yunsh/icons/settings.svg"
                iconColor: Qt.rgba(76/255, 175/255, 80/255, 0.5)
                onClicked: homeScreen.openBrowser()
            }
            
            AppIcon {
                appName: "Metaverse"
                appIcon: "/usr/share/yunsh/icons/metaverse.svg"
                iconColor: Qt.rgba(156/255, 39/255, 176/255, 0.5)
                onClicked: homeScreen.openMetaverse()
            }
            
            AppIcon {
                appName: "应用宝"
                appIcon: "/usr/share/yunsh/icons/appstore.svg"
                iconColor: Qt.rgba(255/255, 152/255, 0/255, 0.5)
                onClicked: homeScreen.openAppStore()
            }
            
            AppIcon {
                appName: "文件"
                appIcon: "/usr/share/yunsh/icons/files.svg"
                iconColor: Qt.rgba(33/255, 150/255, 243/255, 0.5)
                onClicked: homeScreen.openFileManager()
            }
            
            AppIcon {
                appName: "Wi-Fi"
                appIcon: "/usr/share/yunsh/icons/wifi.svg"
                iconColor: Qt.rgba(0/255, 150/255, 255/255, 0.5)
                onClicked: homeScreen.openNetwork()
            }
            
            AppIcon {
                appName: "蓝牙"
                appIcon: "/usr/share/yunsh/icons/bluetooth.svg"
                iconColor: Qt.rgba(33/255, 150/255, 243/255, 0.5)
                onClicked: homeScreen.openBluetooth()
            }
            
            AppIcon {
                appName: "系统更新"
                appIcon: "/usr/share/yunsh/icons/update.svg"
                iconColor: Qt.rgba(0/255, 200/255, 83/255, 0.5)
                onClicked: homeScreen.openSystemUpdateUI()
            }
            
            AppIcon {
                appName: "关于本机"
                appIcon: "/usr/share/yunsh/icons/about.svg"
                iconColor: Qt.rgba(96/255, 125/255, 139/255, 0.5)
                onClicked: homeScreen.openAbout()
            }
        }
        
        // Version text at bottom
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: "YUNSH OS v1.0.0"
            color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
            font.pixelSize: 11
        }
    }
    
    // ===== FLOATING SCREENSHOT BUTTON =====
    Rectangle {
        id: screenshotFloatingBtn
        anchors.right: parent.right; anchors.rightMargin: 24
        anchors.bottom: dockArea.top; anchors.bottomMargin: 16
        width: 48; height: 48
        radius: 24
        z: 50
        color: mouseArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.18) : Qt.rgba(0/255, 212/255, 255/255, 0.08)
        border.color: mouseArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.2) : Qt.rgba(0/255, 212/255, 255/255, 0.06)
        border.width: 1
        
        // Outer glow
        Rectangle {
            anchors.fill: parent; radius: 24
            color: "transparent"
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.05)
            border.width: 2
        }
        
        Image {
            anchors.centerIn: parent
            source: "/usr/share/yunsh/icons/screenshot.svg"
            width: 22; height: 22
            sourceSize.width: 48; sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
        }
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: homeScreen.takeScreenshot()
        }
        
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    
    // Dock
    Item {
        id: dockArea
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.left: parent.left; anchors.leftMargin: 40
        anchors.right: parent.right; anchors.rightMargin: 40
        height: 80
        visible: showDock
        z: 100
        
        AppDock {
            anchors.fill: parent
            onAppLaunched: function(appId) {
                switch(appId) {
                    case "settings": homeScreen.openSettings(); break;
                    case "appstore": homeScreen.openAppStore(); break;
                    case "about": homeScreen.openAbout(); break;
                    case "browser": homeScreen.openBrowser(); break;
                    case "metaverse": homeScreen.openMetaverse(); break;
                    case "update": homeScreen.openSystemUpdateUI(); break;
                }
            }
            onOpenAppLibrary: homeScreen.openAppLibrary()
        }
    }
}
