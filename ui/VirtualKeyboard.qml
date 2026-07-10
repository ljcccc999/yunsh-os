// YUNSH OS v1.0 - Virtual Keyboard (visionOS Style)
// On-screen keyboard with mouse click support, glassmorphism design

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: keyboard
    visible: false
    z: 180
    
    property bool shiftActive: false
    property bool capsActive: false
    property string currentText: ""
    // Target text input to send keystrokes to
    property var targetItem: null
    
    signal keyPressed(string key)
    signal backspacePressed()
    signal enterPressed()
    signal spacePressed()
    signal dismissKeyboard()
    
    // Auto-focus handling: watch for text input focus
    Connections {
        target: keyboard.parent
        onActiveFocusItemChanged: {
            var item = keyboard.parent.activeFocusItem
            if (item && (item instanceof TextInput || item instanceof TextField)) {
                targetItem = item
                if (!keyboard.visible) {
                    keyboard.show()
                }
            }
        }
    }
    
    // When hidden, clear target
    onVisibleChanged: {
        if (!visible) targetItem = null
    }
    
    // ─── Size & position ──────────────────────────
    anchors.left: parent.left; anchors.leftMargin: 40
    anchors.right: parent.right; anchors.rightMargin: 40
    y: parent.height  // slide up from bottom
    height: 280
    
    // ─── Slide animation ─────────────────────────
    Behavior on y {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    
    function show() {
        visible = true
        y = parent.height - height - 20
    }
    
    function hide() {
        y = parent.height
        Qt.callLater(function() { visible = false })
    }
    
    // ─── Glass background ────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Qt.rgba(12/255, 12/255, 28/255, 0.75)
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
        border.width: 1
        
        // Subtle gradient overlay (visionOS atmospheric)
        Rectangle {
            anchors.fill: parent; radius: 24
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0/255, 212/255, 255/255, 0.03) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
    
    // ─── Dismiss handle ──────────────────────────
    Rectangle {
        anchors.top: parent.top; anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: 40; height: 4; radius: 2
        color: Qt.rgba(255/255, 255/255, 255/255, 0.15)
        
        MouseArea {
            anchors.fill: parent
            onClicked: keyboard.hide()
        }
    }
    
    // ─── Keyboard rows ───────────────────────────
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 6
        spacing: 6
        
        // Row 0: Number row
        KeyRow {
            keys: [
                { label: "`", shift: "~" },
                { label: "1", shift: "!" },
                { label: "2", shift: "@" },
                { label: "3", shift: "#" },
                { label: "4", shift: "$" },
                { label: "5", shift: "%" },
                { label: "6", shift: "^" },
                { label: "7", shift: "&" },
                { label: "8", shift: "*" },
                { label: "9", shift: "(" },
                { label: "0", shift: ")" },
                { label: "-", shift: "_" },
                { label: "=", shift: "+" }
            ]
            specialLast: "⌫"
            specialLastWidth: 64
            onSpecialLastClicked: keyboard.backspacePressed()
        }
        
        // Row 1: QWERTY
        KeyRow {
            offset: 12
            keys: [
                { label: "q", shift: "Q" },
                { label: "w", shift: "W" },
                { label: "e", shift: "E" },
                { label: "r", shift: "R" },
                { label: "t", shift: "T" },
                { label: "y", shift: "Y" },
                { label: "u", shift: "U" },
                { label: "i", shift: "I" },
                { label: "o", shift: "O" },
                { label: "p", shift: "P" }
            ]
            specialLast: "["
            extraLast: "]"
            extraLast2: "\\"
            onSpecialLastClicked: keyboard.keyPressed(shiftActive || capsActive ? "{" : "[")
            onExtraLastClicked: keyboard.keyPressed(shiftActive || capsActive ? "}" : "]")
            onExtraLast2Clicked: keyboard.keyPressed("\\")
        }
        
        // Row 2: ASDF
        KeyRow {
            offset: 28
            keys: [
                { label: "a", shift: "A" },
                { label: "s", shift: "S" },
                { label: "d", shift: "D" },
                { label: "f", shift: "F" },
                { label: "g", shift: "G" },
                { label: "h", shift: "H" },
                { label: "j", shift: "J" },
                { label: "k", shift: "K" },
                { label: "l", shift: "L" }
            ]
            specialLast: ";"
            extraLast: "'"
            specialLastWidth: 56
            onSpecialLastClicked: keyboard.keyPressed(shiftActive || capsActive ? ":" : ";")
            onExtraLastClicked: keyboard.keyPressed(shiftActive || capsActive ? "\"" : "'")
        }
        
        // Row 3: ZXCV
        KeyRow {
            offset: 8
            keys: [
                { label: "z", shift: "Z" },
                { label: "x", shift: "X" },
                { label: "c", shift: "C" },
                { label: "v", shift: "V" },
                { label: "b", shift: "B" },
                { label: "n", shift: "N" },
                { label: "m", shift: "M" },
            ]
            specialLast: ","
            specialLastWidth: 44
            extraLast: "."
            extraLast2: "/"
            onSpecialLastClicked: keyboard.keyPressed(shiftActive || capsActive ? "<" : ",")
            onExtraLastClicked: keyboard.keyPressed(shiftActive || capsActive ? ">" : ".")
            onExtraLast2Clicked: keyboard.keyPressed("?")
        }
        
        // Row 4: Space row
        Item {
            width: keyboard.width - 60
            height: 44
            
            Row {
                anchors.centerIn: parent
                spacing: 6
                
                // Shift key (capsule)
                SpecialKey {
                    text: shiftActive || capsActive ? "⇪" : "⇧"
                    width: 60
                    active: shiftActive || capsActive
                    onClicked: {
                        if (capsActive) {
                            capsActive = false
                            shiftActive = false
                        } else if (shiftActive) {
                            shiftActive = false
                            capsActive = true
                        } else {
                            shiftActive = true
                        }
                    }
                }
                
                // Globe / language key
                SpecialKey {
                    text: "🌐"
                    width: 48
                    onClicked: { /* future: switch keyboard language */ }
                }
                
                // Space bar
                Rectangle {
                    width: 220; height: 42; radius: 14
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                    border.width: 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "space"
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.2)
                        font.pixelSize: 13
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Qt.rgba(255/255, 255/255, 255/255, 0.08)
                        onExited: parent.color = Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        onClicked: keyboard.spacePressed()
                    }
                }
                
                // Dictation (voice input, coming soon)
                SpecialKey {
                    text: "🎤"
                    width: 48
                    opacity: 0.3
                    onClicked: { /* future: voice dictation */ }
                }
                
                // Enter key
                SpecialKey {
                    text: "⏎"
                    width: 64
                    accent: true
                    onClicked: keyboard.enterPressed()
                }
            }
        }
    }
    
    // ════════════════════════════════════════════════════
    // Key Row Component
    // ════════════════════════════════════════════════════
    component KeyRow: Item {
        id: keyRow
        width: keyboard.width - 60
        height: 44
        
        property var keys: []
        property int offset: 0
        property string specialLast: ""
        property int specialLastWidth: 48
        property string extraLast: ""
        property string extraLast2: ""
        
        signal specialLastClicked()
        signal extraLastClicked()
        signal extraLast2Clicked()
        
        Row {
            anchors.left: parent.left; anchors.leftMargin: keyRow.offset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            
            Repeater {
                model: keyRow.keys
                delegate: Rectangle {
                    width: 44; height: 42; radius: 10
                    color: mouseArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.12) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                    border.color: mouseArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.1) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                    border.width: 1
                    
                    property var data: modelData
                    
                    Text {
                        anchors.centerIn: parent
                        text: keyboard.shiftActive || keyboard.capsActive ? data.shift : data.label
                        color: "#FFFFFF"
                        font.pixelSize: 16
                        font.weight: Font.Light
                    }
                    
                    property alias mouseArea: mouseArea
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            var k = keyboard.shiftActive || keyboard.capsActive ? data.shift : data.label
                            keyboard.keyPressed(k)
                            // Auto-release shift on single press
                            if (keyboard.shiftActive && !keyboard.capsActive) {
                                keyboard.shiftActive = false
                            }
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: 80 }
                    }
                }
            }
            
            // Special last key (backspace, enter, etc.)
            Rectangle {
                width: keyRow.specialLastWidth; height: 42; radius: 10
                color: keyMousArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.12) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                border.color: keyMousArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.1) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                border.width: 1
                visible: keyRow.specialLast !== ""
                
                Text {
                    anchors.centerIn: parent
                    text: keyRow.specialLast
                    color: "#00D4FF"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    id: keyMousArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: keyRow.specialLastClicked()
                }
            }
            
            // Extra last keys (for RHS brackets etc.)
            Rectangle {
                width: 44; height: 42; radius: 10
                color: extraMousArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.12) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                border.color: extraMousArea.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.1) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                border.width: 1
                visible: keyRow.extraLast !== ""
                
                Text {
                    anchors.centerIn: parent
                    text: keyRow.extraLast
                    color: "#FFFFFF"
                    font.pixelSize: 16
                }
                
                MouseArea {
                    id: extraMousArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: keyRow.extraLastClicked()
                }
            }
            
            Rectangle {
                width: 44; height: 42; radius: 10
                color: extraMousArea2.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.12) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                border.color: extraMousArea2.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.1) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                border.width: 1
                visible: keyRow.extraLast2 !== ""
                
                Text {
                    anchors.centerIn: parent
                    text: keyRow.extraLast2
                    color: "#FFFFFF"
                    font.pixelSize: 16
                }
                
                MouseArea {
                    id: extraMousArea2
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: keyRow.extraLast2Clicked()
                }
            }
        }
    }
    
    // ════════════════════════════════════════════════════
    // Special Key Component (capsules for space row)
    // ════════════════════════════════════════════════════
    component SpecialKey: Rectangle {
        id: specialKey
        height: 42; radius: 12
        color: mouseArea.containsMouse
            ? Qt.rgba(0/255, 212/255, 255/255, 0.15)
            : (active ? Qt.rgba(0/255, 212/255, 255/255, 0.12) : Qt.rgba(255/255, 255/255, 255/255, 0.04))
        border.color: mouseArea.containsMouse || active
            ? Qt.rgba(0/255, 212/255, 255/255, 0.12)
            : Qt.rgba(255/255, 255/255, 255/255, 0.04)
        border.width: 1
        
        property alias text: keyLabel.text
        property bool active: false
        property bool accent: false
        
        signal clicked()
        
        Text {
            id: keyLabel
            anchors.centerIn: parent
            color: accent ? "#00D4FF" : (active ? "#00D4FF" : "#FFFFFF")
            font.pixelSize: 14
            font.weight: active ? Font.Bold : Font.Normal
        }
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: specialKey.clicked()
        }
        
        Behavior on color { ColorAnimation { duration: 80 } }
    }
    
    // ─── Key event handlers ────────────────────────
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
        if (targetItem) {
            targetItem.focus = false
        }
        hide()
    }
}
