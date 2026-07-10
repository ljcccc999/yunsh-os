// YUNSH OS v1.0 - Activation Wizard (visionOS Style)
// First-boot setup: welcome, language, Wi-Fi, initialization
// All glassmorphism, no login required

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// File I/O helper for writing user credentials
import Qt.labs.platform 1.1

Rectangle {
    id: activationScreen
    anchors.fill: parent
    color: "#000000"  // Transparent in AR
    visible: false
    z: 250

    // ─── Signals ─────────────────────────────────────
    signal activationComplete()
    signal skipActivation()

    // ─── State ───────────────────────────────────────
    property int currentStep: 0  // 0=welcome, 1=language, 2=wifi, 3=account, 4=initializing
    readonly property int totalSteps: 5

    property string selectedLanguage: "简体中文"
    property string selectedKeyboard: "拼音"
    property string wifiSSID: ""
    property string accountUsername: "yunsh"
    property string accountPassword: ""
    property string accountConfirmPassword: ""
    property bool accountValid: false
    property string accountError: ""

    // ─── Background layers ──────────────────────────
    // Ambient glow (visionOS atmospheric)
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: parent.height * 0.5
        radius: width / 2
        color: Qt.rgba(0/255, 100/255, 255/255, 0.03)
    }

    // ─── Step indicator dots ────────────────────────
    Row {
        anchors.top: parent.top; anchors.topMargin: 60
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        z: 10

        Repeater {
            model: totalSteps
            Rectangle {
                width: index === currentStep ? 32 : 8
                height: 4; radius: 2
                color: index === currentStep ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.08)
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    // ─── YUNSH logo (always visible) ────────────────
    Image {
        anchors.top: parent.top; anchors.topMargin: 24
        anchors.right: parent.right; anchors.rightMargin: 24
        source: "/usr/share/yunsh/logo/logo-32.png"
        width: 28; height: 28
        sourceSize.width: 32; sourceSize.height: 32
        fillMode: Image.PreserveAspectFit
        opacity: 0.3
    }

    // ════════════════════════════════════════════════════
    // STEP 0: Welcome Page
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 0

        // Central glass card
        Rectangle {
            anchors.centerIn: parent
            width: 520; height: 460
            radius: 32
            color: Qt.rgba(15/255, 15/255, 32/255, 0.45)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
            border.width: 1

            // Top highlight glow
            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: parent.height * 0.4
                radius: 32
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0/255, 212/255, 255/255, 0.04) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 24

                // Logo
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "/usr/share/yunsh/logo/logo-128.png"
                    width: 80; height: 80
                    sourceSize.width: 128; sourceSize.height: 128
                    fillMode: Image.PreserveAspectFit
                }

                // Multi-language "Hello"
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "你好"
                    color: "#FFFFFF"
                    font.pixelSize: 48
                    font.weight: Font.Light
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Hello  Bonjour  こんにちは  안녕하세요"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.3)
                    font.pixelSize: 11
                    letterSpacing: 2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "欢迎使用 YUNSH OS"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.6)
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                // Version
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "v1.0.0"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                    font.pixelSize: 11
                }

                // "继续" button (capsule style)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 200; height: 48; radius: 24
                    color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
                    border.color: Qt.rgba(0/255, 212/255, 255/255, 0.12)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "继续"
                        color: "#00D4FF"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.25)
                        onExited: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.15)
                        onClicked: currentStep = 1
                    }
                }

                // Skip hint
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "按 Esc 跳过设置"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                    font.pixelSize: 10

                    MouseArea {
                        anchors.fill: parent
                        onClicked: activationScreen.skipActivation()
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 1: Language & Keyboard Selection
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 1

        Rectangle {
            anchors.centerIn: parent
            width: 480; height: 400
            radius: 32
            color: Qt.rgba(15/255, 15/255, 32/255, 0.45)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
            border.width: 1

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 28
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "语言 Language"
                    color: "#FFFFFF"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                // Language list (glass cards)
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    // 简体中文
                    Rectangle {
                        width: 360; height: 48; radius: 14
                        color: selectedLanguage === "简体中文" ? Qt.rgba(0/255, 212/255, 255/255, 0.12) : Qt.rgba(255/255, 255/255, 255/255, 0.03)
                        border.color: selectedLanguage === "简体中文" ? Qt.rgba(0/255, 212/255, 255/255, 0.15) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        border.width: 1

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Text { text: "🇨🇳"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "简体中文"; color: "#FFFFFF"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: selectedLanguage === "简体中文" ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.06)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { selectedLanguage = "简体中文"; selectedKeyboard = "拼音" }
                        }
                    }

                    // English
                    Rectangle {
                        width: 360; height: 48; radius: 14
                        color: selectedLanguage === "English" ? Qt.rgba(0/255, 212/255, 255/255, 0.12) : Qt.rgba(255/255, 255/255, 255/255, 0.03)
                        border.color: selectedLanguage === "English" ? Qt.rgba(0/255, 212/255, 255/255, 0.15) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        border.width: 1

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Text { text: "🇺🇸"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "English (US)"; color: "#FFFFFF"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: selectedLanguage === "English" ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.06)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { selectedLanguage = "English"; selectedKeyboard = "QWERTY" }
                        }
                    }

                    // 日本語
                    Rectangle {
                        width: 360; height: 48; radius: 14
                        color: selectedLanguage === "日本語" ? Qt.rgba(0/255, 212/255, 255/255, 0.12) : Qt.rgba(255/255, 255/255, 255/255, 0.03)
                        border.color: selectedLanguage === "日本語" ? Qt.rgba(0/255, 212/255, 255/255, 0.15) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        border.width: 1

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Text { text: "🇯🇵"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "日本語"; color: "#FFFFFF"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: selectedLanguage === "日本語" ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.06)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { selectedLanguage = "日本語"; selectedKeyboard = "かな" }
                        }
                    }

                    // 한국어
                    Rectangle {
                        width: 360; height: 48; radius: 14
                        color: selectedLanguage === "한국어" ? Qt.rgba(0/255, 212/255, 255/255, 0.12) : Qt.rgba(255/255, 255/255, 255/255, 0.03)
                        border.color: selectedLanguage === "한국어" ? Qt.rgba(0/255, 212/255, 255/255, 0.15) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        border.width: 1

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Text { text: "🇰🇷"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "한국어"; color: "#FFFFFF"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: selectedLanguage === "한국어" ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.06)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { selectedLanguage = "한국어"; selectedKeyboard = "두벌식" }
                        }
                    }
                }

                // Continue button
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 200; height: 44; radius: 22
                    color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
                    border.color: Qt.rgba(0/255, 212/255, 255/255, 0.12)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "继续"
                        color: "#00D4FF"; font.pixelSize: 15; font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.25)
                        onExited: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.15)
                        onClicked: currentStep = 2
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 2: Wi-Fi Setup (with real text fields + virtual keyboard)
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 2
        
        Rectangle {
            anchors.centerIn: parent
            width: 480; height: 420
            radius: 32
            color: Qt.rgba(15/255, 15/255, 32/255, 0.45)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
            border.width: 1
            
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 28
                spacing: 12
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "选择 Wi-Fi 网络"
                    color: "#FFFFFF"; font.pixelSize: 18; font.weight: Font.Bold
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "连接互联网以完成设置"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.4)
                    font.pixelSize: 12
                }
                
                // SSID input
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 36
                    text: "Wi-Fi 名称"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.3)
                    font.pixelSize: 11
                }
                
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360; height: 44; radius: 14
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
                    border.color: wifiSSIDInput.activeFocus ? Qt.rgba(0/255, 212/255, 255/255, 0.2) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                    border.width: 1
                    
                    TextInput {
                        id: wifiSSIDInput
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#FFFFFF"
                        font.pixelSize: 15
                        placeholderText: "输入 Wi-Fi 名称"
                        placeholderTextColor: Qt.rgba(255/255, 255/255, 255/255, 0.15)
                        verticalAlignment: TextInput.AlignVCenter
                        
                        onTextChanged: wifiSSID = text
                        
                        // Click to focus → shows virtual keyboard automatically
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: wifiSSIDInput.forceActiveFocus()
                        }
                    }
                }
                
                // Password input
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 36
                    text: "密码"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.3)
                    font.pixelSize: 11
                }
                
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360; height: 44; radius: 14
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
                    border.color: wifiPassInput.activeFocus ? Qt.rgba(0/255, 212/255, 255/255, 0.2) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                    border.width: 1
                    
                    TextInput {
                        id: wifiPassInput
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#FFFFFF"
                        font.pixelSize: 15
                        placeholderText: "输入密码"
                        placeholderTextColor: Qt.rgba(255/255, 255/255, 255/255, 0.15)
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        verticalAlignment: TextInput.AlignVCenter
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: wifiPassInput.forceActiveFocus()
                        }
                    }
                }
                
                // Buttons
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    
                    Rectangle {
                        width: 160; height: 44; radius: 22
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
                        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04); border.width: 1
                        Text { anchors.centerIn: parent; text: "跳过"; color: "#8888A0"; font.pixelSize: 14 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: currentStep = 4
                        }
                    }
                    
                    Rectangle {
                        width: 160; height: 44; radius: 22
                        color: wifiNextBtn.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.25) : Qt.rgba(0/255, 212/255, 255/255, 0.15)
                        border.color: Qt.rgba(0/255, 212/255, 255/255, 0.12); border.width: 1
                        Text { anchors.centerIn: parent; text: "下一步"; color: "#00D4FF"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea {
                            id: wifiNextBtn; anchors.fill: parent; hoverEnabled: true
                            onClicked: currentStep = 4
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 3: Create Account
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 3

        Rectangle {
            anchors.centerIn: parent
            width: 520; height: 480
            radius: 32
            color: Qt.rgba(15/255, 15/255, 32/255, 0.5)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "创建账户"
                    color: "#FFFFFF"; font.pixelSize: 22; font.weight: Font.Medium
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "设置用户名和密码来保护您的设备"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.4)
                    font.pixelSize: 12
                    bottomPadding: 16
                }

                // Username field
                Column {
                    spacing: 6
                    Row {
                        spacing: 8
                        Text { text: "用户名"; color: Qt.rgba(255/255, 255/255, 255/255, 0.6); font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle {
                        width: 380; height: 44; radius: 12
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                        border.color: accountUsernameInput.activeFocus ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        border.width: 1
                        TextInput {
                            id: accountUsernameInput
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#FFFFFF"; font.pixelSize: 15
                            placeholderText: "yunsh"
                            placeholderTextColor: Qt.rgba(255/255, 255/255, 255/255, 0.2)
                            onTextChanged: {
                                accountUsername = text.length > 0 ? text : "yunsh"
                            }
                        }
                    }
                }

                // Password field
                Column {
                    spacing: 6
                    Row {
                        spacing: 8
                        Text { text: "密码"; color: Qt.rgba(255/255, 255/255, 255/255, 0.6); font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle {
                        width: 380; height: 44; radius: 12
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                        border.color: accountPassInput.activeFocus ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        border.width: 1
                        TextInput {
                            id: accountPassInput
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#FFFFFF"; font.pixelSize: 15
                            echoMode: TextInput.Password
                            placeholderText: "输入密码"
                            placeholderTextColor: Qt.rgba(255/255, 255/255, 255/255, 0.2)
                            onTextChanged: accountPassword = text
                        }
                    }
                }

                // Confirm password field
                Column {
                    spacing: 6
                    Row {
                        spacing: 8
                        Text { text: "确认密码"; color: Qt.rgba(255/255, 255/255, 255/255, 0.6); font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle {
                        width: 380; height: 44; radius: 12
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                        border.color: accountConfirmInput.activeFocus ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        border.width: 1
                        TextInput {
                            id: accountConfirmInput
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#FFFFFF"; font.pixelSize: 15
                            echoMode: TextInput.Password
                            placeholderText: "再次输入密码"
                            placeholderTextColor: Qt.rgba(255/255, 255/255, 255/255, 0.2)
                            onTextChanged: accountConfirmPassword = text
                        }
                    }
                }

                // Error message
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: accountError
                    color: "#FF4444"; font.pixelSize: 12
                    visible: accountError.length > 0
                }

                // Buttons
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Rectangle {
                        width: 160; height: 44; radius: 22
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
                        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04); border.width: 1
                        Text { anchors.centerIn: parent; text: "跳过"; color: "#8888A0"; font.pixelSize: 14 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                accountUsername = "yunsh"
                                accountPassword = "yunsh123"
                                currentStep = 4
                            }
                        }
                    }

                    Rectangle {
                        width: 160; height: 44; radius: 22
                        color: accountNextBtn.containsMouse && (accountPassword.length > 0 && accountPassword === accountConfirmPassword) ? Qt.rgba(0/255, 212/255, 255/255, 0.25) : Qt.rgba(0/255, 212/255, 255/255, 0.15)
                        border.color: Qt.rgba(0/255, 212/255, 255/255, 0.12); border.width: 1
                        Text { anchors.centerIn: parent; text: "继续"; color: (accountPassword.length > 0 && accountPassword === accountConfirmPassword) ? "#00D4FF" : "#555566"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea {
                            id: accountNextBtn; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                accountError = ""
                                if (accountPassword.length < 4) {
                                    accountError = "密码至少需要4个字符"
                                } else if (accountPassword !== accountConfirmPassword) {
                                    accountError = "两次密码不一致"
                                } else {
                                    currentStep = 4
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 4: Initializing...
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 4

        property int progressValue: 0
        property int _timerCount: 0

        Timer {
            interval: 80
            running: currentStep === 4 && progressValue < 100
            repeat: true
            onTriggered: {
                _timerCount++
                // Simulate progress: fast at first, then slow
                if (progressValue < 40) progressValue += 2
                else if (progressValue < 70) progressValue += 1
                else if (progressValue < 90) progressValue += 1
                else if (progressValue < 99) progressValue += 1

                if (progressValue >= 99) {
                    progressValue = 100
                    running = false
                    // Auto-complete after showing 100%
                    Qt.callLater(function() {
                        activationScreen.activationComplete()
                    })
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 420; height: 320
            radius: 32
            color: Qt.rgba(15/255, 15/255, 32/255, 0.5)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 24

                // Pulsing logo
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "/usr/share/yunsh/logo/logo-128.png"
                    width: 64; height: 64
                    sourceSize.width: 128; sourceSize.height: 128
                    fillMode: Image.PreserveAspectFit

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: progressValue < 100
                        OpacityAnimator { from: 0.5; to: 1.0; duration: 800 }
                        OpacityAnimator { from: 1.0; to: 0.5; duration: 800 }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "正在初始化..."
                    color: "#FFFFFF"; font.pixelSize: 20; font.weight: Font.Medium
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "正在安装应用宝和系统组件"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.4)
                    font.pixelSize: 12
                }

                // Progress bar (visionOS style)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 280; height: 6; radius: 3
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.06)

                    Rectangle {
                        width: parent.width * (progressValue / 100)
                        height: parent.height; radius: 3
                        color: "#00D4FF"

                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Status text
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: statusMessages[Math.min(_timerCount / 20, statusMessages.length - 1)]
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.2)
                    font.pixelSize: 11

                    readonly property var statusMessages: [
                        "正在准备系统环境...",
                        "正在安装应用宝...",
                        "正在配置 Waydroid...",
                        "正在下载 UI 组件...",
                        "正在优化系统...",
                        "即将完成..."
                    ]
                }
            }
        }
    }

    // ─── Keyboard shortcut ──────────────────────────
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (currentStep < 3) currentStep++
            else skipActivation()
        }
    }
}
