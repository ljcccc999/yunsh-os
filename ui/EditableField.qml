// YUNSH OS v1.0 - Editable Text Field with iOS-style Long Press Menu
// Drop-in replacement for TextField with copy/paste/selectAll popup

import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
    id: field

    // Long press → popup menu
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
                model: field._menuItems

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
                            if (modelData.action === "paste") field.paste()
                            else if (modelData.action === "copy") { field.copy(); _toast("已复制 ✓") }
                            else if (modelData.action === "selectAll") field.selectAll()
                            popup.close()
                        }
                    }
                }
            }
        }
    }

    // Long press handler (overrides TextField's internal touch press)
    MouseArea {
        id: tapArea
        anchors.fill: parent
        propagateComposedEvents: true

        onPressAndHold: {
            // Build menu based on state
            var items = []
            if (!field.readOnly) {
                items.push({label: "粘贴", action: "paste"})
            }
            if (field.selectedText && field.selectedText.length > 0) {
                if (!field.readOnly) items.unshift({label: "复制", action: "copy"})
                else items.push({label: "复制", action: "copy"})
            }
            items.push({label: "全选", action: "selectAll"})
            field._menuItems = items

            // Position popup
            popup.x = Math.max(0, Math.min(
                mouse.x,
                field.width - popup.width - 20
            ))
            popup.y = -popup.height - 10
            popup.open()
        }

        onPressed: {
            // Let the TextField handle normal taps
            mouse.accepted = false
            field.forceActiveFocus()
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
