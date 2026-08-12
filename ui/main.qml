// YUNSH OS v3.1.6 - Main QML Entry Point
// Apple-style glass system + Task Switcher + Home Indicator

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: yunshOS
    visible: true
    // Follow the mode selected by KMS/EDID. Hard-coding 1920x1080 makes
    // small IPS panels and non-1080p HDMI displays appear connected but black.
    width: Screen.width > 0 ? Screen.width : 1920
    height: Screen.height > 0 ? Screen.height : 1080

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

    // Current glasses controller mirrors one complete frame to both displays.
    // SBS is retained only for future controllers with independent eye inputs.
    property bool stereoEnabled: false
    property real ipdMm: 63.0
    property real eyeShiftPx: 0.0
    property real fieldOfView: 50.0
    readonly property real pixelsPerDegree: 1920 / Math.max(30, fieldOfView)
    property bool calibrationMode: false
    property bool reduceMotion: false
    property bool reduceTransparency: false
    property bool highContrast: false
    property bool focusMode: false
    property bool recordingActive: false
    // 0 disables automatic screen-off/lock. Values are persisted with the
    // local spatial preferences because this is a per-device comfort setting.
    property int autoLockSeconds: 120
    // This controls only the graphical lock screen. It never changes the
    // independent Linux/terminal/SSH password.
    property bool lockPasswordEnabled: true
    property string pendingSystemAction: ""
    property int systemActionConfirmStage: 0
    property string factoryResetPassword: ""
    property string factoryResetPasswordError: ""
    property bool factoryResetPasswordBusy: false
    property string activeAppId: ""
    property string androidTarget: "appstore"
    property string lastUiCommandId: ""
    // WebEngine is a separate Chromium process tree.  Do not construct it
    // during the boot shell's first frame: on a Pi 5 it can negotiate EGL
    // before Weston has finished its first repaint and take the whole QML
    // process down, leaving a black display.  The browser is created only
    // after the user opens it (and stays alive for the rest of the session).
    property bool browserRequested: false
    property var browserScreen: browserLoader.item
    property var virtualKeyboardRef: virtualKeyboard
    // A manual hide choice survives desktop clicks. App-driven automatic
    // hiding remains temporary and can be reversed from exposed desktop space.
    property bool appIconsManuallyHidden: false

    Timer {
        id: appIconsIdleTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (!yunshOS.appIconsManuallyHidden
                    && homeScreen.appIconsVisible
                    && yunshOS.hasVisibleAppWindows()) {
                homeScreen.appIconsVisible = false
                yunshOS.showToast("App 图标已自动隐藏")
            }
        }
    }

    function hasVisibleAppWindows() {
        var windows = allWindows()
        for (var i = 0; i < windows.length; i++) {
            if (windows[i] && windows[i].visible && !windows[i].isMinimized)
                return true
        }
        return false
    }

    function hideAppIconsForWindow() {
        homeScreen.appIconsVisible = false
        appIconsIdleTimer.stop()
    }

    function showAppIconsTemporarily() {
        if (appIconsManuallyHidden)
            return
        homeScreen.appIconsVisible = true
        if (hasVisibleAppWindows())
            appIconsIdleTimer.restart()
        else
            appIconsIdleTimer.stop()
    }

    function noteAppShelfInteraction() {
        if (!appIconsManuallyHidden && homeScreen.appIconsVisible
                && hasVisibleAppWindows())
            appIconsIdleTimer.restart()
    }

    function resolveAppIconVisibility() {
        if (appIconsManuallyHidden || hasVisibleAppWindows())
            hideAppIconsForWindow()
        else
            showAppIconsTemporarily()
    }

    // Native QML apps share the system spatial keyboard. Browser and Android
    // surfaces keep using their input-method bridges because their editable
    // elements are not QML TextInput objects.
    function isNativeEditableItem(item) {
        if (!item || item.enabled === false || item.visible === false)
            return false
        try {
            return item.text !== undefined
                    && item.cursorPosition !== undefined
                    && item.readOnly !== true
                    && typeof item.forceActiveFocus === "function"
        } catch (error) {
            return false
        }
    }

    function syncLockState(locked) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/lock-state", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 800
        xhr.send(JSON.stringify({locked: !!locked}))
    }

    // A normal boot always starts behind the local lock. The small marker is
    // written by the launcher and cleared only after this screen is unlocked;
    // it therefore also covers power loss and a restart initiated outside QML.
    function checkBootLock() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8591/api/boot-lock", true)
        xhr.timeout = 1200
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return
            try {
                var result = JSON.parse(xhr.responseText || "{}")
                if (result.required === true) {
                    screensaver_item.passwordRequired = yunshOS.lockPasswordEnabled
                    screensaver_item.show()
                }
            } catch (_error) {}
        }
        xhr.send()
    }

    function clearBootLock() {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/boot-lock", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 1200
        xhr.send(JSON.stringify({required: false}))
    }

    onActiveFocusItemChanged: {
        if (isNativeEditableItem(activeFocusItem))
            virtualKeyboard.showFor(activeFocusItem)
        else if (!screensaver_item.visible && virtualKeyboard.visible
                 && !virtualKeyboard.targetHasFocus())
            virtualKeyboard.hide()
    }

    // Some nested MouseAreas and popup transitions restore focus one event
    // loop after the first click, so activeFocusItemChanged is not guaranteed
    // to fire at the moment the user expects the keyboard. Reconcile the
    // focused editor with the system keyboard without reopening it after the
    // editor has actually lost focus.
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            var editor = yunshOS.activeFocusItem
            if (screensaver_item.visible) {
                if (screensaver_item.passwordRequired
                        && screensaver_item.keyboardRequested
                        && yunshOS.isNativeEditableItem(editor)
                        && (!virtualKeyboard.visible
                            || virtualKeyboard.targetItem !== editor))
                    virtualKeyboard.showFor(editor)
                else if (!screensaver_item.keyboardRequested && virtualKeyboard.visible)
                    virtualKeyboard.hide()
                return
            }
            if (yunshOS.isNativeEditableItem(editor)
                    && (!virtualKeyboard.visible || virtualKeyboard.targetItem !== editor))
                virtualKeyboard.showFor(editor)
            else if (virtualKeyboard.visible && !virtualKeyboard.targetHasFocus())
                virtualKeyboard.hide()
        }
    }

    property var openApps: []
    property var appInfo: ({
        "settings": { name: "设置", icon: "/usr/share/yunsh/icons/settings.svg", color: "#4E8FEA" },
        "browser": { name: "Browser", icon: "/usr/share/yunsh/icons/browser.svg", color: "#5477D6" },
        "terminal": { name: "终端", icon: "/usr/share/yunsh/icons/terminal.svg", color: "#526F9E" },
        "photos": { name: "相册", icon: "/usr/share/yunsh/icons/photos.svg", color: "#C78A62" },
        "appstore": { name: "F-Droid", icon: "/usr/share/yunsh/icons/appstore.svg", color: "#6E8F5B" },
        "files": { name: "文件", icon: "/usr/share/yunsh/icons/files.svg", color: "#5A8CC7" },
        "update": { name: "系统更新", icon: "/usr/share/yunsh/icons/update.svg", color: "#00D4FF" },
        "about": { name: "关于", icon: "/usr/share/yunsh/icons/about.svg", color: "#607D8B" },
        "network": { name: "Wi-Fi", icon: "/usr/share/yunsh/icons/wifi.svg", color: "#0096FF" },
        "bluetooth": { name: "蓝牙", icon: "/usr/share/yunsh/icons/bluetooth.svg", color: "#2196F3" },
        "display": { name: "空间显示", icon: "/usr/share/yunsh/icons/display.svg", color: "#00D4FF" },
        "spacecapsule": { name: "空间胶囊", icon: "/usr/share/yunsh/icons/capsule.svg", color: "#00D4FF" },
        "screenrelay": { name: "iPhone 投屏", icon: "/usr/share/yunsh/icons/screen-relay.svg", color: "#00D4FF" },
        "comfortdna": { name: "Comfort DNA", icon: "/usr/share/yunsh/icons/settings.svg", color: "#00D4FF" },
        "systeminfo": { name: "系统信息", icon: "/usr/share/yunsh/icons/about.svg", color: "#607D8B" },
        "updatehistory": { name: "更新历史", icon: "/usr/share/yunsh/icons/update.svg", color: "#607D8B" }
    })

    function trackAppOpen(appId, fallbackName) {
        for (var i = 0; i < openApps.length; i++) {
            if (openApps[i].appId === appId) return
        }
        var info = appInfo[appId] || {
            name: fallbackName || (appId.indexOf("android:") === 0 ? "Android App" : appId),
            icon: "/usr/share/yunsh/icons/android-app.svg",
            color: "#7C77A8"
        }
        var updated = openApps.slice()
        updated.push({ appId: appId, name: info.name, icon: info.icon, color: info.color, minimized: false })
        openApps = updated
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
        if (openApps.length === 0) {
            taskSwitcher.hide()
            homeScreen.visible = true
        }
        resolveAppIconVisibility()
    }

    function closeWindowById(appId) {
        // Closing or switching away from any app must release the shared
        // keyboard target; otherwise its old editor can keep reopening it.
        virtualKeyboard.hide()
        if (appId === "appstore" || appId === "files" || appId.indexOf("android:") === 0) {
            androidWindow.visible = false
            androidWindow.isMinimized = false
            return
        }
        var w = getWindowById(appId)
        if (w) {
            w.visible = false
            w.isMinimized = false
        }
    }

    function getWindowById(appId) {
        switch (appId) {
            case "settings": return settingsWindow
            case "browser": return browserWindow
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
        if (appId.indexOf("android:") === 0) return androidWindow
        return null
    }

    // The current controller mirrors this full frame to both eye displays.
    // Optional SBS keeps the existing future-controller compatibility path.
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
                homeScreen.appIconsVisible = !yunshOS.appIconsManuallyHidden
                saveActivationFlag()
            }
            onSkipActivation: {
                activationDone = true
                activationScreen.visible = false
                homeScreen.visible = true
                homeScreen.appIconsVisible = !yunshOS.appIconsManuallyHidden
                saveActivationFlag()
            }
        }

        // ===== HOME SCREEN =====
        HomeScreen {
            id: homeScreen
            anchors.fill: parent
            visible: !firstBoot || activationDone
            showStatusBar: false
            stereoEnabled: yunshOS.stereoEnabled
            headTrackingConnected: yunshOS.headTrackingEnabled
            reduceMotion: yunshOS.reduceMotion
            appIconsManuallyHidden: yunshOS.appIconsManuallyHidden
            desktopIconToggleEnabled: yunshOS.hasVisibleAppWindows()
            onOpenSettings: switchTo(settingsWindow, "settings")
            onOpenAbout: switchTo(systemInfoWindow, "systeminfo")
            onOpenAppStore: launchApp("appstore")
            onOpenFileManager: launchApp("files")
            onOpenAndroidApp: function(packageName) { launchApp("android:" + packageName) }
            onOpenBrowser: yunshOS.openBrowser()
            onOpenWorld: yunshOS.openWorld()
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
            onDesktopActivated: {
                if (yunshOS.appIconsManuallyHidden
                        || !yunshOS.hasVisibleAppWindows())
                    return
                if (homeScreen.appIconsVisible) {
                    // A second desktop click keeps the temporary shelf alive;
                    // it must not invert the rule and hide icons immediately.
                    appIconsIdleTimer.restart()
                } else {
                    yunshOS.showAppIconsTemporarily()
                    yunshOS.showToast("App 图标已显示 · 30 秒后自动隐藏")
                }
            }
            onAppShelfInteracted: yunshOS.noteAppShelfInteraction()
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
            recording: yunshOS.recordingActive
            stereoEnabled: yunshOS.stereoEnabled
            reduceMotion: yunshOS.reduceMotion
            appIconsManuallyHidden: yunshOS.appIconsManuallyHidden
            inputMethodLabel: virtualKeyboard.inputMethodLabel
            onOpenNetwork: { controlCenter.hide(); switchTo(networkWindow, "network") }
            onOpenBluetooth: { controlCenter.hide(); switchTo(bluetoothWindow, "bluetooth") }
            onOpenSettings: { controlCenter.hide(); switchTo(settingsWindow, "settings") }
            onOpenPhotos: { controlCenter.hide(); switchTo(photosWindow, "photos") }
            onOpenUpdate: { controlCenter.hide(); switchTo(updateWindow, "update") }
            onToggleWifi: controlCenter.applyWifiPower()
            onToggleBluetooth: controlCenter.applyBluetoothPower()
            onToggleKeyboard: { controlCenter.hide(); virtualKeyboard.visible ? virtualKeyboard.hide() : virtualKeyboard.show() }
            onToggleInputMethod: { virtualKeyboard.toggleInputMethod(); controlCenter.refreshSystemState() }
            onTakeScreenshot: {
                controlCenter.hide()
                Qt.callLater(function() { takeScreenshot() })
            }
            onTakeRegionScreenshot: {
                controlCenter.hide()
                screenshotOverlay.visible = true
            }
            onToggleRecording: yunshOS.toggleScreenRecording()
            onToggleFocusMode: {
                yunshOS.focusMode = !yunshOS.focusMode
                saveSpatialPreferences()
            }
            onToggleAppIcons: {
                yunshOS.appIconsManuallyHidden = !yunshOS.appIconsManuallyHidden
                if (yunshOS.appIconsManuallyHidden) {
                    homeScreen.appIconsVisible = false
                    appIconsIdleTimer.stop()
                } else {
                    yunshOS.showAppIconsTemporarily()
                }
                spatialPreferenceSaveTimer.restart()
                controlCenter.hide()
                yunshOS.showToast(!yunshOS.appIconsManuallyHidden
                    ? "App 图标已显示" : "App 图标已隐藏")
            }
            onOpenSpatialDisplay: {
                controlCenter.hide()
                switchTo(displayWindow, "display")
            }
            onRequestLock: {
                controlCenter.hide()
                screensaver_item.passwordRequired = yunshOS.lockPasswordEnabled
                screensaver_item.show()
            }
            onRequestSystemAction: function(action) {
                controlCenter.hide()
                yunshOS.beginSystemActionConfirmation(action)
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
            SettingsScreen {
                anchors.fill: parent
                autoLockSeconds: yunshOS.autoLockSeconds
                lockPasswordEnabled: yunshOS.lockPasswordEnabled
                onBackToHome: switchToHome()
                onOpenUpdatePage: switchTo(updateWindow, "update")
                onOpenUpdateHistory: switchTo(updateHistoryWindow, "updatehistory")
                onOpenNetworkSettings: switchTo(networkWindow, "network")
                onOpenBluetoothSettings: switchTo(bluetoothWindow, "bluetooth")
                onOpenSystemInfo: switchTo(systemInfoWindow, "systeminfo")
                onOpenDisplaySettings: switchTo(displayWindow, "display")
                onOpenComfortDna: switchTo(comfortDnaWindow, "comfortdna")
                onOpenSoundSettings: { settingsWindow.visible = false; controlCenter.show() }
                onRequestAutoLockSeconds: function(seconds) {
                    yunshOS.autoLockSeconds = seconds
                    idleTimer.restart()
                    yunshOS.saveSpatialPreferences()
                }
                onRequestLockPasswordEnabled: function(enabled) {
                    yunshOS.lockPasswordEnabled = enabled
                    yunshOS.saveSpatialPreferences()
                }
                onRequestFactoryReset: yunshOS.beginSystemActionConfirmation("factory_reset")
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
                onOpenHistory: switchTo(updateHistoryWindow, "updatehistory")
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
            Loader {
                id: browserLoader
                anchors.fill: parent
                active: yunshOS.browserRequested
                sourceComponent: Component {
                    YunshBrowser {
                        anchors.fill: parent
                        onBackToHome: yunshOS.switchToHome()
                        onRequestVirtualKeyboard: function(target) {
                            yunshOS.virtualKeyboardRef.showFor(target)
                        }
                        onDismissVirtualKeyboard: yunshOS.virtualKeyboardRef.hide()
                    }
                }
            }
        }

        // ===== SYSTEM WORLD LAYER =====
        // The metaverse is a shell layer and never enters the app switcher.
        YunshMetaverse {
            id: worldLayer
            anchors.fill: parent
            visible: false
            z: 430
            onBackToHome: switchToHome()
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
            onCloseClicked: yunshOS.closeAppFromSwitcher(yunshOS.androidTarget)
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
                rootContainer.grabToImage(function(result) {
                    var fullPath = "/tmp/yunsh-screenshot-region-full-" + Date.now() + ".png"
                    if (!result.saveToFile(fullPath)) {
                        yunshOS.showToast("区域截图失败")
                        return
                    }
                    appDaemonRequest({
                        action: "crop", source: fullPath, x: x, y: y, w: w, h: h
                    }, function(response) {
                        yunshOS.showToast(response.status === "ok"
                            ? "区域截图已保存" : "截图失败：" + (response.message || "未知错误"))
                    })
                })
            }
            onCancelled: screenshotOverlay.visible = false
        }

        // ===== VIRTUAL KEYBOARD (visionOS floating panel) =====
        VirtualKeyboard {
            id: virtualKeyboard
            anchors.fill: parent
            z: 7200
            reduceMotion: yunshOS.reduceMotion
            headYaw: yunshOS.headYaw
            headPitch: yunshOS.headPitch
            pixelsPerDegree: yunshOS.pixelsPerDegree
            onDismissKeyboard: virtualKeyboard.hide()
        }

        // ===== SCREENSAVER (visionOS standby) =====
        Screensaver {
            id: screensaver_item
            anchors.fill: parent
            visible: false
            z: 400
            onWake: {
                if (!screensaver_item.passwordRequired) {
                    screensaver_item.visible = false
                    idleTimer.restart()
                }
            }
            onUnlocked: {
                virtualKeyboard.hide()
                screensaver_item.hideScreen()
                yunshOS.syncLockState(false)
                yunshOS.clearBootLock()
                idleTimer.restart()
            }
            onVisibleChanged: {
                yunshOS.syncLockState(visible && passwordRequired)
                if (visible) {
                    // Locking is a hard UI boundary: close agent, menus and
                    // background switcher before the password surface shows.
                    orbitPanel.expanded = false
                    controlCenter.hide()
                    taskSwitcher.hide()
                    virtualKeyboard.hide()
                }
            }
            onPasswordRequiredChanged: {
                if (visible) yunshOS.syncLockState(visible && passwordRequired)
            }
            onRequestVirtualKeyboard: function(target) {
                if (visible && passwordRequired)
                    virtualKeyboard.showFor(target)
            }
        }

        // ─── Idle timer — turns the AR surface black and locks locally ───
        Timer {
            id: idleTimer
            interval: Math.max(1, yunshOS.autoLockSeconds) * 1000
            running: yunshOS.autoLockSeconds > 0
            repeat: false
            onTriggered: {
                if (!screensaver_item.visible) {
                    screensaver_item.passwordRequired = yunshOS.lockPasswordEnabled
                    screensaver_item.show()
                }
            }
        }

        // ===== TASK SWITCHER (visionOS App Switcher) =====
        TaskSwitcher {
            id: taskSwitcher
            anchors.fill: parent
            reduceMotion: yunshOS.reduceMotion
            openApps: yunshOS.openApps
            // The switcher is a system surface and must stay above every
            // floating app window.  The lock/activation layers still use a
            // higher z and explicitly hide it.
            z: 6000
            onSwitchToApp: function(appId) { hideTaskSwitcher(); switchToAppById(appId) }
            onCloseApp: function(appId) { yunshOS.closeAppFromSwitcher(appId) }
            onDismissSwitcher: hideTaskSwitcher()
        }

        // ===== HOME INDICATOR (mouse swipe up trigger) =====
        HomeIndicator {
            id: homeIndicator
            z: 5990
            reduceMotion: yunshOS.reduceMotion
            // Keep the home hit zone alive while a minimized/background app is
            // tracked, even if the home surface was briefly hidden during the
            // minimize animation.
            visible: homeScreen.visible || yunshOS.openApps.length > 0 || taskSwitcher.visible
            onSwipeUpTriggered: showTaskSwitcher()
            onClicked: showTaskSwitcher()
        }

        // Full-width bottom gesture target.  The old target was only the
        // 164px-wide pill, so on a large display a normal upward swipe often
        // landed beside it and did nothing.  This transparent surface is
        // active only while an app is tracked and the switcher is closed; it
        // therefore cannot steal card or dialog input.
        MouseArea {
            id: taskSwitcherGestureSurface
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 120
            z: 5995
            visible: homeScreen.visible
                && !taskSwitcher.visible
                && yunshOS.openApps.length > 0
                && !screensaver_item.visible
            hoverEnabled: false
            property real pressY: 0
            property bool triggered: false

            onPressed: function(mouse) {
                pressY = mouse.y
                triggered = false
            }
            onPositionChanged: function(mouse) {
                if (pressed && !triggered && pressY - mouse.y >= 24) {
                    triggered = true
                    showTaskSwitcher()
                }
            }
            onReleased: function(mouse) {
                if (!triggered && Math.abs(pressY - mouse.y) < 24)
                    showTaskSwitcher()
                triggered = false
            }
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
                ? "#F8FCFF" : Qt.rgba(248/255, 252/255, 255/255, 0.88)
            border.width: 1
            border.color: yunshOS.highContrast
                ? Qt.rgba(75/255, 91/255, 103/255, 0.46) : Qt.rgba(1, 1, 1, 0.94)
            opacity: 0
            visible: opacity > 0
            z: 6000

            Text {
                id: toastLabel
                anchors.centerIn: parent
                text: ""
                color: "#17212A"
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

        Rectangle {
            id: systemActionDialog
            anchors.fill: parent
            z: 6900
            visible: yunshOS.systemActionConfirmStage > 0
            color: Qt.rgba(0, 0, 0, 0.58)

            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.centerIn: parent
                width: 500
                height: yunshOS.pendingSystemAction === "factory_reset"
                    ? (yunshOS.systemActionConfirmStage === 1 ? 390 : 310) : 270
                radius: 32
                color: "#F8FDFF"
                border.width: 1
                border.color: "#FFFFFF"

                Column {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 16

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: yunshOS.pendingSystemAction === "factory_reset"
                                && yunshOS.systemActionConfirmStage === 1
                            ? "验证本机密码"
                            : (yunshOS.systemActionConfirmStage === 1
                                ? "确认系统操作" : "最后一次确认")
                        color: "#111820"
                        font.pixelSize: 23
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: {
                            if (yunshOS.pendingSystemAction === "factory_reset")
                                return yunshOS.systemActionConfirmStage === 1
                                    ? "请先输入当前本机密码。验证后仍需最后确认；恢复完成后，本机密码会重置为 yunsh123。"
                                    : "此操作无法撤销。设备完成清理后会自动重启并重新进入激活流程。"
                            if (yunshOS.pendingSystemAction === "restart")
                                return yunshOS.systemActionConfirmStage === 1
                                    ? "系统将关闭所有应用并重新启动，未保存的内容可能丢失。"
                                    : "确定现在重新启动 YUNSH OS 吗？"
                            return yunshOS.systemActionConfirmStage === 1
                                ? "系统将关闭所有应用并停止运行，未保存的内容可能丢失。"
                                : "确定现在关闭 YUNSH OS 吗？"
                        }
                        color: "#52616C"
                        font.pixelSize: 14
                        lineHeight: 1.35
                    }
                    Rectangle {
                        visible: yunshOS.pendingSystemAction === "factory_reset"
                            && yunshOS.systemActionConfirmStage === 1
                        width: parent.width
                        height: visible ? 54 : 0
                        radius: 18
                        color: Qt.rgba(1, 1, 1, 0.64)
                        border.width: 1
                        border.color: factoryResetField.activeFocus ? "#00D4FF" : "#D7E7ED"
                        TextField {
                            id: factoryResetField
                            anchors.fill: parent
                            anchors.margins: 8
                            placeholderText: "输入当前本机密码"
                            echoMode: TextInput.Password
                            color: "#111820"
                            enabled: !yunshOS.factoryResetPasswordBusy
                            background: Item {}
                            onTextChanged: yunshOS.factoryResetPassword = text
                            onAccepted: yunshOS.verifyFactoryResetPassword()
                        }
                    }
                    Text {
                        visible: yunshOS.pendingSystemAction === "factory_reset"
                            && yunshOS.systemActionConfirmStage === 1
                            && yunshOS.factoryResetPasswordError.length > 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: yunshOS.factoryResetPasswordError
                        color: "#C72732"
                        font.pixelSize: 12
                    }
                    Item { width: 1; height: 6 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        Rectangle {
                            width: 150; height: 48; radius: 24
                            color: cancelSystemMouse.pressed ? "#E7F1F4" : "#EEF5F7"
                            Text {
                                anchors.centerIn: parent
                                text: "取消"
                                color: "#17212A"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: cancelSystemMouse
                                anchors.fill: parent
                                onClicked: yunshOS.cancelSystemAction()
                            }
                        }
                        Rectangle {
                            width: 190; height: 48; radius: 24
                            color: confirmSystemMouse.pressed ? "#C72732"
                                : (yunshOS.systemActionConfirmStage === 1 ? "#00D4FF" : "#E43A45")
                            Text {
                                anchors.centerIn: parent
                                text: yunshOS.pendingSystemAction === "factory_reset"
                                        && yunshOS.systemActionConfirmStage === 1
                                    ? (yunshOS.factoryResetPasswordBusy ? "正在验证…" : "验证密码")
                                    : (yunshOS.systemActionConfirmStage === 1
                                        ? (yunshOS.pendingSystemAction === "restart" ? "重新启动" : "关机")
                                        : (yunshOS.pendingSystemAction === "factory_reset"
                                        ? "抹掉并恢复" : (yunshOS.pendingSystemAction === "restart"
                                            ? "立即重启" : "立即关机")))
                                color: yunshOS.systemActionConfirmStage === 1
                                    && yunshOS.pendingSystemAction !== "factory_reset" ? "#00191F" : "#FFFFFF"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: confirmSystemMouse
                                anchors.fill: parent
                                onClicked: {
                                    if (yunshOS.pendingSystemAction === "factory_reset"
                                            && yunshOS.systemActionConfirmStage === 1)
                                        yunshOS.verifyFactoryResetPassword()
                                    else
                                        yunshOS.executeConfirmedSystemAction()
                                }
                            }
                        }
                    }
                }
            }
        }

        SystemMenuBar {
            id: systemMenuBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            z: 7000
            visible: (!firstBoot || activationDone)
            locked: screensaver_item.visible
            orbitConfigured: orbitPanel.configured
            orbitBusy: orbitPanel.computerOperationActive || orbitPanel.voiceConversationActive
            orbitAwaitingApproval: orbitPanel.computerApprovalPending
                || (orbitPanel.pendingApprovalId === "voice" && orbitPanel.voiceConversationActive)
            orbitApprovalCanAlways: !orbitPanel.pendingApprovalAlwaysConfirm
            orbitVoiceActive: orbitPanel.voiceConversationActive
            orbitActivityText: orbitPanel.statusText
            reduceMotion: yunshOS.reduceMotion
            recordingActive: yunshOS.recordingActive
            fullscreenMode: {
                var active = yunshOS.getWindowById(yunshOS.activeAppId)
                return active ? active.isFullscreen : false
            }
            onOpenSystemMenu: controlCenter.show()
            onRequestPowerAction: function(action) {
                controlCenter.hide()
                systemMenuBar.powerMenuVisible = false
                yunshOS.beginSystemActionConfirmation(action)
            }
            onOpenWorld: yunshOS.openWorld()
            onOpenOrbit: orbitPanel.openPanel()
            onOrbitApprovalDecision: function(decision) { orbitPanel.respondToApproval(decision) }
        }

        OrbitPanel {
            id: orbitPanel
            anchors.fill: parent
            z: 7100
            visible: (!firstBoot || activationDone) && !screensaver_item.visible
            showTrigger: false
            locked: screensaver_item.visible
            keyboardVisible: virtualKeyboard.visible
            reduceMotion: yunshOS.reduceMotion
            onToastRequested: function(message) { yunshOS.showToast(message) }
        }
    }

    // ===== FLOATING WINDOW FUNCTIONS =====
    property int windowCount: 0

    function activateWindow(window, appId) {
        if (!window || !window.visible)
            return
        activeAppId = appId
        hideAppIconsForWindow()
        window.z = 60 + (++windowCount)
        updateWindowFocus()
    }

    function minimizeWindow(window, appId) {
        // A minimized window remains a running app and must stay in the App
        // Switcher even when it arrived through a dynamic Android entry.
        trackAppOpen(appId, window && window.appTitle ? window.appTitle : "")
        // A minimized app must not leave its editor/keyboard on top of the
        // home surface; otherwise the bottom gesture is covered and the
        // switcher appears not to respond.
        virtualKeyboard.hide()
        window.visible = false
        window.isMinimized = true
        var updatedApps = openApps.slice()
        for (var i = 0; i < updatedApps.length; i++) {
            if (updatedApps[i].appId === appId) {
                updatedApps[i].minimized = true
                break
            }
        }
        openApps = updatedApps
        if (activeAppId === appId)
            activeAppId = ""
        homeScreen.visible = true
        resolveAppIconVisibility()
        updateWindowFocus()
    }

    function switchTo(window, appId) {
        if (!window.visible) homeScreen.visible = true
        hideAppIconsForWindow()
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
        // Going home is not the same as terminating applications. Preserve
        // every open window as a background card so the upward gesture can
        // restore it, matching the explicit yellow minimize action.
        var updatedApps = openApps.slice()
        for (var i = 0; i < updatedApps.length; i++) {
            var w = getWindowById(updatedApps[i].appId)
            if (w && (w.visible || w.isMinimized)) {
                w.visible = false
                w.isMinimized = true
                updatedApps[i].minimized = true
            }
        }
        openApps = updatedApps
        virtualKeyboard.hide()
        worldLayer.visible = false
        activeAppId = ""
        updateWindowFocus()
        homeScreen.visible = true
        resolveAppIconVisibility()
    }

    function openBrowser() {
        browserRequested = true
        switchTo(browserWindow, "browser")
    }

    function openWorld() {
        worldLayer.visible = true
        homeScreen.visible = false
        activeAppId = ""
        taskSwitcher.hide()
        updateWindowFocus()
    }

    function switchToAppById(appId) {
        var w = getWindowById(appId)
        if (w) switchTo(w, appId)
    }

    // Reconcile the switcher model from the actual window state immediately
    // before it is shown.  A minimize click changes the window first; relying
    // only on the earlier openApps snapshot could therefore leave the
    // background app absent from the swipe-up view.
    function syncOpenAppsFromWindows() {
        var next = []
        var seen = {}
        var candidates = workspaceWindowEntries()
        candidates.push({appId: androidTarget, window: androidWindow})
        for (var i = 0; i < candidates.length; i++) {
            var entry = candidates[i]
            var window = entry.window
            if (!window || (!window.visible && !window.isMinimized))
                continue
            var appId = entry.appId
            if (!appId || seen[appId])
                continue
            seen[appId] = true
            var info = appInfo[appId] || {
                name: window.appTitle || appId,
                icon: "/usr/share/yunsh/icons/android-app.svg",
                color: "#7C77A8"
            }
            next.push({appId: appId, name: info.name, icon: info.icon,
                       color: info.color, minimized: window.isMinimized === true})
        }
        // Keep any tracked Android app that is represented by the shared
        // compositor surface, even when its current target changed.
        for (var j = 0; j < openApps.length; j++) {
            var old = openApps[j]
            if (!old || seen[old.appId])
                continue
            if (old.appId.indexOf("android:") === 0 && androidWindow.isMinimized) {
                seen[old.appId] = true
                next.push(old)
            }
        }
        openApps = next
    }

    function showTaskSwitcher() {
        syncOpenAppsFromWindows()
        if (yunshOS.openApps.length === 0) {
            taskSwitcher.hide()
            homeScreen.visible = true
            resolveAppIconVisibility()
            return
        }
        // The home surface remains the background behind the switcher; this
        // also keeps the bottom hit zone alive after minimizing the last
        // visible window.
        homeScreen.visible = true
        taskSwitcher.show()
    }

    function hideTaskSwitcher() {
        taskSwitcher.hide()
        if (yunshOS.openApps.length === 0) {
            homeScreen.visible = true
            resolveAppIconVisibility()
        }
    }

    function takeScreenshot() {
        console.log("Screenshot triggered - full screen capture")
        rootContainer.grabToImage(function(result) {
            var filename = "/home/yunsh/Pictures/Screenshots/Screenshot_" + Date.now() + ".png"
            if (result.saveToFile(filename)) {
                console.log("Full screenshot saved to " + filename)
                yunshOS.showToast("截图已保存")
            } else {
                yunshOS.showToast("截图失败")
            }
        })
    }

    function appDaemonRequest(payload, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 50000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                callback(JSON.parse(xhr.responseText || "{}"))
            } catch (_error) {
                callback({status: "error", message: "系统服务返回异常"})
            }
        }
        xhr.ontimeout = function() {
            callback({status: "error", message: "系统服务响应超时"})
        }
        xhr.send(JSON.stringify(payload))
    }

    function toggleScreenRecording() {
        var command = recordingActive ? "stop" : "start"
        appDaemonRequest({action: "screen_recording", command: command},
                         function(result) {
            if (result.status !== "ok") {
                showToast("录屏失败：" + (result.message || "录屏组件不可用"))
                return
            }
            recordingActive = result.recording === true
            showToast(recordingActive ? "已开始录屏" : "录屏已保存到视频")
        })
    }

    function refreshRecordingStatus() {
        appDaemonRequest({action: "screen_recording", command: "status"},
                         function(result) {
            if (result.status === "ok")
                recordingActive = result.recording === true
        })
    }

    function beginSystemActionConfirmation(action) {
        if (["restart", "shutdown", "factory_reset"].indexOf(action) < 0)
            return
        pendingSystemAction = action
        systemActionConfirmStage = 1
        factoryResetPassword = ""
        factoryResetPasswordError = ""
        factoryResetPasswordBusy = false
    }

    function cancelSystemAction() {
        pendingSystemAction = ""
        systemActionConfirmStage = 0
        factoryResetPassword = ""
        factoryResetPasswordError = ""
        factoryResetPasswordBusy = false
    }

    function verifyFactoryResetPassword() {
        if (pendingSystemAction !== "factory_reset" || systemActionConfirmStage !== 1)
            return
        if (!factoryResetPassword.length) {
            factoryResetPasswordError = "请输入当前本机密码"
            return
        }
        factoryResetPasswordBusy = true
        factoryResetPasswordError = ""
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/verify-boot-password", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 15000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            factoryResetPasswordBusy = false
            try {
                var result = JSON.parse(xhr.responseText || "{}")
                if (result.success) {
                    factoryResetPassword = ""
                    factoryResetField.text = ""
                    systemActionConfirmStage = 2
                } else {
                    factoryResetPasswordError = result.error || "本机密码不正确"
                }
            } catch (_error) {
                factoryResetPasswordError = "无法验证本机密码"
            }
        }
        xhr.ontimeout = function() {
            factoryResetPasswordBusy = false
            factoryResetPasswordError = "验证超时，请重试"
        }
        xhr.send(JSON.stringify({password: factoryResetPassword}))
    }

    function executeConfirmedSystemAction() {
        var action = pendingSystemAction
        cancelSystemAction()
        appDaemonRequest({action: "system_action", command: action},
                         function(result) {
            if (result.status !== "ok")
                showToast("系统操作失败：" + (result.message || "未知错误"))
            else
                showToast("系统正在处理…")
        })
    }

    function reportUiState() {
        var ids = []
        for (var i = 0; i < openApps.length; i++)
            ids.push(openApps[i].appId)
        appDaemonRequest({
            action: "set_ui_state",
            state: {
                activeAppId: activeAppId,
                homeVisible: homeScreen.visible,
                appIconsVisible: homeScreen.appIconsVisible,
                appIconsManuallyHidden: appIconsManuallyHidden,
                worldVisible: worldLayer.visible,
                focusMode: focusMode,
                recording: recordingActive,
                openApps: ids
            }
        }, function(_result) {})
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
            browserWindow, terminalWindow, photosWindow,
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
            { appId: "comfortdna", window: comfortDnaWindow },
            { appId: "spacecapsule", window: spaceCapsuleWindow },
            { appId: "screenrelay", window: screenRelayWindow },
            { appId: "update", window: updateWindow },
            { appId: "updatehistory", window: updateHistoryWindow },
            { appId: "browser", window: browserWindow },
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
            if (appId === "browser" && browserScreen)
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
        var restoredWindowVisible = false
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
            if (window.visible)
                restoredWindowVisible = true
            window.z = 60 + Math.max(0, item.order)
            windowCount = Math.max(windowCount, item.order)

            if (item.appId === "browser") {
                browserRequested = true
                if (item.state && item.state.url && browserScreen)
                    browserScreen.currentUrl = item.state.url
            }
            if (item.appId === capsule.activeAppId && window.visible)
                restoredActiveWindow = window
            restoredCount++
        }

        homeScreen.visible = true
        if (restoredWindowVisible)
            hideAppIconsForWindow()
        else
            resolveAppIconVisibility()
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
                if (!command.id || command.id === yunshOS.lastUiCommandId)
                    return
                yunshOS.lastUiCommandId = command.id
                if (command.action === "recenter") {
                    yunshOS.recenterTracking()
                } else if (command.action === "open_world") {
                    yunshOS.openWorld()
                } else if (command.action === "open_app" && command.appId) {
                    var appId = String(command.appId)
                    if (appId === "appstore" || appId === "files")
                        yunshOS.launchApp(appId)
                    else
                        yunshOS.switchToAppById(appId)
                } else if (command.action === "confirm_system_action"
                           && command.systemAction) {
                    yunshOS.beginSystemActionConfirmation(
                        String(command.systemAction))
                } else if (command.action === "toast" && command.message) {
                    yunshOS.showToast(String(command.message))
                } else if (command.action === "ui_action" && command.uiAction) {
                    var action = String(command.uiAction)
                    if (action === "home") {
                        yunshOS.switchToHome()
                    } else if (action === "task_switcher") {
                        yunshOS.showTaskSwitcher()
                    } else if (action === "close_active" && yunshOS.activeAppId) {
                        yunshOS.closeAppFromSwitcher(yunshOS.activeAppId)
                    } else if (action === "minimize_active" && yunshOS.activeAppId) {
                        var activeWindow = yunshOS.getWindowById(yunshOS.activeAppId)
                        if (activeWindow)
                            yunshOS.minimizeWindow(activeWindow, yunshOS.activeAppId)
                    } else if (action === "toggle_keyboard") {
                        virtualKeyboard.visible
                            ? virtualKeyboard.hide() : virtualKeyboard.show()
                    } else if (action === "lock") {
                        screensaver_item.passwordRequired = yunshOS.lockPasswordEnabled
                        screensaver_item.show()
                    }
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

    Timer {
        interval: 2000
        running: !firstBoot || activationDone
        repeat: true
        onTriggered: {
            yunshOS.reportUiState()
            yunshOS.refreshRecordingStatus()
        }
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
            focusMode: focusMode,
            lockPasswordEnabled: lockPasswordEnabled,
            autoLockSeconds: autoLockSeconds,
            appIconsManuallyHidden: appIconsManuallyHidden
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
        if (typeof data.lockPasswordEnabled === "boolean")
            lockPasswordEnabled = data.lockPasswordEnabled
        if (typeof data.autoLockSeconds === "number")
            autoLockSeconds = Math.max(0, Math.min(3600, Math.round(data.autoLockSeconds)))
        if (typeof data.appIconsManuallyHidden === "boolean")
            appIconsManuallyHidden = data.appIconsManuallyHidden
        resolveAppIconVisibility()
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
            focusMode: settings.focusMode,
            lockPasswordEnabled: settings.lockPasswordEnabled,
            autoLockSeconds: settings.autoLockSeconds
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
            homeScreen.appIconsVisible = !appIconsManuallyHidden
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
            if (screensaver_item.visible) {
                if (!screensaver_item.passwordRequired) screensaver_item.wake()
                return
            }
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

        // Android remains one compositor surface, but every installed app gets
        // its own desktop icon and title. Keep just that one Android surface
        // in the task switcher when changing between Android applications.
        var isAndroidApp = appId === "appstore" || appId === "files"
            || appId.indexOf("android:") === 0
        if (isAndroidApp) {
            var filteredApps = []
            for (var i = 0; i < openApps.length; i++) {
                if (openApps[i].appId.indexOf("android:") !== 0
                        && openApps[i].appId !== "appstore" && openApps[i].appId !== "files")
                    filteredApps.push(openApps[i])
            }
            openApps = filteredApps
        }
        yunshOS.androidTarget = appId
        androidWindow.appTitle = info.name
        var w = androidWindow
        w.x = 80 + (windowCount % 3) * 40
        w.y = 80 + (windowCount % 3) * 30
        w.visible = true
        w.isMinimized = false
        homeScreen.visible = true
        hideAppIconsForWindow()
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

    function refreshAndroidDesktopApps() {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 5000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var data = JSON.parse(xhr.responseText)
                if (!data.apps || !Array.isArray(data.apps))
                    return
                var nextInfo = appInfo
                for (var i = 0; i < data.apps.length; ++i) {
                    var app = data.apps[i]
                    if (!app.package || app.package === "org.fdroid.fdroid")
                        continue
                    nextInfo["android:" + app.package] = {
                        name: app.name || app.package,
                        icon: "/usr/share/yunsh/icons/android-app.svg",
                        color: "#00D4FF"
                    }
                }
                appInfo = nextInfo
                homeScreen.setAndroidApps(data.apps)
            } catch (error) {
                console.log("Android desktop app refresh unavailable")
            }
        }
        xhr.send(JSON.stringify({action: "android_apps"}))
    }

    Timer {
        interval: 12000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: refreshAndroidDesktopApps()
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
        // A locked password surface must not receive hover/position events.
        // On the Pi DRM path those events can enter the compositor's unstable
        // pointer plane; the lock screen does not need hover feedback.
        hoverEnabled: !screensaver_item.visible || !screensaver_item.passwordRequired
        onPositionChanged: {
            if (screensaver_item.visible && screensaver_item.passwordRequired)
                return
            idleTimer.restart()
            if (screensaver_item.visible) {
                if (!screensaver_item.passwordRequired)
                    screensaver_item.wake()
                return
            }
        }
    }

    Component.onCompleted: {
        console.log("YUNSH OS UI v3.1.6")
        checkFirstBoot()
        showFullScreen()
        applyWindowPreferences()
        // Probe head tracking daemon once (won't poll if not found)
        Qt.callLater(function() {
            yunshOS.loadSpatialPreferences()
            yunshOS.probeHeadTracking()
            if (!firstBoot)
                yunshOS.checkBootLock()
        })
    }
}
