// YUNSH SpaceCapsule + YUNSH Drop nearby workspace transfer.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: capsuleScreen
    anchors.fill: parent

    property var capsules: []
    property var nearbyPeers: []
    property var incomingOffers: []
    property string selectedFilename: ""
    property string statusText: ""
    property bool busy: false
    property bool reduceMotion: false

    signal backToHome()
    signal workspaceExportRequested(string name)
    signal restoreRequested(var capsule)

    function getJson(path, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8591" + path, true)
        xhr.timeout = 6500
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try { callback(JSON.parse(xhr.responseText)) }
            catch (error) { statusText = "无法连接 YUNSH Drop 本地服务" }
        }
        xhr.send()
    }

    function postJson(path, payload, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591" + path, true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 12000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try { callback(JSON.parse(xhr.responseText)) }
            catch (error) {
                busy = false
                statusText = "YUNSH Drop 请求没有完成"
            }
        }
        xhr.send(JSON.stringify(payload))
    }

    function refreshAll() {
        refreshCapsules()
        refreshNearby()
        refreshInbox()
    }

    function refreshCapsules() {
        getJson("/api/space-capsules", function(data) {
            if (data.success)
                capsules = data.capsules || []
            else
                statusText = data.error || "无法读取空间胶囊"
        })
    }

    function refreshNearby() {
        getJson("/api/space-peers", function(data) {
            if (data.success)
                nearbyPeers = data.peers || []
        })
    }

    function refreshInbox() {
        getJson("/api/space-inbox", function(data) {
            if (data.success)
                incomingOffers = data.offers || []
        })
    }

    function exportWorkspace(snapshot, name) {
        if (busy)
            return
        busy = true
        statusText = "正在保存当前工作空间…"
        snapshot.action = "export"
        snapshot.name = name
        postJson("/api/space-capsules", snapshot, function(data) {
            busy = false
            if (data.success) {
                statusText = "工作空间已保存，可选择附近设备发送"
                selectedFilename = data.filename
                capsuleName.text = ""
                refreshCapsules()
                refreshNearby()
            } else {
                statusText = data.error || "保存失败"
            }
        })
    }

    function loadCapsule(filename) {
        if (busy)
            return
        busy = true
        statusText = "正在验证工作空间…"
        postJson("/api/space-capsules", {action: "load", filename: filename}, function(data) {
            busy = false
            if (data.success) {
                statusText = "正在恢复 " + data.capsule.name
                restoreRequested(data.capsule)
            } else {
                statusText = data.error || "无法恢复工作空间"
            }
        })
    }

    function sendToPeer(peer) {
        if (!selectedFilename || busy)
            return
        busy = true
        statusText = "正在加密发送，等待对方确认…"
        postJson("/api/space-transfer", {
            action: "send",
            filename: selectedFilename,
            address: peer.address,
            port: peer.port,
            fingerprint: peer.fingerprint
        }, function(data) {
            busy = false
            statusText = data.success
                ? "已送达 " + peer.name + "，等待对方接受"
                : (data.error || "发送失败")
        })
    }

    function respondToOffer(offerId, action) {
        if (busy)
            return
        busy = true
        statusText = action === "accept" ? "正在验证收到的工作空间…" : "正在拒绝…"
        postJson("/api/space-transfer", {action: action, offerId: offerId}, function(data) {
            busy = false
            if (data.success) {
                statusText = action === "accept" ? "已接受并保存工作空间" : "已拒绝"
                refreshInbox()
                refreshCapsules()
                if (action === "accept" && data.capsule)
                    restoreRequested(data.capsule)
            } else {
                statusText = data.error || "操作失败"
            }
        })
    }

    Timer {
        interval: 4000
        running: capsuleScreen.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            refreshInbox()
            refreshNearby()
        }
    }

    Component.onCompleted: refreshAll()

    Rectangle { anchors.fill: parent; color: "transparent" }

    Column {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 11

        Row {
            width: parent.width
            height: 38
            spacing: 10

            Rectangle {
                width: 88; height: 36; radius: 18; color: "#00D4FF"
                Text { anchors.centerIn: parent; text: "← 返回"; color: "#00151B"; font.pixelSize: 13; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: capsuleScreen.backToHome() }
            }
            Item { width: parent.width - 186; height: 1 }
            Rectangle {
                width: 88; height: 36; radius: 18; color: "#00D4FF"
                Text { anchors.centerIn: parent; text: "刷新附近"; color: "#00151B"; font.pixelSize: 12; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: capsuleScreen.refreshAll() }
            }
        }

        Text {
            text: "SpaceCapsule · YUNSH Drop"
            color: "#FFFFFF"
            font.pixelSize: 25
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: "像隔空投送一样发现同一 Wi‑Fi 或 iPhone 热点中的 YUNSH OS。传输全程加密，对方确认后才能恢复；.yunshspace 文件仍可作为离线备份。"
            color: Qt.rgba(255/255, 255/255, 255/255, 0.58)
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent.width; height: 66; radius: 20
            color: Qt.rgba(250/255, 253/255, 255/255, 0.88)
            border.width: 1; border.color: Qt.rgba(255/255, 255/255, 255/255, 0.75)
            Row {
                anchors.fill: parent; anchors.margins: 10; spacing: 10
                Rectangle {
                    width: parent.width - 190; height: 46; radius: 15
                    color: "#FFFFFF"; border.width: 1
                    border.color: capsuleName.activeFocus ? "#00D4FF" : "#DCE8EE"
                    EditableInput {
                        id: capsuleName
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#121722"; font.pixelSize: 14
                        placeholderText: "空间名称，例如：学习空间"
                        placeholderTextColor: "#87929D"
                    }
                }
                Rectangle {
                    width: 160; height: 46; radius: 23; color: "#00D4FF"
                    opacity: busy ? 0.5 : 1
                    Text { anchors.centerIn: parent; text: busy ? "处理中…" : "保存当前空间"; color: "#00151B"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; enabled: !busy; onClicked: workspaceExportRequested(capsuleName.text) }
                }
            }
        }

        Text {
            width: parent.width
            visible: statusText.length > 0
            text: statusText
            color: statusText.indexOf("失败") >= 0 || statusText.indexOf("无法") >= 0 ? "#FF9A91" : "#7BE7FF"
            font.pixelSize: 12
            elide: Text.ElideMiddle
        }

        ScrollView {
            width: parent.width
            height: parent.height - 220
            clip: true

            Column {
                width: capsuleScreen.width - 44
                spacing: 9

                Text {
                    visible: incomingOffers.length > 0
                    text: "等待你确认"
                    color: "#7BE7FF"; font.pixelSize: 13; font.weight: Font.DemiBold
                }
                Repeater {
                    model: incomingOffers
                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 74; radius: 19
                        color: Qt.rgba(246/255, 252/255, 255/255, 0.91)
                        border.width: 1; border.color: "#8CEEFF"
                        Row {
                            anchors.fill: parent; anchors.margins: 12; spacing: 9
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 196
                                Text { width: parent.width; text: modelData.senderName + " 想发送“" + modelData.name + "”"; color: "#111722"; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { text: modelData.windowCount + " 个窗口"; color: "#64717D"; font.pixelSize: 11 }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter; width: 78; height: 34; radius: 17; color: "#00D4FF"
                                Text { anchors.centerIn: parent; text: "拒绝"; color: "#00151B"; font.pixelSize: 12; font.weight: Font.Medium }
                                MouseArea { anchors.fill: parent; onClicked: respondToOffer(modelData.offerId, "reject") }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter; width: 88; height: 34; radius: 17; color: "#00D4FF"
                                Text { anchors.centerIn: parent; text: "接受并恢复"; color: "#00151B"; font.pixelSize: 12; font.weight: Font.Medium }
                                MouseArea { anchors.fill: parent; onClicked: respondToOffer(modelData.offerId, "accept") }
                            }
                        }
                    }
                }

                Text {
                    text: "我的空间"
                    color: "#B7BBC7"; font.pixelSize: 13; font.weight: Font.Medium
                    topPadding: 5
                }
                Text {
                    width: parent.width
                    visible: capsules.length === 0
                    text: "还没有保存的工作空间"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.34)
                    font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; topPadding: 22
                }
                Repeater {
                    model: capsules
                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 72; radius: 19
                        color: selectedFilename === modelData.filename
                            ? Qt.rgba(222/255, 249/255, 255/255, 0.93)
                            : Qt.rgba(248/255, 252/255, 255/255, 0.84)
                        border.width: 1
                        border.color: selectedFilename === modelData.filename ? "#00D4FF" : Qt.rgba(255/255, 255/255, 255/255, 0.68)
                        Row {
                            anchors.fill: parent; anchors.margins: 12; spacing: 9
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 190
                                Text { width: parent.width; text: modelData.name; color: "#121722"; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { width: parent.width; text: modelData.windowCount + " 个窗口 · " + modelData.filename; color: "#66727D"; font.pixelSize: 10; elide: Text.ElideMiddle }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter; width: 76; height: 34; radius: 17; color: "#00D4FF"
                                Text { anchors.centerIn: parent; text: "恢复"; color: "#00151B"; font.pixelSize: 12; font.weight: Font.Medium }
                                MouseArea { anchors.fill: parent; onClicked: loadCapsule(modelData.filename) }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter; width: 86; height: 34; radius: 17; color: "#00D4FF"
                                Text { anchors.centerIn: parent; text: selectedFilename === modelData.filename ? "已选发送" : "发送"; color: "#00151B"; font.pixelSize: 12; font.weight: Font.Medium }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selectedFilename = modelData.filename
                                        statusText = "请选择下方附近设备"
                                        refreshNearby()
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: selectedFilename.length > 0
                    text: "附近的 YUNSH 设备"
                    color: "#7BE7FF"; font.pixelSize: 13; font.weight: Font.DemiBold
                    topPadding: 6
                }
                Text {
                    width: parent.width
                    visible: selectedFilename.length > 0 && nearbyPeers.length === 0
                    text: "未发现设备。两台设备需处于同一 Wi‑Fi 或同一个 iPhone 热点。"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.42)
                    font.pixelSize: 12; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                }
                Repeater {
                    model: selectedFilename.length > 0 ? nearbyPeers : []
                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 62; radius: 18
                        color: Qt.rgba(246/255, 252/255, 255/255, 0.90)
                        border.width: 1; border.color: "#CDECF3"
                        Row {
                            anchors.fill: parent; anchors.margins: 11; spacing: 12
                            Rectangle { width: 40; height: 40; radius: 20; color: "#DDF8FF"; Text { anchors.centerIn: parent; text: "Y"; color: "#00AFCF"; font.pixelSize: 18; font.weight: Font.Bold } }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 160
                                Text { width: parent.width; text: modelData.name; color: "#121722"; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { text: "YUNSH OS " + modelData.version + " · 加密传输"; color: "#66727D"; font.pixelSize: 10 }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter; width: 82; height: 36; radius: 18; color: "#00D4FF"
                                Text { anchors.centerIn: parent; text: "发送"; color: "#00151B"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                MouseArea { anchors.fill: parent; enabled: !busy; onClicked: sendToPeer(modelData) }
                            }
                        }
                    }
                }
            }
        }
    }
}
