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
    // Active local lock always takes precedence over the system agent.
    property bool locked: false
    property bool settingsVisible: false
    property bool busy: false
    property bool keyboardVisible: false
    property bool reduceMotion: false
    property string reasoningEffort: "medium"
    property bool reasoningExpanded: false
    readonly property real keyboardAvoidance: keyboardVisible && expanded ? -132 : 0
    // The top-right island is reserved for actual system-tool work.
    property bool computerOperationActive: false
    property bool computerApprovalPending: false
    property bool voiceConversationActive: false
    property bool voiceMicrophoneReady: false
    property bool voiceRecognitionReady: false
    property int voiceRequestToken: 0
    readonly property bool voiceAvailable: configured && voiceMicrophoneReady && voiceRecognitionReady
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
        if (locked)
            return
        expanded = true
        refreshStatus()
        Qt.callLater(function() { promptField.forceActiveFocus() })
    }

    function constrainPanelToViewport() {
        if (!panel || panel.width <= 0 || panel.height <= 0)
            return
        panel.x = Math.max(24, Math.min(panel.x, orbit.width - panel.width - 24))
        panel.y = Math.max(56, Math.min(panel.y, orbit.height - panel.height - 24))
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

    function copyMessage(text) {
        if (!text || !String(text).length)
            return
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/clipboard", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 1000
        xhr.send(JSON.stringify({text: String(text)}))
        toastRequested("已复制")
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
            refreshVoiceStatus()
        })
    }

    function refreshVoiceStatus() {
        request("GET", "/v1/voice/status", null, function(status, body) {
            voiceMicrophoneReady = status === 200 && body.microphone === true
            voiceRecognitionReady = status === 200 && body.recognitionReady === true
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
        request("POST", "/v1/chat", {
            message: message,
            history: history,
            reasoningEffort: reasoningEffort
        },
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
        if (busy || !voiceAvailable) {
            toastRequested("未检测到可用麦克风或中文识别组件")
            return
        }
        var requestToken = ++voiceRequestToken
        busy = true
        voiceConversationSettleTimer.stop()
        voiceConversationActive = true
        statusText = "正在聆听…"
        request("POST", "/v1/voice/listen", {approved: approved === true}, function(status, body) {
            if (requestToken !== voiceRequestToken)
                return
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

    function stopVoiceConversation() {
        voiceRequestToken++
        voiceConversationSettleTimer.stop()
        voiceConversationActive = false
        pendingApprovalId = ""
        computerApprovalPending = false
        busy = false
        statusText = configured
            ? "系统级 · " + providerDisplayName() + " · " + modelName
            : "系统级 · 等待配置 API"
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
        visible: showTrigger && !locked
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
        id: panelShadow
        x: panel.x - 12
        y: panel.y - 12 + orbit.keyboardAvoidance
        width: panel.width + 24
        height: panel.height + 24
        radius: 42
        color: Qt.rgba(0, 0, 0, 0.10)
        opacity: expanded ? 0.62 : 0
        z: 2
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {
        id: panel
        x: (orbit.width - width) / 2
        y: Math.max(56, (orbit.height - height) / 2)
        width: Math.min(620, parent.width - 100)
        height: expanded ? Math.min(600, parent.height - 120) : 0
        radius: 34
        z: 3
        visible: height > 0
        clip: true
        opacity: expanded ? 1.0 : 0
        scale: expanded ? 1 : 0.94
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.98) }
            GradientStop { position: 0.52; color: Qt.rgba(0.97, 0.995, 1, 0.95) }
            GradientStop { position: 1.0; color: Qt.rgba(0.93, 0.985, 1, 0.93) }
        }
        border.width: 1
        border.color: "#FFFFFF"

        transform: Translate {
            y: orbit.keyboardAvoidance
            Behavior on y {
                NumberAnimation {
                    duration: orbit.reduceMotion ? 0 : 280
                    easing.type: Easing.OutCubic
                }
            }
        }

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

        // The title region is a direct-manipulation handle. Interactive
        // buttons declared later remain above it and keep their own actions.
        MouseArea {
            id: panelDragArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 82
            z: 0
            cursorShape: Qt.OpenHandCursor
            preventStealing: true
            drag.target: panel
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 24
            drag.maximumX: Math.max(24, orbit.width - panel.width - 24)
            drag.minimumY: 56
            drag.maximumY: Math.max(56, orbit.height - panel.height - 24)
            onPressed: cursorShape = Qt.ClosedHandCursor
            onReleased: {
                cursorShape = Qt.OpenHandCursor
                orbit.constrainPanelToViewport()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    visible: settingsVisible
                    text: "‹ 返回"
                    flat: true
                    onClicked: settingsVisible = false
                }

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
                    visible: !settingsVisible
                    text: "设置"
                    flat: true
                    onClicked: settingsVisible = true
                }
                Button {
                    text: "完成"
                    flat: true
                    onClicked: {
                        if (voiceConversationActive)
                            stopVoiceConversation()
                        expanded = false
                        settingsVisible = false
                    }
                }
                Button {
                    visible: !settingsVisible && voiceConversationActive
                    text: "退出语音"
                    flat: true
                    onClicked: stopVoiceConversation()
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
                                    : Qt.rgba(1, 1, 1, 0.92)
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
                                // Replies are read-only Text, so provide the
                                // same long-press copy affordance as inputs.
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    propagateComposedEvents: true
                                    onPressAndHold: orbit.copyMessage(content)
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton)
                                            orbit.copyMessage(content)
                                        mouse.accepted = false
                                    }
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: modelName
                                color: "#40515D"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Button {
                                flat: true
                                text: (reasoningEffort === "low" ? "Low"
                                    : (reasoningEffort === "high" ? "High" : "Medium"))
                                    + (reasoningExpanded ? " ︿" : " 调节")
                                onClicked: reasoningExpanded = !reasoningExpanded
                            }
                        }

                        ReasoningEffortSlider {
                            Layout.fillWidth: true
                            visible: reasoningExpanded
                            selection: orbit.reasoningEffort
                            onSelectionCommitted: function(value) {
                                orbit.reasoningEffort = value
                            }
                        }
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
                        color: Qt.rgba(1, 1, 1, 0.94)
                        border.width: 1
                        border.color: promptField.activeFocus ? "#00D4FF" : "#D7E7ED"

                        EditableInput {
                            id: promptField
                            anchors.left: microphoneButton.right
                            anchors.right: sendButton.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            anchors.rightMargin: 8
                            placeholderText: "让 Orbit 为你完成任务"
                            color: "#111820"
                            selectByMouse: true
                            enabled: !busy && !pendingApprovalId.length
                            onAccepted: sendMessage()
                        }
                        Rectangle {
                            id: microphoneButton
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 42; height: 42; radius: 21
                            visible: voiceAvailable || voiceConversationActive
                            color: micMouse.pressed
                                ? Qt.rgba(0.86, 0.97, 1, 0.92)
                                : Qt.rgba(1, 1, 1, 0.58)
                            Text {
                                anchors.centerIn: parent
                                text: voiceConversationActive ? "×" : "●"
                                color: "#00A9CC"
                                font.pixelSize: 15
                            }
                            MouseArea {
                                id: micMouse
                                anchors.fill: parent
                                enabled: voiceConversationActive || (!busy && !pendingApprovalId.length && voiceAvailable)
                                onClicked: voiceConversationActive ? stopVoiceConversation() : listenForPrompt()
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

                        EditableInput {
                            id: customModel
                            width: parent.width
                            visible: provider === "compatible"
                            placeholderText: "模型名称，例如 my-model"
                        }
                        EditableInput {
                            id: customEndpoint
                            width: parent.width
                            visible: provider === "compatible"
                            placeholderText: "HTTPS API Base URL"
                        }

                        Text {
                            text: "API Key"
                            color: "#101820"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Row {
                            width: parent.width
                            spacing: 10
                            EditableInput {
                                id: apiKeyField
                                width: parent.width - changeKeyButton.width - parent.spacing
                                placeholderText: apiKeyHint.length
                                        && provider === configuredProvider
                                    ? "已保存 " + apiKeyHint + "；输入新 Key 可替换"
                                    : "输入 API Key"
                                echoMode: TextInput.Password
                                selectByMouse: true
                            }
                            Button {
                                id: changeKeyButton
                                text: "更换"
                                onClicked: {
                                    apiKeyField.text = ""
                                    apiKeyField.forceActiveFocus()
                                }
                            }
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

    component ReasoningEffortSlider: Item {
        id: effortSlider
        property string selection: "medium"
        property real progress: selection === "low" ? 0
            : (selection === "high" ? 1 : 0.5)
        property bool dragging: false
        signal selectionCommitted(string value)
        implicitHeight: 46
        height: 46

        function updateFromPosition(position, commit) {
            var usable = Math.max(1, width - 48)
            progress = Math.max(0, Math.min(1, (position - 24) / usable))
            if (commit) {
                var index = Math.max(0, Math.min(2, Math.round(progress * 2)))
                var value = index === 0 ? "low" : (index === 2 ? "high" : "medium")
                progress = index / 2
                selectionCommitted(value)
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.62)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.88)
        }
        Rectangle {
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(32, 20 + (parent.width - 40) * effortSlider.progress)
            height: parent.height - 8
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00A8FF" }
                GradientStop { position: 1.0; color: "#0071F5" }
            }
        }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: 9; height: 9; radius: 4.5
                x: 24 + index * (effortSlider.width - 48) / 2 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: (index / 2) <= effortSlider.progress
                    ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(0.25, 0.33, 0.38, 0.32)
            }
        }
        Rectangle {
            width: 34; height: 34; radius: 17
            x: 24 + (parent.width - 48) * effortSlider.progress - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            border.width: 3
            border.color: "#007AF5"
            Behavior on x {
                enabled: !effortSlider.dragging && !orbit.reduceMotion
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) {
                effortSlider.dragging = true
                effortSlider.updateFromPosition(mouse.x, false)
            }
            onPositionChanged: function(mouse) {
                if (pressed)
                    effortSlider.updateFromPosition(mouse.x, false)
            }
            onReleased: function(mouse) {
                effortSlider.dragging = false
                effortSlider.updateFromPosition(mouse.x, true)
            }
        }
    }
}
