// YUNSH OS v1.0 - Web Browser (Qt6 WebEngine)
// Fully functional browser with navigation, tabs (single tab), loading progress

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine 6.15  // Qt6 WebEngine

Item {
    id: browserScreen
    anchors.fill: parent
    visible: false
    z: 90

    signal backToHome()

    property url currentUrl: "https://www.bing.com"
    property bool isLoading: false
    property int loadProgress: 0
    property string pageTitle: ""
    property string _pendingDomain: ""  // original domain input, for http fallback

    // Transparent background (GlassBackground shows through)
    Rectangle { anchors.fill: parent; color: "transparent" }

    // ─── Top Bar ─────────────────────────────
    Rectangle {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: Qt.rgba(12/255, 12/255, 25/255, 0.85)

        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
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
            color: Qt.rgba(40/255, 40/255, 55/255, 0.5)
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08); border.width: 1

            Row { anchors.fill: parent; spacing: 0

                // Back navigation
                Rectangle {
                    width: 36; height: parent.height; color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "◀"; color: webView.canGoBack ? "#FFFFFF" : "#555"
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
                        text: "▶"; color: webView.canGoForward ? "#FFFFFF" : "#555"
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
                        color: "#FFFFFF"; font.pixelSize: isLoading ? 14 : 16
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
                    color: Qt.rgba(0/255, 0/255, 0/255, 0.3)
                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.05)

                    EditableInput {
                        id: urlInput
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#FFFFFF"; font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        text: webView.url.toString() === "about:blank" ? "" : webView.url.toString()
                        placeholderText: "搜索或输入网址..."
                        placeholderTextColor: Qt.rgba(255/255, 255/255, 255/255, 0.15)

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

        // Background color
        backgroundColor: "#000000"

        // Loading state
        onLoadingChanged: function(loadRequest) {
            isLoading = loadRequest.status === WebEngineLoadRequest.LoadStartedStatus
            if (loadRequest.status === WebEngineLoadRequest.LoadSucceededStatus) {
                isLoading = false
                loadProgress = 100
                pageTitle = webView.title
                urlInput.text = webView.url.toString()
                browserScreen._pendingDomain = ""
            } else if (loadRequest.status === WebEngineLoadRequest.LoadFailedStatus) {
                isLoading = false
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
            loadProgress = webView.loadProgress
        }

        // Secure connection indicator
        property bool isSecure: false
        onCertificateError: function(error) {
            // Accept self-signed certs (for testing)
            error.accept()
        }

        // New window requests (open in same view)
        onNewWindowRequested: function(request) {
            request.action = WebEngineNewWindowRequest.IgnoreRequest
            if (request.requestedUrl.toString() !== "") {
                webView.url = request.requestedUrl
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
        color: Qt.rgba(12/255, 12/255, 25/255, 0.85)

        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
        }

        Row {
            anchors.centerIn: parent
            spacing: 40

            // Home
            Column {
                spacing: 2; width: 60
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "⌂"; color: "#00D4FF"; font.pixelSize: 16 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "首页"; color: "#00D4FF"; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; onClicked: webView.url = "https://www.bing.com" }
            }

            // Copy URL
            Column {
                spacing: 2; width: 60
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "📋"; color: "#A0B0C0"; font.pixelSize: 16 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "复制链接"; color: "#A0B0C0"; font.pixelSize: 10 }
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

            // Desktop site toggle (not implemented, just visual)
            Column {
                spacing: 2; width: 60
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "🖥"; color: "#A0B0C0"; font.pixelSize: 16 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "桌面版"; color: "#A0B0C0"; font.pixelSize: 10 }
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
            color: Qt.rgba(12/255, 12/255, 25/255, 0.92)
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
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "#FFFFFF"; font.pixelSize: 13 }
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
