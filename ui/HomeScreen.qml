// YUNSH OS v1.0 - Home Screen (visionOS Ultimate)
// Dynamic app pages (iOS-style), glass clock widget, floating dock

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

    // ─── App Model (dynamic, auto-paginates) ────────────
    property var appList: [
        { name: "设置", icon: "settings.svg",        color: "#00D4FF",   action: "settings" },
        { name: "Browser", icon: "settings.svg",      color: "#4CAF50",   action: "browser" },
        { name: "Metaverse", icon: "metaverse.svg",   color: "#9C27B0",   action: "metaverse" },
        { name: "应用宝", icon: "appstore.svg",        color: "#FF9800",   action: "appstore" },
        { name: "文件", icon: "files.svg",             color: "#2196F3",   action: "files" },
        { name: "终端", icon: "terminal.svg",          color: "#00D4FF",   action: "terminal" },
        { name: "相册", icon: "photos.svg",            color: "#FFC107",   action: "photos" }
    ]

    readonly property int columns: 4
    readonly property int rows: 2
    readonly property int appsPerPage: columns * rows

    function appCount() { return appList.length }
    function pageCount() { return Math.ceil(appList.length / appsPerPage) }

    function handleAppAction(action) {
        switch(action) {
            case "settings":    homeScreen.openSettings(); break
            case "browser":     homeScreen.openBrowser(); break
            case "metaverse":   homeScreen.openMetaverse(); break
            case "appstore":    homeScreen.openAppStore(); break
            case "files":       homeScreen.openFileManager(); break
            case "terminal":    homeScreen.openTerminal(); break
            case "photos":      homeScreen.openPhotos(); break
            default:            console.log("Unknown app:", action)
        }
    }

    // ─── Background (transparent - GlassBackground shows through) ─────
    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    // Subtle ambient glow
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

    // ─── Main Content ────────────────────────────
    Item {
        id: mainContent
        anchors.top: statusBar.bottom
        anchors.bottom: dockArea.top
        anchors.left: parent.left
        anchors.right: parent.right

        Column {
            anchors.fill: parent
            spacing: 8

            // ── VisionOS Orb Clock ──
            Item {
                width: parent.width
                height: 56

                Item {
                    anchors.centerIn: parent

                    // Glass orb background
                    Rectangle {
                        anchors.centerIn: parent
                        width: orbContent.width + 36
                        height: 36; radius: 18
                        color: Qt.rgba(12/255, 12/255, 25/255, 0.35)
                        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        border.width: 1

                        // Frost layer
                        Rectangle {
                            anchors.fill: parent; radius: 18
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
                        }

                        // Top highlight rim
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.right: parent.right; anchors.rightMargin: 10
                            height: 1; radius: 1
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                        }

                        layer.enabled: true
                        layer.effect: DropShadowEffect {
                            radius: 20; samples: 40
                            color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
                            verticalOffset: 4
                        }
                    }

                    Row {
                        id: orbContent
                        anchors.centerIn: parent
                        spacing: 12

                        // YUNSH brand
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: -2
                            Text {
                                text: "YUNSH"; color: "#FFFFFF"
                                font.pixelSize: 15; font.weight: Font.Bold
                                font.letterSpacing: 2.5
                            }
                            Text {
                                text: "OS"; color: Qt.rgba(255/255, 255/255, 255/255, 0.25)
                                font.pixelSize: 9; font.letterSpacing: 5
                            }
                        }

                        // Separator
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1; height: 18
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                        }

                        // Time
                        Text {
                            id: clockText
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var d = new Date()
                                return d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
                            }
                            color: "#FFFFFF"
                            font.pixelSize: 16
                            font.weight: Font.Light
                        }
                    }
                }

                Clock { id: clock }
                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: {
                        var d = new Date()
                        clockText.text = d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
                    }
                }
            }

            // ── Dynamic App Pages ──
            Item {
                width: parent.width
                height: parent.height - 64

                SwipeView {
                    id: swipeView
                    anchors.fill: parent
                    interactive: true
                    clip: true

                    Repeater {
                        model: pageCount()

                        Item {
                            property int pageIndex: index
                            property int startIdx: pageIndex * appsPerPage
                            property int endIdx: Math.min(startIdx + appsPerPage, appList.length)

                            Grid {
                                anchors.centerIn: parent
                                spacing: 28
                                columns: columns

                                Repeater {
                                    model: endIdx - startIdx

                                    AppIcon {
                                        appName: appList[startIdx + index].name
                                        appIcon: "/usr/share/yunsh/icons/" + appList[startIdx + index].icon
                                        iconColor: {
                                            var c = appList[startIdx + index].color
                                            var r = parseInt(c.substring(1,3), 16)
                                            var g = parseInt(c.substring(3,5), 16)
                                            var b = parseInt(c.substring(5,7), 16)
                                            return Qt.rgba(r/255, g/255, b/255, 0.5)
                                        }
                                        onClicked: handleAppAction(appList[startIdx + index].action)
                                    }
                                }
                            }

                            // Version text on first page only
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "YUNSH OS v1.0.1"
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                                font.pixelSize: 11
                                visible: pageIndex === 0
                            }
                        }
                    }
                }

                // Page indicator — auto-adjusts
                PageIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 0
                    count: pageCount()
                    currentIndex: swipeView.currentIndex
                    interactive: true
                    spacing: 6
                    visible: pageCount() > 1

                    delegate: Rectangle {
                        width: index === swipeView.currentIndex ? 10 : 6
                        height: 6; radius: 3
                        color: index === swipeView.currentIndex ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.15)
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }

                // Single dot when only 1 page
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 6; height: 6; radius: 3
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.1)
                    visible: pageCount() <= 1
                }
            }
        }
    }

    // ===== FLOATING SCREENSHOT BUTTON =====
    Rectangle {
        id: screenshotFloatingBtn
        anchors.right: parent.right; anchors.rightMargin: 24
        anchors.bottom: dockArea.top; anchors.bottomMargin: 16
        width: 48; height: 48; radius: 24; z: 50
        color: mouseArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.18) : Qt.rgba(0/255, 212/255, 255/255, 0.08)
        border.color: mouseArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.2) : Qt.rgba(0/255, 212/255, 255/255, 0.06)
        border.width: 1

        Rectangle {
            anchors.fill: parent; radius: 24
            color: "transparent"
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.05); border.width: 2
        }

        Image {
            anchors.centerIn: parent
            source: "/usr/share/yunsh/icons/screenshot.svg"
            width: 22; height: 22
            sourceSize.width: 48; sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
        }

        MouseArea {
            id: mouseArea; anchors.fill: parent; hoverEnabled: true
            onClicked: homeScreen.takeScreenshot()
        }

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ===== DOCK =====
    Item {
        id: dockArea
        anchors.bottom: parent.bottom; anchors.bottomMargin: 8
        anchors.left: parent.left; anchors.leftMargin: 40
        anchors.right: parent.right; anchors.rightMargin: 40
        height: 80; visible: showDock; z: 100

        AppDock {
            anchors.fill: parent
            onAppLaunched: function(appId) {
                handleAppAction(appId)
            }
            onOpenAppLibrary: homeScreen.openAppLibrary()
        }
    }
}
