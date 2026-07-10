// YUNSH OS v1.0 - Editable Text Input with iOS-style Long Press Menu
// Drop-in replacement for TextInput with copy/paste/selectAll popup

import QtQuick 2.15
import QtQuick.Controls 2.15

TextInput {
    id: input

    property var _menuItems: [
        {label: "粘贴", action: "paste"},
        {label: "全选", action: "selectAll"}
    ]

    Popup {
        id: popup
        modal: false
        closePolicy: Popup.CloseOnPressOutside
        padding: 4

        background: Rectangle {
            color: "#1e1e3a"
            radius: 10
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
            border.width: 1
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
                        color: "#FFFFFF"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: btn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.action === "paste") input.paste()
                            else if (modelData.action === "copy") { input.copy(); _toast("已复制 ✓") }
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
        propagateComposedEvents: true

        onPressAndHold: {
            var items = []
            if (!input.readOnly) {
                items.push({label: "粘贴", action: "paste"})
            }
            if (input.selectedText && input.selectedText.length > 0) {
                if (!input.readOnly) items.unshift({label: "复制", action: "copy"})
                else items.push({label: "复制", action: "copy"})
            }
            items.push({label: "全选", action: "selectAll"})
            input._menuItems = items

            popup.x = Math.max(0, Math.min(
                mouse.x,
                input.width - popup.width - 20
            ))
            popup.y = -popup.height - 10
            popup.open()
        }

        onPressed: {
            mouse.accepted = false
            input.forceActiveFocus()
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
