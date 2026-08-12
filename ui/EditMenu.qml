// YUNSH OS v1.0 - iOS-style Long Press Edit Menu
// Attach to any TextField/TextInput to get copy/paste/selectAll popup on long press
//
// Usage:
//   TextField { id: myField }
//   EditMenu { target: myField }
//
// Or with TextInput:
//   TextInput { id: myInput }
//   EditMenu { target: myInput }

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: editMenu
    property Item target: null
    property var menuItems: null // auto-set based on target type

    // The popup
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
                model: editMenu.menuItems || []

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
                            editMenu.handleAction(modelData.action)
                            popup.close()
                        }
                    }
                }
            }
        }
    }

    function handleAction(action) {
        if (!target) return
        if (action === "paste") {
            if (typeof target.pasteWithPriority === "function") {
                target.pasteWithPriority()
            } else {
                // Match YUNSH Flow/Mac clipboard semantics even for legacy
                // TextField users: phone clipboard first, then the last local
                // copy returned by the local bridge, and finally Qt's native
                // clipboard if the bridge has no text.
                var xhr = new XMLHttpRequest()
                xhr.open("GET", "http://127.0.0.1:8591/api/clipboard", true)
                xhr.timeout = 700
                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== XMLHttpRequest.DONE) return
                    var preferred = ""
                    try { preferred = JSON.parse(xhr.responseText || "{}").text || "" }
                    catch (_error) {}
                    if (preferred.length > 0 && target.text !== undefined
                            && target.cursorPosition !== undefined) {
                        var pos = target.cursorPosition
                        target.text = target.text.substring(0, pos) + preferred
                            + target.text.substring(pos)
                        target.cursorPosition = pos + preferred.length
                    } else if (typeof target.paste === "function") {
                        target.paste()
                    }
                }
                xhr.ontimeout = function() {
                    if (typeof target.paste === "function") target.paste()
                }
                xhr.send()
            }
        } else if (action === "copy") {
            var textToCopy = target.selectedText || ""
            target.copy()
            if (textToCopy.length > 0) {
                var xhr = new XMLHttpRequest()
                xhr.open("POST", "http://127.0.0.1:8591/api/clipboard", true)
                xhr.setRequestHeader("Content-Type", "application/json")
                xhr.timeout = 700
                xhr.send(JSON.stringify({text: textToCopy}))
            }
            showToast("已复制 ✓")
        } else if (action === "cut") {
            target.cut()
        } else if (action === "selectAll") {
            target.selectAll()
        }
    }

    function showPopup(touchX, touchY) {
        if (!target) return

        // Determine which menu items to show based on target state
        var items = []
        if (typeof target.paste === "function") {
            items.push({label: "粘贴", action: "paste"})
        }
        if (typeof target.copy === "function" && target.selectedText && target.selectedText.length > 0) {
            items.push({label: "复制", action: "copy"})
        }
        if (typeof target.selectAll === "function") {
            items.push({label: "全选", action: "selectAll"})
        }

        if (target.readOnly !== undefined && !target.readOnly && typeof target.paste === "function") {
            // For editable fields, paste is always available
            items = [
                {label: "粘贴", action: "paste"},
                {label: "全选", action: "selectAll"}
            ]
            if (target.selectedText && target.selectedText.length > 0) {
                items.unshift({label: "复制", action: "copy"})
            }
        } else if (typeof target.copy === "function") {
            // Read-only: copy + selectAll
            items = [
                {label: "复制", action: "copy"},
                {label: "全选", action: "selectAll"}
            ]
        }

        if (items.length === 0) return

        editMenu.menuItems = items

        // Position popup relative to the touch point
        var parentCoords = target.mapToItem(target.parent, touchX, touchY)
        popup.x = Math.max(0, Math.min(
            parentCoords.x,
            target.width - popup.width - 10
        ))
        popup.y = Math.max(0, parentCoords.y - popup.height - 10)

        popup.open()
    }

    // Toast helper (reuses terminal's toast if available, or creates one)
    function showToast(msg) {
        var parentWin = target
        while (parentWin && !parentWin.showToast) {
            parentWin = parentWin.parent
        }
        if (parentWin && parentWin.showToast) {
            parentWin.showToast(msg)
        }
    }

    // Attach long press behavior to the target
    onTargetChanged: {
        if (!target) return
        // Wrap target's long press handling if not already wrapped
        // We use a transparent proxy MouseArea over the target
    }

    // This works by adding a MouseArea overlay on the target
    // The component must be nested inside or after the target declaration in QML
    // For simplicity, we add a direct overlay

    Rectangle {
        id: overlay
        anchors.fill: editMenu.parent
        color: "transparent"
        visible: false // We use this as a positioning reference
    }

    // Auto-detect parent as target if target not set
    Component.onCompleted: {
        if (!target) {
            // Walk parent chain to find TextField/TextInput
            var p = editMenu.parent
            while (p) {
                if (p.toString().indexOf("TextField") >= 0 ||
                    p.toString().indexOf("TextInput") >= 0) {
                    target = p
                    break
                }
                p = p.parent
            }
        }
    }
}
