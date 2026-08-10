// YUNSH OS v1.0.1 - visionOS Floating Virtual Keyboard
// Draggable frosted glass panel, circular keys, independent floating window

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: keyboardPanel
    visible: false
    // Always stay above fullscreen apps and global shell controls.
    z: 8000
    width: 1920
    height: 1080

    // ─── Dismiss backdrop ─────────────────────
    MouseArea {
        id: dismissArea
        anchors.fill: parent
        // A movable spatial keyboard closes only through its explicit X.
        // Outside taps must not race with a tilted drag gesture.
        enabled: false
    }

    // ─── Public API ────────────────────────────
    property var targetItem: null
    property bool shiftActive: false
    property bool capsActive: false
    property bool symbolsActive: false
    property bool emojiActive: false
    // `latin` inserts text directly; `pinyin` sends physical-style key events
    // through Fcitx5 so Chinese candidates work in every focused field.
    property string inputMethod: "latin"
    readonly property string inputMethodLabel: inputMethod === "pinyin" ? "中" : "ABC"
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

    function refreshInputMethod() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8591/api/input-method", true)
        xhr.timeout = 1200
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return
            try {
                var body = JSON.parse(xhr.responseText || "{}")
                if (body.mode === "pinyin" || body.mode === "latin")
                    keyboardPanel.inputMethod = body.mode
            } catch (_error) {}
        }
        xhr.send()
    }

    function toggleInputMethod() {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/input-method", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 1500
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return
            try {
                var body = JSON.parse(xhr.responseText || "{}")
                if (body.success && (body.mode === "pinyin" || body.mode === "latin"))
                    keyboardPanel.inputMethod = body.mode
                else
                    keyboardPanel.refreshInputMethod()
            } catch (_error) {}
        }
        // Let the daemon toggle its authoritative state instead of relying on
        // a possibly stale local label after a restart or physical-keyboard
        // switch.
        xhr.send(JSON.stringify({mode: "toggle"}))
    }

    function insertDirect(key) {
        if (!targetItem)
            return
        var pos = targetItem.cursorPosition
        targetItem.text = targetItem.text.substring(0, pos) + key + targetItem.text.substring(pos)
        targetItem.cursorPosition = pos + key.length
    }

    function injectKey(key) {
        var completed = false
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/input-key", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 900
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || completed)
                return
            completed = true
            var ok = false
            try { ok = JSON.parse(xhr.responseText || "{}").success === true } catch (_error) {}
            if (!ok)
                insertDirect(key)
        }
        xhr.ontimeout = function() {
            if (!completed) {
                completed = true
                insertDirect(key)
            }
        }
        try {
            xhr.send(JSON.stringify({key: key}))
        } catch (_error) {
            if (!completed) {
                completed = true
                insertDirect(key)
            }
        }
    }

    Timer {
        id: backspaceHoldDelay
        interval: 360
        repeat: false
        onTriggered: backspaceRepeat.start()
    }

    Timer {
        id: backspaceRepeat
        interval: 70
        repeat: true
        onTriggered: keyboardPanel.backspacePressed()
    }

    function beginBackspace() {
        backspacePressed()
        backspaceHoldDelay.restart()
    }

    function endBackspace() {
        backspaceHoldDelay.stop()
        backspaceRepeat.stop()
    }

    onVisibleChanged: {
        if (!visible) {
            endBackspace()
            targetItem = null
        } else refreshInputMethod()
    }

    // ─── Floating panel ────────────────────────
    // Movable like visionOS — drag to reposition anywhere
    property real panelWidth: 900
    property real panelHeight: 380

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

    function targetHasFocus() {
        if (!targetItem || targetItem.visible === false)
            return false
        if (targetItem.activeFocus !== undefined)
            return targetItem.activeFocus === true
        if (targetItem.focus !== undefined)
            return targetItem.focus === true
        return true
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
                width: 88; height: 34; radius: 17
                color: tiltMouse.pressed ? Qt.rgba(0, 0.83, 1, 0.42)
                    : Qt.rgba(1, 1, 1, 0.94)
                border.width: 1
                border.color: "#FFFFFF"
                Text {
                    anchors.centerIn: parent
                    text: keyboardPanel.tilted ? "倾斜" : "正向"
                    color: "#17212A"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
                MouseArea {
                    id: tiltMouse
                    anchors.fill: parent
                    onClicked: keyboardPanel.tilted = !keyboardPanel.tilted
                }
            }

            Rectangle {
                width: 104; height: 34; radius: 17
                color: pinMouse.pressed ? Qt.rgba(0, 0.83, 1, 0.42)
                    : Qt.rgba(1, 1, 1, 0.94)
                border.width: 1
                border.color: "#FFFFFF"
                Text {
                    anchors.centerIn: parent
                    text: keyboardPanel.pinMode === "pinned" ? "固定" : "跟随视线"
                    color: "#17212A"
                    font.pixelSize: 14
                    font.weight: Font.Bold
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
            width: 48; height: 48; radius: 24
            z: 30
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
                font.pixelSize: 18
                font.weight: Font.DemiBold
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
                symbolKeys: ["~", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+"]
                emojiKeys: ["😀", "😂", "🥰", "😍", "😊", "😭", "😡", "🤔", "😎", "🥳"]
                lastKey: "⌫"
                onKeyClicked: {
                    keyboardPanel.keyPressed(k)
                    if (keyboardPanel.shiftActive && !keyboardPanel.capsActive)
                        keyboardPanel.shiftActive = false
                }
                onSpecialPressed: keyboardPanel.beginBackspace()
                onSpecialReleased: keyboardPanel.endBackspace()
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
                symbolKeys: ["[", "]", "{", "}", "<", ">", "=", "+", "-", "_"]
                emojiKeys: ["👍", "👎", "👏", "🙏", "💪", "👀", "❤️", "💙", "✨", "🔥"]
                lastKey: "["
                extraKey: "]"
                last3Key: "\\"
                onKeyClicked: {
                    keyboardPanel.keyPressed(k)
                    if (keyboardPanel.shiftActive && !keyboardPanel.capsActive)
                        keyboardPanel.shiftActive = false
                }
                onSpecialClicked: keyboardPanel.keyPressed(
                    keyboardPanel.shiftActive || keyboardPanel.capsActive ? "{" : "[")
                onExtraClicked: keyboardPanel.keyPressed(
                    keyboardPanel.shiftActive || keyboardPanel.capsActive ? "}" : "]")
                onExtra2Clicked: keyboardPanel.keyPressed(
                    keyboardPanel.shiftActive || keyboardPanel.capsActive ? "|" : "\\")
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
                symbolKeys: ["/", "\\", "|", ":", ";", "'", "\"", "?", "!"]
                emojiKeys: ["🎉", "🚀", "💡", "✅", "❌", "⚠️", "📱", "💻", "🥽"]
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
                symbolKeys: ["`", "~", ",", ".", "…", "·", "、"]
                emojiKeys: ["🌍", "🌙", "☀️", "⭐", "☁️", "🌈", "🎵"]
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
                onExtra2Clicked: { keyboardPanel.keyPressed(keyboardPanel.shiftActive || keyboardPanel.capsActive ? "?" : "/") }
            }

            // Row 4: Space row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                RoundKey {
                    label: keyboardPanel.inputMethod === "pinyin" ? "中" : "🌐"
                    width: 56
                    accent: keyboardPanel.inputMethod === "pinyin"
                    onClicked: keyboardPanel.toggleInputMethod()
                }

                RoundKey {
                    label: keyboardPanel.symbolsActive ? "ABC" : "#+="
                    width: 64
                    accent: keyboardPanel.symbolsActive
                    onClicked: {
                        keyboardPanel.symbolsActive = !keyboardPanel.symbolsActive
                        keyboardPanel.emojiActive = false
                        keyboardPanel.shiftActive = false
                        keyboardPanel.capsActive = false
                    }
                }

                RoundKey {
                    label: "😊"
                    width: 52
                    accent: keyboardPanel.emojiActive
                    onClicked: {
                        keyboardPanel.emojiActive = !keyboardPanel.emojiActive
                        keyboardPanel.symbolsActive = false
                        keyboardPanel.shiftActive = false
                        keyboardPanel.capsActive = false
                    }
                }

                RoundKey { label: keyboardPanel.shiftActive || keyboardPanel.capsActive ? "⇪" : "⇧"; width: 64; accent: keyboardPanel.shiftActive || keyboardPanel.capsActive
                    onClicked: {
                        if (keyboardPanel.capsActive) { keyboardPanel.capsActive = false; keyboardPanel.shiftActive = false }
                        else if (keyboardPanel.shiftActive) { keyboardPanel.shiftActive = false; keyboardPanel.capsActive = true }
                        else keyboardPanel.shiftActive = true
                    }
                }

                RoundKey { label: "⇤"; width: 48
                    onClicked: {
                        if (keyboardPanel.inputMethod === "pinyin") keyboardPanel.injectKey("left")
                        else if (keyboardPanel.targetItem)
                            keyboardPanel.targetItem.cursorPosition = Math.max(0,
                                keyboardPanel.targetItem.cursorPosition - 1)
                    }
                }

                RoundKey { label: "⇥"; width: 48
                    onClicked: {
                        if (keyboardPanel.inputMethod === "pinyin") keyboardPanel.injectKey("right")
                        else if (keyboardPanel.targetItem)
                            keyboardPanel.targetItem.cursorPosition = Math.min(
                                keyboardPanel.targetItem.text.length,
                                keyboardPanel.targetItem.cursorPosition + 1)
                    }
                }

                Rectangle {
                    width: 180; height: 48; radius: 24
                    color: kma.pressed ? Qt.rgba(0/255, 212/255, 255/255, 0.34) : Qt.rgba(255/255, 255/255, 255/255, 0.62)
                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.86); border.width: 1
                    Text { anchors.centerIn: parent; text: "space"; color: Qt.rgba(23/255,33/255,42/255,0.62); font.pixelSize: 13; font.weight: Font.Light }
                    MouseArea { id: kma; anchors.fill: parent; hoverEnabled: true
                        onClicked: keyboardPanel.spacePressed() }
                }

                RoundKey { label: "🎤"; width: 52; opacity: 0.3 }
                RoundKey { label: "⏎"; width: 68
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
        // Ordinary keys flash only while physically pressed. `accent` is
        // reserved for latched state keys such as Shift/Caps Lock.
        color: kArea.pressed
            ? (accent ? Qt.rgba(0/255, 212/255, 255/255, 0.38) : Qt.rgba(225/255, 248/255, 255/255, 0.90))
            : (accent ? Qt.rgba(0/255, 212/255, 255/255, 0.30) : Qt.rgba(255/255, 255/255, 255/255, keyboardPanel.tilted ? 0.94 : 0.76))
        border.color: kArea.pressed || accent
            ? Qt.rgba(0/255, 212/255, 255/255, kArea.pressed ? 0.25 : 0.18)
            : Qt.rgba(255/255, 255/255, 255/255, 0.86)
        border.width: 1
        property alias label: keyText.text
        property bool accent: false
        signal clicked()
        signal pressed()
        signal released()

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Qt.rgba(210/255, 241/255, 255/255, 0.10)
        }

        Text {
            id: keyText; anchors.centerIn: parent
            color: accent ? "#007F99" : (keyboardPanel.tilted ? "#071116" : "#17212A")
            font.pixelSize: keyboardPanel.tilted ? 18 : 16
            font.weight: accent ? Font.Bold : (keyboardPanel.tilted ? Font.DemiBold : Font.Medium)
        }

        MouseArea {
            id: kArea; anchors.fill: parent; hoverEnabled: true
            onClicked: roundKey.clicked()
            onPressed: roundKey.pressed()
            onReleased: roundKey.released()
            onCanceled: roundKey.released()
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
        property var symbolKeys: []
        property var emojiKeys: []
        property real perspectiveScale: 1.0
        property string lastKey: ""; property string extraKey: ""
        property string last3Key: ""

        signal keyClicked(string k)
        signal specialClicked(); signal extraClicked(); signal extra2Clicked()
        signal specialPressed(); signal specialReleased()

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            scale: keyRow.perspectiveScale
            transformOrigin: Item.Bottom

            Repeater {
                model: keyboardPanel.emojiActive ? keyRow.emojiKeys
                    : (keyboardPanel.symbolsActive ? keyRow.symbolKeys : keyRow.keys)
                delegate: RoundKey {
                    width: 46; height: 46
                    label: keyboardPanel.emojiActive || keyboardPanel.symbolsActive ? String(modelData)
                        : (keyboardPanel.shiftActive || keyboardPanel.capsActive ? modelData.shift : modelData.primary)
                    onClicked: keyRow.keyClicked(keyboardPanel.emojiActive || keyboardPanel.symbolsActive ? String(modelData)
                        : (keyboardPanel.shiftActive || keyboardPanel.capsActive ? modelData.shift : modelData.primary))
                }
            }

            RoundKey { width: 46; height: 46; label: keyRow.lastKey; visible: keyRow.lastKey !== ""
                onClicked: keyRow.specialClicked()
                onPressed: keyRow.specialPressed()
                onReleased: keyRow.specialReleased() }
            RoundKey { width: 46; height: 46; label: keyRow.extraKey; visible: keyRow.extraKey !== ""
                onClicked: keyRow.extraClicked() }
            RoundKey { width: 46; height: 46; label: keyRow.last3Key; visible: keyRow.last3Key !== ""
                onClicked: keyRow.extra2Clicked() }
        }
    }

    // ─── Key event handlers ─────────────────────
    onKeyPressed: {
        if (inputMethod === "pinyin" && key.length <= 1 && key.charCodeAt(0) < 128)
            injectKey(key)
        else if (targetItem) {
            var pos = targetItem.cursorPosition
            targetItem.text = targetItem.text.substring(0, pos) + key + targetItem.text.substring(pos)
            targetItem.cursorPosition = pos + 1
        }
    }
    onBackspacePressed: {
        if (inputMethod === "pinyin") {
            injectKey("backspace")
        } else if (targetItem && targetItem.cursorPosition > 0) {
            var pos = targetItem.cursorPosition
            targetItem.text = targetItem.text.substring(0, pos - 1) + targetItem.text.substring(pos)
            targetItem.cursorPosition = pos - 1
        }
    }
    onSpacePressed: {
        if (inputMethod === "pinyin") {
            injectKey(" ")
        } else if (targetItem) {
            var pos = targetItem.cursorPosition
            targetItem.text = targetItem.text.substring(0, pos) + " " + targetItem.text.substring(pos)
            targetItem.cursorPosition = pos + 1
        }
    }
    onEnterPressed: {
        if (inputMethod === "pinyin") {
            injectKey("\n")
        } else if (targetItem && typeof targetItem.submit === "function")
            targetItem.submit()
        else if (targetItem && typeof targetItem.accepted === "function")
            targetItem.accepted()
        else if (targetItem)
            targetItem.focus = false
    }
}
