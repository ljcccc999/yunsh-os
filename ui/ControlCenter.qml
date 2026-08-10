// YUNSH system menu — anchored to the persistent top-left YUNSH mark.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool recording: false
    property string wifiSSID: ""
    property string btDevice: ""
    property string currentTime: "00:00"
    property int brightnessLevel: 72
    property int volumeLevel: 55
    property bool glassesConnected: false
    property bool iPhoneConnected: false
    property int glassesBattery: -1
    property int hostBattery: -1
    property bool focusMode: false
    property bool stereoEnabled: false
    property bool reduceMotion: false
    property bool appIconsManuallyHidden: false

    signal dismissPanel()
    signal openNetwork()
    signal openBluetooth()
    signal openSettings()
    signal openPhotos()
    signal openUpdate()
    signal takeScreenshot()
    signal takeRegionScreenshot()
    signal toggleRecording()
    signal toggleWifi()
    signal toggleBluetooth()
    signal toggleKeyboard()
    signal toggleFocusMode()
    signal toggleAppIcons()
    signal openSpatialDisplay()
    signal requestLock()
    signal requestSystemAction(string action)

    visible: false
    z: 150

    function postJson(path, payload, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591" + path, true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && callback)
                callback(xhr)
        }
        xhr.send(JSON.stringify(payload))
    }

    function refreshSystemState() {
        var networkRequest = new XMLHttpRequest()
        networkRequest.open("GET", "http://127.0.0.1:8591/api/network-status", true)
        networkRequest.onreadystatechange = function() {
            if (networkRequest.readyState === XMLHttpRequest.DONE && networkRequest.status === 200) {
                try {
                    var state = JSON.parse(networkRequest.responseText)
                    wifiOn = state.enabled === true
                    wifiSSID = state.ssid || ""
                } catch (_error) {}
            }
        }
        networkRequest.send()

        var bluetoothRequest = new XMLHttpRequest()
        bluetoothRequest.open("GET", "http://127.0.0.1:8591/api/bluetooth-status", true)
        bluetoothRequest.onreadystatechange = function() {
            if (bluetoothRequest.readyState === XMLHttpRequest.DONE && bluetoothRequest.status === 200) {
                try {
                    var state = JSON.parse(bluetoothRequest.responseText)
                    bluetoothOn = state.powered === true
                    btDevice = ""
                    var devices = state.paired_devices || []
                    for (var i = 0; i < devices.length; i++) {
                        if (devices[i].connected) {
                            btDevice = devices[i].name || ""
                            break
                        }
                    }
                } catch (_error) {}
            }
        }
        bluetoothRequest.send()

        var glassesRequest = new XMLHttpRequest()
        glassesRequest.open("GET", "http://127.0.0.1:8591/api/glasses-status", true)
        glassesRequest.onreadystatechange = function() {
            if (glassesRequest.readyState === XMLHttpRequest.DONE && glassesRequest.status === 200) {
                try {
                    var glasses = JSON.parse(glassesRequest.responseText)
                    glassesConnected = glasses.connected === true
                    glassesBattery = glasses.battery === null || glasses.battery === undefined
                        ? -1 : Math.max(0, Math.min(100, Number(glasses.battery)))
                    if (glasses.brightness !== null && glasses.brightness !== undefined)
                        brightnessLevel = Math.max(0, Math.min(100, Number(glasses.brightness)))
                } catch (_error) {}
            }
        }
        glassesRequest.send()

        var linkRequest = new XMLHttpRequest()
        linkRequest.open("GET", "http://127.0.0.1:8591/api/link-status", true)
        linkRequest.onreadystatechange = function() {
            if (linkRequest.readyState === XMLHttpRequest.DONE && linkRequest.status === 200) {
                try { iPhoneConnected = JSON.parse(linkRequest.responseText).connected === true }
                catch (_error) {}
            }
        }
        linkRequest.send()

        var powerRequest = new XMLHttpRequest()
        powerRequest.open("GET", "http://127.0.0.1:8591/api/power-status", true)
        powerRequest.onreadystatechange = function() {
            if (powerRequest.readyState === XMLHttpRequest.DONE && powerRequest.status === 200) {
                try {
                    var power = JSON.parse(powerRequest.responseText)
                    hostBattery = power.available && power.battery !== null && power.battery !== undefined
                        ? Math.max(0, Math.min(100, Number(power.battery))) : -1
                } catch (_error) {}
            }
        }
        powerRequest.send()
    }

    function applyWifiPower() {
        postJson("/api/network", {command: "power", enabled: wifiOn},
                 function() { refreshSystemState() })
    }

    function applyBluetoothPower() {
        postJson("/api/bluetooth", {
            command: bluetoothOn ? "power_on" : "power_off"
        }, function() { refreshSystemState() })
    }

    function activateTile(action) {
        if (action === "wifi") {
            wifiOn = !wifiOn
            toggleWifi()
        } else if (action === "bluetooth") {
            bluetoothOn = !bluetoothOn
            toggleBluetooth()
        } else if (action === "keyboard") {
            toggleKeyboard()
        } else if (action === "screenshot") {
            takeScreenshot()
        } else if (action === "region") {
            takeRegionScreenshot()
        } else if (action === "record") {
            toggleRecording()
        } else if (action === "focus") {
            toggleFocusMode()
        } else if (action === "apps") {
            toggleAppIcons()
        } else if (action === "display") {
            openSpatialDisplay()
        } else if (action === "photos") {
            openPhotos()
        } else if (action === "settings") {
            openSettings()
        } else if (action === "update") {
            openUpdate()
        } else if (action === "lock") {
            requestLock()
        }
    }

    function tileActive(action) {
        if (action === "wifi") return wifiOn
        if (action === "bluetooth") return bluetoothOn
        if (action === "record") return recording
        if (action === "focus") return focusMode
        if (action === "apps") return !appIconsManuallyHidden
        if (action === "display") return stereoEnabled
        return false
    }

    Timer {
        id: clockTimer
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: currentTime = new Date().toLocaleTimeString(
                         Qt.locale("zh_CN"), "HH:mm")
    }

    Timer {
        id: brightnessTimer
        interval: 120
        onTriggered: root.postJson("/api/glasses", {
            action: "set_brightness", value: brightnessLevel
        })
    }

    Timer {
        id: volumeTimer
        interval: 120
        onTriggered: root.postJson("/api/audio", {
            action: "set_volume", value: volumeLevel
        })
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.34)
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
    }

    Rectangle {
        id: menu
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 66
        width: Math.min(520, parent.width - 36)
        height: Math.min(790, parent.height - 86)
        radius: 32
        color: Qt.rgba(248/255, 253/255, 1, 0.72)
        border.width: 1
        border.color: "#FFFFFF"
        clip: true
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96
        transformOrigin: Item.TopLeft

        Behavior on opacity {
            NumberAnimation { duration: root.reduceMotion ? 70 : 170 }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.reduceMotion ? 70 : 220
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 30
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.16)
            z: 2
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 22
            contentHeight: content.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            z: 1

            Column {
                id: content
                width: parent.width
                spacing: 18

                Row {
                    width: parent.width
                    height: 48
                    spacing: 12
                    Image {
                        source: "/usr/share/yunsh/logo/logo-32.png"
                        width: 34; height: 34
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Column {
                        width: parent.width - 120
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: "YUNSH"
                            color: "#101820"
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.1
                        }
                        Text {
                            text: (wifiSSID.length ? wifiSSID : "YUNSH OS")
                                  + (recording ? " · 正在录屏" : "")
                            color: recording ? "#E43A45" : "#61707C"
                            font.pixelSize: 11
                        }
                    }
                    Text {
                        text: currentTime
                        color: "#101820"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Grid {
                    width: parent.width
                    columns: 4
                    spacing: 10

                    Repeater {
                        model: [
                            {label: "Wi-Fi", icon: "wifi.svg", action: "wifi"},
                            {label: "蓝牙", icon: "bluetooth.svg", action: "bluetooth"},
                            {label: "键盘", icon: "keyboard.svg", action: "keyboard"},
                            {label: "全屏截图", icon: "screenshot.svg", action: "screenshot"},
                            {label: "区域截图", icon: "screenshot.svg", action: "region"},
                            {label: recording ? "停止录屏" : "录屏", icon: "screen-relay.svg", action: "record"},
                            {label: "专注", icon: "metaverse.svg", action: "focus"},
                            {label: appIconsManuallyHidden ? "显示 App" : "隐藏 App", icon: "appstore.svg", action: "apps"},
                            {label: "显示", icon: "display.svg", action: "display"},
                            {label: "相册", icon: "photos.svg", action: "photos"},
                            {label: "设置", icon: "settings.svg", action: "settings"},
                            {label: "系统更新", icon: "update.svg", action: "update"},
                            {label: "锁定", icon: "keyboard.svg", action: "lock"}
                        ]

                        Rectangle {
                            id: actionTile
                            required property var modelData
                            width: (content.width - 30) / 4
                            height: 82
                            radius: 20
                            property bool active: root.tileActive(modelData.action)
                            color: tileMouse.pressed ? "#DDF7FD"
                                : (active ? Qt.rgba(214/255, 249/255, 1, 0.72) : Qt.rgba(1, 1, 1, 0.60))
                            border.width: 1
                            border.color: active ? "#8DEAFF" : "#DDEBF0"
                            scale: tileMouse.pressed ? 0.96
                                : (tileMouse.containsMouse ? 1.035 : 1)

                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 38
                                    height: 38
                                    radius: 19
                                    color: actionTile.active
                                        ? Qt.rgba(0/255, 212/255, 255/255, 0.16)
                                        : Qt.rgba(1, 1, 1, 0.48)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.72)
                                    Image {
                                        anchors.centerIn: parent
                                        source: "/usr/share/yunsh/icons/" + modelData.icon
                                        width: 21
                                        height: 21
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: "#26333D"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }
                            }
                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.activateTile(modelData.action)
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 98
                    radius: 24
                    color: Qt.rgba(1, 1, 1, 0.64)
                    border.width: 1
                    border.color: "#DDEBF0"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14
                        Rectangle {
                            width: 48; height: 64; radius: 16
                            color: Qt.rgba(0/255, 212/255, 255/255, 0.12)
                            border.width: 1
                            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.35)
                            Image {
                                anchors.centerIn: parent
                                source: "/usr/share/yunsh/icons/screen-relay.svg"
                                width: 26; height: 26
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 190
                            spacing: 4
                            Text { text: "YUNSH Link"; color: "#17212A"; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text {
                                text: iPhoneConnected ? "iPhone 已连接 · 可远程控制" : "iPhone 未连接 · 可稍后配对"
                                color: iPhoneConnected ? "#087F5B" : "#61707C"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: glassesConnected ? "眼镜已连接" : "眼镜未连接"
                                color: "#61707C"; font.pixelSize: 10
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Text { text: glassesBattery >= 0 ? "眼镜 " + glassesBattery + "%" : "眼镜 —"; color: "#26333D"; font.pixelSize: 11; font.weight: Font.Medium }
                            Text { text: hostBattery >= 0 ? "主机 " + hostBattery + "%" : "主机 —"; color: "#61707C"; font.pixelSize: 11 }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 118
                    radius: 24
                    color: Qt.rgba(1, 1, 1, 0.64)
                    border.width: 1
                    border.color: "#DDEBF0"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 20

                        Row {
                            width: parent.width
                            spacing: 12
                            Text { text: "☀"; color: "#17212A"; width: 20; font.pixelSize: 17 }
                            Slider {
                                width: parent.width - 32
                                from: 0; to: 100
                                value: brightnessLevel
                                onMoved: {
                                    brightnessLevel = Math.round(value)
                                    brightnessTimer.restart()
                                }
                            }
                        }
                        Row {
                            width: parent.width
                            spacing: 12
                            Text { text: "◖"; color: "#17212A"; width: 20; font.pixelSize: 17 }
                            Slider {
                                width: parent.width - 32
                                from: 0; to: 100
                                value: volumeLevel
                                onMoved: {
                                    volumeLevel = Math.round(value)
                                    volumeTimer.restart()
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: [
                            {label: "网络详情", action: "network"},
                            {label: "蓝牙设备", action: "bluetooth"}
                        ]
                        Rectangle {
                            required property var modelData
                            width: (content.width - 10) / 2
                            height: 48
                            radius: 18
                            color: detailMouse.pressed ? "#DDF7FD" : Qt.rgba(1, 1, 1, 0.60)
                            border.width: 1
                            border.color: "#DDEBF0"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label + "  ›"
                                color: "#17212A"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: detailMouse
                                anchors.fill: parent
                                onClicked: {
                                    if (modelData.action === "network") root.openNetwork()
                                    else root.openBluetooth()
                                }
                            }
                        }
                    }
                }

                Text {
                    text: "电源与恢复"
                    color: "#61707C"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    leftPadding: 4
                }

                Row {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: [
                            {label: "重新启动", action: "restart", danger: false},
                            {label: "关机", action: "shutdown", danger: false},
                            {label: "恢复出厂", action: "factory_reset", danger: true}
                        ]
                        Rectangle {
                            required property var modelData
                            width: (content.width - 20) / 3
                            height: 48
                            radius: 18
                            color: powerMouse.pressed
                                ? (modelData.danger ? "#FFE0E2" : "#E7F4F7")
                                : Qt.rgba(1, 1, 1, 0.60)
                            border.width: 1
                            border.color: modelData.danger ? "#FFB8BE" : "#DDEBF0"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: modelData.danger ? "#D62F3A" : "#17212A"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: powerMouse
                                anchors.fill: parent
                                onClicked: root.requestSystemAction(modelData.action)
                            }
                        }
                    }
                }
            }
        }
    }

    function show() {
        visible = true
        currentTime = new Date().toLocaleTimeString(Qt.locale("zh_CN"), "HH:mm")
        refreshSystemState()
    }

    function hide() {
        visible = false
    }
}
