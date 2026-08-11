// YUNSH OS v1.0 - Settings Screen (visionOS / iOS Style)
// iOS grouped table style with glass cards, detailed About + system info

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: settingsScreen
    anchors.fill: parent
    visible: true
    color: "transparent"
    z: 50
    
    signal backToHome()
    signal openUpdatePage()
    signal openUpdateHistory()
    signal openNetworkSettings()
    signal openBluetoothSettings()
    signal openSystemInfo()
    signal openComfortDna()
    signal requestFactoryReset()

    property string osVersionName: "YUNSH OS v3.1.1"
    property string selectedLanguageDisplay: "简体中文 · 拼音"
    property int autoLockSeconds: 120
    property bool lockPasswordEnabled: true
    signal requestAutoLockSeconds(int seconds)
    signal requestLockPasswordEnabled(bool enabled)

    function autoLockLabel() {
        if (autoLockSeconds <= 0) return "永不自动熄屏"
        if (autoLockSeconds < 60) return autoLockSeconds + " 秒后自动熄屏并锁定"
        return (autoLockSeconds / 60) + " 分钟后自动熄屏并锁定"
    }

    function cycleAutoLock() {
        var presets = [30, 60, 120, 300, 600, 0]
        var index = presets.indexOf(autoLockSeconds)
        requestAutoLockSeconds(presets[(index + 1 + presets.length) % presets.length])
    }

    function loadVersionConfig() {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 3000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return
            try {
                var values = JSON.parse(xhr.responseText || "{}")
                if (values.version)
                    osVersionName = "YUNSH OS " + values.version
            } catch (_error) {}
        }
        xhr.send(JSON.stringify({action: "system_settings"}))
    }

    function loadLanguageConfig() {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 3000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return
            try {
                var values = JSON.parse(xhr.responseText || "{}")
                selectedLanguageDisplay = (values.language || "简体中文")
                    + " · " + (values.keyboard || "拼音")
            } catch (_error) {}
        }
        xhr.send(JSON.stringify({action: "system_settings"}))
    }

    Component.onCompleted: {
        loadVersionConfig()
        loadLanguageConfig()
    }
    signal openDisplaySettings()
    signal openSoundSettings()
    
    // ── Helper: send command to update daemon ──
    function sendDaemonCmd(cmd) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:8591/api/update-config", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(cmd));
    }

    function changeBootPassword() {
        passwordError = ""
        if (newPasswordField.text.length < 4) {
            passwordError = "新密码至少需要 4 个字符"
            return
        }
        if (newPasswordField.text !== confirmPasswordField.text) {
            passwordError = "两次输入的新密码不一致"
            return
        }
        passwordBusy = true
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8591/api/boot-password", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 15000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            passwordBusy = false
            try {
                var body = JSON.parse(xhr.responseText || "{}")
                if (!body.success) {
                    passwordError = body.error || "密码修改失败"
                    return
                }
                currentPasswordField.text = ""
                newPasswordField.text = ""
                confirmPasswordField.text = ""
                passwordDialog.visible = false
                passwordSuccess.visible = true
                passwordSuccessTimer.restart()
            } catch (_error) {
                passwordError = "系统服务返回异常"
            }
        }
        xhr.ontimeout = function() {
            passwordBusy = false
            passwordError = "修改超时，请重试"
        }
        xhr.send(JSON.stringify({
            currentPassword: currentPasswordField.text,
            newPassword: newPasswordField.text
        }))
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
            color: "#17212A"; font.pixelSize: 20; font.weight: Font.Bold
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
                title: "YUNSH 眼镜"
                subtitle: "配对、重新连接与管理头部追踪设备"
                showArrow: true
                onClicked: settingsScreen.openBluetoothSettings()
            }

            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/bluetooth.svg"
                iconSize: 18
                title: "YUNSH Link / iPhone"
                subtitle: "等待手机连接、回正与系统控制"
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
                iconSource: "/usr/share/yunsh/icons/display.svg"
                iconSize: 18
                title: "空间显示"
                subtitle: "当前双屏镜像、高级 SBS、3DoF 与舒适度"
                showArrow: true
                onClicked: settingsScreen.openDisplaySettings()
            }

            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/capsule.svg"
                iconSize: 18
                title: "Comfort DNA"
                subtitle: "调整头追平滑、视野与动效舒适起点"
                showArrow: true
                onClicked: settingsScreen.openComfortDna()
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/sound.svg"
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
                iconSource: "/usr/share/yunsh/icons/language.svg"
                iconSize: 18
                title: "语言与输入"
                subtitle: selectedLanguageDisplay + " · 在激活流程中设置"
                showArrow: false
            }

            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/lock.svg"
                iconSize: 18
                title: "锁屏需要密码"
                subtitle: lockPasswordEnabled ? "已开启 · 不影响终端与 SSH 密码" : "已关闭 · 锁屏点击即可唤醒"
                isToggle: true
                toggleState: lockPasswordEnabled
                onToggled: function(state) { settingsScreen.requestLockPasswordEnabled(state) }
            }

            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/lock.svg"
                iconSize: 18
                title: "本机锁定密码"
                subtitle: "修改 Linux 用户 yunsh 的终端与 SSH 密码"
                showArrow: true
                onClicked: {
                    passwordError = ""
                    passwordDialog.visible = true
                    currentPasswordField.forceActiveFocus()
                }
            }

            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/clock.svg"
                iconSize: 18
                title: "自动熄屏与锁定"
                subtitle: autoLockLabel() + " · 点击切换"
                showArrow: true
                onClicked: settingsScreen.cycleAutoLock()
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/clock.svg"
                iconSize: 18
                title: "日期与时间"
                subtitle: "由网络自动同步 · Asia/Shanghai"
                showArrow: false
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
                subtitle: "查看实时容量与使用情况"
                showArrow: true
                onClicked: settingsScreen.openSystemInfo()
            }
            
            GlassCard {
                width: parent.width; height: 60
                iconSource: "/usr/share/yunsh/icons/factory-reset.svg"
                iconSize: 18
                title: "恢复出厂设置"
                subtitle: "清除数据，保留系统文件"
                showArrow: true
                titleColor: "#FF5252"
                onClicked: settingsScreen.requestFactoryReset()
            }
        }
        
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }

    property bool passwordBusy: false
    property string passwordError: ""

    Rectangle {
        id: passwordDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.62)
        visible: false
        z: 220

        MouseArea {
            anchors.fill: parent
            onClicked: if (!passwordBusy) passwordDialog.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 440
            height: 390
            radius: 32
            color: "#F5F8FA"
            border.width: 1
            border.color: "#FFFFFF"

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 13

                Text {
                    text: "修改开机密码"
                    color: "#111820"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: "这只修改 Linux 用户 yunsh 的本机开机与锁屏密码，不会修改 YUNSH 账户密码。"
                    color: "#60707C"
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }
                TextField {
                    id: currentPasswordField
                    width: parent.width
                    height: 48
                    placeholderText: "当前开机密码"
                    echoMode: TextInput.Password
                    enabled: !passwordBusy
                }
                TextField {
                    id: newPasswordField
                    width: parent.width
                    height: 48
                    placeholderText: "新密码（至少 4 个字符）"
                    echoMode: TextInput.Password
                    enabled: !passwordBusy
                }
                TextField {
                    id: confirmPasswordField
                    width: parent.width
                    height: 48
                    placeholderText: "再次输入新密码"
                    echoMode: TextInput.Password
                    enabled: !passwordBusy
                    onAccepted: changeBootPassword()
                }
                Text {
                    width: parent.width
                    text: passwordError
                    visible: passwordError.length > 0
                    color: "#D93025"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
                Row {
                    anchors.right: parent.right
                    spacing: 10
                    Button {
                        text: "取消"
                        enabled: !passwordBusy
                        onClicked: passwordDialog.visible = false
                    }
                    Button {
                        text: passwordBusy ? "正在修改…" : "确认修改"
                        enabled: !passwordBusy
                        onClicked: changeBootPassword()
                    }
                }
            }
        }
    }

    Rectangle {
        id: passwordSuccess
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width: 300
        height: 48
        radius: 24
        color: "#F4FFF7"
        border.width: 1
        border.color: "#A7E6B5"
        visible: false
        z: 230
        Text {
            anchors.centerIn: parent
            text: "密码已同步更新"
            color: "#167A32"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Timer {
            id: passwordSuccessTimer
            interval: 2400
            onTriggered: passwordSuccess.visible = false
        }
    }

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
            color: Qt.rgba(248/255, 252/255, 255/255, 0.94)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.94); border.width: 1
            
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
                    color: "#61707C"; font.pixelSize: 13
                }
                
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
                    
                    Rectangle {
                        width: 140; height: 44; radius: 22
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.68)
                        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.88); border.width: 1
                        Text { anchors.centerIn: parent; text: "取消"; color: "#8888A0"; font.pixelSize: 14 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: factoryResetDialog.visible = false
                        }
                    }
                    
                    Rectangle {
                        width: 160; height: 44; radius: 22
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.68)
                        border.color: "#FF5252"; border.width: 1
                        Text { anchors.centerIn: parent; text: "恢复出厂设置"; color: "#FF5252"; font.pixelSize: 14 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                factoryResetDialog.visible = false
                                var xhr = new XMLHttpRequest()
                                xhr.open("POST", "http://127.0.0.1:8591/api/factory-reset", true)
                                xhr.setRequestHeader("Content-Type", "application/json")
                                xhr.send("{}")
                            }
                        }
                    }
                }
            }
        }
    }
}
