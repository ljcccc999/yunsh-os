// YUNSH OS v3.0.2 - touch-first activation experience.
// Physical keyboard input is never required.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

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
    property int currentStep: 0  // welcome, language, Wi-Fi, glasses, phone, account, Orbit, comfort, finish
    readonly property int totalSteps: 9

    property string selectedLanguage: "简体中文"
    property string selectedKeyboard: "拼音"
    property string wifiSSID: ""
    property string accountUsername: "YUNSH User"
    property string accountPassword: ""
    property string accountConfirmPassword: ""
    property string bootPassword: ""
    property string bootConfirmPassword: ""
    property bool accountValid: false
    property string accountError: ""
    property bool activationConfigReady: false
    property string activationConfigError: ""
    property bool wifiConnecting: false
    property bool wifiConnected: false
    property string wifiStatusText: ""
    property var glassesDevices: []
    property string selectedGlassesMac: ""
    property string selectedGlassesName: ""
    property string glassesPairingState: "ready"
    property string glassesPairingStatus: "打开眼镜并让它保持在附近"
    property int glassesPairingProgress: 0
    property bool phoneConnected: false
    property bool phoneAuthenticated: false
    property int phonePairingProgress: 0
    property string phonePairingStatus: "在 iPhone 上打开 YUNSH Link"
    property string phonePairingCode: "••••••"
    property string orbitProvider: "deepseek"
    property string orbitModel: "deepseek-v4-flash"
    property string orbitApiKey: ""
    property string orbitVoice: "sweet_female"
    property string orbitSetupError: ""
    property bool orbitSaving: false
    property int helloIndex: 0
    readonly property var helloWords: ["你好", "Hello", "Bonjour", "こんにちは", "안녕하세요"]

    function scanForGlasses() {
        if (glassesPairingState === "scanning" || glassesPairingState === "pairing")
            return
        glassesPairingState = "scanning"
        glassesPairingProgress = 18
        glassesPairingStatus = "正在搜索附近的 YUNSH 眼镜…"
        glassesDevices = []
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/bluetooth", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 18000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var response = JSON.parse(xhr.responseText)
                var found = response.devices || []
                var matching = []
                for (var i = 0; i < found.length; i++) {
                    var name = String(found[i].name || "")
                    if (name.indexOf("YUNSH V1") === 0)
                        matching.push(found[i])
                }
                glassesDevices = matching
                glassesPairingProgress = matching.length > 0 ? 45 : 0
                glassesPairingState = matching.length > 0 ? "found" : "notFound"
                glassesPairingStatus = matching.length > 0
                    ? "已找到 " + matching.length + " 台眼镜，请选择并配对"
                    : "没有找到眼镜，请确认眼镜已开机"
            } catch (error) {
                glassesPairingState = "error"
                glassesPairingProgress = 0
                glassesPairingStatus = "暂时无法搜索，请重试或跳过"
            }
        }
        xhr.send(JSON.stringify({command: "scan", timeout: 8}))
    }

    function pairSelectedGlasses() {
        if (!selectedGlassesMac || glassesPairingState === "pairing")
            return
        glassesPairingState = "pairing"
        glassesPairingProgress = 62
        glassesPairingStatus = "正在建立安全配对…"
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/bluetooth", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 30000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var response = JSON.parse(xhr.responseText)
                if (response.success || response.paired) {
                    glassesPairingProgress = 100
                    glassesPairingState = "paired"
                    glassesPairingStatus = "配对完成，YUNSH OS 会记住这副眼镜"
                } else {
                    glassesPairingProgress = 45
                    glassesPairingState = "error"
                    glassesPairingStatus = response.error || response.message || "配对失败，请重试"
                }
            } catch (error) {
                glassesPairingProgress = 45
                glassesPairingState = "error"
                glassesPairingStatus = "配对服务没有响应，请重试或跳过"
            }
        }
        xhr.send(JSON.stringify({command: "pair", mac: selectedGlassesMac}))
    }

    function requestPhonePairingCode() {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/link-pairing", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 1200
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var data = JSON.parse(xhr.responseText)
                phonePairingCode = data.success ? data.code : "暂不可用"
            } catch (error) {
                phonePairingCode = "暂不可用"
            }
        }
        xhr.send(JSON.stringify({action: "new_code"}))
    }

    function applyActivationConfiguration() {
        activationConfigReady = false
        activationConfigError = ""
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 15000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                try {
                    var response = JSON.parse(xhr.responseText)
                    activationConfigReady = response.success === true
                    activationConfigError = response.success ? "" : (response.error || "配置失败")
                } catch(e) {
                    activationConfigError = "无法保存激活设置"
                }
            }
        }
        xhr.send(JSON.stringify({
            action: "configure_activation",
            language: selectedLanguage,
            keyboard: selectedKeyboard,
            displayName: accountUsername,
            password: accountPassword,
            bootPassword: bootPassword
        }))
    }

    function saveOrbitConfiguration() {
        if (!orbitApiKey.length) {
            orbitSetupError = "请输入 API Key，或选择稍后设置"
            return
        }
        orbitSaving = true
        orbitSetupError = ""
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8597/v1/config", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 15000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            orbitSaving = false
            try {
                var response = JSON.parse(xhr.responseText || "{}")
                if (xhr.status === 200 && response.success) {
                    currentStep = 7
                } else {
                    orbitSetupError = response.error || "Orbit 配置保存失败"
                }
            } catch (error) {
                orbitSetupError = "Orbit 运行时仍在启动，可稍后设置"
            }
        }
        xhr.send(JSON.stringify({
            provider: orbitProvider,
            model: orbitModel,
            apiKey: orbitApiKey,
            voice: orbitVoice,
            speakResponses: true,
            permissions: {
                apps: true, files: true, shell: true, settings: true,
                network: true, screen: true, microphone: true,
                memory: true, world: true
            }
        }))
    }

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

    Timer {
        interval: 1050
        running: currentStep === 0
        repeat: true
        onTriggered: helloIndex = (helloIndex + 1) % helloWords.length
    }

    Timer {
        interval: 1000
        running: currentStep === 4
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", "http://127.0.0.1:8591/api/link-status", true)
            xhr.timeout = 800
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE)
                    return
                try {
                    var data = JSON.parse(xhr.responseText)
                    phoneAuthenticated = data.authenticated === true
                    phoneConnected = data.connected === true || phoneAuthenticated
                    phonePairingProgress = phoneAuthenticated ? 100 : Math.min(78, phonePairingProgress + 7)
                    phonePairingStatus = phoneAuthenticated
                        ? "手机已验证，请在 Pi 上点击“继续”"
                        : "正在等待 YUNSH Link 连接…"
                } catch (error) {
                    phonePairingStatus = "等待连接服务启动，可稍后重试或跳过"
                }
            }
            xhr.send()
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 0: Welcome Page
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 0

        // White floating glass: the black canvas stays transparent on the
        // glasses, while the welcome surface remains bright and legible.
        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 14
            width: 536; height: 468
            radius: 38
            color: Qt.rgba(0.20, 0.62, 0.78, 0.13)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
        }

        Rectangle {
            anchors.centerIn: parent
            width: 520; height: 460
            radius: 36
            color: Qt.rgba(1, 1, 1, 0.88)
            border.color: Qt.rgba(1, 1, 1, 0.96)
            border.width: 1

            // Top highlight glow
            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: parent.height * 0.4
                radius: 36
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.76) }
                    GradientStop { position: 0.58; color: Qt.rgba(0.88, 0.97, 1, 0.42) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
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
                    text: helloWords[helloIndex]
                    color: "#10202A"
                    font.pixelSize: 48
                    font.weight: Font.Light
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Hello  Bonjour  こんにちは  안녕하세요"
                    color: Qt.rgba(16/255, 32/255, 42/255, 0.42)
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "欢迎使用 YUNSH OS"
                    color: Qt.rgba(16/255, 32/255, 42/255, 0.68)
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                // Version
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "v3.0.2"
                    color: Qt.rgba(16/255, 32/255, 42/255, 0.28)
                    font.pixelSize: 11
                }

                // "继续" button (capsule style)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 200; height: 48; radius: 24
                    color: "#00D4FF"
                    border.color: "#7BE7FF"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "继续"
                        color: "#00151B"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = "#45E1FF"
                        onExited: parent.color = "#00D4FF"
                        onClicked: currentStep = 1
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "全程可使用触控、眼镜指针或 YUNSH Link 操作"
                    color: Qt.rgba(16/255, 32/255, 42/255, 0.48)
                    font.pixelSize: 10
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
            color: Qt.rgba(248/255, 252/255, 255/255, 0.90)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.92)
            border.width: 1

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 28
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "语言 Language"
                    color: "#101820"
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
                        color: selectedLanguage === "简体中文" ? Qt.rgba(210/255, 247/255, 255/255, 0.86) : Qt.rgba(255/255, 255/255, 255/255, 0.60)
                        border.color: selectedLanguage === "简体中文" ? Qt.rgba(0/255, 142/255, 170/255, 0.42) : Qt.rgba(255/255, 255/255, 255/255, 0.84)
                        border.width: 1

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Text { text: "🇨🇳"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "简体中文"; color: "#17212A"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: selectedLanguage === "简体中文" ? "#00D4FF" : Qt.rgba(70/255, 88/255, 102/255, 0.18)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { selectedLanguage = "简体中文"; selectedKeyboard = "拼音" }
                        }
                    }

                    // English
                    Rectangle {
                        width: 360; height: 48; radius: 14
                        color: selectedLanguage === "English" ? Qt.rgba(210/255, 247/255, 255/255, 0.86) : Qt.rgba(255/255, 255/255, 255/255, 0.60)
                        border.color: selectedLanguage === "English" ? Qt.rgba(0/255, 142/255, 170/255, 0.42) : Qt.rgba(255/255, 255/255, 255/255, 0.84)
                        border.width: 1

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Text { text: "🇺🇸"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "English (US)"; color: "#17212A"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: selectedLanguage === "English" ? "#00D4FF" : Qt.rgba(70/255, 88/255, 102/255, 0.18)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { selectedLanguage = "English"; selectedKeyboard = "QWERTY" }
                        }
                    }

                    // 日本語
                    Rectangle {
                        width: 360; height: 48; radius: 14
                        color: selectedLanguage === "日本語" ? Qt.rgba(210/255, 247/255, 255/255, 0.86) : Qt.rgba(255/255, 255/255, 255/255, 0.60)
                        border.color: selectedLanguage === "日本語" ? Qt.rgba(0/255, 142/255, 170/255, 0.42) : Qt.rgba(255/255, 255/255, 255/255, 0.84)
                        border.width: 1

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Text { text: "🇯🇵"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "日本語"; color: "#17212A"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: selectedLanguage === "日本語" ? "#00D4FF" : Qt.rgba(70/255, 88/255, 102/255, 0.18)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { selectedLanguage = "日本語"; selectedKeyboard = "かな" }
                        }
                    }

                    // 한국어
                    Rectangle {
                        width: 360; height: 48; radius: 14
                        color: selectedLanguage === "한국어" ? Qt.rgba(210/255, 247/255, 255/255, 0.86) : Qt.rgba(255/255, 255/255, 255/255, 0.60)
                        border.color: selectedLanguage === "한국어" ? Qt.rgba(0/255, 142/255, 170/255, 0.42) : Qt.rgba(255/255, 255/255, 255/255, 0.84)
                        border.width: 1

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Text { text: "🇰🇷"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "한국어"; color: "#17212A"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: selectedLanguage === "한국어" ? "#00D4FF" : Qt.rgba(70/255, 88/255, 102/255, 0.18)
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
                    color: "#00D4FF"
                    border.color: "#7BE7FF"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "继续"
                        color: "#00151B"; font.pixelSize: 15; font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = "#45E1FF"
                        onExited: parent.color = "#00D4FF"
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
            color: Qt.rgba(248/255, 252/255, 255/255, 0.90)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.92)
            border.width: 1
            
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 28
                spacing: 12
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "选择 Wi-Fi 网络"
                    color: "#101820"; font.pixelSize: 18; font.weight: Font.Bold
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "连接互联网以完成设置"
                    color: "#61707C"
                    font.pixelSize: 12
                }
                
                // SSID input
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 36
                    text: "Wi-Fi 名称"
                    color: "#52616C"
                    font.pixelSize: 11
                }
                
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360; height: 44; radius: 14
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.66)
                    border.color: wifiSSIDInput.activeFocus ? Qt.rgba(0/255, 142/255, 170/255, 0.50) : Qt.rgba(255/255, 255/255, 255/255, 0.86)
                    border.width: 1
                    
                    EditableInput {
                        id: wifiSSIDInput
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#17212A"
                        font.pixelSize: 15
                        placeholderText: "输入 Wi-Fi 名称"
                        placeholderTextColor: Qt.rgba(23/255, 33/255, 42/255, 0.36)
                        verticalAlignment: TextInput.AlignVCenter
                        
                        onTextChanged: wifiSSID = text
                    }
                }
                
                // Password input
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 36
                    text: "密码"
                    color: "#52616C"
                    font.pixelSize: 11
                }
                
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360; height: 44; radius: 14
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.66)
                    border.color: wifiPassInput.activeFocus ? Qt.rgba(0/255, 142/255, 170/255, 0.50) : Qt.rgba(255/255, 255/255, 255/255, 0.86)
                    border.width: 1
                    
                    EditableInput {
                        id: wifiPassInput
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#17212A"
                        font.pixelSize: 15
                        placeholderText: "输入密码"
                        placeholderTextColor: Qt.rgba(23/255, 33/255, 42/255, 0.36)
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        verticalAlignment: TextInput.AlignVCenter
                    }
                }
                
                // Buttons
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    
                    Rectangle {
                        width: 160; height: 44; radius: 22
                        color: "#00D4FF"
                        border.color: "#7BE7FF"; border.width: 1
                        Text { anchors.centerIn: parent; text: "跳过"; color: "#00151B"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: currentStep = 3
                        }
                    }
                    
                    Rectangle {
                        width: 160; height: 44; radius: 22
                        color: wifiNextBtn.containsMouse ? "#45E1FF" : "#00D4FF"
                        border.color: "#7BE7FF"; border.width: 1
                        Text { anchors.centerIn: parent; text: "下一步"; color: "#00151B"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea {
                            id: wifiNextBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (wifiConnecting) return
                                if (wifiSSIDInput.text.length > 0) {
                                    wifiConnecting = true
                                    wifiStatusText = "正在连接..."

                                    var xhr = new XMLHttpRequest()
                                    xhr.open("POST", "http://127.0.0.1:8591/", true)
                                    xhr.setRequestHeader("Content-Type", "application/json")
                                    xhr.timeout = 10000
                                    xhr.onreadystatechange = function() {
                                        if (xhr.readyState === XMLHttpRequest.DONE) {
                                            wifiConnecting = false
                                            try {
                                                var resp = JSON.parse(xhr.responseText)
                                                if (resp.success) {
                                                    wifiConnected = true
                                                    wifiStatusText = "已连接: " + wifiSSIDInput.text
                                                    Qt.callLater(function() { currentStep = 3 })
                                                } else {
                                                    wifiStatusText = "连接失败: " + (resp.error || "未知错误")
                                                }
                                            } catch(e) {
                                                wifiStatusText = "连接失败 — 已跳过"
                                                Qt.callLater(function() { currentStep = 3 })
                                            }
                                        }
                                    }
                                    xhr.send(JSON.stringify({
                                        action: "connect_wifi",
                                        ssid: wifiSSIDInput.text,
                                        password: wifiPassInput.text
                                    }))
                                } else {
                                    currentStep = 3
                                }
                            }
                        }
                    }
                }

                // Wi-Fi connection status
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: wifiStatusText
                    color: wifiConnected ? "#66BB6A" : "#FF8A65"
                    font.pixelSize: 12
                    visible: wifiStatusText.length > 0
                }
            }
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 3: Optional glasses pairing
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 3

        onVisibleChanged: {
            if (visible && glassesPairingState === "ready")
                scanForGlasses()
        }

        Rectangle {
            anchors.centerIn: parent
            width: 560
            height: 500
            radius: 34
            color: Qt.rgba(248/255, 252/255, 255/255, 0.88)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.75)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 15

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "连接你的 YUNSH 眼镜"
                    color: "#10131A"
                    font.pixelSize: 25
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 470
                    text: "配对后可使用 3DoF 头部追踪、亮度和电量状态。此步骤可以跳过，稍后也能在蓝牙设置中完成。"
                    color: "#59616E"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.25
                }

                Rectangle {
                    width: parent.width
                    height: 7
                    radius: 4
                    color: "#DDE7ED"
                    Rectangle {
                        width: parent.width * glassesPairingProgress / 100
                        height: parent.height
                        radius: 4
                        color: "#00D4FF"
                        Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    width: parent.width
                    text: glassesPairingStatus
                    color: glassesPairingState === "error" ? "#C43D4A" : "#237489"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }

                ScrollView {
                    width: parent.width
                    height: 190
                    clip: true

                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            width: parent.width
                            visible: glassesDevices.length === 0
                            text: glassesPairingState === "scanning"
                                ? "正在扫描附近设备…"
                                : "附近还没有可选择的 YUNSH 眼镜"
                            color: "#75808D"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 56
                        }

                        Repeater {
                            model: glassesDevices
                            Rectangle {
                                required property var modelData
                                width: parent.width
                                height: 64
                                radius: 18
                                color: selectedGlassesMac === modelData.mac ? "#DDF8FF" : "#FFFFFF"
                                border.width: 1
                                border.color: selectedGlassesMac === modelData.mac ? "#00D4FF" : "#DCE8EE"

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 13
                                    spacing: 12
                                    Rectangle {
                                        width: 38; height: 38; radius: 12
                                        color: "#E5FAFF"
                                        Text { anchors.centerIn: parent; text: "⌁"; color: "#00AACA"; font.pixelSize: 22 }
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 100
                                        Text { width: parent.width; text: modelData.name || "YUNSH V1 (Glasses)"; color: "#151922"; font.pixelSize: 14; font.weight: Font.Medium; elide: Text.ElideRight }
                                        Text { text: modelData.paired ? "已配对，可重新连接" : "可配对"; color: "#697582"; font.pixelSize: 11 }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: selectedGlassesMac === modelData.mac ? "✓" : ""
                                        color: "#00AACA"
                                        font.pixelSize: 19
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selectedGlassesMac = modelData.mac
                                        selectedGlassesName = modelData.name || "YUNSH V1 (Glasses)"
                                        glassesPairingStatus = "已选择 " + selectedGlassesName
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Rectangle {
                        width: 145; height: 44; radius: 22
                        color: "#00D4FF"
                        Text { anchors.centerIn: parent; text: "重新搜索"; color: "#00151B"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea { anchors.fill: parent; enabled: glassesPairingState !== "pairing"; onClicked: scanForGlasses() }
                    }
                    Rectangle {
                        width: 145; height: 44; radius: 22
                        color: "#00D4FF"
                        opacity: selectedGlassesMac.length > 0 && glassesPairingState !== "pairing" ? 1 : 0.42
                        Text {
                            anchors.centerIn: parent
                            text: glassesPairingState === "pairing" ? "配对中…" : "配对"
                            color: "#00151B"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: selectedGlassesMac.length > 0 && glassesPairingState !== "pairing"
                            onClicked: pairSelectedGlasses()
                        }
                    }
                    Rectangle {
                        width: 145; height: 44; radius: 22
                        color: "#00D4FF"
                        Text {
                            anchors.centerIn: parent
                            text: glassesPairingState === "paired" ? "继续" : "跳过"
                            color: "#00151B"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        MouseArea { anchors.fill: parent; onClicked: currentStep = 4 }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 4: Optional iPhone / YUNSH Link pairing
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 4

        onVisibleChanged: {
            if (visible) {
                phoneConnected = false
                phoneAuthenticated = false
                phonePairingProgress = 20
                phonePairingStatus = "在 YUNSH Link 输入下方的一次性密钥"
                requestPhonePairingCode()
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 540; height: 590; radius: 34
            color: Qt.rgba(248/255, 252/255, 255/255, 0.90)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.78)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 34
                spacing: 18

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 82; height: 82; radius: 25
                    color: "#E1F9FF"
                    Text { anchors.centerIn: parent; text: "◉"; color: "#00AFCF"; font.pixelSize: 42 }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "连接 iPhone"
                    color: "#10131A"
                    font.pixelSize: 25
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 450
                    text: "请先在 iPhone 下载并打开 YUNSH Link，再选择“YUNSH OS 模式”并连接 YUNSH V1，然后输入眼镜中显示的一次性密钥。无需二维码。"
                    color: "#59616E"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "未安装？请通过 YUNSH 官方安装页或当前 TestFlight 获取 YUNSH Link"
                    color: "#008DA8"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                Rectangle {
                    width: parent.width; height: 8; radius: 4
                    color: "#DDE7ED"
                    Rectangle {
                        width: parent.width * phonePairingProgress / 100
                        height: parent.height; radius: 4
                        color: "#00D4FF"
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    width: parent.width
                    text: phonePairingStatus
                    color: phoneAuthenticated ? "#14865D" : "#237489"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: parent.width
                    height: 84
                    radius: 20
                    color: "#FFFFFF"
                    border.width: 1
                    border.color: "#DCE8EE"
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: phoneAuthenticated ? "✓ 手机已验证" : phonePairingCode
                            color: "#00AFCF"
                            font.pixelSize: phoneAuthenticated ? 17 : 31
                            font.weight: Font.Bold
                            font.letterSpacing: phoneAuthenticated ? 0 : 7
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: phoneAuthenticated ? "首次验证已完成，后续自动恢复连接" : "10 分钟有效 · 仅在 YUNSH Link 中输入"
                            color: "#64717D"
                            font.pixelSize: 11
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Rectangle {
                        width: 190; height: 46; radius: 23
                        color: "#00D4FF"
                        Text { anchors.centerIn: parent; text: "跳过"; color: "#00151B"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea { anchors.fill: parent; onClicked: currentStep = 5 }
                    }
                    Rectangle {
                        width: 190; height: 46; radius: 23
                        color: "#00D4FF"
                        opacity: phoneAuthenticated ? 1 : 0.42
                        Text { anchors.centerIn: parent; text: phoneAuthenticated ? "继续" : "等待手机验证"; color: "#00151B"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea { anchors.fill: parent; enabled: phoneAuthenticated; onClicked: currentStep = 5 }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 5: Create Account
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 5

        Rectangle {
            anchors.centerIn: parent
            width: 560; height: 650
            radius: 32
            color: Qt.rgba(248/255, 252/255, 255/255, 0.92)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.94)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "创建本地 YUNSH 账户"
                    color: "#101820"; font.pixelSize: 22; font.weight: Font.Medium
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "YUNSH 账户密码与本机锁定密码完全独立；默认自动熄屏可直接唤醒"
                    color: "#61707C"
                    font.pixelSize: 12
                    bottomPadding: 16
                }

                // Username field
                Column {
                    spacing: 6
                    Row {
                        spacing: 8
                        Text { text: "用户名"; color: "#52616C"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle {
                        width: 380; height: 44; radius: 12
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.68)
                        border.color: accountUsernameInput.activeFocus ? "#00AFCF" : Qt.rgba(255/255, 255/255, 255/255, 0.88)
                        border.width: 1
                        EditableInput {
                            id: accountUsernameInput
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#17212A"; font.pixelSize: 15
                            placeholderText: "你的显示名称"
                            text: "YUNSH User"
                            placeholderTextColor: Qt.rgba(23/255, 33/255, 42/255, 0.36)
                            onTextChanged: {
                                accountUsername = text
                            }
                        }
                    }
                }

                Column {
                    spacing: 6
                    Text { text: "本机开机与锁屏密码"; color: "#52616C"; font.pixelSize: 12 }
                    Rectangle {
                        width: 380; height: 44; radius: 12
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.68)
                        border.color: bootPassInput.activeFocus ? "#00AFCF" : Qt.rgba(255/255, 255/255, 255/255, 0.88)
                        border.width: 1
                        EditableInput {
                            id: bootPassInput
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#17212A"; font.pixelSize: 15
                            echoMode: TextInput.Password
                            placeholderText: "输入独立的本机密码"
                            placeholderTextColor: Qt.rgba(23/255, 33/255, 42/255, 0.36)
                            onTextChanged: bootPassword = text
                        }
                    }
                }

                Column {
                    spacing: 6
                    Text { text: "确认本机密码"; color: "#52616C"; font.pixelSize: 12 }
                    Rectangle {
                        width: 380; height: 44; radius: 12
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.68)
                        border.color: bootConfirmInput.activeFocus ? "#00AFCF" : Qt.rgba(255/255, 255/255, 255/255, 0.88)
                        border.width: 1
                        EditableInput {
                            id: bootConfirmInput
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#17212A"; font.pixelSize: 15
                            echoMode: TextInput.Password
                            placeholderText: "再次输入本机密码"
                            placeholderTextColor: Qt.rgba(23/255, 33/255, 42/255, 0.36)
                            onTextChanged: bootConfirmPassword = text
                        }
                    }
                }

                // Password field
                Column {
                    spacing: 6
                    Row {
                        spacing: 8
                        Text { text: "YUNSH 账户密码"; color: "#52616C"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle {
                        width: 380; height: 44; radius: 12
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.68)
                        border.color: accountPassInput.activeFocus ? "#00AFCF" : Qt.rgba(255/255, 255/255, 255/255, 0.88)
                        border.width: 1
                        EditableInput {
                            id: accountPassInput
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#17212A"; font.pixelSize: 15
                            echoMode: TextInput.Password
                            placeholderText: "输入 YUNSH 账户密码"
                            placeholderTextColor: Qt.rgba(23/255, 33/255, 42/255, 0.36)
                            onTextChanged: accountPassword = text
                        }
                    }
                }

                // Confirm password field
                Column {
                    spacing: 6
                    Row {
                        spacing: 8
                        Text { text: "确认 YUNSH 账户密码"; color: "#52616C"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle {
                        width: 380; height: 44; radius: 12
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.68)
                        border.color: accountConfirmInput.activeFocus ? "#00AFCF" : Qt.rgba(255/255, 255/255, 255/255, 0.88)
                        border.width: 1
                        EditableInput {
                            id: accountConfirmInput
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#17212A"; font.pixelSize: 15
                            echoMode: TextInput.Password
                            placeholderText: "再次输入 YUNSH 账户密码"
                            placeholderTextColor: Qt.rgba(23/255, 33/255, 42/255, 0.36)
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
                        color: "#00D4FF"
                        border.color: "#7BE7FF"; border.width: 1
                        Text { anchors.centerIn: parent; text: "跳过"; color: "#00151B"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                accountUsername = "YUNSH User"
                                accountPassword = ""
                                accountConfirmPassword = ""
                                bootPassword = ""
                                bootConfirmPassword = ""
                                currentStep = 6
                            }
                        }
                    }

                    Rectangle {
                        width: 160; height: 44; radius: 22
                        color: "#00D4FF"
                        opacity: accountPassword.length > 0 && accountPassword === accountConfirmPassword && bootPassword.length > 0 && bootPassword === bootConfirmPassword ? 1 : 0.42
                        border.color: "#7BE7FF"; border.width: 1
                        Text { anchors.centerIn: parent; text: "继续"; color: "#00151B"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea {
                            id: accountNextBtn; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                accountError = ""
                                if (accountUsername.trim().length < 1) {
                                    accountError = "请输入显示名称"
                                } else if (accountPassword.length < 4) {
                                    accountError = "密码至少需要4个字符"
                                } else if (accountPassword !== accountConfirmPassword) {
                                    accountError = "两次密码不一致"
                                } else if (bootPassword.length < 4) {
                                    accountError = "本机密码至少需要4个字符"
                                } else if (bootPassword !== bootConfirmPassword) {
                                    accountError = "两次本机密码不一致"
                                } else {
                                    currentStep = 6
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 6: Optional Orbit setup
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 6

        Rectangle {
            anchors.centerIn: parent
            width: 610; height: 690; radius: 36
            color: Qt.rgba(249/255, 253/255, 1, 0.95)
            border.width: 1
            border.color: "#FFFFFF"

            Column {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 8

                OrbitGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 54; height: 54
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "设置 Orbit"
                    color: "#101820"
                    font.pixelSize: 27
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: "Orbit 是系统级 Agent，会在每次开机自动运行。依次选择 API 提供商、模型版本，再输入你自己的 API Key。"
                    color: "#5F6D78"
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.3
                }

                Text { text: "API 提供商"; color: "#26333D"; font.pixelSize: 12; font.weight: Font.DemiBold }
                ComboBox {
                    id: activationOrbitProvider
                    width: parent.width
                    model: ["DeepSeek", "Kimi"]
                    onActivated: {
                        orbitProvider = currentIndex === 1 ? "kimi" : "deepseek"
                        activationOrbitModel.model = currentIndex === 1
                            ? ["kimi-k3", "kimi-k2.6"]
                            : ["deepseek-v4-flash", "deepseek-v4-pro"]
                        activationOrbitModel.currentIndex = 0
                        orbitModel = String(activationOrbitModel.currentText)
                    }
                }

                Text { text: "模型版本"; color: "#26333D"; font.pixelSize: 12; font.weight: Font.DemiBold }
                ComboBox {
                    id: activationOrbitModel
                    width: parent.width
                    model: ["deepseek-v4-flash", "deepseek-v4-pro"]
                    onActivated: orbitModel = String(currentText)
                }

                Text { text: "API Key"; color: "#26333D"; font.pixelSize: 12; font.weight: Font.DemiBold }
                TextField {
                    width: parent.width
                    placeholderText: "输入该提供商的 API Key"
                    echoMode: TextInput.Password
                    selectByMouse: true
                    onTextChanged: orbitApiKey = text
                }

                Text { text: "声音"; color: "#26333D"; font.pixelSize: 12; font.weight: Font.DemiBold }
                ComboBox {
                    width: parent.width
                    model: ["甜美女声（默认）", "年轻男声"]
                    onActivated: orbitVoice = currentIndex === 1 ? "young_male" : "sweet_female"
                }

                Rectangle {
                    width: parent.width
                    height: 68
                    radius: 20
                    color: "#FFFFFF"
                    border.width: 1
                    border.color: "#DCECF1"
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "系统权限默认全部开启"
                            color: "#17222C"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "应用 · 文件 · Shell · 设置 · 网络 · 屏幕 · 记忆 · 世界层"
                            color: "#657580"
                            font.pixelSize: 10
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: orbitSetupError
                    color: "#C43D4A"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    visible: orbitSetupError.length > 0
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Rectangle {
                        width: 210; height: 46; radius: 23
                        color: "#00D4FF"
                        Text { anchors.centerIn: parent; text: "稍后设置"; color: "#00151B"; font.pixelSize: 14; font.weight: Font.Medium }
                        MouseArea { anchors.fill: parent; onClicked: currentStep = 7 }
                    }
                    Rectangle {
                        width: 210; height: 46; radius: 23
                        color: "#00D4FF"
                        opacity: orbitSaving ? 0.5 : 1
                        Text {
                            anchors.centerIn: parent
                            text: orbitSaving ? "正在连接…" : "保存并继续"
                            color: "#00151B"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !orbitSaving
                            onClicked: saveOrbitConfiguration()
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 7: Optional Comfort DNA
    // ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: currentStep === 7

        ComfortDnaScreen {
            id: activationComfortDna
            anchors.fill: parent
            onboarding: true
            onProfileApplied: currentStep = 8
            onSetupSkipped: currentStep = 8
        }
    }

    // ════════════════════════════════════════════════════
    // STEP 8: Initializing...
    // ════════════════════════════════════════════════════
    Item {
        id: initializingStep
        anchors.fill: parent
        visible: currentStep === 8

        property int progressValue: 0
        property int _timerCount: 0
        onVisibleChanged: {
            if (visible) {
                progressValue = 0
                _timerCount = 0
                applyActivationConfiguration()
            }
        }

        Timer {
            interval: 80
            running: currentStep === 8 && activationConfigReady && initializingStep.progressValue < 100
            repeat: true
            onTriggered: {
                initializingStep._timerCount++
                // Simulate progress: fast at first, then slow
                if (initializingStep.progressValue < 40) initializingStep.progressValue += 2
                else if (initializingStep.progressValue < 70) initializingStep.progressValue += 1
                else if (initializingStep.progressValue < 90) initializingStep.progressValue += 1
                else if (initializingStep.progressValue < 99) initializingStep.progressValue += 1

                if (initializingStep.progressValue >= 99) {
                    initializingStep.progressValue = 100
                    running = false
                    // Auto-complete after showing 100%
                    Qt.callLater(function() {
                        activationScreen.activationComplete()
                    })
                }
            }
        }

        Timer {
            interval: 2000
            running: currentStep === 8 && !activationConfigReady && activationConfigError.length > 0
            repeat: false
            onTriggered: applyActivationConfiguration()
        }

        Rectangle {
            anchors.centerIn: parent
            width: 420; height: 320
            radius: 32
            color: Qt.rgba(248/255, 252/255, 255/255, 0.92)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.94)
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
                        running: initializingStep.progressValue < 100
                        OpacityAnimator { from: 0.5; to: 1.0; duration: 800 }
                        OpacityAnimator { from: 1.0; to: 0.5; duration: 800 }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "正在初始化..."
                    color: "#101820"; font.pixelSize: 20; font.weight: Font.Medium
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: activationConfigError.length > 0
                        ? activationConfigError
                        : "正在保存系统设置"
                    color: activationConfigError.length > 0 ? "#B83242" : "#61707C"
                    font.pixelSize: 12
                }

                // Progress bar (visionOS style)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 280; height: 6; radius: 3
                    color: Qt.rgba(69/255, 88/255, 102/255, 0.18)

                    Rectangle {
                        width: parent.width * (initializingStep.progressValue / 100)
                        height: parent.height; radius: 3
                        color: "#00D4FF"

                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Status text
                Text {
                    id: activationStatusText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: activationStatusText.statusMessages[Math.min(
                        Math.floor(initializingStep._timerCount / 20),
                        activationStatusText.statusMessages.length - 1)]
                    color: Qt.rgba(23/255, 33/255, 42/255, 0.48)
                    font.pixelSize: 11

                    readonly property var statusMessages: [
                        "正在准备系统环境...",
                        "正在保存语言与键盘设置...",
                        "正在保护本地账户...",
                        "正在检查设备服务...",
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
            if (currentStep < 5) currentStep++
            else if (currentStep === 5) currentStep = 6
            else if (currentStep === 6) currentStep = 7
            else if (currentStep === 7) activationComfortDna.skipSetup()
            else skipActivation()
        }
    }
}
