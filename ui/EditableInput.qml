// YUNSH OS v1.0 - Editable Text Input with iOS-style Long Press Menu
// Drop-in replacement for TextInput with copy/paste/selectAll popup

import QtQuick 2.15
import QtQuick.Controls 2.15

TextInput {
    id: input

    // Qt Quick TextInput does not provide the placeholder properties exposed
    // by TextField.  Declare and render them here because this lightweight
    // component is used inside custom glass input surfaces.
    property string placeholderText: ""
    property color placeholderTextColor: Qt.rgba(23/255, 33/255, 42/255, 0.38)
    property var _menuItems: [
        {label: "粘贴", action: "paste"},
        {label: "全选", action: "selectAll"}
    ]

    function pasteWithPriority() {
        var xhr = new XMLHttpRequest()
        var completed = false
        function insertText(value) {
            if (completed) return
            completed = true
            if (value && value.length > 0) {
                var pos = input.cursorPosition
                input.text = input.text.substring(0, pos) + value + input.text.substring(pos)
                input.cursorPosition = pos + value.length
            } else {
                // Preserve Qt's native system-clipboard path when Flow has no
                // phone text or its local bridge is temporarily unavailable.
                input.paste()
            }
        }
        xhr.open("GET", "http://127.0.0.1:8591/api/clipboard", true)
        xhr.timeout = 700
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            var phoneText = ""
            try { phoneText = JSON.parse(xhr.responseText || "{}").text || "" } catch (error) {}
            insertText(phoneText)
        }
        xhr.onerror = function() { insertText("") }
        xhr.ontimeout = function() { insertText("") }
        xhr.send()
    }

    function copyWithFallback() {
        var textToCopy = input.selectedText || ""
        if (!textToCopy.length) return
        input.copy()
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/clipboard", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 700
        xhr.send(JSON.stringify({text: textToCopy}))
    }

    Text {
        anchors.fill: parent
        text: input.placeholderText
        color: input.placeholderTextColor
        font: input.font
        horizontalAlignment: input.horizontalAlignment
        verticalAlignment: input.verticalAlignment
        elide: Text.ElideRight
        visible: input.text.length === 0 && input.placeholderText.length > 0
    }

    Popup {
        id: popup
        modal: false
        closePolicy: Popup.CloseOnPressOutside
        padding: 4

        background: Rectangle {
            color: Qt.rgba(248/255, 252/255, 255/255, 0.92)
            radius: 12
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.94)
            border.width: 1

            // Frost
            Rectangle {
                anchors.fill: parent; radius: 12
                color: Qt.rgba(205/255, 239/255, 255/255, 0.12)
            }
            // Top highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 8
                height: 1; radius: 1
                color: Qt.rgba(255/255, 255/255, 255/255, 0.88)
            }
        }

        Row {
            spacing: 1
            padding: 4

            Repeater {
                model: input._menuItems

                Rectangle {
                    width: 64; height: 36
                    radius: 6
                    color: btn.containsMouse ?
                        Qt.rgba(0/255, 212/255, 255/255, 0.15) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: "#17212A"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: btn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.action === "paste") input.pasteWithPriority()
                            else if (modelData.action === "copy") { input.copyWithFallback(); _toast("已复制 ✓") }
                            else if (modelData.action === "selectAll") input.selectAll()
                            popup.close()
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: tapArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        propagateComposedEvents: true

        function showEditMenu(x) {
            var items = []
            if ((!input.selectedText || input.selectedText.length === 0)
                    && input.text.length > 0)
                input.selectAll()
            if (!input.readOnly)
                items.push({label: "粘贴", action: "paste"})
            if (input.selectedText && input.selectedText.length > 0) {
                if (!input.readOnly) items.unshift({label: "复制", action: "copy"})
                else items.push({label: "复制", action: "copy"})
            }
            items.push({label: "全选", action: "selectAll"})
            input._menuItems = items
            popup.x = Math.max(0, Math.min(
                x, input.width - popup.width - 20
            ))
            popup.y = -popup.height - 10
            popup.open()
        }

        onPressAndHold: {
            showEditMenu(mouse.x)
        }

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton)
                showEditMenu(mouse.x)
        }

        onPressed: {
            mouse.accepted = false
            input.forceActiveFocus()
        }

        onReleased: {
            // A parent window/popup may update focus during the same pointer
            // release. Reassert it on the next turn so the global keyboard
            // watcher sees this editor reliably.
            Qt.callLater(function() { input.forceActiveFocus() })
            mouse.accepted = false
        }
    }

    function _toast(msg) {
        var p = parent
        while (p) {
            if (p.showToast) { p.showToast(msg); return }
            p = p.parent
        }
    }
}
