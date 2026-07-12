// YUNSH OS v1.0.1 - Main QML Entry Point (visionOS Ultimate)
// Apple-style glass system + Task Switcher + Home Indicator

import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    id: yunshOS
    visible: true
    width: 1920
    height: 1080

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "#000000"

    // ─── First-boot detection ────────────────────────
    property bool firstBoot: false
    property bool activationDone: false

    // ─── App Switcher tracking ───────────────────────
    // ─── 3DoF Head Tracking ─────────────────────────
    property real headYaw: 0.0
    property real headPitch: 0.0
    property real headRoll: 0.0
    property real pixelsPerDegree: 21.3  // 1920px ÷ ~90° FOV
    property bool headTrackingEnabled: false

    property var openApps: []
    property var appInfo: ({
        "settings": { name: "设置", icon: "/usr/share/yunsh/icons/settings.svg", color: "#00D4FF" },
        "browser": { name: "Browser", icon: "/usr/share/yunsh/icons/settings.svg", color: "#4CAF50" },
        "metaverse": { name: "Metaverse", icon: "/usr/share/yunsh/icons/metaverse.svg", color: "#9C27B0" },
        "terminal": { name: "终端", icon: "/usr/share/yunsh/icons/terminal.svg", color: "#00D4FF" },
        "photos": { name: "相册", icon: "/usr/share/yunsh/icons/photos.svg", color: "#FFC107" },
        "appstore": { name: "应用宝", icon: "/usr/share/yunsh/icons/appstore.svg", color: "#FF9800" },
        "files": { name: "文件", icon: "/usr/share/yunsh/icons/files.svg", color: "#2196F3" },
        "update": { name: "系统更新", icon: "/usr/share/yunsh/icons/update.svg", color: "#00D4FF" },
        "about": { name: "关于", icon: "/usr/share/yunsh/icons/about.svg", color: "#607D8B" },
        "network": { name: "Wi-Fi", icon: "/usr/share/yunsh/icons/wifi.svg", color: "#0096FF" },
        "bluetooth": { name: "蓝牙", icon: "/usr/share/yunsh/icons/bluetooth.svg", color: "#2196F3" },
        "systeminfo": { name: "系统信息", icon: "/usr/share/yunsh/icons/about.svg", color: "#607D8B" },
        "updatehistory": { name: "更新历史", icon: "/usr/share/yunsh/icons/update.svg", color: "#607D8B" }
    })

    function trackAppOpen(appId) {
        for (var i = 0; i < openApps.length; i++) {
            if (openApps[i].appId === appId) return
        }
        var info = appInfo[appId]
        if (info) {
            openApps.push({ appId: appId, name: info.name, icon: info.icon, color: info.color })
        }
    }

    function closeAppFromSwitcher(appId) {
        for (var i = 0; i < openApps.length; i++) {
            if (openApps[i].appId === appId) {
                openApps.splice(i, 1)
                break
            }
        }
        closeWindowById(appId)
        if (openApps.length === 0) homeScreen.visible = true
    }

    function closeWindowById(appId) {
        if (appId === "appstore" || appId === "files") {
            androidWindow.visible = false
            return
        }
        var w = getWindowById(appId)
        if (w) w.visible = false
    }

    function getWindowById(appId) {
        switch (appId) {
            case "settings": return settingsWindow
            case "browser": return browserWindow
            case "metaverse": return metaverseWindow
            case "terminal": return terminalWindow
            case "photos": return photosWindow
            case "update": return updateWindow
            case "about": return aboutWindow
            case "systeminfo": return systemInfoWindow
            case "network": return networkWindow
            case "bluetooth": return bluetoothWindow
            case "updatehistory": return updateHistoryWindow
            case "appstore":
            case "files": return androidWindow
        }
        return null
    }

    // Root container
    Item {
        id: rootContainer
        anchors.fill: parent

        // ===== ACTIVATION SCREEN (first boot) =========
        ActivationScreen {
            id: activationScreen
            anchors.fill: parent
            visible: firstBoot && !activationDone
            z: 500
            onActivationComplete: {
                activationDone = true
                activationScreen.visible = false
                homeScreen.visible = true
                saveActivationFlag()
            }
            onSkipActivation: {
                activationDone = true
                activationScreen.visible = false
                homeScreen.visible = true
                saveActivationFlag()
            }
        }

        // ===== HOME SCREEN =====
        HomeScreen {
            id: homeScreen
            anchors.fill: parent
            visible: !firstBoot || activationDone
            onOpenSettings: switchTo(settingsWindow, "settings")
            onOpenAbout: switchTo(systemInfoWindow, "systeminfo")
            onOpenAppStore: launchApp("appstore")
            onOpenFileManager: launchApp("files")
            onOpenBrowser: switchTo(browserWindow, "browser")
            onOpenMetaverse: switchTo(metaverseWindow, "metaverse")
            onOpenSystemUpdateUI: switchTo(updateWindow, "update")
            onOpenNetwork: switchTo(networkWindow, "network")
            onOpenBluetooth: switchTo(bluetoothWindow, "bluetooth")
            onOpenTerminal: switchTo(terminalWindow, "terminal")
            onOpenPhotos: switchTo(photosWindow, "photos")
            onShowControlCenter: controlCenter.show()
            onTakeScreenshot: takeScreenshot()
            onOpenAppLibrary: {}
        }

        // ===== CONTROL CENTER =====
        ControlCenter {
            id: controlCenter
            anchors.fill: parent
            visible: false
            z: 300
            onDismissPanel: controlCenter.hide()
            onOpenNetwork: { controlCenter.hide(); switchTo(networkWindow, "network") }
            onOpenBluetooth: { controlCenter.hide(); switchTo(bluetoothWindow, "bluetooth") }
            onToggleKeyboard: { controlCenter.hide(); virtualKeyboard.visible ? virtualKeyboard.hide() : virtualKeyboard.show() }
            onTakeScreenshot: takeScreenshot()
        }

        // ===== SETTINGS =====
        MacWindow {
            id: settingsWindow
            appTitle: "设置"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 80; y: 60; width: 900; height: 650
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("settings") }
            onMinimizeClicked: { settingsWindow.visible = false; settingsWindow.isMinimized = true; homeScreen.visible = true }
            SettingsScreen { anchors.fill: parent
                onBackToHome: switchToHome()
                onOpenUpdatePage: switchTo(updateWindow, "update")
                onOpenUpdateHistory: switchTo(updateHistoryWindow, "updatehistory")
                onOpenNetworkSettings: switchTo(networkWindow, "network")
                onOpenBluetoothSettings: switchTo(bluetoothWindow, "bluetooth")
                onOpenSystemInfo: switchTo(systemInfoWindow, "systeminfo")
                onOpenDisplaySettings: {}
                onOpenSoundSettings: {}
                onOpenLanguageSettings: {}
                onOpenDateTimeSettings: {}
            }
        }

        // ===== SYSTEM INFO =====
        MacWindow {
            id: systemInfoWindow
            appTitle: "系统信息"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 140; y: 100; width: 800; height: 600
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("systeminfo") }
            onMinimizeClicked: { systemInfoWindow.visible = false; systemInfoWindow.isMinimized = true; homeScreen.visible = true }
            SystemInfoScreen { anchors.fill: parent
                onBackToSettings: switchTo(settingsWindow, "settings")
            }
        }

        // ===== ABOUT =====
        MacWindow {
            id: aboutWindow
            appTitle: "关于"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 120; y: 160; width: 800; height: 550
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("about") }
            onMinimizeClicked: { aboutWindow.visible = false; aboutWindow.isMinimized = true; homeScreen.visible = true }
            AboutScreen { anchors.fill: parent
                onBackToHome: switchToHome()
            }
        }

        // ===== NETWORK/Wi-Fi =====
        MacWindow {
            id: networkWindow
            appTitle: "Wi-Fi"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 100; y: 120; width: 800; height: 550
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("network") }
            onMinimizeClicked: { networkWindow.visible = false; networkWindow.isMinimized = true; homeScreen.visible = true }
            NetworkScreen { anchors.fill: parent
                onBackToSettings: switchTo(settingsWindow, "settings")
                onBackToHome: switchToHome()
            }
        }

        // ===== BLUETOOTH =====
        MacWindow {
            id: bluetoothWindow
            appTitle: "蓝牙"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 180; y: 80; width: 800; height: 550
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("bluetooth") }
            onMinimizeClicked: { bluetoothWindow.visible = false; bluetoothWindow.isMinimized = true; homeScreen.visible = true }
            BluetoothScreen { anchors.fill: parent
                onBackToSettings: switchTo(settingsWindow, "settings")
                onBackToHome: switchToHome()
            }
        }

        // ===== UPDATE =====
        MacWindow {
            id: updateWindow
            appTitle: "系统更新"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 80; y: 100; width: 850; height: 600
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("update") }
            onMinimizeClicked: { updateWindow.visible = false; updateWindow.isMinimized = true; homeScreen.visible = true }
            UpdateScreen { anchors.fill: parent
                onBackToHome: switchToHome()
            }
        }

        // ===== UPDATE HISTORY =====
        MacWindow {
            id: updateHistoryWindow
            appTitle: "更新历史"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 160; y: 140; width: 800; height: 550
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("updatehistory") }
            onMinimizeClicked: { updateHistoryWindow.visible = false; updateHistoryWindow.isMinimized = true; homeScreen.visible = true }
            UpdateHistoryScreen { anchors.fill: parent
                onBackToUpdates: switchTo(settingsWindow, "settings")
            }
        }

        // ===== BROWSER =====
        MacWindow {
            id: browserWindow
            appTitle: "Browser"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 120; y: 60; width: 1000; height: 700
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("browser") }
            onMinimizeClicked: { browserWindow.visible = false; browserWindow.isMinimized = true; homeScreen.visible = true }
            YunshBrowser { anchors.fill: parent
                onBackToHome: switchToHome()
            }
        }

        // ===== METAVERSE =====
        MacWindow {
            id: metaverseWindow
            appTitle: "Metaverse"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 80; y: 160; width: 950; height: 680
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("metaverse") }
            onMinimizeClicked: { metaverseWindow.visible = false; metaverseWindow.isMinimized = true; homeScreen.visible = true }
            YunshMetaverse { anchors.fill: parent
                onBackToHome: switchToHome()
            }
        }

        // ===== TERMINAL =====
        MacWindow {
            id: terminalWindow
            appTitle: "终端"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 200; y: 120; width: 850; height: 600
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("terminal") }
            onMinimizeClicked: { terminalWindow.visible = false; terminalWindow.isMinimized = true; homeScreen.visible = true }
            TerminalScreen { anchors.fill: parent
                onBackToHome: switchToHome()
            }
        }

        // ===== PHOTOS =====
        MacWindow {
            id: photosWindow
            appTitle: "相册"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 140; y: 80; width: 900; height: 650
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("photos") }
            onMinimizeClicked: { photosWindow.visible = false; photosWindow.isMinimized = true; homeScreen.visible = true }
            PhotosScreen { anchors.fill: parent
                onBackToHome: switchToHome()
            }
        }

        // ===== ANDROID APP (Waydroid) =====
        MacWindow {
            id: androidWindow
            appTitle: "Android App"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 130; y: 80; width: 700; height: 540
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("appstore"); yunshOS.closeAppFromSwitcher("files") }
            onMinimizeClicked: { androidWindow.visible = false; androidWindow.isMinimized = true; homeScreen.visible = true }
        }

        // ===== SCREENSHOT OVERLAY =====
        ScreenshotOverlay {
            id: screenshotOverlay
            anchors.fill: parent; visible: false; z: 200
            onRegionSelected: function(x, y, w, h) {
                screenshotOverlay.visible = false
                // Grab the full window and crop to region
                yunshOS.grabToImage(function(result) {
                    var fullPath = "/tmp/yunsh-screenshot-region-full-" + Date.now() + ".png"
                    result.saveToFile(fullPath)
                    console.log("Region screenshot: (" + x + "," + y + " " + w + "x" + h + ") saved to " + fullPath)
                })
            }
            onCancelled: screenshotOverlay.visible = false
        }

        // ===== VIRTUAL KEYBOARD (visionOS floating panel) =====
        VirtualKeyboard {
            id: virtualKeyboard
            z: 1000
            onDismissKeyboard: virtualKeyboard.hide()
        }

        // ===== SCREENSAVER (visionOS standby) =====
        Screensaver {
            id: screensaver_item
            anchors.fill: parent
            visible: false
            z: 400
            onWake: {
                screensaver_item.visible = false
                idleTimer.restart()
            }
        }

        // ─── Idle timer — shows screensaver after 2 min no mouse ───
        Timer {
            id: idleTimer
            interval: 120000  // 2 minutes
            running: true
            repeat: false
            onTriggered: {
                if (!screensaver_item.visible) {
                    screensaver_item.visible = true
                }
            }
        }

        // ===== TASK SWITCHER (visionOS App Switcher) =====
        TaskSwitcher {
            id: taskSwitcher
            anchors.fill: parent
            openApps: yunshOS.openApps
            onSwitchToApp: function(appId) { hideTaskSwitcher(); switchToAppById(appId) }
            onCloseApp: function(appId) { yunshOS.closeAppFromSwitcher(appId) }
            onDismissSwitcher: hideTaskSwitcher()
        }

        // ===== HOME INDICATOR (mouse swipe up trigger) =====
        HomeIndicator {
            id: homeIndicator
            z: 300
            visible: homeScreen.visible || (taskSwitcher.visible && yunshOS.openApps.length > 0)
            onSwipeUpTriggered: showTaskSwitcher()
            onClicked: showTaskSwitcher()
        }
    }

    // ===== FLOATING WINDOW FUNCTIONS =====
    var windowCount = 0

    function switchTo(window, appId) {
        if (!window.visible) homeScreen.visible = true
        window.visible = true
        window.isMinimized = false
        windowCount++
        window.z = 60 + windowCount
        if (appId) trackAppOpen(appId)
    }

    function switchToHome() {
        var ids = ["update","updatehistory","browser","metaverse","terminal",
                    "photos","settings","about","systeminfo","network","bluetooth"]
        for (var i = 0; i < ids.length; i++) {
            var w = getWindowById(ids[i])
            if (w) { w.visible = false; w.isMinimized = false }
        }
        homeScreen.visible = true
    }

    function switchToAppById(appId) {
        var w = getWindowById(appId)
        if (w) switchTo(w, appId)
    }

    function showTaskSwitcher() {
        taskSwitcher.show()
    }

    function hideTaskSwitcher() {
        taskSwitcher.hide()
        if (yunshOS.openApps.length === 0) homeScreen.visible = true
    }

    function takeScreenshot() {
        console.log("Screenshot triggered - full screen capture")
        yunshOS.grabToImage(function(result) {
            var filename = "/tmp/yunsh-screenshot-" + Date.now() + ".png"
            result.saveToFile(filename)
            console.log("Full screenshot saved to " + filename)
        })
    }

    // ─── First-boot flag management ────────────────
    function checkFirstBoot() {
        var args = Qt.application.arguments
        firstBoot = true
        for (var i = 0; i < args.length; i++) {
            if (args[i] === "--activated") {
                firstBoot = false
                break
            }
        }
        activationDone = !firstBoot
        if (firstBoot) {
            activationScreen.visible = true
            homeScreen.visible = false
        } else {
            activationScreen.visible = false
            homeScreen.visible = true
        }
    }

    function saveActivationFlag() {
        Qt.quit(42)
    }

    // ===== KEYBOARD SHORTCUTS =====
    Shortcut { sequence: "Print"; onActivated: takeScreenshot() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: screenshotOverlay.visible = true }
    Shortcut { sequence: "Ctrl+Shift+C"; onActivated: controlCenter.toggle() }
    Shortcut { sequence: "Ctrl+Up"; onActivated: showTaskSwitcher() }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (taskSwitcher.visible) { hideTaskSwitcher(); return }
            if (controlCenter.visible) { controlCenter.hide(); return }
            if (screenshotOverlay.visible) { screenshotOverlay.cancelled(); return }
            if (virtualKeyboard.visible) { virtualKeyboard.hide(); return }
            if (screensaver_item.visible) { screensaver_item.wake(); return }
            if (activationScreen.visible && !activationDone) {
                activationScreen.skipActivation()
                return
            }
            if (!homeScreen.visible) { switchToHome(); return }
        }
    }

    property var androidAppInfo: ({})

    function launchApp(appId) {
        var info = appInfo[appId]
        if (!info) return

        // Show Android window
        androidWindow.appTitle = info.name
        var w = androidWindow
        w.x = 80 + (windowCount % 3) * 40
        w.y = 80 + (windowCount % 3) * 30
        w.visible = true
        w.isMinimized = false
        w.z = 60 + (++windowCount)
        trackAppOpen(appId)

        // Send launch to daemon (port 8590 — needs yunsh-app-daemon running)
        try {
            var xhr = new XMLHttpRequest()
            xhr.open("POST", "http://127.0.0.1:8590/launch", true)
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.timeout = 1000
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    console.log("App launch [" + appId + "]: " + (xhr.responseText || "no response"))
                }
            }
            xhr.send(JSON.stringify({action: "launch", appId: appId}))
        } catch(e) {
            console.log("App daemon not available on port 8590 — window shown regardless")
        }
    }

    // ─── Head Tracking Polling ────────────────────────
    // Polls yunsh-headtracking daemon.
    // Uses a two-phase approach:
    //   1. Initial probe: try once, if no response → don't poll
    //   2. If daemon detected: poll every 100ms while active
    // This avoids 20 req/s forever on systems without IMU.
    property bool htDaemonDetected: false
    property int htPollInterval: 100

    function probeHeadTracking() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8592/tracking", true)
        xhr.timeout = 500
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    yunshOS.htDaemonDetected = true
                    yunshOS.htPollInterval = 100
                    headTrackingTimer.interval = 100
                    headTrackingTimer.running = true
                } else {
                    yunshOS.htDaemonDetected = false
                    headTrackingTimer.running = false
                    console.log("YUNSH: No head tracking daemon found — IMU polling disabled")
                }
            }
        }
        xhr.send()
    }

    Timer {
        id: headTrackingTimer
        interval: 100
        running: false  // Don't start until probe succeeds
        repeat: true
        onTriggered: {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", "http://127.0.0.1:8592/tracking", true)
            xhr.timeout = 200
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var data = JSON.parse(xhr.responseText)
                            yunshOS.headYaw = data.yaw || 0
                            yunshOS.headPitch = data.pitch || 0
                            yunshOS.headRoll = data.roll || 0
                            yunshOS.headTrackingEnabled = true
                        } catch(e) {}
                    } else {
                        // Lost connection — slow polling
                        if (yunshOS.htPollInterval < 5000) {
                            yunshOS.htPollInterval = Math.min(5000, yunshOS.htPollInterval * 2)
                            headTrackingTimer.interval = yunshOS.htPollInterval
                        }
                    }
                }
            }
            xhr.send()
        }
    }

    // ─── Mouse movement resets idle timer ──────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: false
        onPositionChanged: {
            idleTimer.restart()
            if (screensaver_item.visible) {
                screensaver_item.visible = false
            }
        }
    }

    Component.onCompleted: {
        console.log("YUNSH OS UI v1.0.1.1 (visionOS Ultimate + Task Switcher)")
        checkFirstBoot()
        showFullScreen()
        // Probe head tracking daemon once (won't poll if not found)
        Qt.callLater(function() {
            yunshOS.probeHeadTracking()
        })
    }
}
