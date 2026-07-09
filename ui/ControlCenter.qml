// YUNSH OS v1.0 - Control Center (visionOS/iOS Style)
// Swipe-down panel from top-right, inspired by iOS Control Center + visionOS glassmorphism

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: controlCenterRoot

    // ─── Public Properties ───────────────────────────────────────────────
    property bool wifiOn: false
    property bool bluetoothOn: false
    property string wifiSSID: ""
    property string btDevice: ""
    property string currentTime: "00:00"

    // ─── Signals ─────────────────────────────────────────────────────────
    signal dismissPanel()
    signal openNetwork()
    signal openBluetooth()
    signal takeScreenshot()
    signal toggleWifi()
    signal toggleBluetooth()
    signal toggleKeyboard()

    // ─── Visibility & state ──────────────────────────────────────────────
    visible: false
    z: 150

    // ─── Timer for clock updates ─────────────────────────────────────────
    Timer {
        id: clockTimer
        interval: 1000
        running: controlCenterRoot.visible
        repeat: true
        onTriggered: {
            var d = new Date()
            currentTime = d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
        }
    }

    // ─── Backdrop (semi-transparent, click to dismiss) ───────────────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: controlCenterRoot.visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                animateOut.start()
                controlCenterRoot.dismissPanel()
            }
        }
    }

    // ─── Panel Container ─────────────────────────────────────────────────
    Item {
        id: panelContainer
        anchors.top: parent.top
        anchors.topMargin: 60   // Below status bar area
        anchors.right: parent.right
        anchors.rightMargin: 20

        width: 420
        height: panelContent.height + 40

        opacity: controlCenterRoot.visible ? 1.0 : 0.0

        // Slide in/out animation
        transform: Translate {
            id: panelTranslate
            y: controlCenterRoot.visible ? 0 : -30
        }

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutBack }
        }

        Behavior on transform {
            NumberAnimation { duration: 250; easing.type: Easing.OutBack }
        }

        // ─── Glass Panel ─────────────────────────────────────────────
        GlassPanel {
            id: glassPanel
            anchors.fill: parent

            // visionOS deep glass
            panelColor: Qt.rgba(18/255, 18/255, 35/255, 0.65)
            borderColor: Qt.rgba(255/255, 255/255, 255/255, 0.04)
            glassOpacity: 0.65
            blurRadius: 28
            cornerRadius: 28
            borderWidth: 1
            shadowDepth: 20
            shadowOpacity: 0.6
            glowBorder: false

            // ─── Content ─────────────────────────────────────────────
            Item {
                id: panelContent
                anchors.fill: parent
                anchors.margins: 0
                anchors.topMargin: 20
                anchors.bottomMargin: 20
                anchors.leftMargin: 20
                anchors.rightMargin: 20

                implicitHeight: contentColumn.height + 40

                Column {
                    id: contentColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 20

                    // ── Section: Quick Toggles (3-column grid) ──────
                    Grid {
                        id: toggleGrid
                        anchors.left: parent.left
                        anchors.right: parent.right
                        columns: 3
                        columnSpacing: 28
                        rowSpacing: 18
                        horizontalItemAlignment: Grid.AlignHCenter

                        // Wi-Fi toggle
                        Column {
                            spacing: 6
                            height: 72

                            Rectangle {
                                id: wifiToggleBtn
                                width: 48; height: 48; radius: 24
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: wifiOn ? Qt.rgba(0/255, 150/255, 255/255, 0.25)
                                             : Qt.rgba(255/255, 255/255, 255/255, 0.06)
                                border.color: wifiOn ? Qt.rgba(0/255, 150/255, 255/255, 0.3)
                                                     : Qt.rgba(255/255, 255/255, 255/255, 0.08)
                                border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    source: "/usr/share/yunsh/icons/wifi.svg"
                                    width: 22; height: 22
                                    sourceSize.width: 44; sourceSize.height: 44
                                    fillMode: Image.PreserveAspectFit
                                }

                                // Outer glow when active
                                Rectangle {
                                    anchors.fill: parent; radius: 24
                                    color: "transparent"
                                    border.color: wifiOn ? Qt.rgba(0/255, 150/255, 255/255, 0.12) : "transparent"
                                    border.width: 3
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.scale = 1.1
                                    onExited: parent.scale = 1.0
                                    onClicked: {
                                        wifiOn = !wifiOn
                                        controlCenterRoot.toggleWifi()
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Wi-Fi"
                                color: "#CCCCDD"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }

                        // Bluetooth toggle
                        Column {
                            spacing: 6
                            height: 72

                            Rectangle {
                                id: btToggleBtn
                                width: 48; height: 48; radius: 24
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: bluetoothOn ? Qt.rgba(0/255, 150/255, 255/255, 0.25)
                                                   : Qt.rgba(255/255, 255/255, 255/255, 0.06)
                                border.color: bluetoothOn ? Qt.rgba(0/255, 150/255, 255/255, 0.3)
                                                         : Qt.rgba(255/255, 255/255, 255/255, 0.08)
                                border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    source: "/usr/share/yunsh/icons/bluetooth.svg"
                                    width: 22; height: 22
                                    sourceSize.width: 44; sourceSize.height: 44
                                    fillMode: Image.PreserveAspectFit
                                }

                                Rectangle {
                                    anchors.fill: parent; radius: 24
                                    color: "transparent"
                                    border.color: bluetoothOn ? Qt.rgba(0/255, 150/255, 255/255, 0.12) : "transparent"
                                    border.width: 3
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.scale = 1.1
                                    onExited: parent.scale = 1.0
                                    onClicked: {
                                        bluetoothOn = !bluetoothOn
                                        controlCenterRoot.toggleBluetooth()
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "蓝牙"
                                color: "#CCCCDD"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }

                        // Keyboard toggle
                        Column {
                            spacing: 6
                            height: 72

                            Rectangle {
                                id: keyboardToggleBtn
                                width: 48; height: 48; radius: 24
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "⌨️"
                                    font.pixelSize: 20
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.scale = 1.1
                                    onExited: parent.scale = 1.0
                                    onClicked: controlCenterRoot.toggleKeyboard()
                                }

                                Behavior on scale {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "键盘"
                                color: "#CCCCDD"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }

                        // Screenshot
                        Column {
                            spacing: 6
                            height: 72

                            Rectangle {
                                id: screenshotBtn
                                width: 48; height: 48; radius: 24
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "📷"
                                    font.pixelSize: 20
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.scale = 1.1
                                    onExited: parent.scale = 1.0
                                    onClicked: controlCenterRoot.takeScreenshot()
                                }

                                Behavior on scale {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "截图"
                                color: "#CCCCDD"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // ── Separator line ───────────────────────────────
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                    }

                    // ── Section: Sliders ─────────────────────────────
                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 14

                        // Brightness slider
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 10
                            height: 36

                            Text {
                                text: "☀️"
                                font.pixelSize: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 44
                                height: 6; radius: 3
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.08)

                                Rectangle {
                                    width: parent.width * 0.72
                                    height: parent.height; radius: 3
                                    color: Qt.rgba(0/255, 212/255, 255/255, 0.4)
                                }

                                // Thumb
                                Rectangle {
                                    x: parent.width * 0.72 - 6
                                    y: -4
                                    width: 14; height: 14; radius: 7
                                    color: "#00D4FF"
                                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.2)
                                    border.width: 1
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onPositionChanged: function(mouse) {
                                        var newX = Math.max(0, Math.min(mouse.x, parent.width - 14))
                                        // Slider would update brightness via backend
                                        parent.children[0].width = newX + 6
                                        parent.children[1].x = newX
                                    }
                                }
                            }
                        }

                        // Volume slider
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 10
                            height: 36

                            Text {
                                text: "🔊"
                                font.pixelSize: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 44
                                height: 6; radius: 3
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.08)

                                Rectangle {
                                    width: parent.width * 0.55
                                    height: parent.height; radius: 3
                                    color: Qt.rgba(255/255, 255/255, 255/255, 0.25)
                                }

                                Rectangle {
                                    x: parent.width * 0.55 - 6
                                    y: -4
                                    width: 14; height: 14; radius: 7
                                    color: "#FFFFFF"
                                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.2)
                                    border.width: 1
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onPositionChanged: function(mouse) {
                                        var newX = Math.max(0, Math.min(mouse.x, parent.width - 14))
                                        parent.children[0].width = newX + 6
                                        parent.children[1].x = newX
                                    }
                                }
                            }
                        }
                    }

                    // ── Separator line ───────────────────────────────
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                    }

                    // ── Section: Large controls (Wi-Fi / Bluetooth) ──
                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 12

                        // Wi-Fi card (large)
                        Rectangle {
                            width: (parent.width - 12) / 2
                            height: 72
                            radius: 16
                            color: Qt.rgba(0/255, 150/255, 255/255, 0.08)
                            border.color: Qt.rgba(0/255, 150/255, 255/255, 0.12)
                            border.width: 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Image {
                                    source: "/usr/share/yunsh/icons/wifi.svg"
                                    width: 22; height: 22
                                    sourceSize.width: 44; sourceSize.height: 44
                                    anchors.verticalCenter: parent.verticalCenter
                                    fillMode: Image.PreserveAspectFit
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: "Wi-Fi"
                                        color: "#0096FF"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: wifiOn ? (wifiSSID !== "" ? wifiSSID : "已开启") : "已关闭"
                                        color: wifiOn ? "#88CCFF" : "#666680"
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: "#0096FF"
                                font.pixelSize: 22
                                font.weight: Font.Light
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: parent.color = Qt.rgba(0/255, 150/255, 255/255, 0.15)
                                onExited: parent.color = Qt.rgba(0/255, 150/255, 255/255, 0.08)
                                onClicked: controlCenterRoot.openNetwork()
                            }
                        }

                        // Bluetooth card (large)
                        Rectangle {
                            width: (parent.width - 12) / 2
                            height: 72
                            radius: 16
                            color: Qt.rgba(0/255, 150/255, 255/255, 0.08)
                            border.color: Qt.rgba(0/255, 150/255, 255/255, 0.12)
                            border.width: 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Image {
                                    source: "/usr/share/yunsh/icons/bluetooth.svg"
                                    width: 22; height: 22
                                    sourceSize.width: 44; sourceSize.height: 44
                                    anchors.verticalCenter: parent.verticalCenter
                                    fillMode: Image.PreserveAspectFit
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: "蓝牙"
                                        color: "#0096FF"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: bluetoothOn ? (btDevice !== "" ? btDevice : "已开启") : "已关闭"
                                        color: bluetoothOn ? "#88CCFF" : "#666680"
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: "#0096FF"
                                font.pixelSize: 22
                                font.weight: Font.Light
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: parent.color = Qt.rgba(0/255, 150/255, 255/255, 0.15)
                                onExited: parent.color = Qt.rgba(0/255, 150/255, 255/255, 0.08)
                                onClicked: controlCenterRoot.openBluetooth()
                            }
                        }
                    }

                    // ── Section: Connection info ─────────────────────
                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 4

                        // Wi-Fi status
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 32
                            radius: 8
                            color: wifiOn && wifiSSID !== ""
                                   ? Qt.rgba(0/255, 230/255, 118/255, 0.06)
                                   : "transparent"

                            visible: wifiOn && wifiSSID !== ""

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: "📶"
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Wi-Fi: " + wifiSSID
                                    color: "#88CCFF"
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Bluetooth status
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 32
                            radius: 8
                            color: bluetoothOn && btDevice !== ""
                                   ? Qt.rgba(0/255, 230/255, 118/255, 0.06)
                                   : "transparent"

                            visible: bluetoothOn && btDevice !== ""

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: "🎧"
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "蓝牙: " + btDevice
                                    color: "#88CCFF"
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Time display
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 28
                            radius: 8
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.03)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "🕐"
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: currentTime
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── Animation definitions ──────────────────────────────────────────
    SequentialAnimation {
        id: animateOut

        ParallelAnimation {
            NumberAnimation {
                target: panelContainer
                property: "opacity"
                to: 0.0
                duration: 150
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panelTranslate
                property: "y"
                to: -20
                duration: 150
                easing.type: Easing.InCubic
            }
        }

        ScriptAction {
            script: {
                controlCenterRoot.visible = false
            }
        }
    }

    // ─── Show function (call from parent) ───────────────────────────────
    function show() {
        visible = true
        panelContainer.opacity = 1.0
        panelTranslate.y = 0
        // Reset clock timer on show
        var d = new Date()
        currentTime = d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
        clockTimer.running = true
    }

    // ─── Hide function ──────────────────────────────────────────────────
    function hide() {
        animateOut.start()
        clockTimer.running = false
    }

    // ─── Reset visibility if dismissed externally ───────────────────────
    onVisibleChanged: {
        if (visible) {
            var d = new Date()
            currentTime = d.toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
            clockTimer.running = true
            backdrop.opacity = 1.0
            panelContainer.opacity = 1.0
            panelTranslate.y = 0
        } else {
            clockTimer.running = false
            backdrop.opacity = 0.0
        }
    }
}
