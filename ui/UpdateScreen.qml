import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15

import Yunsh.Components 1.0

/* ==========================================================================
   UpdateScreen.qml — YUNSH OS OTA Update Manager
   visionOS glassmorphism style, pure black background for AR transparency.
   ========================================================================== */

Item {
    id: root

    anchors.fill: parent

    /* ---- Signals ---- */
    signal backToHome()

    /* ---- State ---- */
    property string currentVersion: "1.0.0"
    property string latestVersion: ""
    property bool updateAvailable: false
    property bool isChecking: false
    property bool isDownloading: false
    property int downloadProgress: 0
    property string downloadSpeed: ""
    property string downloadEta: ""
    property bool autoUpdate: false
    property bool wifiOnly: true
    property string lastCheckTime: ""
    property string changelog: ""
    property bool showChangelog: false

    /* Backend integration — call this to refresh all data */
    function refreshStatus() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:8080/api/update-status", true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    currentVersion = data.currentVersion || "1.0.0";
                    latestVersion = data.latestVersion || "";
                    updateAvailable = data.updateAvailable || false;
                    autoUpdate = data.autoUpdate || false;
                    wifiOnly = data.wifiOnly || true;
                    lastCheckTime = data.lastCheckTime || "";
                    changelog = data.changelog || "";
                    updateAvailable = data.updateAvailable || false;
                } catch(e) {
                    console.warn("UpdateScreen: failed to parse status:", e);
                }
            }
        };
        xhr.send();
    }

    Component.onCompleted: {
        refreshStatus();
    }

    /* ---- Background (transparent - GlassBackground shows through) ---- */
    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    /* ---- Header ---- */
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 88

        /* Back button — visionOS style pill */
        GlassButton {
            id: backBtn
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 20
            iconSource: "qrc:/icons/chevron-left-white.svg"
            bgColor: Qt.rgba(1, 1, 1, 0.15)
            onClicked: root.backToHome()
        }

        Text {
            anchors.centerIn: parent
            text: "系统更新"
            color: "#FFFFFF"
            font.pixelSize: 28
            font.weight: Font.Medium
            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
            opacity: 0.95
        }
    }

    /* ---- Scrollable content ---- */
    Flickable {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        contentHeight: contentColumn.implicitHeight + 60
        clip: true
        boundsBehavior: Flickable.OvershootBounds

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 16

            /* ==========================================================
               Current version info card
               ========================================================== */
            GlassCard {
                id: versionCard
                Layout.fillWidth: true
                implicitHeight: 180

                contentItem: ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 8

                    Text {
                        text: "YUNSH OS"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.pixelSize: 13
                        font.letterSpacing: 2
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        textFormat: Text.PlainText
                    }

                    Text {
                        text: "v" + currentVersion
                        color: "#FFFFFF"
                        font.pixelSize: 38
                        font.weight: Font.Bold
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                    }

                    RowLayout {
                        spacing: 8
                        Layout.topMargin: 4

                        GlassIcon {
                            source: updateAvailable
                                   ? "qrc:/icons/exclamationmark-circle.svg"
                                   : "qrc:/icons/checkmark-circle.svg"
                            iconColor: updateAvailable ? "#FFD60A" : "#30D158"
                            size: 20
                        }

                        Text {
                            text: updateAvailable
                                  ? "YUNSH OS v" + latestVersion + " 可供更新"
                                  : "已是最新版本"
                            color: updateAvailable ? "#FFD60A" : "#30D158"
                            font.pixelSize: 15
                            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        }
                    }

                }
            }

            /* ==========================================================
               Check for updates button
               ========================================================== */
            GlassButton {
                id: checkBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 26
                enabled: !isChecking && !isDownloading

                bgColor: isChecking
                         ? Qt.rgba(0.3, 0.3, 0.35, 0.4)
                         : Qt.rgba(0.0, 0.478, 1.0, 0.4)
                hoverBgColor: Qt.rgba(0.0, 0.478, 1.0, 0.55)
                pressedBgColor: Qt.rgba(0.0, 0.4, 0.85, 0.6)

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    BusyIndicator {
                        visible: isChecking
                        running: isChecking
                        implicitWidth: 20
                        implicitHeight: 20
                        contentItem: Item {
                            Rectangle {
                                id: spinner
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                radius: 9
                                color: "transparent"
                                border.width: 2
                                border.color: "#FFFFFF"
                                opacity: 0.8
                                SequentialAnimation on rotation {
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        from: 0; to: 360
                                        duration: 1000
                                        easing.type: Easing.Linear
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: isChecking ? "正在检查…" : "检查更新"
                        color: isChecking
                               ? Qt.rgba(1, 1, 1, 0.5)
                               : "#FFFFFF"
                        font.pixelSize: 17
                        font.weight: Font.Medium
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                    }

                    Image {
                        visible: !isChecking
                        source: "qrc:/icons/arrow.clockwise.svg"
                        width: 18
                        height: 18
                        opacity: 0.8
                        sourceSize.width: 18
                        sourceSize.height: 18
                        layer.smooth: true
                    }
                }

                onClicked: {
                    isChecking = true;
                    // Send command to daemon
                    var xhr = new XMLHttpRequest();
                    xhr.open("POST", "http://127.0.0.1:8080/api/update-check", true);
                    xhr.onreadystatechange = function() {
                        if (xhr.readyState === XMLHttpRequest.DONE) {
                            isChecking = false;
                            root.refreshStatus();
                            if (xhr.status !== 200) {
                                console.warn("Check failed:", xhr.status);
                            }
                        }
                    };
                    xhr.send(JSON.stringify({action: "check"}));
                }
            }

            /* ==========================================================
               Download / Update button (only visible when update available)
               ========================================================== */
            GlassButton {
                id: downloadBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 26
                visible: updateAvailable && !isDownloading
                enabled: !isDownloading

                bgColor: Qt.rgba(0.345, 0.886, 0.51, 0.35)
                hoverBgColor: Qt.rgba(0.345, 0.886, 0.51, 0.5)
                pressedBgColor: Qt.rgba(0.25, 0.75, 0.4, 0.55)

                contentItem: Text {
                    anchors.centerIn: parent
                    text: "下载并更新"
                    color: "#FFFFFF"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                }

                onClicked: {
                    isDownloading = true;
                    var xhr = new XMLHttpRequest();
                    xhr.open("POST", "http://127.0.0.1:8080/api/update-download", true);
                    xhr.onreadystatechange = function() {
                        if (xhr.readyState === XMLHttpRequest.DONE) {
                            if (xhr.status !== 200) {
                                isDownloading = false;
                            }
                        }
                    };
                    xhr.send(JSON.stringify({action: "start_download"}));
                }
            }

            /* ==========================================================
               Changelog expandable section — shows full release notes
               ========================================================== */
            GlassCard {
                Layout.fillWidth: true
                implicitHeight: showChangelog ? changelogColumn.implicitHeight + 60 : 64
                visible: updateAvailable && changelog.length > 0
                Behavior on implicitHeight { NumberAnimation { duration: 250 } }

                contentItem: ColumnLayout {
                    id: changelogColumn
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 0

                    /* Toggle header */
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 64

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            Image {
                                source: "/usr/share/yunsh/icons/doc.text.svg"
                                width: 18
                                height: 18
                                opacity: 0.6
                                sourceSize.width: 18
                                sourceSize.height: 18
                            }

                            Text {
                                text: "更新内容"
                                color: "#FFFFFF"
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                                Layout.fillWidth: true
                            }

                            Image {
                                source: showChangelog ? "/usr/share/yunsh/icons/chevron.up.svg" : "/usr/share/yunsh/icons/chevron.down.svg"
                                width: 16
                                height: 16
                                opacity: 0.5
                                sourceSize.width: 16
                                sourceSize.height: 16
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: showChangelog = !showChangelog
                        }
                    }

                    /* Full changelog content (collapsible) */
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(changelogText.implicitHeight + 20, 300)
                        Layout.bottomMargin: 16
                        visible: showChangelog
                        clip: true
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 12
                            contentHeight: changelogText.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.OvershootBounds

                            Text {
                                id: changelogText
                                width: parent.width
                                text: changelog
                                color: Qt.rgba(1, 1, 1, 0.75)
                                font.pixelSize: 13
                                font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText
                                lineHeight: 1.4
                            }

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                active: true
                                interactive: true
                            }
                        }
                    }
                }
            }

            /* ==========================================================
               Operation guide section
               ========================================================== */
            GlassCard {
                Layout.fillWidth: true
                implicitHeight: guideHeader.height + guideContent.implicitHeight + 60
                visible: updateAvailable

                contentItem: ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    anchors.topMargin: 20
                    anchors.bottomMargin: 20
                    spacing: 12

                    RowLayout {
                        id: guideHeader
                        Layout.fillWidth: true
                        spacing: 8

                        Image {
                            source: "/usr/share/yunsh/icons/keyboard.svg"
                            width: 18
                            height: 18
                            opacity: 0.6
                            sourceSize.width: 18
                            sourceSize.height: 18
                        }

                        Text {
                            text: "操作方式"
                            color: "#FFFFFF"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        }
                    }

                    Text {
                        id: guideContent
                        Layout.fillWidth: true
                        text: "键盘快捷键:\n"
                            + "  Escape  → 返回 / 关闭面板\n"
                            + "  Print  → 截取全屏\n"
                            + "  Ctrl+Shift+S  → 区域截图\n"
                            + "  Ctrl+Shift+C  → 控制中心\n"
                            + "  Ctrl+↑  → App Switcher\n"
                            + "  Ctrl+L  → 地址栏聚焦 / 清屏\n"
                            + "  Ctrl+R  → 刷新页面\n"
                            + "\n鼠标操作:\n"
                            + "  Home 指示条点击/上滑  → App Switcher\n"
                            + "  长按文字  → 复制菜单\n"
                            + "  右键  → 粘贴"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 13
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        font.weight: Font.Light
                        lineHeight: 1.5
                        wrapMode: Text.WordWrap
                    }
                }
            }

            /* ==========================================================
               Progress section (hidden by default)
               ========================================================== */
            GlassPanel {
                id: progressPanel
                Layout.fillWidth: true
                implicitHeight: progressColumn.implicitHeight + 40
                visible: isDownloading

                opacity: isDownloading ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                contentItem: ColumnLayout {
                    id: progressColumn
                    anchors.fill: parent
                    anchors.margins: 24
                    anchors.topMargin: 32
                    spacing: 12

                    /* YUNSH Logo */
                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        source: "/usr/share/yunsh/logo/logo-512.png"
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.8
                        
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: isDownloading
                            OpacityAnimator { from: 0.6; to: 1.0; duration: 1000 }
                            OpacityAnimator { from: 1.0; to: 0.6; duration: 1000 }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "正在更新 YUNSH OS…"
                        color: "#FFFFFF"
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                    }

                    /* Linear progress bar */
                    Rectangle {
                        Layout.fillWidth: true
                        height: 8
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.1)

                        Rectangle {
                            id: progressFill
                            width: parent.width * (downloadProgress / 100.0)
                            height: parent.height
                            radius: 4
                            color: "#007AFF"
                            Behavior on width { SmoothedAnimation { duration: 300 } }

                            /* Glow effect */
                            layer.enabled: true
                            layer.effect: GlassEffect {
                                blurRadius: 4
                                color: "#007AFF"
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: downloadProgress + "%"
                            color: "#FFFFFF"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        }

                        Text {
                            text: downloadSpeed
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 13
                            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: downloadEta
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 13
                            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        }
                    }

                    /* Cancel button */
                    GlassButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        radius: 18
                        bgColor: Qt.rgba(1, 1, 1, 0.1)
                        hoverBgColor: Qt.rgba(1, 1, 1, 0.2)
                        pressedBgColor: Qt.rgba(1, 1, 1, 0.3)

                        contentItem: Text {
                            anchors.centerIn: parent
                            text: "取消"
                            color: Qt.rgba(1, 1, 1, 0.7)
                            font.pixelSize: 14
                            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        }

                        onClicked: {
                            isDownloading = false;
                            var xhr = new XMLHttpRequest();
                            xhr.open("POST", "http://127.0.0.1:8080/api/update-cancel", true);
                            xhr.send(JSON.stringify({action: "cancel"}));
                        }
                    }
                }
            }

            /* ==========================================================
               Settings row: auto update toggle
               ========================================================== */
            GlassCard {
                Layout.fillWidth: true
                implicitHeight: 64

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 12

                    Text {
                        text: "自动更新"
                        color: "#FFFFFF"
                        font.pixelSize: 17
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        Layout.fillWidth: true
                    }

                    /* iOS-style toggle */
                    Rectangle {
                        id: autoToggle
                        width: 51
                        height: 31
                        radius: 15.5
                        color: autoUpdate
                               ? Qt.rgba(0.345, 0.886, 0.51, 0.6)
                               : Qt.rgba(1, 1, 1, 0.15)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            id: autoToggleThumb
                            x: autoUpdate ? parent.width - width - 2 : 2
                            y: 2
                            width: 27
                            height: 27
                            radius: 13.5
                            color: "#FFFFFF"
                            Behavior on x { SmoothedAnimation { duration: 150 } }

                            layer.enabled: true
                            layer.effect: DropShadowEffect {
                                transparentBorder: true
                                horizontalOffset: 0
                                verticalOffset: 1
                                radius: 4
                                samples: 8
                                color: Qt.rgba(0, 0, 0, 0.2)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                autoUpdate = !autoUpdate;
                                var xhr = new XMLHttpRequest();
                                xhr.open("POST", "http://127.0.0.1:8080/api/update-config", true);
                                xhr.send(JSON.stringify({
                                    action: "set_auto_update",
                                    value: autoUpdate
                                }));
                            }
                        }
                    }
                }
            }

            /* ==========================================================
               Settings row: WiFi only toggle
               ========================================================== */
            GlassCard {
                Layout.fillWidth: true
                implicitHeight: 64

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 12

                    Text {
                        text: "仅WiFi下载"
                        color: "#FFFFFF"
                        font.pixelSize: 17
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        id: wifiToggle
                        width: 51
                        height: 31
                        radius: 15.5
                        color: wifiOnly
                               ? Qt.rgba(0.345, 0.886, 0.51, 0.6)
                               : Qt.rgba(1, 1, 1, 0.15)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            id: wifiToggleThumb
                            x: wifiOnly ? parent.width - width - 2 : 2
                            y: 2
                            width: 27
                            height: 27
                            radius: 13.5
                            color: "#FFFFFF"
                            Behavior on x { SmoothedAnimation { duration: 150 } }

                            layer.enabled: true
                            layer.effect: DropShadowEffect {
                                transparentBorder: true
                                horizontalOffset: 0
                                verticalOffset: 1
                                radius: 4
                                samples: 8
                                color: Qt.rgba(0, 0, 0, 0.2)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                wifiOnly = !wifiOnly;
                                var xhr = new XMLHttpRequest();
                                xhr.open("POST", "http://127.0.0.1:8080/api/update-config", true);
                                xhr.send(JSON.stringify({
                                    action: "set_wifi_only",
                                    value: wifiOnly
                                }));
                            }
                        }
                    }
                }
            }

            /* ==========================================================
               Last check timestamp
               ========================================================== */
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                visible: lastCheckTime.length > 0
                text: "上次检查: " + lastCheckTime
                color: Qt.rgba(1, 1, 1, 0.35)
                font.pixelSize: 12
                font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
            }

            /* ==========================================================
               Update history link
               ========================================================== */
            GlassButton {
                id: historyBtn
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 180
                Layout.preferredHeight: 40
                radius: 20
                bgColor: Qt.rgba(1, 1, 1, 0.08)
                hoverBgColor: Qt.rgba(1, 1, 1, 0.16)
                pressedBgColor: Qt.rgba(1, 1, 1, 0.24)

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "更新历史"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 14
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                    }

                    Image {
                        source: "qrc:/icons/chevron.right.svg"
                        width: 12
                        height: 12
                        opacity: 0.4
                        sourceSize.width: 12
                        sourceSize.height: 12
                    }
                }

                onClicked: {
                    // Navigate to update history screen
                    // Signal to parent to switch view
                }
            }
        }
    }
}
