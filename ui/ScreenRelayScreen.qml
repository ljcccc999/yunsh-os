import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: relay
    anchors.fill: parent
    property bool live: false
    property real lastFrame: 0
    signal backToHome()

    function refreshStatus() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8591/api/screen-relay-status", true)
        xhr.timeout = 500
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var data = JSON.parse(xhr.responseText)
                live = data.live === true
                if (data.lastFrame && data.lastFrame !== lastFrame) {
                    lastFrame = data.lastFrame
                    phoneFrame.source = ""
                    Qt.callLater(function() {
                        phoneFrame.source = "file:///run/yunsh/screen-relay.jpg"
                    })
                }
            } catch (error) {
                live = false
            }
        }
        xhr.send()
    }

    Timer {
        interval: 180
        running: relay.visible
        repeat: true
        onTriggered: relay.refreshStatus()
    }

    Rectangle { anchors.fill: parent; color: "#050607" }

    Image {
        id: phoneFrame
        anchors.fill: parent
        anchors.margins: 10
        fillMode: Image.PreserveAspectFit
        cache: false
        asynchronous: true
        visible: live
    }

    Column {
        anchors.centerIn: parent
        spacing: 14
        visible: !live
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "iPhone Screen Relay"
            color: "#FFFFFF"
            font.pixelSize: 25
            font.weight: Font.DemiBold
        }
        Text {
            width: 470
            text: "在 YUNSH Link 中完成密钥配对，然后点“开始投屏”。iOS 会显示系统广播确认，只有你明确开始后画面才会传输。"
            color: "#AAB3BC"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Rectangle {
        anchors.left: parent.left; anchors.leftMargin: 18
        anchors.top: parent.top; anchors.topMargin: 16
        width: 86; height: 36; radius: 18
        color: "#00D4FF"
        Text { anchors.centerIn: parent; text: "← 返回"; color: "#00151B"; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { anchors.fill: parent; onClicked: relay.backToHome() }
    }

    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 18
        anchors.top: parent.top; anchors.topMargin: 16
        width: 88; height: 32; radius: 16
        color: live ? "#1ED69A" : "#00D4FF"
        Text { anchors.centerIn: parent; text: live ? "直播中" : "等待 iPhone"; color: "#00151B"; font.pixelSize: 11; font.weight: Font.DemiBold }
    }
}
