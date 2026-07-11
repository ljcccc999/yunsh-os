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
            onTakeScreenshot: takeScreenshot()
        }

        // ===== SETTINGS =====
        MacWindow {
            id: settingsWindow
            appTitle: "设置"
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
            x: 140; y: 80; width: 900; height: 650
            visible: false
            onCloseClicked: { yunshOS.closeAppFromSwitcher("photos") }
            onMinimizeClicked: { photosWindow.visible = false; photosWindow.isMinimized = true; homeScreen.visible = true }
            PhotosScreen { anchors.fill: parent
                onBackToHome: switchToHome()
            }
        }

        // ===== SCREENSHOT OVERLAY =====
        ScreenshotOverlay {
            id: screenshotOverlay
            anchors.fill: parent; visible: false; z: 200
            onRegionSelected: function(x, y, w, h) { screenshotOverlay.visible = false }
            onCancelled: screenshotOverlay.visible = false
        }

        // ===== VIRTUAL KEYBOARD =====
        VirtualKeyboard {
            id: virtualKeyboard
            anchors.fill: parent; z: 1000
            onDismissKeyboard: virtualKeyboard.hide()
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
        console.log("Screenshot triggered")
        Qt.callLater(function() {})
    }

    // ─── First-boot flag management ────────────────
    function checkFirstBoot() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file:///etc/yunsh/.activated", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                firstBoot = (xhr.status === 0)
                if (firstBoot) {
                    activationDone = false
                    activationScreen.visible = true
                    homeScreen.visible = false
                } else {
                    activationDone = true
                    activationScreen.visible = false
                    homeScreen.visible = true
                }
            }
        }
        xhr.send()
    }

    function saveActivationFlag() {
        var script = "#!/bin/bash\n"
        script += "# Auto-generated by YUNSH ActivationScreen\n"
        script += "if ! id -u " + activationScreen.accountUsername + " &>/dev/null; then\n"
        script += "    useradd -m -s /bin/bash " + activationScreen.accountUsername + "\n"
        script += "    echo '" + activationScreen.accountUsername + ":" + activationScreen.accountPassword + "' | chpasswd\n"
        script += "    usermod -aG sudo,audio,video,input,render " + activationScreen.accountUsername + "\n"
        script += "fi\n"
        script += "touch /etc/yunsh/.activated\n"
        script += "chmod 644 /etc/yunsh/.activated\n"
        var xhr = new XMLHttpRequest()
        xhr.open("PUT", "file:///etc/yunsh/.save_user_creds.sh")
        xhr.send(script)
        Qt.quit()
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
            if (screensaver.visible) { screensaver.wake(); return }
            if (activationScreen.visible && !activationDone) {
                activationScreen.skipActivation()
                return
            }
            if (!homeScreen.visible) { switchToHome(); return }
        }
    }

    function launchApp(appId) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("App launch [" + appId + "]: " + xhr.responseText)
            }
        }
        xhr.send(JSON.stringify({action: "launch", appId: appId}))
    }

    // ─── Mouse movement resets idle timer ──────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: false
        onPositionChanged: idleTimer.restart()
    }

    Component.onCompleted: {
        console.log("YUNSH OS UI v1.0.1.1 (visionOS Ultimate + Task Switcher)")
        checkFirstBoot()
        showFullScreen()
    }
}
