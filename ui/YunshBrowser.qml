// YUNSH OS v1.0 - Web Browser (Qt6 WebEngine)
// Fully functional browser with navigation, tabs (single tab), loading progress

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine

Item {
    id: browserScreen
    anchors.fill: parent
    visible: true
    z: 90

    signal backToHome()

    property url currentUrl: "https://www.bing.com"
    property bool isLoading: false
    property int loadProgress: 0
    property string pageTitle: ""
    property string _pendingDomain: ""  // original domain input, for http fallback
    property string downloadStatus: ""
    property string downloadedApkPath: ""
    property bool downloadBusy: false
    property bool desktopMode: false
    property string defaultUserAgent: ""

    function setDesktopMode(enabled) {
        desktopMode = enabled
        if (defaultUserAgent.length === 0)
            defaultUserAgent = browserProfile.httpUserAgent
        browserProfile.httpUserAgent = enabled
            ? "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
            : defaultUserAgent
        webView.reload()
    }

    function installDownloadedApk() {
        if (downloadedApkPath.length === 0)
            return
        downloadBusy = true
        downloadStatus = "正在安装 Android 应用…"
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 190000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            downloadBusy = false
            try {
                var data = JSON.parse(xhr.responseText)
                downloadStatus = data.status === "ok"
                    ? "Android 应用安装完成"
                    : (data.message || "安装失败")
            } catch (error) {
                downloadStatus = "无法连接 Android 安装服务"
            }
        }
        xhr.send(JSON.stringify({
            action: "install_apk",
            path: downloadedApkPath
        }))
    }

    WebEngineProfile {
        id: browserProfile
        storageName: "yunsh-browser"
        offTheRecord: false
        persistentStoragePath: "/home/yunsh/.local/share/yunsh-browser"
        cachePath: "/home/yunsh/.cache/yunsh-browser"
        downloadPath: "/home/yunsh/Downloads"

        Component.onCompleted: {
            browserScreen.defaultUserAgent = httpUserAgent
        }

        onDownloadRequested: function(download) {
            download.downloadDirectory = "/home/yunsh/Downloads"
            browserScreen.downloadStatus = "正在下载 " + download.suggestedFileName
            browserScreen.downloadedApkPath = ""
            browserScreen.downloadBusy = true
            download.accept()
        }

        onDownloadFinished: function(download) {
            browserScreen.downloadBusy = false
            if (download.state === WebEngineDownloadRequest.DownloadCompleted) {
                var path = download.downloadDirectory + "/" + download.downloadFileName
                browserScreen.downloadStatus = "已保存到 Downloads"
                if (download.downloadFileName.toLowerCase().endsWith(".apk"))
                    browserScreen.downloadedApkPath = path
            } else {
                browserScreen.downloadStatus = download.interruptReasonString.length > 0
                    ? download.interruptReasonString : "下载未完成"
            }
        }
    }

    // Transparent background (GlassBackground shows through)
    Rectangle { anchors.fill: parent; color: "transparent" }

    // ─── Top Bar ─────────────────────────────
    Rectangle {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: Qt.rgba(248/255, 252/255, 255/255, 0.86)

        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Qt.rgba(255/255, 255/255, 255/255, 0.88)
        }

        // Back button (close browser)
        Text {
            id: backBtn
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "←"; color: "#00D4FF"; font.pixelSize: 22; font.bold: true
            MouseArea {
                anchors.fill: parent; width: 40; height: 40
                anchors.centerIn: parent
                onClicked: browserScreen.backToHome()
            }
        }

        // Navigation pill
        Rectangle {
            id: navBar
            anchors.left: backBtn.right; anchors.leftMargin: 4
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 36; radius: 18
            color: Qt.rgba(255/255, 255/255, 255/255, 0.62)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.88); border.width: 1

            Row { anchors.fill: parent; spacing: 0

                // Back navigation
                Rectangle {
                    width: 36; height: parent.height; color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "◀"; color: webView.canGoBack ? "#17212A" : "#8A969F"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { if (webView.canGoBack) webView.goBack() }
                    }
                }

                // Forward navigation
                Rectangle {
                    width: 36; height: parent.height; color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "▶"; color: webView.canGoForward ? "#17212A" : "#8A969F"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { if (webView.canGoForward) webView.goForward() }
                    }
                }

                // Refresh / Stop
                Rectangle {
                    width: 36; height: parent.height; color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: isLoading ? "✕" : "⟳"
                        color: "#17212A"; font.pixelSize: isLoading ? 14 : 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (isLoading) webView.stop()
                            else webView.reload()
                        }
                    }
                }

                // URL bar
                Rectangle {
                    width: parent.width - 220; height: 26; radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(225/255, 244/255, 250/255, 0.70)
                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.86)

                    EditableInput {
                        id: urlInput
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#17212A"; font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        text: webView.url.toString() === "about:blank" ? "" : webView.url.toString()
                        placeholderText: "搜索或输入网址..."
                        placeholderTextColor: Qt.rgba(23/255, 33/255, 42/255, 0.36)

                        onAccepted: {
                            var text = urlInput.text.trim()
                            if (text.length === 0) return
                            // Auto-add protocol if missing
                            if (!text.startsWith("http://") && !text.startsWith("https://")) {
                                // Check if it looks like a domain (contains dot like .com/.org/.cn)
                                if (text.indexOf(".") >= 0 && text.indexOf(" ") < 0) {
                                    browserScreen._pendingDomain = text
                                    text = "https://" + text
                                } else {
                                    // Search via Bing
                                    browserScreen._pendingDomain = ""
                                    text = "https://www.bing.com/search?q=" + encodeURIComponent(text)
                                }
                            } else {
                                browserScreen._pendingDomain = ""
                            }
                            webView.url = text
                            urlInput.text = text
                            Qt.inputMethod.hide()
                        }
                    }
                }

                // Menu
                Rectangle {
                    width: 36; height: parent.height; color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "⋮"; color: "#A0B0C0"; font.pixelSize: 18; font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: browserMenu.open()
                    }
                }
            }
        }
    }

    // ─── Loading Bar ──────────────────────────
    Rectangle {
        id: progressBar
        anchors.top: topBar.bottom
        anchors.left: parent.left
        height: 2
        width: parent.width * (loadProgress / 100.0)
        color: "#00D4FF"
        visible: isLoading && loadProgress < 100

        // Glow effect
        Rectangle {
            anchors.right: parent.right; width: 20; height: 2
            color: "transparent"
        }
    }

    // ─── Web Engine View ──────────────────────
    WebEngineView {
        id: webView
        anchors.top: progressBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomBar.top
        url: currentUrl
        profile: browserProfile

        // Background color
        backgroundColor: "#000000"

        // Loading state
        onLoadingChanged: function(loadRequest) {
            browserScreen.isLoading = loadRequest.status === WebEngineView.LoadStartedStatus
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                browserScreen.isLoading = false
                browserScreen.loadProgress = 100
                pageTitle = webView.title
                urlInput.text = webView.url.toString()
                browserScreen._pendingDomain = ""
            } else if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                browserScreen.isLoading = false
                console.log("Page load failed:", loadRequest.errorString)

                // Auto fallback: https → http
                if (browserScreen._pendingDomain.length > 0) {
                    console.log("HTTPS failed, retrying with HTTP for:", browserScreen._pendingDomain)
                    var domain = browserScreen._pendingDomain
                    browserScreen._pendingDomain = ""  // prevent infinite loop
                    webView.url = "http://" + domain
                }
            }
        }

        onLoadProgressChanged: {
            browserScreen.loadProgress = webView.loadProgress
        }

        // Secure connection indicator
        property bool isSecure: false
        onCertificateError: function(error) {
            console.warn("Rejected invalid TLS certificate:", error.description)
            error.rejectCertificate()
        }

        // New window requests (open in same view)
        onNewWindowRequested: function(request) {
            request.openIn(webView)
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: bottomBar.top
        anchors.bottomMargin: 12
        width: Math.min(parent.width - 40, 520)
        height: downloadStatus.length > 0 ? 52 : 0
        radius: 18
        color: Qt.rgba(248/255, 252/255, 255/255, 0.92)
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.94)
        visible: downloadStatus.length > 0
        z: 20

        Row {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 10
            spacing: 12

            Text {
                width: parent.width - (downloadedApkPath.length > 0 ? 110 : 24)
                anchors.verticalCenter: parent.verticalCenter
                text: downloadStatus
                elide: Text.ElideMiddle
                color: "#17212A"
                font.pixelSize: 13
            }

            GlassButton {
                width: 88
                height: 34
                anchors.verticalCenter: parent.verticalCenter
                visible: downloadedApkPath.length > 0
                enabled: !downloadBusy
                onClicked: browserScreen.installDownloadedApk()
                Text {
                    anchors.centerIn: parent
                    text: downloadBusy ? "安装中…" : "安装 APK"
                    color: "#00D4FF"
                    font.pixelSize: 12
                }
            }
        }
    }

    // ─── Bottom Bar ───────────────────────────
    Rectangle {
        id: bottomBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        color: Qt.rgba(248/255, 252/255, 255/255, 0.86)

        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Qt.rgba(255/255, 255/255, 255/255, 0.88)
        }

        Row {
            anchors.centerIn: parent
            spacing: 40

            // Home
            Item {
                width: 60; height: 40
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "⌂"; color: "#00D4FF"; font.pixelSize: 16 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "首页"; color: "#00D4FF"; font.pixelSize: 10 }
                }
                MouseArea { anchors.fill: parent; onClicked: webView.url = "https://www.bing.com" }
            }

            // Copy URL
            Item {
                width: 60; height: 40
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "📋"; color: "#A0B0C0"; font.pixelSize: 16 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "复制链接"; color: "#A0B0C0"; font.pixelSize: 10 }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        urlInput.selectAll()
                        urlInput.copy()
                        var p = browserScreen.parent
                        while (p) { if (p.showToast) { p.showToast("已复制 ✓"); break }; p = p.parent }
                    }
                }
            }

            // Desktop site user-agent toggle
            Item {
                width: 60; height: 40
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🖥"
                        color: desktopMode ? "#00D4FF" : "#A0B0C0"
                        font.pixelSize: 16
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: desktopMode ? "桌面版 ✓" : "桌面版"
                        color: desktopMode ? "#00D4FF" : "#A0B0C0"
                        font.pixelSize: 10
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: browserScreen.setDesktopMode(!desktopMode)
                }
            }
        }
    }

    // ─── Browser Menu Popup ───────────────────
    Popup {
        id: browserMenu
        modal: true
        closePolicy: Popup.CloseOnPressOutside
        x: parent.width - width - 16
        y: topBar.height + 4
        padding: 4

        background: Rectangle {
            color: Qt.rgba(248/255, 252/255, 255/255, 0.94)
            radius: 12
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.12)
        }

        Column {
            spacing: 2; padding: 6

            Repeater {
                model: [
                    {icon: "📋", label: "复制链接", action: function(){ urlInput.selectAll(); urlInput.copy(); browserMenu.close() }},
                    {icon: "🔗", label: "分享页面", action: function(){ urlInput.selectAll(); urlInput.copy(); browserMenu.close() }},
                    {icon: "🔄", label: "刷新", action: function(){ webView.reload(); browserMenu.close() }},
                ]

                Rectangle {
                    width: 140; height: 36; radius: 8
                    color: itemMouse.containsMouse ? Qt.rgba(0/255, 212/255, 255/255, 0.1) : "transparent"

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 10
                        spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; color: "#A0B0C0"; font.pixelSize: 14 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "#17212A"; font.pixelSize: 13 }
                    }

                    MouseArea {
                        id: itemMouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: { modelData.action(); browserMenu.close() }
                    }
                }
            }
        }
    }

    // ─── Show on visible ─────────────────────
    onVisibleChanged: {
        if (visible && webView.url.toString() === "about:blank") {
            webView.url = currentUrl
        }
    }

    // Keyboard shortcut to focus URL bar
    Shortcut {
        sequence: "Ctrl+L"
        onActivated: {
            urlInput.forceActiveFocus()
            urlInput.selectAll()
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: browserScreen.backToHome()
    }

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: webView.reload()
    }
}
