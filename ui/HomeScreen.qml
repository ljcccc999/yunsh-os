// YUNSH OS v1.0 - Home Screen (visionOS Ultimate)
// Dynamic visionOS-style circular app pages.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: homeScreen
    anchors.fill: parent
    
    property bool showStatusBar: true
    property bool stereoEnabled: false
    property bool headTrackingConnected: false
    property bool appIconsVisible: true
    property bool appIconsManuallyHidden: false
    property bool desktopIconToggleEnabled: false
    property bool reduceMotion: false
    
    signal openSettings()
    signal openAbout()
    signal openAppStore()
    signal openFileManager()
    signal openBrowser()
    signal openWorld()
    signal openSystemUpdateUI()
    signal openNetwork()
    signal openBluetooth()
    signal openTerminal()
    signal openPhotos()
    signal openSpatialDisplay()
    signal openSpaceCapsule()
    signal openScreenRelay()
    signal openAndroidApp(string packageName)
    signal showControlCenter()
    signal takeScreenshot()
    signal desktopActivated()
    signal appShelfInteracted()

    // ─── App Model (dynamic, auto-paginates) ────────────
    property var coreAppList: [
        { name: "设置", icon: "settings.svg",          color: "#4E8FEA",   action: "settings" },
        { name: "Browser", icon: "browser.svg",        color: "#5477D6",   action: "browser" },
        { name: "F-Droid", icon: "appstore.svg",       color: "#6E8F5B",   action: "appstore" },
        { name: "文件", icon: "files.svg",             color: "#5A8CC7",   action: "files" },
        { name: "终端", icon: "terminal.svg",          color: "#526F9E",   action: "terminal" },
        { name: "相册", icon: "photos.svg",            color: "#C78A62",   action: "photos" },
        { name: "空间显示", icon: "display.svg",       color: "#6678B8",   action: "display" },
        { name: "空间胶囊", icon: "capsule.svg",        color: "#8C76B0",   action: "spacecapsule" },
        { name: "iPhone 投屏", icon: "screen-relay.svg", color: "#4D93A6", action: "screenrelay" }
    ]
    property var androidApps: []
    property var appList: coreAppList.concat(androidApps)

    function setAndroidApps(apps) {
        var next = []
        for (var i = 0; i < apps.length; ++i) {
            var app = apps[i]
            if (!app || !app.package || app.package === "org.fdroid.fdroid")
                continue
            next.push({
                name: app.name || app.package,
                icon: "android-app.svg",
                color: "#7C77A8",
                action: "android:" + app.package
            })
        }
        androidApps = next
    }

    // A calm, evenly spaced spatial grid. The visual rhythm is inspired by
    // modern spatial operating systems while retaining YUNSH iconography.
    readonly property var rowPattern: [4, 5, 4]
    readonly property var rowOffsets: [0, 4, 9]
    readonly property int appsPerPage: 13

    function appCount() { return appList.length }
    function pageCount() { return Math.ceil(appList.length / appsPerPage) }

    function reorderApp(fromIndex, direction) {
        var toIndex = Math.max(0, Math.min(appList.length - 1, fromIndex + direction))
        if (toIndex === fromIndex) return
        var next = appList.slice(0)
        var moved = next[fromIndex]
        next[fromIndex] = next[toIndex]
        next[toIndex] = moved
        appList = next
        appShelfInteracted()
    }

    function handleAppAction(action) {
        switch(action) {
            case "settings":    homeScreen.openSettings(); break
            case "browser":     homeScreen.openBrowser(); break
            case "appstore":    homeScreen.openAppStore(); break
            case "files":       homeScreen.openFileManager(); break
            case "terminal":    homeScreen.openTerminal(); break
            case "photos":      homeScreen.openPhotos(); break
            case "display":     homeScreen.openSpatialDisplay(); break
            case "spacecapsule": homeScreen.openSpaceCapsule(); break
            case "screenrelay": homeScreen.openScreenRelay(); break
            default:
                if (action.indexOf("android:") === 0)
                    homeScreen.openAndroidApp(action.substring(8))
                else
                    console.log("Unknown app:", action)
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

    // With a visible app window, exposed desktop space toggles the temporary
    // icon shelf. This target sits below icon pages and app windows, so it does
    // not steal icon, window, or menu input.
    MouseArea {
        anchors.fill: parent
        enabled: homeScreen.desktopIconToggleEnabled
            && !homeScreen.appIconsManuallyHidden
        onClicked: homeScreen.desktopActivated()
    }

    // Status Bar
    StatusBar {
        id: statusBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: showStatusBar
        z: 100
        stereoEnabled: homeScreen.stereoEnabled
        headTrackingConnected: homeScreen.headTrackingConnected
        onScreenshotTriggered: homeScreen.takeScreenshot()
        onOpenControlCenter: homeScreen.showControlCenter()
    }

    // ─── Main Content ────────────────────────────
    Item {
        id: mainContent
        anchors.top: statusBar.bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        anchors.left: parent.left
        anchors.right: parent.right

        Column {
            anchors.fill: parent
            spacing: 8

            // ── VisionOS Orb Clock ──
            Item {
                // Global menu bar already owns the YUNSH/METAVERSE entry.
                // Avoid a second logo-and-clock strip on the desktop.
                visible: false
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

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: {
                        var d = new Date()
                        clockText.text = d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
                    }
                }
            }

            Rectangle {
                id: worldEntry
                // The persistent-world entry lives in the global menu bar.
                // Keep the home canvas focused on usable app icons.
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 120, 760)
                height: 82
                radius: 28
                color: worldEntryMouse.pressed ? "#E6FAFF" : Qt.rgba(1, 1, 1, 0.92)
                border.width: 1
                border.color: "#D6F5FF"
                scale: worldEntryMouse.pressed ? 0.985 : 1

                Row {
                    anchors.centerIn: parent
                    spacing: 18
                    Image {
                        source: "/usr/share/yunsh/logo/logo-64.png"
                        width: 36; height: 36
                        fillMode: Image.PreserveAspectFit
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: "YUNSH META Universe"
                            color: "#111820"
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.4
                        }
                        Text {
                            text: "THE SYSTEM WORLD · ENTER"
                            color: "#00A9CC"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1.8
                        }
                    }
                    Text {
                        text: "›"
                        color: "#00A9CC"
                        font.pixelSize: 30
                        font.weight: Font.Light
                    }
                }

                MouseArea {
                    id: worldEntryMouse
                    anchors.fill: parent
                    onClicked: homeScreen.openWorld()
                }
                Behavior on scale { NumberAnimation { duration: 100 } }
            }

            // ── Dynamic App Pages ──
            Item {
                id: appShelf
                width: parent.width
                height: parent.height - 162
                enabled: homeScreen.appIconsVisible
                visible: opacity > 0
                opacity: homeScreen.appIconsVisible ? 1 : 0
                scale: homeScreen.appIconsVisible ? 1 : 0.94
                transformOrigin: Item.Center

                Behavior on opacity {
                    NumberAnimation {
                        duration: homeScreen.reduceMotion ? 70 : 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: homeScreen.reduceMotion ? 70 : 240
                        easing.type: Easing.OutCubic
                    }
                }

                SwipeView {
                    id: swipeView
                    anchors.fill: parent
                    interactive: true
                    clip: true
                    onCurrentIndexChanged: homeScreen.appShelfInteracted()

                    Repeater {
                        model: pageCount()

                        Item {
                            property int pageIndex: index
                            property int startIdx: pageIndex * appsPerPage
                            property int endIdx: Math.min(startIdx + appsPerPage, appList.length)

                            Column {
                                anchors.centerIn: parent
                                spacing: 26

                                Repeater {
                                    model: 3

                                    Item {
                                        id: appRow
                                        required property int index
                                        property int rowStart: rowOffsets[index]
                                        property int remaining: Math.max(
                                            0, endIdx - startIdx - rowStart)
                                        property int rowCount: Math.min(
                                            rowPattern[index], remaining)
                                        width: Math.max(1, appItems.width)
                                        height: 100
                                        visible: rowCount > 0

                                        Row {
                                            id: appItems
                                            anchors.centerIn: parent
                                            spacing: 42

                                            Repeater {
                                                model: appRow.rowCount

                                                AppIcon {
                                                    required property int index
                                                    property int appIndex: startIdx
                                                        + appRow.rowStart + index
                                                    appName: appList[appIndex].name
                                                    iconSource: "/usr/share/yunsh/icons/"
                                                        + appList[appIndex].icon
                                                    iconColor: {
                                                        var c = appList[appIndex].color
                                                        var r = parseInt(c.substring(1,3), 16)
                                                        var g = parseInt(c.substring(3,5), 16)
                                                        var b = parseInt(c.substring(5,7), 16)
                                                        return Qt.rgba(r/255, g/255, b/255, 0.5)
                                                    }
                                                    onClicked: {
                                                        homeScreen.appShelfInteracted()
                                                        handleAppAction(appList[appIndex].action)
                                                    }
                                                    onReorderRequested: function(direction) {
                                                        homeScreen.reorderApp(appIndex, direction)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Version text on first page only
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "YUNSH OS v3.0.3"
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

}
