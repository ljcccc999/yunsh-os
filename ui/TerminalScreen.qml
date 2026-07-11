// YUNSH OS v1.0 - Terminal Screen
// QML-based terminal with PTY backend
// iOS-style: long press to select text, show "复制/全选" popup
// Long press on input → "粘贴" popup

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15

Rectangle {
    id: terminalScreen
    anchors.fill: parent
    color: "transparent"
    visible: false
    z: 60

    property string terminalHost: "http://127.0.0.1:8591"
    property bool terminalReady: false

    signal backToHome()

    // ─── Context Popup (reusable) ────────────────
    Popup {
        id: outputPopup
        modal: false
        closePolicy: Popup.CloseOnPressOutside

        background: Rectangle {
            color: Qt.rgba(12/255, 12/255, 25/255, 0.75)
            radius: 12
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.12)
            border.width: 1

            // Frost
            Rectangle {
                anchors.fill: parent; radius: 12
                color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
            }
            // Top highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 8
                height: 1; radius: 1
                color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
            }
        }

        Row {
            spacing: 1
            padding: 4

            Repeater {
                model: outputPopup.menuModel || []

                Rectangle {
                    width: 64; height: 36
                    radius: 6
                    color: popBtn.containsMouse ?
                        Qt.rgba(0/255, 212/255, 255/255, 0.15) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: "#FFFFFF"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: popBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.action === "copy") {
                                outputText.copy()
                                showToast("已复制 ✓")
                            } else if (modelData.action === "selectAll") {
                                outputText.selectAll()
                            }
                            outputPopup.close()
                        }
                    }
                }
            }
        }
    }

    property var outputMenuModel: [
        {label: "复制", action: "copy"},
        {label: "全选", action: "selectAll"}
    ]

    Popup {
        id: inputPopup
        modal: false
        closePolicy: Popup.CloseOnPressOutside

        background: Rectangle {
            color: Qt.rgba(12/255, 12/255, 25/255, 0.75)
            radius: 12
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.12)
            border.width: 1

            // Frost
            Rectangle {
                anchors.fill: parent; radius: 12
                color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
            }
            // Top highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 8
                height: 1; radius: 1
                color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
            }
        }

        Row {
            spacing: 1
            padding: 4

            Repeater {
                model: inputPopup.menuModel || []

                Rectangle {
                    width: 64; height: 36
                    radius: 6
                    color: popBtn2.containsMouse ?
                        Qt.rgba(0/255, 212/255, 255/255, 0.15) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: "#FFFFFF"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: popBtn2
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.action === "paste") {
                                inputField.paste()
                            } else if (modelData.action === "copy") {
                                inputField.copy()
                                showToast("已复制 ✓")
                            } else if (modelData.action === "selectAll") {
                                inputField.selectAll()
                            }
                            inputPopup.close()
                        }
                    }
                }
            }
        }
    }

    property var inputMenuModel: [
        {label: "粘贴", action: "paste"},
        {label: "全选", action: "selectAll"}
    ]

    property var inputMenuFullModel: [
        {label: "粘贴", action: "paste"},
        {label: "复制", action: "copy"},
        {label: "全选", action: "selectAll"}
    ]

    // ─── Title Bar ───────────────────────────────
    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        color: Qt.rgba(12/255, 12/255, 28/255, 0.8)

        Text {
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "终端"
            color: "#FFFFFF"
            font.pixelSize: 16
            font.weight: Font.Medium
        }

        // Close button
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 8
            color: mouseClose.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.1) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: "#888"
                font.pixelSize: 14
            }

            MouseArea {
                id: mouseClose
                anchors.fill: parent
                hoverEnabled: true
                onClicked: terminalScreen.backToHome()
            }
        }

        // Bottom border
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
        }
    }

    // ─── Terminal Output Area ────────────────────
    Rectangle {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: inputBar.top
        color: "#0d0d1a"

        // Tap on empty = dismiss popups
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onPressed: {
                outputPopup.close()
                inputPopup.close()
                mouse.accepted = false
            }
        }

        Flickable {
            id: outputFlick
            anchors.fill: parent
            anchors.margins: 8
            contentHeight: outputText.height + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Scroll to bottom when content changes
            onContentHeightChanged: {
                if (contentHeight > height) {
                    contentY = contentHeight - height
                }
            }

            TextEdit {
                id: outputText
                width: outputFlick.width - 4
                text: ""
                color: "#00FF88"
                font.family: "Menlo, Courier, monospace"
                font.pixelSize: 13
                font.weight: Font.Normal
                readOnly: true
                selectByMouse: true
                selectByKeyboard: true
                wrapMode: TextEdit.Wrap
                renderType: Text.QtRendering
                textFormat: Text.PlainText

                // Selection color
                selectionColor: Qt.rgba(0/255, 212/255, 255/255, 0.25)
                selectedTextColor: "#FFFFFF"

                // iOS-style: long press → if text selected show copy menu
                // if no selection → start selection mode
                MouseArea {
                    id: outputTextArea
                    anchors.fill: parent
                    propagateComposedEvents: true

                    onPressAndHold: {
                        // Check if there's already selected text
                        if (outputText.selectedText.length > 0) {
                            // Show copy/select popup near the touch point
                            outputPopup.menuModel = outputMenuModel
                            outputPopup.x = Math.min(mouse.x, terminalScreen.width - outputPopup.width - 20)
                            outputPopup.y = Math.min(mouse.y - 50, terminalScreen.height - inputBar.height - outputPopup.height - 60)
                            outputPopup.open()
                        }
                        // If no selection yet, let the TextEdit handle selection
                        // (propagateComposedEvents passes it through)
                    }

                    // Right click → paste into input
                    onClicked: {
                        if (mouse.button === Qt.RightButton) {
                            inputField.paste()
                            inputField.forceActiveFocus()
                        }
                        mouse.accepted = false
                    }
                }

                onSelectedTextChanged: {
                    if (selectedText.length > 0) {
                        // Auto-show copy popup when text is selected (like iOS)
                        outputPopup.menuModel = outputMenuModel
                        outputPopup.x = Math.min(
                            outputFlick.contentX + outputFlick.width - outputPopup.width - 20,
                            terminalScreen.width - outputPopup.width - 20
                        )
                        outputPopup.y = Math.min(
                            outputFlick.contentY + 20,
                            terminalScreen.height - inputBar.height - outputPopup.height - 60
                        )
                        outputPopup.open()
                    } else {
                        outputPopup.close()
                    }
                }
            }
        }

        // Toast notification
        Rectangle {
            id: toast
            anchors.centerIn: parent
            width: 120; height: 32; radius: 16
            color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.2)
            border.width: 1
            visible: false
            z: 10

            Text {
                id: toastText
                anchors.centerIn: parent
                text: ""
                color: "#00D4FF"
                font.pixelSize: 12
            }

            SequentialAnimation on opacity {
                id: toastAnim
                running: false
                PropertyAction { target: toast; property: "visible"; value: true }
                PropertyAction { target: toast; property: "opacity"; value: 1 }
                PauseAnimation { duration: 800 }
                NumberAnimation { property: "opacity"; to: 0; duration: 300 }
                PropertyAction { target: toast; property: "visible"; value: false }
            }

            function show(msg) {
                toastText.text = msg
                toastAnim.restart()
            }
        }
    }

    // ─── Input Bar ───────────────────────────────
    Rectangle {
        id: inputBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        color: Qt.rgba(12/255, 12/255, 28/255, 0.8)

        // Prompt
        Text {
            id: promptText
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "$"
            color: "#00FF88"
            font.family: "Menlo, Courier, monospace"
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        // Input field
        TextField {
            id: inputField
            anchors.left: promptText.right; anchors.leftMargin: 8
            anchors.right: sendBtn.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 30
            color: "#FFFFFF"
            font.family: "Menlo, Courier, monospace"
            font.pixelSize: 13
            background: Rectangle {
                color: "transparent"
            }
            placeholderText: "输入命令..."
            placeholderTextColor: Qt.rgba(255/255, 255/255, 255/255, 0.2)

            // iOS-style: long press → paste popup
            MouseArea {
                id: inputFieldArea
                anchors.fill: parent
                propagateComposedEvents: true

                onPressAndHold: {
                    // Let go of any selection, show paste popup
                    inputPopup.menuModel = inputMenuFullModel
                    inputPopup.x = Math.min(
                        mouse.x,
                        terminalScreen.width - inputPopup.width - 20
                    )
                    inputPopup.y = parent.y - inputPopup.height - 10
                    inputPopup.open()
                }

                onPressed: {
                    // Let the TextField handle normal clicks
                    mouse.accepted = false
                }
            }

            onAccepted: {
                sendCommand(inputField.text)
                inputField.text = ""
            }
        }

        // Send button
        Rectangle {
            id: sendBtn
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 28; radius: 6
            color: sendMouse.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.15) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "↵"
                color: "#00D4FF"
                font.pixelSize: 14
            }

            MouseArea {
                id: sendMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    sendCommand(inputField.text)
                    inputField.text = ""
                    inputField.forceActiveFocus()
                }
            }
        }
    }

    // ─── Poll Timer ──────────────────────────────
    property string lastOutput: ""

    Timer {
        id: pollTimer
        interval: 150
        repeat: true
        running: terminalScreen.visible && terminalScreen.terminalReady
        onTriggered: pollOutput()
    }

    function showToast(msg) {
        toast.show(msg)
    }

    function pollOutput() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", terminalHost + "/output", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                if (xhr.responseText !== terminalScreen.lastOutput) {
                    terminalScreen.lastOutput = xhr.responseText
                    outputText.text = xhr.responseText
                }
            }
        }
        xhr.send()
    }

    function sendCommand(cmd) {
        if (!cmd || cmd.trim() === "") return
        var xhr = new XMLHttpRequest()
        xhr.open("POST", terminalHost + "/input", true)
        xhr.send(cmd + "\n")
    }

    function checkTerminalStatus() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", terminalHost + "/status", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                terminalScreen.terminalReady = true
                pollOutput()
            }
        }
        xhr.send()
    }

    function resetTerminal() {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", terminalHost + "/reset", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                terminalScreen.lastOutput = ""
                pollOutput()
            }
        }
        xhr.send()
    }

    onVisibleChanged: {
        if (visible) {
            checkTerminalStatus()
            inputField.forceActiveFocus()
        }
    }

    // Keyboard shortcuts
    Shortcut {
        sequence: "Ctrl+Shift+C"
        onActivated: {
            if (outputText.selectedText.length > 0) {
                outputText.copy()
                showToast("已复制 ✓")
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+V"
        onActivated: {
            inputField.paste()
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: terminalScreen.backToHome()
    }

    Shortcut {
        sequence: "Ctrl+L"
        onActivated: {
            sendCommand("clear")
            outputText.text = ""
            terminalScreen.lastOutput = ""
        }
    }
}
