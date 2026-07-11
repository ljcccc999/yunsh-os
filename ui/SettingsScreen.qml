// YUNSH OS v1.0 - Settings Screen (visionOS / iOS Style)
// iOS grouped table style with glass cards, detailed About + system info

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: settingsScreen
    anchors.fill: parent
    visible: false
    color: "transparent"
    z: 50
    
    signal backToHome()
    signal openUpdatePage()
    signal openUpdateHistory()
    signal openNetworkSettings()
    signal openBluetoothSettings()
    signal openSystemInfo()

    property string osVersionName: "YUNSH OS v1.0.1"

    function loadVersionConfig() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file:///etc/yunsh/version.conf", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 0 || xhr.status === 200) {
                    var text = xhr.responseText
                    var lines = text.split('\n')
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim()
                        if (line.indexOf('VERSION=') === 0) {
                            osVersionName = "YUNSH OS " + line.substring(8)
                        }
                    }
                }
            }
        }
        xhr.send()
    }

    Component.onCompleted: loadVersionConfig()
    signal openDisplaySettings()
    signal openSoundSettings()
    signal openLanguageSettings()
    signal openDateTimeSettings()
    
    // ── Helper: send command to update daemon ──
    function sendDaemonCmd(cmd) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:8080/api/update-command", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(cmd));
    }
    
    // Header
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "transparent"
        
        // Back capsule
        Rectangle {
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 80; height: 32; radius: 16
            color: Qt.rgba(0/255, 212/255, 255/255, 0.1)
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.15)
            border.width: 1
            
            Text {
                anchors.centerIn: parent; text: "← 返回"
                color: "#00D4FF"; font.pixelSize: 14; font.weight: Font.Medium
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.2)
                onExited: parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.1)
                onClicked: settingsScreen.backToHome()
            }
        }
        
        Text {
            anchors.centerIn: parent; text: "设置"
            color: "#FFFFFF"; font.pixelSize: 20; font.weight: Font.Bold
        }
    }
    
    // Settings list (iOS grouped style)
    Flickable {
        anchors.top: parent.top; anchors.topMargin: 60
        anchors.left: parent.left; anchors.leftMargin: 32
        anchors.right: parent.right; anchors.rightMargin: 32
        anchors.bottom: parent.bottom; anchors.bottomMargin: 16
        contentHeight: settingsColumn.height + 32
        clip: true
        
        Column {
            id: settingsColumn
            width: parent.width
            spacing: 2
            
            // ── Section: 连接 ──
            Text {
                text: "连接"
                color: "#8888A0"
                font.pixelSize: 13
                font.weight: Font.Medium
                leftPadding: 16
                bottomPadding: 6
                topPadding: 12
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/wifi.svg"
                iconSize: 18
                title: "Wi-Fi"
                subtitle: "选择网络"
                showArrow: true
                onClicked: settingsScreen.openNetworkSettings()
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/bluetooth.svg"
                iconSize: 18
                title: "蓝牙"
                subtitle: "设备和连接"
                showArrow: true
                onClicked: settingsScreen.openBluetoothSettings()
            }
            
            // ── Section: 显示与声音 ──
            Text {
                text: "显示与声音"
                color: "#8888A0"
                font.pixelSize: 13
                font.weight: Font.Medium
                leftPadding: 16
                bottomPadding: 6
                topPadding: 20
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/settings.svg"
                iconSize: 18
                title: "显示与亮度"
                subtitle: "亮度, 字体大小, AR 透明背景"
                showArrow: true
                onClicked: settingsScreen.openDisplaySettings()
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/settings.svg"
                iconSize: 18
                title: "声音"
                subtitle: "音量, 输入输出"
                showArrow: true
                onClicked: settingsScreen.openSoundSettings()
            }
            
            // ── Section: 通用 ──
            Text {
                text: "通用"
                color: "#8888A0"
                font.pixelSize: 13
                font.weight: Font.Medium
                leftPadding: 16
                bottomPadding: 6
                topPadding: 20
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/settings.svg"
                iconSize: 18
                title: "语言与输入"
                subtitle: selectedLanguageDisplay
                showArrow: true
                onClicked: settingsScreen.openLanguageSettings()
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/settings.svg"
                iconSize: 18
                title: "日期与时间"
                subtitle: "24 小时制, Asia/Shanghai"
                showArrow: true
                onClicked: settingsScreen.openDateTimeSettings()
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/about.svg"
                iconSize: 18
                title: "关于本机"
                subtitle: osVersionName + " · 内存 · 存储"
                showArrow: true
                onClicked: settingsScreen.openSystemInfo()
            }
            
            // ── Section: 软件更新 ──
            Text {
                text: "软件更新"
                color: "#8888A0"
                font.pixelSize: 13
                font.weight: Font.Medium
                leftPadding: 16
                bottomPadding: 6
                topPadding: 20
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/update.svg"
                iconSize: 18
                title: "系统更新"
                subtitle: osVersionName + " · 点击检查"
                showArrow: true
                onClicked: settingsScreen.openUpdatePage()
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/update.svg"
                iconSize: 18
                title: "更新历史"
                subtitle: "查看系统更新记录"
                showArrow: true
                onClicked: settingsScreen.openUpdateHistory()
            }
            
            // ── Section: 更新通道 ──
            Text {
                text: "更新通道"
                color: "#8888A0"
                font.pixelSize: 13
                font.weight: Font.Medium
                leftPadding: 16
                bottomPadding: 6
                topPadding: 20
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/update.svg"
                iconSize: 18
                title: "接收测试版更新"
                subtitle: "开启后可获得最新测试版系统"
                isToggle: true
                toggleState: false
                onToggled: function(state) {
                    if (state) {
                        sendDaemonCmd({"action":"set_channel","channel":"beta"})
                    } else {
                        sendDaemonCmd({"action":"set_channel","channel":"stable"})
                    }
                }
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/update.svg"
                iconSize: 18
                title: "大版本更新"
                subtitle: "主版本号升级（如 v1 → v2）"
                isToggle: true
                toggleState: true
                onToggled: function(state) {
                    sendDaemonCmd({"action":"set_allow_major_update","allow_major_update":state})
                }
            }
            
            // ── Section: 系统 ──
            Text {
                text: "系统"
                color: "#8888A0"
                font.pixelSize: 13
                font.weight: Font.Medium
                leftPadding: 16
                bottomPadding: 6
                topPadding: 20
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/files.svg"
                iconSize: 18
                title: "存储"
                subtitle: "4.5 GB / 32 GB 已使用"
                showArrow: true
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/settings.svg"
                iconSize: 18
                title: "恢复出厂设置"
                subtitle: "清除数据，保留系统文件"
                showArrow: true
                titleColor: "#FF5252"
                onClicked: factoryResetDialog.open()
            }
        }
        
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }

    // ── Language display (placeholder) ──
    readonly property string selectedLanguageDisplay: "简体中文 · 拼音"
    
    // ════════════════════════════════════════════════════
    // Factory Reset Dialog
    // ════════════════════════════════════════════════════
    Rectangle {
        id: factoryResetDialog
        anchors.fill: parent
        color: Qt.rgba(0/255, 0/255, 0/255, 0.6)
        visible: false
        z: 200
        
        MouseArea { anchors.fill: parent; onClicked: factoryResetDialog.visible = false }
        
        Rectangle {
            anchors.centerIn: parent
            width: 420; height: 260; radius: 32
            color: Qt.rgba(15/255, 15/255, 32/255, 0.5)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04); border.width: 1
            
            Column {
                anchors.centerIn: parent; spacing: 16
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⚠️"
                    font.pixelSize: 36
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "恢复出厂设置"
                    color: "#FF5252"; font.pixelSize: 20; font.weight: Font.Bold
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 340; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: "这将清除所有用户数据，重置激活状态。\n系统文件和 UI 组件不会被删除。"
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.4); font.pixelSize: 13
                }
                
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
                    
                    Rectangle {
                        width: 140; height: 44; radius: 22
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
                        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04); border.width: 1
                        Text { anchors.centerIn: parent; text: "取消"; color: "#8888A0"; font.pixelSize: 14 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: factoryResetDialog.visible = false
                        }
                    }
                    
                    Rectangle {
                        width: 160; height: 44; radius: 22
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                        border.color: "#FF5252"; border.width: 1
                        Text { anchors.centerIn: parent; text: "恢复出厂设置"; color: "#FF5252"; font.pixelSize: 14 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                factoryResetDialog.visible = false
                                // Trigger factory reset script
                                var cmd = "/usr/bin/yunsh-factory-reset &";
                                console.log("Triggering factory reset: " + cmd);
                                Qt.callLater(function() {
                                    Qt.quit()
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
