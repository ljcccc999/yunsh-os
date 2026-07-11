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
        if (appId === "settings") settingsScreen.visible = false
        else if (appId === "browser") browserScreen.visible = false
        else if (appId === "metaverse") metaverseScreen.visible = false
        else if (appId === "terminal") terminalScreen.visible = false
        else if (appId === "photos") photosScreen.visible = false
        else if (appId === "update") updateScreen.visible = false
        else if (appId === "about") aboutScreen.visible = false
        else if (appId === "systeminfo") systemInfoScreen.visible = false
        else if (appId === "network") networkScreen.visible = false
        else if (appId === "bluetooth") bluetoothScreen.visible = false
        else if (appId === "updatehistory") updateHistoryScreen.visible = false
        if (openApps.length === 0) homeScreen.visible = true
    }

    // Root container
    Item {
        id: rootContainer
        anchors.fill: parent

        // Full-screen white glass background for all screens
        GlassBackground { anchors.fill: parent }

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
            onOpenSettings: switchTo(settingsScreen, "settings")
            onOpenAbout: switchTo(systemInfoScreen, "systeminfo")
            onOpenAppStore: launchApp("appstore")
            onOpenFileManager: launchApp("files")
            onOpenBrowser: switchTo(browserScreen, "browser")
            onOpenMetaverse: switchTo(metaverseScreen, "metaverse")
            onOpenSystemUpdateUI: switchTo(updateScreen, "update")
            onOpenNetwork: switchTo(networkScreen, "network")
            onOpenBluetooth: switchTo(bluetoothScreen, "bluetooth")
            onOpenTerminal: switchTo(terminalScreen, "terminal")
            onOpenPhotos: switchTo(photosScreen, "photos")
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
            onOpenNetwork: { controlCenter.hide(); switchTo(networkScreen, "network") }
            onOpenBluetooth: { controlCenter.hide(); switchTo(bluetoothScreen, "bluetooth") }
            onTakeScreenshot: takeScreenshot()
        }

        // ===== SETTINGS =====
        Item { id: settingsScreen; anchors.fill: parent; visible: false; z: 50
            SettingsScreen { anchors.fill: parent; visible: true
                onBackToHome: switchToHome()
                onOpenUpdatePage: switchTo(updateScreen, "update")
                onOpenUpdateHistory: switchTo(updateHistoryScreen, "updatehistory")
                onOpenNetworkSettings: switchTo(networkScreen, "network")
                onOpenBluetoothSettings: switchTo(bluetoothScreen, "bluetooth")
                onOpenSystemInfo: switchTo(systemInfoScreen, "systeminfo")
                onOpenDisplaySettings: {}
                onOpenSoundSettings: {}
                onOpenLanguageSettings: {}
                onOpenDateTimeSettings: {}
            }
        }

        // ===== SYSTEM INFO =====
        Item { id: systemInfoScreen; anchors.fill: parent; visible: false; z: 55
            SystemInfoScreen { anchors.fill: parent; visible: true
                onBackToSettings: switchTo(settingsScreen, "settings")
            }
        }

        // ===== ABOUT =====
        Item { id: aboutScreen; anchors.fill: parent; visible: false; z: 50
            AboutScreen { anchors.fill: parent; visible: true
                onBackToHome: switchToHome()
            }
        }

        // ===== NETWORK/Wi-Fi =====
        Item { id: networkScreen; anchors.fill: parent; visible: false; z: 55
            NetworkScreen { anchors.fill: parent; visible: true
                onBackToSettings: switchTo(settingsScreen, "settings")
                onBackToHome: switchToHome()
            }
        }

        // ===== BLUETOOTH =====
        Item { id: bluetoothScreen; anchors.fill: parent; visible: false; z: 55
            BluetoothScreen { anchors.fill: parent; visible: true
                onBackToSettings: switchTo(settingsScreen, "settings")
                onBackToHome: switchToHome()
            }
        }

        // ===== UPDATE =====
        Item { id: updateScreen; anchors.fill: parent; visible: false; z: 60
            UpdateScreen { anchors.fill: parent; visible: true; z: 10
                onBackToHome: switchToHome()
            }
        }

        // ===== UPDATE HISTORY =====
        Item { id: updateHistoryScreen; anchors.fill: parent; visible: false; z: 60
            UpdateHistoryScreen { anchors.fill: parent; visible: true; z: 10
                onBackToUpdates: switchTo(settingsScreen, "settings")
            }
        }

        // ===== BROWSER =====
        Item { id: browserScreen; anchors.fill: parent; visible: false; z: 60
            YunshBrowser { anchors.fill: parent; visible: true; z: 10
                onBackToHome: switchToHome()
            }
        }

        // ===== METAVERSE =====
        Item { id: metaverseScreen; anchors.fill: parent; visible: false; z: 60
            YunshMetaverse { anchors.fill: parent; visible: true; z: 10
                onBackToHome: switchToHome()
            }
        }

        // ===== TERMINAL =====
        Item { id: terminalScreen; anchors.fill: parent; visible: false; z: 60
            TerminalScreen { anchors.fill: parent; visible: true
                onBackToHome: switchToHome()
            }
        }

        // ===== PHOTOS =====
        Item { id: photosScreen; anchors.fill: parent; visible: false; z: 60
            PhotosScreen { anchors.fill: parent; visible: true; z: 10
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

    // ===== NAVIGATION FUNCTIONS =====
    function switchTo(screen, appId) {
        homeScreen.visible = false
        settingsScreen.visible = false
        aboutScreen.visible = false
        systemInfoScreen.visible = false
        networkScreen.visible = false
        bluetoothScreen.visible = false
        updateScreen.visible = false
        updateHistoryScreen.visible = false
        browserScreen.visible = false
        metaverseScreen.visible = false
        terminalScreen.visible = false
        photosScreen.visible = false
        screen.visible = true
        if (appId) trackAppOpen(appId)
    }

    function switchToHome() {
        updateScreen.visible = false
        updateHistoryScreen.visible = false
        browserScreen.visible = false
        metaverseScreen.visible = false
        terminalScreen.visible = false
        photosScreen.visible = false
        settingsScreen.visible = false
        aboutScreen.visible = false
        systemInfoScreen.visible = false
        networkScreen.visible = false
        bluetoothScreen.visible = false
        homeScreen.visible = true
    }

    function switchToAppById(appId) {
        switch (appId) {
            case "settings": switchTo(settingsScreen, appId); break
            case "browser": switchTo(browserScreen, appId); break
            case "metaverse": switchTo(metaverseScreen, appId); break
            case "terminal": switchTo(terminalScreen, appId); break
            case "photos": switchTo(photosScreen, appId); break
            case "update": switchTo(updateScreen, appId); break
            case "about": switchTo(aboutScreen, appId); break
            case "systeminfo": switchTo(systemInfoScreen, appId); break
            case "network": switchTo(networkScreen, appId); break
            case "bluetooth": switchTo(bluetoothScreen, appId); break
            case "updatehistory": switchTo(updateHistoryScreen, appId); break
        }
    }

    function showTaskSwitcher() {
        homeScreen.visible = false
        switchToHome()
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
