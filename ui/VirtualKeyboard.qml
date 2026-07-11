// YUNSH OS v1.0.1 - visionOS Floating Virtual Keyboard
// Draggable frosted glass panel, circular keys, independent floating window

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: keyboardPanel
    visible: false
    z: 200
    width: 1920
    height: 1080

    // ─── Dismiss backdrop ─────────────────────
    MouseArea {
        id: dismissArea
        anchors.fill: parent
        enabled: keyboardPanel.visible
        onClicked: {
            var gx = mouseX; var gy = mouseY
            var kw = keyboardPanel.panelWidth; var kh = keyboardPanel.panelHeight
            var kx_ = keyboardPanel.x; var ky_ = keyboardPanel.y
            if (gx < kx_ || gx > kx_ + kw || gy < ky_ || gy > ky_ + kh)
                keyboardPanel.hide()
        }
    }

    // ─── Public API ────────────────────────────
    property var targetItem: null
    property bool shiftActive: false
    property bool capsActive: false

    signal keyPressed(string key)
    signal backspacePressed()
    signal enterPressed()
    signal spacePressed()
    signal dismissKeyboard()

    // ─── Auto-show when text input gets focus ──
    Connections {
        target: keyboardPanel.parent
        onActiveFocusItemChanged: {
            var item = keyboardPanel.parent.activeFocusItem
            if (item && (item instanceof TextInput || item instanceof TextField)) {
                targetItem = item
                if (!keyboardPanel.visible) show()
            }
        }
    }

    onVisibleChanged: { if (!visible) targetItem = null }

    // ─── Floating panel ────────────────────────
    // Movable like visionOS — drag to reposition anywhere
    property real panelWidth: 840
    property real panelHeight: 300

    // Initial position bottom-center
    x: (1920 - panelWidth) / 2
    y: 740

    // Slide-in/out animation (disabled during drag)
    property bool animating: true
    Behavior on y { enabled: keyboardPanel.animating; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    function show() {
        visible = true
        opacity = 1.0
        // Reset to bottom-center if position is way off screen
        if (y < 50 || y > 1000) { animating = true; y = 740 }
        Qt.callLater(function() { keyboardPanel.x = Math.max(0, Math.min(keyboardPanel.x, 1920 - keyboardPanel.panelWidth)) })
    }

    function hide() {
        animating = false
        opacity = 0
        Qt.callLater(function() { visible = false })
    }

    // ─── Glass panel body ──────────────────────
    Rectangle {
        id: panelBody
        width: keyboardPanel.panelWidth
        height: keyboardPanel.panelHeight
        radius: 32
        color: Qt.rgba(250/255, 250/255, 255/255, 0.15)
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
        border.width: 1

        // Frost overlay
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
        }

        // Top edge highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left; anchors.leftMargin: 28
            anchors.right: parent.right; anchors.rightMargin: 28
            height: 1; radius: 1
            color: Qt.rgba(255/255, 255/255, 255/255, 0.12)
        }

        // Shadow beneath
        Rectangle {
            width: parent.width; height: parent.height
            radius: parent.radius + 6; x: 0; y: 10
            color: Qt.rgba(0, 0, 0, 0.15); z: -1
        }

        // ─── Drag handle (entire top area) ─────
        // visionOS: drag keyboard to move it in 3D space
        MouseArea {
            id: dragHandle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40  // top strip for drag
            cursorShape: Qt.OpenHandCursor
            drag.target: keyboardPanel
            drag.axis: Drag.XAndY
            drag.minimumX: 20; drag.maximumX: 1920 - keyboardPanel.panelWidth - 20
            drag.minimumY: 20; drag.maximumY: 1000
            onPressed: { keyboardPanel.animating = false; keyboardPanel.z = 201 }
            onReleased: keyboardPanel.z = 200
        }

        // ─── Close button ✕ (top-right) ────────
        Rectangle {
            anchors.top: parent.top; anchors.topMargin: 10
            anchors.right: parent.right; anchors.rightMargin: 14
            width: 28; height: 28; radius: 14
            color: closeBtn.containsMouse
                ? Qt.rgba(255/255, 95/255, 87/255, 0.3)  // red tint on hover
                : Qt.rgba(255/255, 255/255, 255/255, 0.06)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeBtn.containsMouse
                    ? "#FF5F57"
                    : Qt.rgba(1, 1, 1, 0.35)
                font.pixelSize: 12
                font.weight: Font.Light
            }

            MouseArea {
                id: closeBtn
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: keyboardPanel.hide()
            }
        }

        // ─── Dismiss pill ──────────────────────
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            width: 36; height: 4; radius: 2
            color: Qt.rgba(255/255, 255/255, 255/255, 0.2)
            MouseArea {
                anchors.fill: parent; anchors.margins: -6
                onClicked: keyboardPanel.hide()
            }
        }

        // ─── Keyboard rows ─────────────────────
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 10
            spacing: 8

            // Row 0: Numbers
            KeyRow {
                keys: [
                    { primary: "`", shift: "~" },
                    { primary: "1", shift: "!" }, { primary: "2", shift: "@" },
                    { primary: "3", shift: "#" }, { primary: "4", shift: "$" },
                    { primary: "5", shift: "%" }, { primary: "6", shift: "^" },
                    { primary: "7", shift: "&" }, { primary: "8", shift: "*" },
                    { primary: "9", shift: "(" }, { primary: "0", shift: ")" },
                    { primary: "-", shift: "_" }, { primary: "=", shift: "+" }
                ]
                lastKey: "⌫"
                onKeyClicked: {
                    keyboardPanel.keyPressed(k)
                    if (keyboardPanel.shiftActive && !keyboardPanel.capsActive)
                        keyboardPanel.shiftActive = false
                }
                onSpecialClicked: keyboardPanel.backspacePressed()
            }

            // Row 1: QWERTY
            KeyRow {
                keys: [
                    { primary: "q", shift: "Q" }, { primary: "w", shift: "W" },
                    { primary: "e", shift: "E" }, { primary: "r", shift: "R" },
                    { primary: "t", shift: "T" }, { primary: "y", shift: "Y" },
                    { primary: "u", shift: "U" }, { primary: "i", shift: "I" },
                    { primary: "o", shift: "O" }, { primary: "p", shift: "P" }
                ]
                onKeyClicked: {
                    keyboardPanel.keyPressed(k)
                    if (keyboardPanel.shiftActive && !keyboardPanel.capsActive)
                        keyboardPanel.shiftActive = false
                }
            }

            // Row 2: ASDF
            KeyRow {
                keys: [
                    { primary: "a", shift: "A" }, { primary: "s", shift: "S" },
                    { primary: "d", shift: "D" }, { primary: "f", shift: "F" },
                    { primary: "g", shift: "G" }, { primary: "h", shift: "H" },
                    { primary: "j", shift: "J" }, { primary: "k", shift: "K" },
                    { primary: "l", shift: "L" }
                ]
                lastKey: ";"
                extraKey: "'"
                onKeyClicked: {
                    keyboardPanel.keyPressed(k)
                    if (keyboardPanel.shiftActive && !keyboardPanel.capsActive)
                        keyboardPanel.shiftActive = false
                }
                onSpecialClicked: { keyboardPanel.keyPressed(keyboardPanel.shiftActive || keyboardPanel.capsActive ? ":" : ";") }
                onExtraClicked: { keyboardPanel.keyPressed(keyboardPanel.shiftActive || keyboardPanel.capsActive ? "\"" : "'") }
            }

            // Row 3: ZXCV
            KeyRow {
                keys: [
                    { primary: "z", shift: "Z" }, { primary: "x", shift: "X" },
                    { primary: "c", shift: "C" }, { primary: "v", shift: "V" },
                    { primary: "b", shift: "B" }, { primary: "n", shift: "N" },
                    { primary: "m", shift: "M" }
                ]
                lastKey: ","
                extraKey: "."
                last3Key: "/"
                onKeyClicked: {
                    keyboardPanel.keyPressed(k)
                    if (keyboardPanel.shiftActive && !keyboardPanel.capsActive)
                        keyboardPanel.shiftActive = false
                }
                onSpecialClicked: { keyboardPanel.keyPressed(keyboardPanel.shiftActive || keyboardPanel.capsActive ? "<" : ",") }
                onExtraClicked: { keyboardPanel.keyPressed(keyboardPanel.shiftActive || keyboardPanel.capsActive ? ">" : ".") }
                onExtra2Clicked: { keyboardPanel.keyPressed("?") }
            }

            // Row 4: Space row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                RoundKey { label: keyboardPanel.shiftActive || keyboardPanel.capsActive ? "⇪" : "⇧"; width: 64; accent: keyboardPanel.shiftActive || keyboardPanel.capsActive
                    onClicked: {
                        if (keyboardPanel.capsActive) { keyboardPanel.capsActive = false; keyboardPanel.shiftActive = false }
                        else if (keyboardPanel.shiftActive) { keyboardPanel.shiftActive = false; keyboardPanel.capsActive = true }
                        else keyboardPanel.shiftActive = true
                    }
                }

                RoundKey { label: "🌐"; width: 52; }

                Rectangle {
                    width: 180; height: 48; radius: 24
                    color: kma.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.25) : Qt.rgba(255/255, 255/255, 255/255, 0.1)
                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08); border.width: 1
                    Text { anchors.centerIn: parent; text: "space"; color: Qt.rgba(1,1,1,0.3); font.pixelSize: 13; font.weight: Font.Light }
                    MouseArea { id: kma; anchors.fill: parent; hoverEnabled: true
                        onClicked: keyboardPanel.spacePressed() }
                }

                RoundKey { label: "🎤"; width: 52; opacity: 0.3 }
                RoundKey { label: "⏎"; width: 68; accent: true
                    onClicked: keyboardPanel.enterPressed() }
            }
        }
    }

    // ══════════════════════════════════════════════
    // Round Key Component
    // ══════════════════════════════════════════════
    component RoundKey: Rectangle {
        id: roundKey
        width: 48; height: 48; radius: width / 2
        color: kArea.containsMouse
            ? (accent ? Qt.rgba(0/255, 212/255, 255/255, 0.35) : Qt.rgba(255/255, 255/255, 255/255, 0.25))
            : (accent ? Qt.rgba(0/255, 212/255, 255/255, 0.2) : Qt.rgba(255/255, 255/255, 255/255, 0.1))
        border.color: kArea.containsMouse || accent
            ? Qt.rgba(0/255, 212/255, 255/255, kArea.containsMouse ? 0.25 : 0.18)
            : Qt.rgba(255/255, 255/255, 255/255, 0.06)
        border.width: 1
        property alias label: keyText.text
        property bool accent: false
        signal clicked()

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
        }

        Text {
            id: keyText; anchors.centerIn: parent
            color: accent ? "#00D4FF" : Qt.rgba(1,1,1,0.7)
            font.pixelSize: 16; font.weight: accent ? Font.Bold : Font.Light
        }

        MouseArea {
            id: kArea; anchors.fill: parent; hoverEnabled: true
            onClicked: roundKey.clicked()
        }

        Behavior on color { ColorAnimation { duration: 80 } }
    }

    // ══════════════════════════════════════════════
    // Key Row Component
    // ══════════════════════════════════════════════
    component KeyRow: Item {
        id: keyRow
        width: keyboardPanel.panelWidth - 40
        height: 48
        property var keys: []
        property string lastKey: ""; property string extraKey: ""
        property string last3Key: ""

        signal keyClicked(string k)
        signal specialClicked(); signal extraClicked(); signal extra2Clicked()

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Repeater {
                model: keyRow.keys
                delegate: RoundKey {
                    width: 46; height: 46
                    label: keyboardPanel.shiftActive || keyboardPanel.capsActive ? modelData.shift : modelData.primary
                    onClicked: keyRow.keyClicked(keyboardPanel.shiftActive || keyboardPanel.capsActive ? modelData.shift : modelData.primary)
                }
            }

            RoundKey { width: 46; height: 46; label: keyRow.lastKey; visible: keyRow.lastKey !== ""; accent: keyRow.lastKey === "⌫"
                onClicked: keyRow.specialClicked() }
            RoundKey { width: 46; height: 46; label: keyRow.extraKey; visible: keyRow.extraKey !== ""
                onClicked: keyRow.extraClicked() }
            RoundKey { width: 46; height: 46; label: keyRow.last3Key; visible: keyRow.last3Key !== ""
                onClicked: keyRow.extra2Clicked() }
        }
    }

    // ─── Key event handlers ─────────────────────
    onKeyPressed: {
        if (targetItem) {
            var pos = targetItem.cursorPosition
            targetItem.text = targetItem.text.substring(0, pos) + key + targetItem.text.substring(pos)
            targetItem.cursorPosition = pos + 1
        }
    }
    onBackspacePressed: {
        if (targetItem && targetItem.cursorPosition > 0) {
            var pos = targetItem.cursorPosition
            targetItem.text = targetItem.text.substring(0, pos - 1) + targetItem.text.substring(pos)
            targetItem.cursorPosition = pos - 1
        }
    }
    onSpacePressed: {
        if (targetItem) {
            var pos = targetItem.cursorPosition
            targetItem.text = targetItem.text.substring(0, pos) + " " + targetItem.text.substring(pos)
            targetItem.cursorPosition = pos + 1
        }
    }
    onEnterPressed: {
        if (targetItem) targetItem.focus = false
        hide()
    }
}
