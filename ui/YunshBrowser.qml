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
    clip: true

    signal backToHome()
    signal requestVirtualKeyboard(var target)
    signal dismissVirtualKeyboard()

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
    property double keyboardSuppressedUntil: 0
    property int activeTabIndex: 0

    ListModel { id: downloadHistory }

    function openDownloadsFolder() {
        Qt.openUrlExternally("file:///home/yunsh/Downloads")
    }

    function removeDownload(index) {
        if (index < 0 || index >= downloadHistory.count) return
        var path = downloadHistory.get(index).path
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8590/launch", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({action: "delete_download", path: path}))
        downloadHistory.remove(index)
    }

    ListModel {
        id: browserTabs
        ListElement { title: "新标签页"; address: "https://www.bing.com" }
    }

    function newTab(address) {
        // New tabs are an editable start surface, not a literal about:blank
        // page.  Keeping the address empty also prevents the WebEngine page
        // from stealing focus from the URL field.
        var target = address && String(address).length ? String(address) : ""
        browserTabs.append({title: "新标签页", address: target})
        activeTabIndex = browserTabs.count - 1
        webView.url = target.length ? target : "about:blank"
        Qt.callLater(function() { urlInput.text = ""; urlInput.forceActiveFocus() })
    }

    function switchTab(index) {
        if (index < 0 || index >= browserTabs.count || index === activeTabIndex) return
        browserTabs.setProperty(activeTabIndex, "address", webView.url.toString())
        browserTabs.setProperty(activeTabIndex, "title", webView.title || "标签页")
        activeTabIndex = index
        webView.url = browserTabs.get(index).address
    }

    function closeTab(index) {
        if (browserTabs.count === 1) {
            browserTabs.set(0, {title: "新标签页", address: "https://www.bing.com"})
            activeTabIndex = 0; webView.url = "https://www.bing.com"; return
        }
        browserTabs.remove(index)
        activeTabIndex = Math.max(0, Math.min(activeTabIndex, browserTabs.count - 1))
        webView.url = browserTabs.get(activeTabIndex).address
    }

    QtObject {
        id: webInputProxy
        property string text: ""
        property int cursorPosition: 0
        property bool focus: true
        property bool syncing: false
        onFocusChanged: {
            if (!focus) {
                browserScreen.keyboardSuppressedUntil = Date.now() + 1200
                webView.runJavaScript("(function(){var e=document.activeElement;if(e&&e.blur)e.blur();})()")
            }
        }
        function submit() {
            webView.runJavaScript("(function(){var e=document.activeElement;if(!e)return;var t=(e.tagName||'').toLowerCase();if(t==='textarea'||e.isContentEditable){var s=e.selectionStart||0,v=e.value||'';e.value=v.slice(0,s)+'\\n'+v.slice(s);e.selectionStart=e.selectionEnd=s+1;e.dispatchEvent(new Event('input',{bubbles:true}));return;}e.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));if(e.form){if(e.form.requestSubmit)e.form.requestSubmit();else e.form.submit();}e.dispatchEvent(new KeyboardEvent('keyup',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));})()")
        }
        onTextChanged: {
            if (syncing) return
            var encoded = JSON.stringify(text)
            webView.runJavaScript("(function(){var e=document.activeElement;if(!e)return;if('value' in e){e.value="
                + encoded + ";e.selectionStart=e.selectionEnd=" + cursorPosition
                + ";}else if(e.isContentEditable){e.textContent=" + encoded
                + ";}e.dispatchEvent(new Event('input',{bubbles:true}));})()")
        }
        onCursorPositionChanged: {
            if (!syncing)
                webView.runJavaScript("(function(){var e=document.activeElement;if(e&&'selectionStart' in e)e.selectionStart=e.selectionEnd=" + cursorPosition + ";})()")
        }
    }

    Timer {
        interval: 300; repeat: true; running: browserScreen.visible
        onTriggered: webView.runJavaScript(
            "(function(){var e=document.activeElement;if(!e)return null;var t=(e.tagName||'').toLowerCase();if(t!=='input'&&t!=='textarea'&&!e.isContentEditable)return null;return {v:('value' in e?e.value:e.textContent)||'',p:('selectionStart' in e?e.selectionStart:(e.textContent||'').length)};})()",
            function(value) {
                if (!value) {
                    // Clicking the floating keyboard temporarily removes the
                    // WebEngine activeElement. Do not close the keyboard on
                    // that transient gap; only explicit browser navigation or
                    // a real focus change should dismiss it.
                    if (webInputProxy.focus) return
                    browserScreen.dismissVirtualKeyboard()
                    return
                }
                if (Date.now() < browserScreen.keyboardSuppressedUntil) return
                webInputProxy.syncing = true
                webInputProxy.text = value.v || ""
                webInputProxy.cursorPosition = Math.max(0, value.p || 0)
                webInputProxy.syncing = false
                webInputProxy.focus = true
                browserScreen.requestVirtualKeyboard(webInputProxy)
            })
    }

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
                downloadHistory.insert(0, {
                    name: download.downloadFileName,
                    path: path,
                    time: Qt.formatTime(new Date(), "HH:mm")
                })
                while (downloadHistory.count > 10) downloadHistory.remove(10)
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
            clip: true
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
                        onClicked: {
                            webInputProxy.focus = false
                            browserScreen.dismissVirtualKeyboard()
                            if (webView.canGoBack) webView.goBack()
                        }
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
                        onClicked: {
                            webInputProxy.focus = false
                            browserScreen.dismissVirtualKeyboard()
                            if (webView.canGoForward) webView.goForward()
                        }
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
                            webInputProxy.focus = false
                            browserScreen.dismissVirtualKeyboard()
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
                        clip: true
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
                            browserScreen.dismissVirtualKeyboard()
                            webInputProxy.focus = false
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
        id: tabBar
        anchors.top: topBar.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 38; color: Qt.rgba(244/255, 250/255, 252/255, 0.94)
        Row {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 6
            Repeater {
                model: browserTabs
                Rectangle {
                    width: Math.min(190, Math.max(110, (tabBar.width - 58) / Math.max(1, browserTabs.count)))
                    height: 30; anchors.verticalCenter: parent.verticalCenter; radius: 15
                    color: index === activeTabIndex ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.48)
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: closeTabText.left; anchors.verticalCenter: parent.verticalCenter; text: title || "标签页"; color: "#17212A"; font.pixelSize: 11; elide: Text.ElideRight }
                    Text { id: closeTabText; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "×"; color: "#61707C"; font.pixelSize: 15; z: 2; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: browserScreen.closeTab(index) } }
                    MouseArea { anchors.fill: parent; z: 1; onClicked: browserScreen.switchTab(index) }
                }
            }
            Rectangle { width: 32; height: 30; anchors.verticalCenter: parent.verticalCenter; radius: 15; color: Qt.rgba(0, 0.83, 1, 0.18); Text { anchors.centerIn: parent; text: "+"; color: "#008EAA"; font.pixelSize: 20 } MouseArea { anchors.fill: parent; onClicked: browserScreen.newTab("") } }
        }
    }

    Rectangle {
        id: progressBar
        anchors.top: tabBar.bottom
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
        settings.webGLEnabled: true
        settings.accelerated2dCanvasEnabled: true

        onNavigationRequested: function(request) {
            if (request.navigationType !== WebEngineNavigationRequest.LinkClickedNavigation)
                return
            var target = request.url
            var targetText = target.toString()
            var scheme = targetText.indexOf(":") > 0
                ? targetText.substring(0, targetText.indexOf(":")).toLowerCase() : ""
            if (scheme !== "http" && scheme !== "https") {
                // Web pages cannot directly launch privileged local apps.
                request.action = WebEngineNavigationRequest.IgnoreRequest
                browserScreen.downloadStatus = "该链接需要受支持的系统 App 才能打开"
                return
            }
            var currentHost = String(webView.url.host).toLowerCase()
            var targetHost = String(target.host).toLowerCase()
            if (currentHost.length > 0 && targetHost.length > 0 && currentHost !== targetHost) {
                request.action = WebEngineNavigationRequest.IgnoreRequest
                browserScreen.newTab(target)
            }
        }

        onUrlChanged: {
            browserTabs.setProperty(browserScreen.activeTabIndex, "address", webView.url.toString())
            urlInput.text = webView.url.toString() === "about:blank" ? "" : webView.url.toString()
        }

        // Background color
        backgroundColor: "#000000"

        // Loading state
        onLoadingChanged: function(loadRequest) {
            browserScreen.isLoading = loadRequest.status === WebEngineView.LoadStartedStatus
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                browserScreen.isLoading = false
                browserScreen.loadProgress = 100
                pageTitle = webView.title
                browserTabs.setProperty(activeTabIndex, "title", webView.title || "标签页")
                browserTabs.setProperty(activeTabIndex, "address", webView.url.toString())
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
            browserScreen.newTab(request.requestedUrl || "about:blank")
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
        radius: 28
        color: Qt.rgba(248/255, 252/255, 255/255, 0.86)

        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 28; color: parent.color
        }

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
                            urlInput.copyWithFallback()
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
                    {icon: "📋", label: "复制链接", action: function(){ urlInput.selectAll(); urlInput.copyWithFallback(); browserMenu.close() }},
                    {icon: "🔗", label: "分享页面", action: function(){ urlInput.selectAll(); urlInput.copyWithFallback(); browserMenu.close() }},
                    {icon: "⬇", label: "最近下载", action: function(){ browserMenu.close(); downloadsPopup.open() }},
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

    Popup {
        id: downloadsPopup
        modal: true
        closePolicy: Popup.CloseOnPressOutside
        x: parent.width - width - 16
        y: topBar.height + 4
        width: 300
        padding: 10
        background: Rectangle {
            color: Qt.rgba(248/255, 252/255, 255/255, 0.96)
            radius: 14
            border.color: Qt.rgba(0/255, 212/255, 255/255, 0.16)
        }
        Column {
            width: parent.width
            spacing: 6
            Text { text: "最近下载"; color: "#17212A"; font.pixelSize: 15; font.bold: true }
            Repeater {
                model: downloadHistory
                delegate: Rectangle {
                    width: 280; height: 38; radius: 9
                    color: Qt.rgba(1, 1, 1, 0.42)
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
                        spacing: 8
                        Text { width: 185; anchors.verticalCenter: parent.verticalCenter; text: model.name; elide: Text.ElideMiddle; color: "#17212A"; font.pixelSize: 12 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "×"; color: "#FF453A"; font.pixelSize: 18; z: 2
                            MouseArea { anchors.fill: parent; anchors.margins: -8; z: 2; onClicked: browserScreen.removeDownload(index) } }
                    }
                    MouseArea { anchors.fill: parent; z: 0; onClicked: browserScreen.openDownloadsFolder() }
                }
            }
            Text {
                visible: downloadHistory.count === 0
                text: "暂无最近下载"
                color: Qt.rgba(23/255, 33/255, 42/255, 0.52)
                font.pixelSize: 13
            }
            GlassButton {
                width: 280; height: 34; radius: 17
                onClicked: browserScreen.openDownloadsFolder()
                Text { anchors.centerIn: parent; text: "打开下载文件夹"; color: "#00D4FF"; font.pixelSize: 12 }
            }
        }
    }

    // ─── Show on visible ─────────────────────
    onVisibleChanged: {}

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
