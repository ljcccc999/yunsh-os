import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: androidScreen
    anchors.fill: parent
    color: "transparent"

    property string targetApp: "appstore"
    property string setupState: "pending"
    property string statusMessage: "正在检查 Android 运行环境"
    property string statusError: ""
    property int setupProgress: 0
    property bool runtimeReady: false
    property bool requestBusy: false

    function request(action, appId) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 10000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            requestBusy = false
            try {
                var data = JSON.parse(xhr.responseText)
                if (action === "android_status") {
                    setupState = data.state || "pending"
                    setupProgress = data.progress || 0
                    runtimeReady = data.ready === true
                    statusMessage = data.message || (runtimeReady
                        ? "Android 运行环境已就绪"
                        : "Android 运行环境正在后台准备")
                    statusError = data.error || ""
                } else if (data.status === "ok") {
                    statusMessage = data.message || "正在打开"
                    statusError = ""
                } else {
                    statusMessage = data.message || "Android 运行环境尚未就绪"
                    statusError = data.error || ""
                }
            } catch (error) {
                statusError = "无法连接 Android 管理服务"
            }
        }
        var payload = {"action": action}
        if (appId)
            payload.appId = appId
        xhr.send(JSON.stringify(payload))
    }

    function refreshStatus() {
        request("android_status", "")
    }

    function openTarget() {
        requestBusy = true
        request("launch", targetApp)
    }

    function retrySetup() {
        requestBusy = true
        request("android_retry", "")
        retryRefresh.restart()
    }

    Timer {
        interval: runtimeReady ? 10000 : 3000
        running: androidScreen.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: refreshStatus()
    }

    Timer {
        id: retryRefresh
        interval: 1200
        repeat: false
        onTriggered: refreshStatus()
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 520)
        spacing: 20

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 82
            height: 82
            radius: 41
            color: Qt.rgba(255/255, 152/255, 0/255, 0.14)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.10)

            Image {
                anchors.centerIn: parent
                width: 44
                height: 44
                source: targetApp === "files"
                    ? "/usr/share/yunsh/icons/files.svg"
                    : "/usr/share/yunsh/icons/appstore.svg"
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: targetApp === "files" ? "Files" : "Android Apps"
            color: "#17212A"
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: statusError.length > 0 ? statusError : statusMessage
            color: statusError.length > 0 ? "#C43D4A" : Qt.rgba(23/255, 33/255, 42/255, 0.64)
            font.pixelSize: 14
        }

        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(70/255, 88/255, 102/255, 0.18)
            visible: !runtimeReady && setupState !== "error" && setupState !== "display_unavailable"

            Rectangle {
                width: parent.width * Math.max(0.05, setupProgress / 100)
                height: parent.height
                radius: parent.radius
                color: "#00D4FF"
                Behavior on width { NumberAnimation { duration: 240 } }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            GlassButton {
                width: 170
                height: 46
                enabled: runtimeReady && !requestBusy
                bgColor: Qt.rgba(0/255, 212/255, 255/255, 0.24)
                onClicked: openTarget()
                Text {
                    anchors.centerIn: parent
                    text: requestBusy ? "正在打开…" :
                        (targetApp === "files" ? "打开文件" : "打开 F-Droid")
                    color: "#17212A"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
            }

            GlassButton {
                width: 132
                height: 46
                enabled: !requestBusy
                visible: !runtimeReady || statusError.length > 0
                onClicked: retrySetup()
                Text {
                    anchors.centerIn: parent
                    text: "重试准备"
                    color: "#00D4FF"
                    font.pixelSize: 14
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: runtimeReady
                ? "应用在隔离的 Android 容器中运行"
                : (setupState === "error" || setupState === "display_unavailable"
                    ? "系统桌面可以正常使用；修复网络或图形环境后可重新准备 Android"
                    : "系统桌面可以正常使用；Android 镜像会在后台下载并自动重试")
            color: Qt.rgba(23/255, 33/255, 42/255, 0.46)
            font.pixelSize: 12
        }
    }
}
