// YUNSH OS v1.0 - Terminal Screen
// QML-based terminal with PTY backend (like macOS Terminal)
// Long press on output → copy selected text
// Long press on input → paste

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15

Rectangle {
    id: terminalScreen
    anchors.fill: parent
    color: "#1a1a2e"
    visible: false
    z: 60

    property string terminalHost: "http://127.0.0.1:8591"
    property bool terminalReady: false

    signal backToHome()

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
                wrapMode: TextEdit.Wrap
                renderType: Text.QtRendering
                textFormat: Text.PlainText

                // Long press → copy selected text
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton | Qt.LeftButton
                    propagateComposedEvents: true

                    onPressAndHold: {
                        if (outputText.selectedText.length > 0) {
                            outputText.copy()
                            copyFeedback.start()
                        }
                    }

                    // Right click = paste into input
                    onClicked: {
                        if (mouse.button === Qt.RightButton) {
                            inputField.paste()
                            inputField.forceActiveFocus()
                        }
                        mouse.accepted = false
                    }
                }

                // Selection color
                selectionColor: Qt.rgba(0/255, 212/255, 255/255, 0.25)
                selectedTextColor: "#FFFFFF"
            }
        }

        // Copy confirmation
        Rectangle {
            id: copyFeedback
            anchors.centerIn: parent
            width: 120; height: 32; radius: 16
            color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.2)
            border.width: 1
            visible: false
            z: 10

            Text {
                anchors.centerIn: parent
                text: "已复制 ✓"
                color: "#00D4FF"
                font.pixelSize: 12
            }

            SequentialAnimation on opacity {
                id: copyFeedbackAnim
                running: false
                PropertyAction { target: copyFeedback; property: "visible"; value: true }
                PropertyAction { target: copyFeedback; property: "opacity"; value: 1 }
                PauseAnimation { duration: 800 }
                NumberAnimation { property: "opacity"; to: 0; duration: 300 }
                PropertyAction { target: copyFeedback; property: "visible"; value: false }
            }

            function start() {
                copyFeedbackAnim.restart()
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

            // Long press → paste
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                propagateComposedEvents: true

                onPressAndHold: {
                    inputField.paste()
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
    property int pollCounter: 0
    property string lastOutput: ""

    Timer {
        id: pollTimer
        interval: 150
        repeat: true
        running: terminalScreen.visible && terminalScreen.terminalReady
        onTriggered: pollOutput()
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
                if (xhr.status === 200) {
                    // Terminal is running
                }
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
                copyFeedback.start()
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
            // Also clear local text
            outputText.text = ""
            terminalScreen.lastOutput = ""
        }
    }
}
