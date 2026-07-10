// YUNSH OS v1.0 - Main QML Entry Point (visionOS Enhanced)
// Manages all screens, Control Center, gestures, first-boot activation

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
    property bool firstBoot: false  // Will be set to true on first run
    property bool activationDone: false
    
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
            
            onOpenSettings: switchTo(settingsScreen)
            onOpenAbout: switchTo(systemInfoScreen)
            onOpenAppStore: launchApp("appstore")
            onOpenFileManager: launchApp("files")
            onOpenBrowser: switchTo(browserScreen)
            onOpenMetaverse: switchTo(metaverseScreen)
            onOpenSystemUpdateUI: switchTo(updateScreen)
            onOpenNetwork: switchTo(networkScreen)
            onOpenBluetooth: switchTo(bluetoothScreen)
            onOpenTerminal: switchTo(terminalScreen)
            onOpenPhotos: switchTo(photosScreen)
            onShowControlCenter: controlCenter.show()
            onTakeScreenshot: takeScreenshot()
            onOpenAppLibrary: { /* future: app library */ }
        }
        
        // ===== CONTROL CENTER =====
        ControlCenter {
            id: controlCenter
            anchors.fill: parent
            visible: false
            z: 300
            
            onDismissPanel: controlCenter.hide()
            onOpenNetwork: {
                controlCenter.hide()
                switchTo(networkScreen)
            }
            onOpenBluetooth: {
                controlCenter.hide()
                switchTo(bluetoothScreen)
            }
            onTakeScreenshot: takeScreenshot()
        }
        
        // ===== SETTINGS =====
        SettingsScreen {
            id: settingsScreen
            anchors.fill: parent
            visible: false
            z: 50
            
            onBackToHome: switchToHome()
            onOpenUpdatePage: switchTo(updateScreen)
            onOpenUpdateHistory: switchTo(updateHistoryScreen)
            onOpenNetworkSettings: switchTo(networkScreen)
            onOpenBluetoothSettings: switchTo(bluetoothScreen)
            onOpenSystemInfo: switchTo(systemInfoScreen)
            onOpenDisplaySettings: { /* display settings: brightness/theme - TBD */ }
            onOpenSoundSettings: { /* sound settings: volume/output - TBD */ }
            onOpenLanguageSettings: { /* language/input settings - TBD */ }
            onOpenDateTimeSettings: { /* date/time/timezone settings - TBD */ }
        }
        
        // ===== SYSTEM INFO (About) =====
        SystemInfoScreen {
            id: systemInfoScreen
            anchors.fill: parent; visible: false; z: 55
            onBackToSettings: switchTo(settingsScreen)
        }
        
        // ===== ABOUT (legacy) =====
        AboutScreen {
            id: aboutScreen
            anchors.fill: parent; visible: false; z: 50
            onBackToHome: switchToHome()
        }
        
        // ===== NETWORK/Wi-Fi =====
        NetworkScreen {
            id: networkScreen
            anchors.fill: parent; visible: false; z: 55
            onBackToSettings: switchTo(settingsScreen)
            onBackToHome: switchToHome()
        }
        
        // ===== BLUETOOTH =====
        BluetoothScreen {
            id: bluetoothScreen
            anchors.fill: parent; visible: false; z: 55
            onBackToSettings: switchTo(settingsScreen)
            onBackToHome: switchToHome()
        }
        
        // ===== UPDATE =====
        Rectangle {
            id: updateScreen
            anchors.fill: parent; visible: false; z: 60; color: "#000000"
            // Glass backdrop
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
            }
            UpdateScreen {
                anchors.fill: parent; visible: true; z: 10
                onBackToHome: switchToHome()
            }
        }
        
        // ===== UPDATE HISTORY =====
        Rectangle {
            id: updateHistoryScreen
            anchors.fill: parent; visible: false; z: 60; color: "#000000"
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
            }
            UpdateHistoryScreen {
                anchors.fill: parent; visible: true; z: 10
                onBackToUpdates: switchTo(settingsScreen)
            }
        }
        
        // ===== BROWSER =====
        Rectangle {
            id: browserScreen
            anchors.fill: parent; visible: false; z: 60; color: "#000000"
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
            }
            YunshBrowser {
                anchors.fill: parent; visible: true; z: 10
                onBackToHome: switchToHome()
            }
        }
        
        // ===== METAVERSE =====
        Rectangle {
            id: metaverseScreen
            anchors.fill: parent; visible: false; z: 60; color: "#000000"
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
            }
            YunshMetaverse {
                anchors.fill: parent; visible: true; z: 10
                onBackToHome: switchToHome()
            }
        }
        
        // ===== TERMINAL =====
        TerminalScreen {
            id: terminalScreen
            anchors.fill: parent
            onBackToHome: switchToHome()
        }

        // ===== PHOTOS =====
        Rectangle {
            id: photosScreen
            anchors.fill: parent; visible: false; z: 60; color: "#000000"
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
            }
            PhotosScreen {
                anchors.fill: parent; visible: true; z: 10
                onBackToHome: switchToHome()
            }
        }
        
        // ===== SCREENSHOT OVERLAY =====
        ScreenshotOverlay {
            id: screenshotOverlay
            anchors.fill: parent; visible: false; z: 200
            onRegionSelected: function(x, y, w, h) {
                screenshotOverlay.visible = false
            }
            onCancelled: screenshotOverlay.visible = false
        }
        
        // ===== VIRTUAL KEYBOARD =====
        // ===== VIRTUAL KEYBOARD (system-wide, highest z) =====
        VirtualKeyboard {
            id: virtualKeyboard
            anchors.fill: parent
            z: 1000
            
            onDismissKeyboard: virtualKeyboard.hide()
        }
    }
    
    // ===== NAVIGATION FUNCTIONS =====
    function switchTo(screen) {
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
        photosScreen.visible = false
        screen.visible = true
    }
    
    function switchToHome() {
        updateScreen.visible = false
        updateHistoryScreen.visible = false
        browserScreen.visible = false
        metaverseScreen.visible = false
        photosScreen.visible = false
        settingsScreen.visible = false
        aboutScreen.visible = false
        systemInfoScreen.visible = false
        networkScreen.visible = false
        bluetoothScreen.visible = false
        homeScreen.visible = true
    }
    
    function takeScreenshot() {
        console.log("Screenshot triggered")
        Qt.callLater(function() { /* yunsh-screenshot-launcher full */ })
    }
    
    // ─── First-boot flag management ────────────────
    function checkFirstBoot() {
        // Check if activation has been completed by looking for flag file
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file:///etc/yunsh/.activated", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                // File not found (.activated missing) = first boot
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
        // Write user credentials script (launcher will create the user after QML exits)
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
    
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if(controlCenter.visible) { controlCenter.hide(); return }
            if(screenshotOverlay.visible) { screenshotOverlay.cancelled(); return }
            if(screensaver.visible) { screensaver.wake(); return }
            if(activationScreen.visible && !activationDone) {
                activationScreen.skipActivation()
                return
            }
            if(!homeScreen.visible) { switchToHome(); return }
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
        console.log("YUNSH OS UI v1.0 (visionOS Ultimate)")
        // First boot: show activation; subsequent: go to home
        checkFirstBoot()
        showFullScreen()
    }
}
