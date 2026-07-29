// YUNSH OS v2.0.0 - Main QML Entry Point
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
    property real rawHeadYaw: 0.0
    property real rawHeadPitch: 0.0
    property real rawHeadRoll: 0.0
    property real filteredHeadYaw: 0.0
    property real filteredHeadPitch: 0.0
    property real filteredHeadRoll: 0.0
    property real headCenterYaw: 0.0
    property real headCenterPitch: 0.0
    property real headCenterRoll: 0.0
    property bool headTrackingEnabled: false
    property real trackingSmoothing: 0.35

    // ─── Binocular display and comfort ─────────────────
    property bool stereoEnabled: true
    property real ipdMm: 63.0
    property real eyeShiftPx: 0.0
    property real fieldOfView: 50.0
    readonly property real pixelsPerDegree: 1920 / Math.max(30, fieldOfView)
    property bool calibrationMode: false
    property bool reduceMotion: false
    property bool reduceTransparency: false
    property bool highContrast: false
    property bool focusMode: false
    property string activeAppId: ""
    property string androidTarget: "appstore"
    property string lastUiCommandId: ""

    property var openApps: []
    property var appInfo: ({
        "settings": { name: "设置", icon: "/usr/share/yunsh/icons/settings.svg", color: "#00D4FF" },
        "browser": { name: "Browser", icon: "/usr/share/yunsh/icons/settings.svg", color: "#4CAF50" },
        "metaverse": { name: "Metaverse", icon: "/usr/share/yunsh/icons/metaverse.svg", color: "#9C27B0" },
        "terminal": { name: "终端", icon: "/usr/share/yunsh/icons/terminal.svg", color: "#00D4FF" },
        "photos": { name: "相册", icon: "/usr/share/yunsh/icons/photos.svg", color: "#FFC107" },
        "appstore": { name: "Android Apps", icon: "/usr/share/yunsh/icons/appstore.svg", color: "#FF9800" },
        "files": { name: "文件", icon: "/usr/share/yunsh/icons/files.svg", color: "#2196F3" },
        "update": { name: "系统更新", icon: "/usr/share/yunsh/icons/update.svg", color: "#00D4FF" },
        "about": { name: "关于", icon: "/usr/share/yunsh/icons/about.svg", color: "#607D8B" },
        "network": { name: "Wi-Fi", icon: "/usr/share/yunsh/icons/wifi.svg", color: "#0096FF" },
        "bluetooth": { name: "蓝牙", icon: "/usr/share/yunsh/icons/bluetooth.svg", color: "#2196F3" },
        "display": { name: "空间显示", icon: "/usr/share/yunsh/icons/settings.svg", color: "#00D4FF" },
        "spacecapsule": { name: "空间胶囊", icon: "/usr/share/yunsh/icons/files.svg", color: "#00D4FF" },
        "screenrelay": { name: "iPhone 投屏", icon: "/usr/share/yunsh/icons/photos.svg", color: "#00D4FF" },
        "comfortdna": { name: "Comfort DNA", icon: "/usr/share/yunsh/icons/settings.svg", color: "#00D4FF" },
        "systeminfo": { name: "系统信息", icon: "/usr/share/yunsh/icons/about.svg", color: "#607D8B" },
        "updatehistory": { name: "更新历史", icon: "/usr/share/yunsh/icons/update.svg", color: "#607D8B" }
    })

    function trackAppOpen(appId) {
        for (var i = 0; i < openApps.length; i++) {
            if (openApps[i].appId === appId) return
        }
        var info = appInfo[appId]
        if (info) {
            var updated = openApps.slice()
            updated.push({ appId: appId, name: info.name, icon: info.icon, color: info.color })
            openApps = updated
        }
    }

    function closeAppFromSwitcher(appId) {
        var updated = openApps.slice()
        for (var i = 0; i < openApps.length; i++) {
            if (openApps[i].appId === appId) {
                updated.splice(i, 1)
                break
            }
        }
        openApps = updated
        closeWindowById(appId)
        if (activeAppId === appId)
            activeAppId = ""
        updateWindowFocus()
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
            case "display": return displayWindow
            case "spacecapsule": return spaceCapsuleWindow
            case "screenrelay": return screenRelayWindow
            case "comfortdna": return comfortDnaWindow
            case "updatehistory": return updateHistoryWindow
            case "appstore":
            case "files": return androidWindow
        }
        return null
    }

    // Root container. In binocular mode the left surface is interactive and
    // the right surface is a frame-locked GPU copy for side-by-side output.
    StereoCompositor {
        id: rootContainer
        anchors.fill: parent
        stereoEnabled: yunshOS.stereoEnabled
        eyeShiftPx: yunshOS.eyeShiftPx
        calibrationVisible: yunshOS.calibrationMode

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
            showDock: !yunshOS.focusMode
            showStatusBar: !yunshOS.focusMode
            stereoEnabled: yunshOS.stereoEnabled
            headTrackingConnected: yunshOS.headTrackingEnabled
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
            onOpenSpatialDisplay: switchTo(displayWindow, "display")
            onOpenSpaceCapsule: switchTo(spaceCapsuleWindow, "spacecapsule")
            onOpenScreenRelay: switchTo(screenRelayWindow, "screenrelay")
            onShowControlCenter: controlCenter.show()
            onTakeScreenshot: takeScreenshot()
            onOpenAppLibrary: showTaskSwitcher()
        }

        // ===== IPHONE SCREEN RELAY =====
        MacWindow {
            id: screenRelayWindow
            appTitle: "iPhone Screen Relay"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 170; y: 60; width: 820; height: 720
            visible: false
            onActivated: yunshOS.activateWindow(screenRelayWindow, "screenrelay")
            onCloseClicked: yunshOS.closeAppFromSwitcher("screenrelay")
            onMinimizeClicked: yunshOS.minimizeWindow(screenRelayWindow, "screenrelay")
            ScreenRelayScreen {
                anchors.fill: parent
                onBackToHome: switchToHome()
            }
        }

        // Always-reachable touch/gaze target for a keyboard-free recenter.
        Rectangle {
            id: floatingRecenterButton
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            width: 118
            height: 48
            radius: 24
            z: 420
            visible: (!firstBoot || activationDone)
                && !calibrationMode
                && !screensaver_item.visible
                && !virtualKeyboard.visible
            color: recenterTouch.pressed ? "#45E1FF" : "#00D4FF"
            border.width: 1
            border.color: "#8AEEFF"

            Row {
                anchors.centerIn: parent
                spacing: 7
                Text {
                    text: "⌾"
                    color: "#00151B"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Text {
                    text: "回正"
                    color: "#00151B"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: recenterTouch
                anchors.fill: parent
                onClicked: yunshOS.recenterTracking()
            }
        }

        // ===== CONTROL CENTER =====
        ControlCenter {
            id: controlCenter
            anchors.fill: parent
            visible: false
            z: 300
            focusMode: yunshOS.focusMode
            stereoEnabled: yunshOS.stereoEnabled
            headTrackingConnected: yunshOS.headTrackingEnabled
            reduceMotion: yunshOS.reduceMotion
            onDismissPanel: controlCenter.hide()
            onOpenNetwork: { controlCenter.hide(); switchTo(networkWindow, "network") }
            onOpenBluetooth: { controlCenter.hide(); switchTo(bluetoothWindow, "bluetooth") }
            onToggleWifi: controlCenter.applyWifiPower()
            onToggleBluetooth: controlCenter.applyBluetoothPower()
            onToggleKeyboard: { controlCenter.hide(); virtualKeyboard.visible ? virtualKeyboard.hide() : virtualKeyboard.show() }
            onTakeScreenshot: takeScreenshot()
            onToggleFocusMode: {
                yunshOS.focusMode = !yunshOS.focusMode
                saveSpatialPreferences()
            }
            onOpenSpatialDisplay: {
                controlCenter.hide()
                switchTo(displayWindow, "display")
            }
            onRecenterTracking: {
                controlCenter.hide()
                yunshOS.recenterTracking()
            }
        }

        // ===== SETTINGS =====
        MacWindow {
            id: settingsWindow
            appTitle: "设置"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 80; y: 60; width: 900; height: 650
            visible: false
            onActivated: yunshOS.activateWindow(settingsWindow, "settings")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("settings") }
            onMinimizeClicked: yunshOS.minimizeWindow(settingsWindow, "settings")
            SettingsScreen { anchors.fill: parent
                onBackToHome: switchToHome()
                onOpenUpdatePage: switchTo(updateWindow, "update")
                onOpenUpdateHistory: switchTo(updateHistoryWindow, "updatehistory")
                onOpenNetworkSettings: switchTo(networkWindow, "network")
                onOpenBluetoothSettings: switchTo(bluetoothWindow, "bluetooth")
                onOpenSystemInfo: switchTo(systemInfoWindow, "systeminfo")
                onOpenDisplaySettings: switchTo(displayWindow, "display")
                onOpenComfortDna: switchTo(comfortDnaWindow, "comfortdna")
                onOpenSoundSettings: { settingsWindow.visible = false; controlCenter.show() }
            }
        }

        // ===== SPATIAL DISPLAY =====
        MacWindow {
            id: displayWindow
            appTitle: "空间显示"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 210; y: 70; width: 860; height: 720
            visible: false
            onActivated: yunshOS.activateWindow(displayWindow, "display")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("display") }
            onMinimizeClicked: yunshOS.minimizeWindow(displayWindow, "display")
            SpatialDisplaySettings {
                id: spatialDisplaySettings
                anchors.fill: parent
                stereoEnabled: yunshOS.stereoEnabled
                ipdMm: yunshOS.ipdMm
                eyeShiftPx: yunshOS.eyeShiftPx
                fieldOfView: yunshOS.fieldOfView
                trackingSmoothing: yunshOS.trackingSmoothing
                reduceMotion: yunshOS.reduceMotion
                reduceTransparency: yunshOS.reduceTransparency
                highContrast: yunshOS.highContrast
                focusMode: yunshOS.focusMode
                headTrackingConnected: yunshOS.headTrackingEnabled
                outputWidth: yunshOS.width
                outputHeight: yunshOS.height
                onBackToSettings: {
                    displayWindow.visible = false
                    switchTo(settingsWindow, "settings")
                }
                onPreferencesChanged: yunshOS.applySpatialSettings(spatialDisplaySettings)
                onCalibrationRequested: yunshOS.calibrationMode = true
                onRecenterRequested: yunshOS.recenterTracking()
            }
        }

        // ===== COMFORT DNA =====
        MacWindow {
            id: comfortDnaWindow
            appTitle: "Comfort DNA"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 190; y: 70; width: 760; height: 700
            visible: false
            onActivated: yunshOS.activateWindow(comfortDnaWindow, "comfortdna")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("comfortdna") }
            onMinimizeClicked: yunshOS.minimizeWindow(comfortDnaWindow, "comfortdna")
            ComfortDnaScreen {
                anchors.fill: parent
                onboarding: false
                reduceMotion: yunshOS.reduceMotion
                onBackRequested: {
                    comfortDnaWindow.visible = false
                    switchTo(settingsWindow, "settings")
                }
                onProfileApplied: function(data) {
                    yunshOS.applySpatialPreferenceObject(data)
                    yunshOS.loadSpatialPreferences()
                    yunshOS.showToast("Comfort DNA 已应用：" + data.label)
                }
            }
        }

        // ===== SPACE CAPSULE =====
        MacWindow {
            id: spaceCapsuleWindow
            appTitle: "空间胶囊"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 130; y: 70; width: 900; height: 700
            visible: false
            onActivated: yunshOS.activateWindow(spaceCapsuleWindow, "spacecapsule")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("spacecapsule") }
            onMinimizeClicked: yunshOS.minimizeWindow(spaceCapsuleWindow, "spacecapsule")
            SpaceCapsuleScreen {
                id: spaceCapsuleScreen
                anchors.fill: parent
                reduceMotion: yunshOS.reduceMotion
                onBackToHome: switchToHome()
                onWorkspaceExportRequested: function(name) {
                    spaceCapsuleScreen.exportWorkspace(yunshOS.captureWorkspace(), name)
                }
                onRestoreRequested: function(capsule) {
                    yunshOS.restoreWorkspace(capsule)
                }
            }
        }

        // ===== SYSTEM INFO =====
        MacWindow {
            id: systemInfoWindow
            appTitle: "系统信息"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 140; y: 100; width: 800; height: 600
            visible: false
            onActivated: yunshOS.activateWindow(systemInfoWindow, "systeminfo")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("systeminfo") }
            onMinimizeClicked: yunshOS.minimizeWindow(systemInfoWindow, "systeminfo")
            SystemInfoScreen {
                anchors.fill: parent
                displayRes: Math.round(yunshOS.width) + " × " + Math.round(yunshOS.height)
                            + (yunshOS.stereoEnabled ? "（SBS 双目）" : "（单目）")
                onBackToSettings: switchTo(settingsWindow, "settings")
            }
        }

        // ===== ABOUT =====
        MacWindow {
            id: aboutWindow
            appTitle: "关于"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 120; y: 160; width: 800; height: 550
            visible: false
            onActivated: yunshOS.activateWindow(aboutWindow, "about")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("about") }
            onMinimizeClicked: yunshOS.minimizeWindow(aboutWindow, "about")
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
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 100; y: 120; width: 800; height: 550
            visible: false
            onActivated: yunshOS.activateWindow(networkWindow, "network")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("network") }
            onMinimizeClicked: yunshOS.minimizeWindow(networkWindow, "network")
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
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 180; y: 80; width: 800; height: 550
            visible: false
            onActivated: yunshOS.activateWindow(bluetoothWindow, "bluetooth")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("bluetooth") }
            onMinimizeClicked: yunshOS.minimizeWindow(bluetoothWindow, "bluetooth")
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
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 80; y: 100; width: 850; height: 600
            visible: false
            onActivated: yunshOS.activateWindow(updateWindow, "update")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("update") }
            onMinimizeClicked: yunshOS.minimizeWindow(updateWindow, "update")
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
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 160; y: 140; width: 800; height: 550
            visible: false
            onActivated: yunshOS.activateWindow(updateHistoryWindow, "updatehistory")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("updatehistory") }
            onMinimizeClicked: yunshOS.minimizeWindow(updateHistoryWindow, "updatehistory")
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
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 120; y: 60; width: 1000; height: 700
            visible: false
            onActivated: yunshOS.activateWindow(browserWindow, "browser")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("browser") }
            onMinimizeClicked: yunshOS.minimizeWindow(browserWindow, "browser")
            YunshBrowser {
                id: browserScreen
                anchors.fill: parent
                onBackToHome: switchToHome()
            }
        }

        // ===== METAVERSE =====
        MacWindow {
            id: metaverseWindow
            appTitle: "Metaverse"
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 80; y: 160; width: 950; height: 680
            visible: false
            onActivated: yunshOS.activateWindow(metaverseWindow, "metaverse")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("metaverse") }
            onMinimizeClicked: yunshOS.minimizeWindow(metaverseWindow, "metaverse")
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
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 200; y: 120; width: 850; height: 600
            visible: false
            onActivated: yunshOS.activateWindow(terminalWindow, "terminal")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("terminal") }
            onMinimizeClicked: yunshOS.minimizeWindow(terminalWindow, "terminal")
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
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 140; y: 80; width: 900; height: 650
            visible: false
            onActivated: yunshOS.activateWindow(photosWindow, "photos")
            onCloseClicked: { yunshOS.closeAppFromSwitcher("photos") }
            onMinimizeClicked: yunshOS.minimizeWindow(photosWindow, "photos")
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
            headRoll: yunshOS.headRoll
            pixelsPerDegree: yunshOS.pixelsPerDegree
            x: 130; y: 80; width: 700; height: 540
            visible: false
            onActivated: yunshOS.activateWindow(
                androidWindow, yunshOS.androidTarget
            )
            onCloseClicked: { yunshOS.closeAppFromSwitcher("appstore"); yunshOS.closeAppFromSwitcher("files") }
            onMinimizeClicked: yunshOS.minimizeWindow(
                androidWindow, yunshOS.androidTarget
            )
            AndroidAppsScreen {
                anchors.fill: parent
                targetApp: yunshOS.androidTarget
            }
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
                    if (result.saveToFile(fullPath)) {
                        var xhr = new XMLHttpRequest()
                        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
                        xhr.setRequestHeader("Content-Type", "application/json")
                        xhr.send(JSON.stringify({
                            action: "crop",
                            source: fullPath,
                            x: x, y: y, w: w, h: h
                        }))
                    }
                })
            }
            onCancelled: screenshotOverlay.visible = false
        }

        // ===== VIRTUAL KEYBOARD (visionOS floating panel) =====
        VirtualKeyboard {
            id: virtualKeyboard
            z: 1000
            reduceMotion: yunshOS.reduceMotion
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
            reduceMotion: yunshOS.reduceMotion
            openApps: yunshOS.openApps
            onSwitchToApp: function(appId) { hideTaskSwitcher(); switchToAppById(appId) }
            onCloseApp: function(appId) { yunshOS.closeAppFromSwitcher(appId) }
            onDismissSwitcher: hideTaskSwitcher()
        }

        // ===== HOME INDICATOR (mouse swipe up trigger) =====
        HomeIndicator {
            id: homeIndicator
            z: 300
            reduceMotion: yunshOS.reduceMotion
            visible: homeScreen.visible || (taskSwitcher.visible && yunshOS.openApps.length > 0)
            onSwipeUpTriggered: showTaskSwitcher()
            onClicked: showTaskSwitcher()
        }

        StereoCalibration {
            anchors.fill: parent
            visible: yunshOS.calibrationMode
            z: 5000
            ipdMm: yunshOS.ipdMm
            eyeShiftPx: yunshOS.eyeShiftPx
            fieldOfView: yunshOS.fieldOfView
            onCloseRequested: yunshOS.calibrationMode = false
        }

        Rectangle {
            id: systemToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 62
            width: toastLabel.width + 44
            height: 42
            radius: 21
            color: yunshOS.reduceTransparency
                ? "#20202A" : Qt.rgba(22/255, 22/255, 35/255, 0.86)
            border.width: 1
            border.color: yunshOS.highContrast
                ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.12)
            opacity: 0
            visible: opacity > 0
            z: 6000

            Text {
                id: toastLabel
                anchors.centerIn: parent
                text: ""
                color: "#FFFFFF"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: yunshOS.reduceMotion ? 80 : 180
                    easing.type: Easing.OutCubic
                }
            }

            Timer {
                id: toastTimer
                interval: 1600
                repeat: false
                onTriggered: systemToast.opacity = 0
            }
        }
    }

    // ===== FLOATING WINDOW FUNCTIONS =====
    property int windowCount: 0

    function activateWindow(window, appId) {
        if (!window || !window.visible)
            return
        activeAppId = appId
        window.z = 60 + (++windowCount)
        updateWindowFocus()
    }

    function minimizeWindow(window, appId) {
        window.visible = false
        window.isMinimized = true
        if (activeAppId === appId)
            activeAppId = ""
        homeScreen.visible = true
        updateWindowFocus()
    }

    function switchTo(window, appId) {
        if (!window.visible) homeScreen.visible = true
        window.visible = true
        window.isMinimized = false
        windowCount++
        window.z = 60 + windowCount
        if (appId) {
            activeAppId = appId
            trackAppOpen(appId)
        }
        applyWindowPreferences()
        updateWindowFocus()
    }

    function switchToHome() {
        var ids = ["update","updatehistory","browser","metaverse","terminal",
                    "photos","settings","about","systeminfo","network","bluetooth",
                    "display","comfortdna","spacecapsule"]
        for (var i = 0; i < ids.length; i++) {
            var w = getWindowById(ids[i])
            if (w) { w.visible = false; w.isMinimized = false }
        }
        androidWindow.visible = false
        androidWindow.isMinimized = false
        activeAppId = ""
        updateWindowFocus()
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
            var filename = "/home/yunsh/Pictures/Screenshots/Screenshot_" + Date.now() + ".png"
            result.saveToFile(filename)
            console.log("Full screenshot saved to " + filename)
        })
    }

    function showToast(message) {
        toastLabel.text = message
        systemToast.opacity = 1
        toastTimer.restart()
    }

    function allWindows() {
        return [
            settingsWindow, displayWindow, comfortDnaWindow, spaceCapsuleWindow, screenRelayWindow,
            systemInfoWindow, aboutWindow,
            networkWindow, bluetoothWindow, updateWindow, updateHistoryWindow,
            browserWindow, metaverseWindow, terminalWindow, photosWindow,
            androidWindow
        ]
    }

    function applyWindowPreferences() {
        var windows = allWindows()
        for (var i = 0; i < windows.length; i++) {
            windows[i].reduceMotion = reduceMotion
            windows[i].reduceTransparency = reduceTransparency
            windows[i].highContrast = highContrast
        }
    }

    function isAppTracked(appId) {
        for (var i = 0; i < openApps.length; i++) {
            if (openApps[i].appId === appId)
                return true
        }
        return false
    }

    function workspaceWindowEntries() {
        return [
            { appId: "settings", window: settingsWindow },
            { appId: "display", window: displayWindow },
            { appId: "systeminfo", window: systemInfoWindow },
            { appId: "about", window: aboutWindow },
            { appId: "network", window: networkWindow },
            { appId: "bluetooth", window: bluetoothWindow },
            { appId: "screenrelay", window: screenRelayWindow },
            { appId: "update", window: updateWindow },
            { appId: "updatehistory", window: updateHistoryWindow },
            { appId: "browser", window: browserWindow },
            { appId: "metaverse", window: metaverseWindow },
            { appId: "terminal", window: terminalWindow },
            { appId: "photos", window: photosWindow },
            { appId: androidTarget, window: androidWindow }
        ]
    }

    function captureWorkspace() {
        var result = []
        var entries = workspaceWindowEntries()
        for (var i = 0; i < entries.length; i++) {
            var appId = entries[i].appId
            var window = entries[i].window
            if (!window || (!window.visible && !window.isMinimized && !isAppTracked(appId)))
                continue
            var item = {
                appId: appId,
                x: window.x,
                y: window.y,
                width: window.width,
                height: window.height,
                visible: window.visible,
                minimized: window.isMinimized,
                spatialPlacement: window.spatialPlacement,
                pinMode: window.pinMode,
                order: window.z
            }
            if (appId === "browser")
                item.state = {url: String(browserScreen.currentUrl)}
            result.push(item)
        }
        return {
            activeAppId: activeAppId,
            windows: result
        }
    }

    function restoreWorkspace(capsule) {
        if (!capsule || !capsule.windows)
            return

        var windows = allWindows()
        for (var i = 0; i < windows.length; i++) {
            windows[i].visible = false
            windows[i].isMinimized = false
        }
        openApps = []
        activeAppId = ""

        var restoredActiveWindow = null
        var restoredCount = 0
        for (var j = 0; j < capsule.windows.length; j++) {
            var item = capsule.windows[j]
            var window = getWindowById(item.appId)
            if (!window || item.appId === "spacecapsule" || item.appId === "comfortdna")
                continue

            if (item.appId === "appstore" || item.appId === "files") {
                launchApp(item.appId)
                window = androidWindow
            }
            trackAppOpen(item.appId)
            window.x = item.x
            window.y = item.y
            window.width = item.width
            window.height = item.height
            window.spatialPlacement = item.spatialPlacement
            window.pinMode = item.pinMode
            window.isMinimized = item.minimized
            window.visible = item.visible && !item.minimized
            window.z = 60 + Math.max(0, item.order)
            windowCount = Math.max(windowCount, item.order)

            if (item.appId === "browser" && item.state && item.state.url)
                browserScreen.currentUrl = item.state.url
            if (item.appId === capsule.activeAppId && window.visible)
                restoredActiveWindow = window
            restoredCount++
        }

        homeScreen.visible = true
        if (capsule.activeAppId && restoredActiveWindow) {
            activeAppId = capsule.activeAppId
            activateWindow(restoredActiveWindow, capsule.activeAppId)
        }
        applyWindowPreferences()
        updateWindowFocus()
        showToast("已恢复“" + capsule.name + "” · " + restoredCount + " 个窗口")
    }

    function updateWindowFocus() {
        var activeWindow = getWindowById(activeAppId)
        var windows = allWindows()
        for (var i = 0; i < windows.length; i++)
            windows[i].focusDimmed = focusMode && activeWindow && windows[i] !== activeWindow
    }

    function angularDelta(target, current) {
        var delta = target - current
        while (delta > 180) delta -= 360
        while (delta < -180) delta += 360
        return delta
    }

    function updateHeadPose(yaw, pitch, roll) {
        rawHeadYaw = yaw
        rawHeadPitch = pitch
        rawHeadRoll = roll
        var alpha = Math.max(0.1, Math.min(1.0, 1.0 - trackingSmoothing))
        if (!headTrackingEnabled) {
            filteredHeadYaw = yaw
            filteredHeadPitch = pitch
            filteredHeadRoll = roll
        } else {
            filteredHeadYaw += angularDelta(yaw, filteredHeadYaw) * alpha
            filteredHeadPitch += (pitch - filteredHeadPitch) * alpha
            filteredHeadRoll += angularDelta(roll, filteredHeadRoll) * alpha
        }
        headYaw = angularDelta(filteredHeadYaw, headCenterYaw)
        headPitch = filteredHeadPitch - headCenterPitch
        headRoll = angularDelta(filteredHeadRoll, headCenterRoll)
        headTrackingEnabled = true
    }

    function recenterTracking() {
        if (!headTrackingEnabled) {
            showToast("头部追踪尚未连接")
            return
        }
        headCenterYaw = filteredHeadYaw
        headCenterPitch = filteredHeadPitch
        headCenterRoll = filteredHeadRoll
        headYaw = 0
        headPitch = 0
        headRoll = 0
        showToast("已将当前朝向设为正前方")
    }

    function pollUiCommand() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8591/api/ui-command", true)
        xhr.timeout = 500
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return
            try {
                var command = JSON.parse(xhr.responseText)
                if (command.action === "recenter"
                        && command.id
                        && command.id !== yunshOS.lastUiCommandId) {
                    yunshOS.lastUiCommandId = command.id
                    yunshOS.recenterTracking()
                }
            } catch (error) {}
        }
        xhr.send()
    }

    Timer {
        interval: 500
        running: !firstBoot || activationDone
        repeat: true
        onTriggered: yunshOS.pollUiCommand()
    }

    function spatialPreferencesPayload() {
        return {
            stereoEnabled: stereoEnabled,
            ipdMm: ipdMm,
            eyeShiftPx: eyeShiftPx,
            fieldOfView: fieldOfView,
            trackingSmoothing: trackingSmoothing,
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            highContrast: highContrast,
            focusMode: focusMode
        }
    }

    function applySpatialPreferenceObject(data) {
        if (typeof data.stereoEnabled === "boolean")
            stereoEnabled = data.stereoEnabled
        if (typeof data.ipdMm === "number")
            ipdMm = data.ipdMm
        if (typeof data.eyeShiftPx === "number")
            eyeShiftPx = data.eyeShiftPx
        if (typeof data.fieldOfView === "number")
            fieldOfView = data.fieldOfView
        if (typeof data.trackingSmoothing === "number")
            trackingSmoothing = data.trackingSmoothing
        if (typeof data.reduceMotion === "boolean")
            reduceMotion = data.reduceMotion
        if (typeof data.reduceTransparency === "boolean")
            reduceTransparency = data.reduceTransparency
        if (typeof data.highContrast === "boolean")
            highContrast = data.highContrast
        if (typeof data.focusMode === "boolean")
            focusMode = data.focusMode
        applyWindowPreferences()
        updateWindowFocus()
    }

    function applySpatialSettings(settings) {
        applySpatialPreferenceObject({
            stereoEnabled: settings.stereoEnabled,
            ipdMm: settings.ipdMm,
            eyeShiftPx: settings.eyeShiftPx,
            fieldOfView: settings.fieldOfView,
            trackingSmoothing: settings.trackingSmoothing,
            reduceMotion: settings.reduceMotion,
            reduceTransparency: settings.reduceTransparency,
            highContrast: settings.highContrast,
            focusMode: settings.focusMode
        })
        spatialPreferenceSaveTimer.restart()
    }

    function loadSpatialPreferences() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8591/api/spatial-preferences", true)
        xhr.timeout = 1200
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return
            try {
                applySpatialPreferenceObject(JSON.parse(xhr.responseText))
            } catch (error) {
                console.log("YUNSH: Could not parse spatial preferences")
            }
        }
        xhr.send()
    }

    function saveSpatialPreferences() {
        applyWindowPreferences()
        updateWindowFocus()
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/spatial-preferences", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 1200
        xhr.send(JSON.stringify(spatialPreferencesPayload()))
    }

    Timer {
        id: spatialPreferenceSaveTimer
        interval: 180
        repeat: false
        onTriggered: yunshOS.saveSpatialPreferences()
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
        Qt.exit(42)
    }

    // ===== KEYBOARD SHORTCUTS =====
    Shortcut { sequence: "Print"; onActivated: takeScreenshot() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: screenshotOverlay.visible = true }
    Shortcut {
        sequence: "Ctrl+Shift+C"
        onActivated: controlCenter.visible ? controlCenter.hide() : controlCenter.show()
    }
    Shortcut { sequence: "Ctrl+Up"; onActivated: showTaskSwitcher() }
    Shortcut { sequence: "Ctrl+Shift+R"; onActivated: recenterTracking() }
    Shortcut {
        sequence: "Ctrl+Shift+F"
        onActivated: {
            focusMode = !focusMode
            saveSpatialPreferences()
            showToast(focusMode ? "专注模式已开启" : "专注模式已关闭")
        }
    }
    Shortcut {
        sequence: "Ctrl+Shift+D"
        onActivated: switchTo(displayWindow, "display")
    }

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
        var otherAndroidId = appId === "appstore" ? "files" : "appstore"
        var filteredApps = []
        for (var i = 0; i < openApps.length; i++) {
            if (openApps[i].appId !== otherAndroidId)
                filteredApps.push(openApps[i])
        }
        openApps = filteredApps
        yunshOS.androidTarget = appId
        androidWindow.appTitle = info.name
        var w = androidWindow
        w.x = 80 + (windowCount % 3) * 40
        w.y = 80 + (windowCount % 3) * 30
        w.visible = true
        w.isMinimized = false
        w.z = 60 + (++windowCount)
        activeAppId = appId
        trackAppOpen(appId)
        applyWindowPreferences()
        updateWindowFocus()

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
    // Uses a slow discovery probe and switches to a 30 Hz stream after the
    // daemon is available. This also survives service startup races.
    property bool htDaemonDetected: false
    property int htPollInterval: 33
    property bool htRequestInFlight: false

    function probeHeadTracking() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8592/tracking", true)
        xhr.timeout = 500
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    yunshOS.htDaemonDetected = true
                    yunshOS.htPollInterval = 33
                    headTrackingTimer.interval = 33
                    headTrackingTimer.running = true
                } else {
                    yunshOS.htDaemonDetected = false
                    headTrackingTimer.running = false
                    headTrackingProbeTimer.restart()
                }
            }
        }
        xhr.send()
    }

    Timer {
        id: headTrackingTimer
        interval: 33
        running: false  // Don't start until probe succeeds
        repeat: true
        onTriggered: {
            if (yunshOS.htRequestInFlight)
                return
            yunshOS.htRequestInFlight = true
            var xhr = new XMLHttpRequest()
            xhr.open("GET", "http://127.0.0.1:8592/tracking", true)
            xhr.timeout = 200
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    yunshOS.htRequestInFlight = false
                    if (xhr.status === 200) {
                        try {
                            var data = JSON.parse(xhr.responseText)
                            yunshOS.updateHeadPose(
                                Number(data.yaw) || 0,
                                Number(data.pitch) || 0,
                                Number(data.roll) || 0
                            )
                        } catch(e) {}
                    } else {
                        // Lost connection — slow polling
                        yunshOS.headTrackingEnabled = false
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

    Timer {
        id: headTrackingProbeTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: yunshOS.probeHeadTracking()
    }

    // ─── Mouse movement resets idle timer ──────────
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        hoverEnabled: true
        onPositionChanged: {
            idleTimer.restart()
            if (screensaver_item.visible) {
                screensaver_item.visible = false
            }
        }
    }

    Component.onCompleted: {
        console.log("YUNSH OS UI v2.0.0")
        checkFirstBoot()
        showFullScreen()
        applyWindowPreferences()
        // Probe head tracking daemon once (won't poll if not found)
        Qt.callLater(function() {
            yunshOS.loadSpatialPreferences()
            yunshOS.probeHeadTracking()
        })
    }
}
