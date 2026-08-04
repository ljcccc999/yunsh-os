// Orbit — system-level AI agent surface for YUNSH OS.
// The runtime starts at boot; this panel is a global shell surface, not an app.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: orbit
    anchors.fill: parent

    property bool expanded: false
    property bool showTrigger: false
    property bool settingsVisible: false
    property bool busy: false
    // The top-right island is reserved for actual system-tool work.
    property bool computerOperationActive: false
    property bool computerApprovalPending: false
    property bool voiceConversationActive: false
    property bool configured: false
    property string configuredProvider: ""
    property string provider: "deepseek"
    property string modelName: "deepseek-v4-flash"
    property string apiKeyHint: ""
    property string voice: "sweet_female"
    property bool speakResponses: true
    property string statusText: "正在连接系统运行时…"
    property var deepseekModels: ["deepseek-v4-flash", "deepseek-v4-pro"]
    property var kimiModels: ["kimi-k3", "kimi-k2.6"]
    property var compatibleModels: ["输入模型名称"]
    property var conversationHistory: []
    property string pendingApprovalId: ""
    property string pendingApprovalSummary: ""
    property string pendingApprovalPermission: ""
    property bool pendingApprovalAlwaysConfirm: false

    Timer {
        id: computerOperationSettleTimer
        interval: 2200
        repeat: false
        onTriggered: orbit.computerOperationActive = false
    }
    Timer {
        id: voiceConversationSettleTimer
        interval: 2200
        repeat: false
        onTriggered: orbit.voiceConversationActive = false
    }

    signal toastRequested(string message)

    function openPanel() {
        expanded = true
        refreshStatus()
        Qt.callLater(function() { promptField.forceActiveFocus() })
    }

    function currentModels() {
        if (provider === "kimi")
            return kimiModels
        if (provider === "compatible")
            return compatibleModels
        return deepseekModels
    }

    function request(method, path, payload, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open(method, "http://127.0.0.1:8597" + path, true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 80000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var body = JSON.parse(xhr.responseText || "{}")
                callback(xhr.status, body)
            } catch (error) {
                callback(xhr.status, {success: false, error: "Orbit 返回了无法识别的数据"})
            }
        }
        xhr.ontimeout = function() {
            callback(0, {success: false, error: "Orbit 请求超时"})
        }
        xhr.send(payload ? JSON.stringify(payload) : "")
    }

    function refreshStatus() {
        request("GET", "/v1/status", null, function(status, body) {
            if (status !== 200 || !body.success) {
                statusText = "运行时正在启动"
                return
            }
            configured = body.config.hasApiKey === true
            provider = body.config.provider || "deepseek"
            configuredProvider = configured ? provider : ""
            modelName = body.config.model || "deepseek-v4-flash"
            apiKeyHint = body.config.apiKeyHint || ""
            voice = body.config.voice || "sweet_female"
            speakResponses = body.config.speakResponses !== false
            voiceBox.currentIndex = voice === "young_male" ? 1 : 0
            speakToggle.checked = speakResponses
            statusText = configured
                ? "系统级 · " + providerDisplayName() + " · " + modelName
                : "系统级 · 等待配置 API"
            providerBox.currentIndex = provider === "kimi" ? 1
                : (provider === "compatible" ? 2 : 0)
            modelBox.model = currentModels()
            var modelIndex = currentModels().indexOf(modelName)
            modelBox.currentIndex = modelIndex >= 0 ? modelIndex : 0
            customModel.text = provider === "compatible" ? modelName : ""
            customEndpoint.text = provider === "compatible"
                ? (body.config.endpoint || "") : ""
            applyPermissionState(body.config.permissions || {})
        })
    }

    function providerDisplayName() {
        if (provider === "kimi")
            return "Kimi"
        if (provider === "compatible")
            return "OpenAI 兼容"
        return "DeepSeek"
    }

    function applyPermissionState(values) {
        appsPermission.checked = values.apps !== false
        filesPermission.checked = values.files !== false
        shellPermission.checked = values.shell !== false
        settingsPermission.checked = values.settings !== false
        networkPermission.checked = values.network !== false
        screenPermission.checked = values.screen !== false
        microphonePermission.checked = values.microphone !== false
        memoryPermission.checked = values.memory !== false
        worldPermission.checked = values.world !== false
    }

    function setAllPermissions(allowed) {
        appsPermission.checked = allowed
        filesPermission.checked = allowed
        shellPermission.checked = allowed
        settingsPermission.checked = allowed
        networkPermission.checked = allowed
        screenPermission.checked = allowed
        microphonePermission.checked = allowed
        memoryPermission.checked = allowed
        worldPermission.checked = allowed
    }

    function saveConfiguration() {
        var selectedModel = provider === "compatible"
            ? customModel.text.trim()
            : String(modelBox.currentText)
        if (!selectedModel.length) {
            toastRequested("请输入模型版本")
            return
        }
        if (!apiKeyField.text.length
                && (!configured || provider !== configuredProvider)) {
            toastRequested("请输入 API Key")
            return
        }
        busy = true
        request("POST", "/v1/config", {
            provider: provider,
            model: selectedModel,
            endpoint: customEndpoint.text.trim(),
            apiKey: apiKeyField.text,
            permissions: {
                apps: appsPermission.checked,
                files: filesPermission.checked,
                shell: shellPermission.checked,
                settings: settingsPermission.checked,
                network: networkPermission.checked,
                screen: screenPermission.checked,
                microphone: microphonePermission.checked,
                memory: memoryPermission.checked,
                world: worldPermission.checked
            },
            voice: voiceBox.currentIndex === 1 ? "young_male" : "sweet_female",
            speakResponses: speakToggle.checked
        }, function(status, body) {
            busy = false
            if (status !== 200 || !body.success) {
                toastRequested(body.error || "Orbit 配置保存失败")
                return
            }
            configured = body.hasApiKey === true
            configuredProvider = configured ? provider : ""
            modelName = body.model
            voice = body.voice || "sweet_female"
            speakResponses = body.speakResponses !== false
            apiKeyHint = body.apiKeyHint || ""
            apiKeyField.text = ""
            settingsVisible = false
            statusText = "系统级 · " + providerDisplayName() + " · " + modelName
            toastRequested("Orbit 已连接 " + providerDisplayName())
        })
    }

    function sendMessage() {
        var message = promptField.text.trim()
        if (!message.length || busy)
            return
        if (!configured) {
            settingsVisible = true
            toastRequested("请先配置 API 提供商")
            return
        }
        var history = conversationHistory.slice()
        conversationHistory.push({role: "user", content: message})
        messagesModel.append({role: "user", content: message})
        promptField.text = ""
        busy = true
        request("POST", "/v1/chat", {message: message, history: history},
                function(status, body) {
            busy = false
            handleAgentResponse(status, body)
        })
    }

    function handleAgentResponse(status, body) {
        if (voiceConversationActive)
            voiceConversationSettleTimer.restart()
        if (status !== 200 || !body.success) {
            appendAssistantReply("没有完成：" + (body.error || "Orbit 运行时不可用"), false)
            return
        }
        if (body.approval) {
            computerOperationSettleTimer.stop()
            computerOperationActive = true
            computerApprovalPending = true
            pendingApprovalId = body.approval.requestId || ""
            pendingApprovalSummary = body.approval.summary || "Orbit 请求一项系统权限"
            pendingApprovalPermission = body.approval.permissionLabel || "系统操作"
            pendingApprovalAlwaysConfirm = body.approval.alwaysConfirm === true
            statusText = "等待你的授权"
            return
        }
        if (Array.isArray(body.tools) && body.tools.length > 0) {
            computerOperationActive = true
            computerOperationSettleTimer.restart()
        }
        pendingApprovalId = ""
        computerApprovalPending = false
        pendingApprovalSummary = ""
        appendAssistantReply(body.reply || "任务已完成。", true)
    }

    function appendAssistantReply(reply, speak) {
        conversationHistory.push({role: "assistant", content: reply})
        if (conversationHistory.length > 24)
            conversationHistory = conversationHistory.slice(-24)
        messagesModel.append({role: "assistant", content: reply})
        messageList.positionViewAtEnd()
        statusText = configured
            ? "系统级 · " + providerDisplayName() + " · " + modelName
            : "系统级 · 等待配置 API"
        if (speak && speakResponses)
            request("POST", "/v1/voice/speak", {text: reply, voice: voice},
                    function(_voiceStatus, _voiceBody) {})
    }

    function respondToApproval(decision) {
        if (!pendingApprovalId.length || busy)
            return
        if (pendingApprovalId === "voice") {
            pendingApprovalId = ""
            computerApprovalPending = false
            if (decision === "deny") {
                voiceConversationSettleTimer.stop()
                voiceConversationActive = false
                statusText = configured
                    ? "系统级 · " + providerDisplayName() + " · " + modelName
                    : "系统级 · 等待配置 API"
                return
            }
            if (decision === "always") {
                busy = true
                request("POST", "/v1/permissions/grant",
                        {name: "voice_listen"}, function(status, body) {
                    busy = false
                    if (status !== 200 || !body.success) {
                        toastRequested(body.error || "无法保存麦克风授权")
                        return
                    }
                    listenForPrompt(true)
                })
            } else {
                listenForPrompt(true)
            }
            return
        }
        busy = true
        computerOperationActive = true
        computerOperationSettleTimer.stop()
        var requestId = pendingApprovalId
        pendingApprovalId = ""
        computerApprovalPending = false
        request("POST", "/v1/approve", {
            requestId: requestId,
            decision: decision
        }, function(status, body) {
            busy = false
            handleAgentResponse(status, body)
        })
    }

    function listenForPrompt(approved) {
        if (busy)
            return
        busy = true
        voiceConversationSettleTimer.stop()
        voiceConversationActive = true
        statusText = "正在聆听…"
        request("POST", "/v1/voice/listen", {approved: approved === true}, function(status, body) {
            busy = false
            refreshStatus()
            if (body.approvalRequired) {
                pendingApprovalId = "voice"
                pendingApprovalSummary = body.summary || "允许 Orbit 使用麦克风"
                pendingApprovalPermission = body.permissionLabel || "麦克风"
                pendingApprovalAlwaysConfirm = false
                statusText = "等待你的授权"
                return
            }
            if (status !== 200 || !body.success) {
                toastRequested(body.error || "语音识别不可用")
                return
            }
            promptField.text = body.text || ""
            if (promptField.text.length)
                sendMessage()
            else
                voiceConversationSettleTimer.restart()
        })
    }

    Component.onCompleted: refreshStatus()

    // Global trigger. It remains available above applications and the world.
    Rectangle {
        id: orbitTrigger
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: expanded ? 38 : 24
        width: expanded ? 0 : 148
        height: expanded ? 0 : 48
        radius: 24
        z: 2
        color: triggerMouse.pressed ? Qt.rgba(0.88, 0.98, 1, 0.86) : Qt.rgba(1, 1, 1, 0.72)
        border.width: 1
        border.color: "#BDEFFF"
        opacity: expanded ? 0 : 0.94
        visible: showTrigger
        scale: triggerMouse.pressed ? 0.97 : 1

        Row {
            anchors.centerIn: parent
            spacing: 9
            OrbitGlyph { width: 30; height: 30 }
            Text {
                text: "Orbit"
                color: "#101820"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: -0.2
            }
        }

        MouseArea {
            id: triggerMouse
            anchors.fill: parent
            onClicked: {
                expanded = true
                refreshStatus()
                promptField.forceActiveFocus()
            }
        }

        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(644, parent.width - 76)
        height: expanded ? Math.min(624, parent.height - 96) : 0
        radius: 42
        color: Qt.rgba(0, 0, 0, 0.10)
        opacity: expanded ? 0.62 : 0
        z: 2
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(620, parent.width - 100)
        height: expanded ? Math.min(600, parent.height - 120) : 0
        radius: 34
        z: 3
        visible: height > 0
        clip: true
        opacity: expanded ? 0.97 : 0
        scale: expanded ? 1 : 0.94
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.86) }
            GradientStop { position: 0.52; color: Qt.rgba(0.96, 0.99, 1, 0.72) }
            GradientStop { position: 1.0; color: Qt.rgba(0.90, 0.97, 1, 0.66) }
        }
        border.width: 1
        border.color: "#FFFFFF"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.92)
            anchors.margins: 2
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            height: 1
            radius: 0.5
            color: Qt.rgba(1, 1, 1, 0.96)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                OrbitGlyph { width: 48; height: 48 }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Orbit"
                        color: "#101820"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.5
                    }
                    Text {
                        text: statusText
                        color: "#61707C"
                        font.pixelSize: 11
                    }
                }

                Button {
                    text: settingsVisible ? "对话" : "设置"
                    flat: true
                    onClicked: settingsVisible = !settingsVisible
                }
                Button {
                    text: "完成"
                    flat: true
                    onClicked: {
                        expanded = false
                        settingsVisible = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#DCEBF0"
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    visible: !settingsVisible
                    spacing: 12

                    ListView {
                        id: messageList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 10
                        model: ListModel {
                            id: messagesModel
                            ListElement {
                                role: "assistant"
                                content: "我是 Orbit。可以直接让我打开系统功能、处理文件、运行命令，或带你进入 YUNSH 世界。"
                            }
                        }
                        delegate: Item {
                            width: messageList.width
                            height: messageBubble.height
                            Rectangle {
                                id: messageBubble
                                anchors.right: role === "user" ? parent.right : undefined
                                anchors.left: role === "user" ? undefined : parent.left
                                width: Math.min(messageText.implicitWidth + 34, messageList.width * 0.82)
                                height: messageText.implicitHeight + 24
                                radius: 18
                                color: role === "user"
                                    ? Qt.rgba(0/255, 212/255, 255/255, 0.54)
                                    : Qt.rgba(1, 1, 1, 0.66)
                                border.width: role === "user" ? 0 : 1
                                border.color: "#DDECF1"
                                Text {
                                    id: messageText
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    text: content
                                    color: role === "user" ? "#00191F" : "#17212A"
                                    wrapMode: Text.Wrap
                                    font.pixelSize: 14
                                    lineHeight: 1.28
                                }
                            }
                        }
                    }

                    Text {
                        visible: busy
                        text: "Orbit 正在规划、执行并检查结果…"
                        color: "#61707C"
                        font.pixelSize: 12
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: pendingApprovalId.length ? 154 : 0
                        visible: pendingApprovalId.length > 0
                        radius: 22
                        color: "#FFF8E8"
                        border.width: 1
                        border.color: "#FFD88A"
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            Text {
                                text: "Orbit 请求权限 · " + pendingApprovalPermission
                                color: "#8A5700"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: pendingApprovalSummary
                                color: "#2C2518"
                                font.pixelSize: 13
                                wrapMode: Text.Wrap
                            }
                            Row {
                                anchors.right: parent.right
                                spacing: 8
                                Button {
                                    text: "拒绝"
                                    flat: true
                                    onClicked: respondToApproval("deny")
                                }
                                Button {
                                    text: "始终允许"
                                    visible: !pendingApprovalAlwaysConfirm
                                    flat: true
                                    onClicked: respondToApproval("always")
                                }
                                Button {
                                    text: "仅本次允许"
                                    onClicked: respondToApproval("once")
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 54
                        radius: 27
                        color: Qt.rgba(1, 1, 1, 0.66)
                        border.width: 1
                        border.color: promptField.activeFocus ? "#00D4FF" : "#D7E7ED"

                        TextField {
                            id: promptField
                            anchors.left: microphoneButton.right
                            anchors.right: sendButton.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            anchors.rightMargin: 8
                            placeholderText: "让 Orbit 为你完成任务"
                            color: "#111820"
                            background: Item {}
                            enabled: !busy && !pendingApprovalId.length
                            onAccepted: sendMessage()
                        }
                        Rectangle {
                            id: microphoneButton
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 42; height: 42; radius: 21
                            color: micMouse.pressed
                                ? Qt.rgba(0.86, 0.97, 1, 0.92)
                                : Qt.rgba(1, 1, 1, 0.58)
                            Text {
                                anchors.centerIn: parent
                                text: "●"
                                color: "#00A9CC"
                                font.pixelSize: 15
                            }
                            MouseArea {
                                id: micMouse
                                anchors.fill: parent
                                enabled: !busy && !pendingApprovalId.length
                                onClicked: listenForPrompt()
                            }
                        }
                        Rectangle {
                            id: sendButton
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 42; height: 42; radius: 21
                            color: busy ? Qt.rgba(0.55, 0.80, 0.86, 0.62)
                                : Qt.rgba(0/255, 212/255, 255/255, 0.66)
                            Text {
                                anchors.centerIn: parent
                                text: "↑"
                                color: "#00191F"
                                font.pixelSize: 20
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !busy && !pendingApprovalId.length
                                onClicked: sendMessage()
                            }
                        }
                    }
                }

                Flickable {
                    anchors.fill: parent
                    visible: settingsVisible
                    clip: true
                    contentHeight: settingsColumn.height

                    Column {
                        id: settingsColumn
                        width: parent.width
                        spacing: 14

                        Text {
                            text: "模型提供商"
                            color: "#101820"
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "依次选择提供商、模型版本，再使用你自己的 API Key。"
                            color: "#61707C"
                            font.pixelSize: 12
                        }

                        ComboBox {
                            id: providerBox
                            width: parent.width
                            model: ["DeepSeek", "Kimi", "OpenAI 兼容"]
                            onActivated: {
                                provider = currentIndex === 1 ? "kimi"
                                    : (currentIndex === 2 ? "compatible" : "deepseek")
                                modelBox.model = currentModels()
                                modelBox.currentIndex = 0
                            }
                        }

                        ComboBox {
                            id: modelBox
                            width: parent.width
                            model: deepseekModels
                            visible: provider !== "compatible"
                        }

                        TextField {
                            id: customModel
                            width: parent.width
                            visible: provider === "compatible"
                            placeholderText: "模型名称，例如 my-model"
                        }
                        TextField {
                            id: customEndpoint
                            width: parent.width
                            visible: provider === "compatible"
                            placeholderText: "HTTPS API Base URL"
                        }

                        TextField {
                            id: apiKeyField
                            width: parent.width
                            placeholderText: apiKeyHint.length
                                    && provider === configuredProvider
                                ? "已保存 " + apiKeyHint + "；留空保持不变"
                                : "输入 API Key"
                            echoMode: TextInput.Password
                            selectByMouse: true
                        }

                        Text {
                            text: "Orbit 声音"
                            color: "#101820"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            topPadding: 6
                        }
                        ComboBox {
                            id: voiceBox
                            width: parent.width
                            model: ["甜美女声（默认）", "年轻男声"]
                        }
                        CheckBox {
                            id: speakToggle
                            text: "自动朗读 Orbit 回复"
                            checked: true
                        }

                        Text {
                            text: "系统能力与权限"
                            color: "#101820"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            topPadding: 8
                        }

                        Row {
                            width: parent.width
                            spacing: 10
                            Button {
                                text: "全部允许"
                                onClicked: orbit.setAllPermissions(true)
                            }
                            Button {
                                text: "全部关闭"
                                onClicked: orbit.setAllPermissions(false)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "破坏性操作仍需本机确认"
                                color: "#61707C"
                                font.pixelSize: 11
                            }
                        }

                        Grid {
                            width: parent.width
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 2
                            CheckBox { id: appsPermission; text: "打开与管理应用"; checked: true }
                            CheckBox { id: filesPermission; text: "读取和修改文件"; checked: true }
                            CheckBox { id: shellPermission; text: "运行系统命令"; checked: true }
                            CheckBox { id: settingsPermission; text: "修改系统设置"; checked: true }
                            CheckBox { id: networkPermission; text: "访问网络"; checked: true }
                            CheckBox { id: screenPermission; text: "读取屏幕与窗口状态"; checked: true }
                            CheckBox { id: microphonePermission; text: "使用麦克风"; checked: true }
                            CheckBox { id: memoryPermission; text: "保存长期任务记忆"; checked: true }
                            CheckBox { id: worldPermission; text: "控制 YUNSH 世界层"; checked: true }
                        }

                        Rectangle {
                            width: parent.width
                            height: 52
                            radius: 26
                            color: saveMouse.pressed ? "#38DEFF" : "#00D4FF"
                            opacity: busy ? 0.55 : 1
                            Text {
                                anchors.centerIn: parent
                                text: busy ? "正在保存…" : "保存并连接"
                                color: "#00191F"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: saveMouse
                                anchors.fill: parent
                                enabled: !busy
                                onClicked: saveConfiguration()
                            }
                        }

                        Text {
                            width: parent.width
                            text: "API Key 使用设备密钥加密保存在本机。功能开启后，Orbit 第一次使用敏感能力仍会请求“仅本次”或“始终允许”；关闭功能会立即撤销对应授权。破坏性操作永远需要重新确认。"
                            color: "#71808B"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            bottomPadding: 20
                        }
                    }
                }
            }
        }

        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }
}
