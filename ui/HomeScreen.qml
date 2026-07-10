// YUNSH OS v1.0 - Home Screen (visionOS / iOS-style)
// Pure app grid pages + YUNSH logo + dock

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
    signal openTerminal()
    signal openPhotos()
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
    
    // Main content - YUNSH logo + swipeable app pages
    Item {
        id: mainContent
        anchors.top: statusBar.bottom
        anchors.bottom: dockArea.top
        anchors.left: parent.left
        anchors.right: parent.right

        Column {
            anchors.fill: parent
            spacing: 8

            // ── YUNSH Logo ──
            Item {
                width: parent.width
                height: 48
                anchors.horizontalCenter: undefined  // reset centering

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    // Atom logo
                    Item {
                        width: 28; height: 28
                        anchors.verticalCenter: parent.verticalCenter

                        // Electron orbit ring
                        Rectangle {
                            anchors.centerIn: parent
                            width: 28; height: 14
                            radius: 14
                            color: "transparent"
                            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.18)
                            border.width: 1.5
                            transform: Rotation { angle: -30 }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 28; height: 14
                            radius: 14
                            color: "transparent"
                            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.18)
                            border.width: 1.5
                            transform: Rotation { angle: 30 }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 28; height: 14
                            radius: 14
                            color: "transparent"
                            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.18)
                            border.width: 1.5
                            transform: Rotation { angle: 90 }
                        }
                        // Electron dot
                        Rectangle {
                            anchors.centerIn: parent
                            width: 4; height: 4; radius: 2
                            color: "#00D4FF"
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -2
                        Text {
                            text: "YUNSH"
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            font.letterSpacing: 3
                        }
                        Text {
                            text: "OS"
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.3)
                            font.pixelSize: 10
                            font.letterSpacing: 6
                        }
                    }
                }
            }

            // ── Swipeable App Pages ──
            Item {
                width: parent.width
                height: parent.height - 56  // subtract logo area

                SwipeView {
                    id: swipeView
                    anchors.fill: parent
                    interactive: true
                    clip: true

                    // ─── Page 1: Main Apps ─────────────
                    Item {
                        Grid {
                            anchors.centerIn: parent
                            spacing: 28
                            columns: 4

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
                                appName: "终端"
                                appIcon: "/usr/share/yunsh/icons/terminal.svg"
                                iconColor: Qt.rgba(0/255, 212/255, 255/255, 0.5)
                                onClicked: homeScreen.openTerminal()
                            }
                            AppIcon {
                                appName: "相册"
                                appIcon: "/usr/share/yunsh/icons/photos.svg"
                                iconColor: Qt.rgba(255/255, 193/255, 7/255, 0.5)
                                onClicked: homeScreen.openPhotos()
                            }
                            AppIcon {
                                appName: "摄像头"
                                appIcon: "/usr/share/yunsh/icons/camera.svg"
                                iconColor: Qt.rgba(0/255, 150/255, 255/255, 0.5)
                                visible: false  // placeholder
                            }
                        }

                        // Version text at bottom
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 16
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "YUNSH OS v1.0.0"
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                            font.pixelSize: 11
                        }
                    }

                    // ─── Page 2: Waydroid / Library ─────────────
                    Item {
                        Column {
                            anchors.centerIn: parent
                            spacing: 24

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "已安装应用"
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.5)
                                font.pixelSize: 20
                                font.weight: Font.Light
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "通过应用宝安装 Android 应用"
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.2)
                                font.pixelSize: 12
                            }

                            Grid {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 28
                                columns: 4

                                AppIcon {
                                    appName: "应用宝"
                                    appIcon: "/usr/share/yunsh/icons/appstore.svg"
                                    iconColor: Qt.rgba(255/255, 152/255, 0/255, 0.5)
                                    onClicked: homeScreen.openAppStore()
                                }
                            }
                        }
                    }
                }

                // Page indicator
                PageIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 0
                    count: swipeView.count
                    currentIndex: swipeView.currentIndex
                    interactive: true
                    spacing: 6

                    delegate: Rectangle {
                        width: index === swipeView.currentIndex ? 10 : 6
                        height: 6; radius: 3
                        color: index === swipeView.currentIndex ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.15)
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }
            }
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
