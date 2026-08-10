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
            var localPoint = panelBody.mapFromItem(keyboardPanel, mouseX, mouseY)
            if (!panelBody.contains(localPoint))
                keyboardPanel.hide()
        }
    }

    // ─── Public API ────────────────────────────
    property var targetItem: null
    property bool shiftActive: false
    property bool capsActive: false
    property bool reduceMotion: false
    property bool tilted: true
    property string pinMode: "following" // following, pinned
    property real headYaw: 0.0
    property real headPitch: 0.0
    property real pixelsPerDegree: 21.3
    // A keyboard is a working surface, so it sits pitched toward the user
    // instead of sharing the upright reading plane used by app windows.
    property real restingPitch: 38
    readonly property real currentPitch: tilted ? restingPitch : 0

    function headOffsetX() {
        return -(pinMode === "pinned" ? headYaw : headYaw * 0.08)
                * pixelsPerDegree
    }

    function headOffsetY() {
        return -(pinMode === "pinned" ? headPitch : headPitch * 0.08)
                * pixelsPerDegree
    }

    signal keyPressed(string key)
    signal backspacePressed()
    signal enterPressed()
    signal spacePressed()
    signal dismissKeyboard()

    onVisibleChanged: { if (!visible) targetItem = null }

    // ─── Floating panel ────────────────────────
    // Movable like visionOS — drag to reposition anywhere
    property real panelWidth: 840
    property real panelHeight: 340

    // Slide-in/out animation (disabled during drag)
    property bool animating: true
    Behavior on opacity { NumberAnimation { duration: keyboardPanel.reduceMotion ? 80 : 200 } }

    function constrainPanelToViewport() {
        if (keyboardPanel.width <= 0 || keyboardPanel.height <= 0)
            return
        if (panelBody.y < 20 || panelBody.y > keyboardPanel.height - 40) {
            animating = true
            panelBody.y = Math.max(20, keyboardPanel.height - panelHeight - 40)
        }
        panelBody.x = Math.max(20, Math.min(panelBody.x,
                    keyboardPanel.width - panelWidth - 20))
    }

    function show() {
        visible = true
        opacity = 1.0
        // Anchor layout may settle one event-loop turn after startup.
        Qt.callLater(constrainPanelToViewport)
    }

    function hide() {
        animating = false
        if (targetItem)
            targetItem.focus = false
        opacity = 0
        Qt.callLater(function() { visible = false })
    }

    function showFor(item) {
        if (!item)
            return
        targetItem = item
        show()
    }

    // ─── Glass panel body ──────────────────────
    Rectangle {
        id: panelBody
        width: keyboardPanel.panelWidth
        height: keyboardPanel.panelHeight
        x: (keyboardPanel.width - width) / 2
        y: Math.max(20, keyboardPanel.height - height - 40)
        radius: 32
        color: Qt.rgba(248/255, 252/255, 255/255, 0.82)
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.90)
        border.width: 1
        antialiasing: true
        layer.enabled: true

        Behavior on y {
            enabled: keyboardPanel.animating && !keyboardPanel.reduceMotion
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        transform: [
            Rotation {
                origin.x: panelBody.width / 2
                origin.y: panelBody.height
                axis { x: 1; y: 0; z: 0 }
                angle: keyboardPanel.currentPitch
                Behavior on angle {
                    NumberAnimation {
                        duration: keyboardPanel.reduceMotion ? 0 : 320
                        easing.type: Easing.OutCubic
                    }
                }
            },
            Translate {
                x: keyboardPanel.headOffsetX()
                y: keyboardPanel.headOffsetY()
                Behavior on x {
                    NumberAnimation { duration: keyboardPanel.reduceMotion ? 0 : 120 }
                }
                Behavior on y {
                    NumberAnimation { duration: keyboardPanel.reduceMotion ? 0 : 120 }
                }
            }
        ]

        // Frost overlay
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(205/255, 239/255, 255/255, 0.14) }
                GradientStop { position: 1.0; color: Qt.rgba(255/255, 255/255, 255/255, 0.30) }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.topMargin: 8
            spacing: 8
            z: 5

            Rectangle {
                width: 72; height: 28; radius: 14
                color: tiltMouse.pressed ? Qt.rgba(0, 0.83, 1, 0.34)
                    : Qt.rgba(1, 1, 1, 0.58)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.82)
                Text {
                    anchors.centerIn: parent
                    text: keyboardPanel.tilted ? "倾斜" : "正向"
                    color: "#17212A"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: tiltMouse
                    anchors.fill: parent
                    onClicked: keyboardPanel.tilted = !keyboardPanel.tilted
                }
            }

            Rectangle {
                width: 80; height: 28; radius: 14
                color: pinMouse.pressed ? Qt.rgba(0, 0.83, 1, 0.34)
                    : Qt.rgba(1, 1, 1, 0.58)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.82)
                Text {
                    anchors.centerIn: parent
                    text: keyboardPanel.pinMode === "pinned" ? "固定" : "跟随视线"
                    color: "#17212A"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: pinMouse
                    anchors.fill: parent
                    onClicked: keyboardPanel.pinMode = keyboardPanel.pinMode === "pinned"
                        ? "following" : "pinned"
                }
            }
        }

        // Top edge highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left; anchors.leftMargin: 28
            anchors.right: parent.right; anchors.rightMargin: 28
            height: 1; radius: 1
            color: Qt.rgba(255/255, 255/255, 255/255, 0.84)
        }

        // Shadow beneath
        Rectangle {
            width: parent.width; height: parent.height
            radius: parent.radius + 6; x: 0; y: 18
            color: Qt.rgba(0, 0, 0, 0.22); z: -1
        }

        // Bright near edge preserves the physical plane on transparent-black
        // AR optics and makes the direction of the pitch immediately clear.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 34
            anchors.rightMargin: 34
            height: 2
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.24)
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
            preventStealing: true
            drag.target: panelBody
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 20
            drag.maximumX: Math.max(20, keyboardPanel.width - panelBody.width - 20)
            drag.minimumY: 20
            drag.maximumY: Math.max(20, keyboardPanel.height - 80)
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
                : Qt.rgba(255/255, 255/255, 255/255, 0.60)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.84)

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeBtn.containsMouse
                    ? "#FF5F57"
                    : Qt.rgba(23/255, 33/255, 42/255, 0.55)
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
            color: Qt.rgba(23/255, 33/255, 42/255, 0.28)
            MouseArea {
                anchors.fill: parent; anchors.margins: -6
                onClicked: keyboardPanel.hide()
            }
        }

        // ─── Keyboard rows ─────────────────────
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 22
            spacing: 8

            // Row 0: Numbers
            KeyRow {
                perspectiveScale: 0.90
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
                perspectiveScale: 0.93
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
                perspectiveScale: 0.96
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
                perspectiveScale: 0.98
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
                    color: kma.containsMouse ? Qt.rgba(225/255, 248/255, 255/255, 0.88) : Qt.rgba(255/255, 255/255, 255/255, 0.62)
                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.86); border.width: 1
                    Text { anchors.centerIn: parent; text: "space"; color: Qt.rgba(23/255,33/255,42/255,0.62); font.pixelSize: 13; font.weight: Font.Light }
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
            ? (accent ? Qt.rgba(0/255, 212/255, 255/255, 0.38) : Qt.rgba(225/255, 248/255, 255/255, 0.90))
            : (accent ? Qt.rgba(0/255, 212/255, 255/255, 0.24) : Qt.rgba(255/255, 255/255, 255/255, 0.62))
        border.color: kArea.containsMouse || accent
            ? Qt.rgba(0/255, 212/255, 255/255, kArea.containsMouse ? 0.25 : 0.18)
            : Qt.rgba(255/255, 255/255, 255/255, 0.86)
        border.width: 1
        property alias label: keyText.text
        property bool accent: false
        signal clicked()

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Qt.rgba(210/255, 241/255, 255/255, 0.10)
        }

        Text {
            id: keyText; anchors.centerIn: parent
            color: accent ? "#008EAA" : "#17212A"
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
        property real perspectiveScale: 1.0
        property string lastKey: ""; property string extraKey: ""
        property string last3Key: ""

        signal keyClicked(string k)
        signal specialClicked(); signal extraClicked(); signal extra2Clicked()

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            scale: keyRow.perspectiveScale
            transformOrigin: Item.Bottom

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
