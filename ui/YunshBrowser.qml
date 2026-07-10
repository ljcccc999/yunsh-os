// YUNSH OS v1.0 - Web Browser
import QtQuick 2.15
import QtQuick.Controls 2.15
// Note: QtWebEngine would be imported in C++ side, QML defines UI shell

Item {
    id: browserScreen
    anchors.fill: parent
    visible: false
    
    signal backToHome()
    
    property string currentUrl: ""
    property bool isLoading: false
    property string pageTitle: ""
    property double loadProgress: 0.0
    
    // Pure black background
    Rectangle { anchors.fill: parent; color: "#000000" }
    
    // Top bar - floating glass panel
    Rectangle {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: Qt.rgba(20, 20, 30, 0.45)
        
        // Bottom border
        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Qt.rgba(255, 255, 255, 0.08)
        }
        
        // Back button
        Text {
            id: backBtn
            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
            text: "←"; color: "#00D4FF"; font.pixelSize: 20; font.bold: true
            MouseArea {
                anchors.fill: parent
                onClicked: browserScreen.backToHome()
            }
        }
        
        // Navigation bar (pill shape)
        Rectangle {
            id: navBar
            anchors.left: backBtn.right; anchors.leftMargin: 8
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 36
            radius: 18
            color: Qt.rgba(40, 40, 55, 0.5)
            border.color: Qt.rgba(255, 255, 255, 0.08); border.width: 1
            
            Row {
                anchors.fill: parent
                spacing: 0
                
                // Back page
                Rectangle {
                    width: 40; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "◀"; color: "#A0B0C0"; font.pixelSize: 14 }
                    MouseArea { anchors.fill: parent; onClicked: browserNavBack() }
                }
                // Forward page
                Rectangle {
                    width: 40; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "▶"; color: "#A0B0C0"; font.pixelSize: 14 }
                    MouseArea { anchors.fill: parent; onClicked: browserNavForward() }
                }
                // Refresh
                Rectangle {
                    width: 40; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "⟳"; color: "#A0B0C0"; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: browserReload() }
                }
                
                // URL bar
                Rectangle {
                    width: parent.width - 200; height: 28; radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(0, 0, 0, 0.3)
                    border.color: Qt.rgba(255, 255, 255, 0.05); border.width: 1
                    
                    EditableInput {
                        id: urlInput
                        anchors.fill: parent; anchors.margins: 8
                        color: "#FFFFFF"; font.pixelSize: 13
                        verticalAlignment: TextInput.AlignVCenter
                        text: currentUrl || "输入网址..."
                        onAccepted: loadUrl(urlInput.text)
                    }
                }
                
                // Bookmarks
                Rectangle {
                    width: 40; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "★"; color: "#A0B0C0"; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: showBookmarks() }
                }
                
                // Tabs
                Rectangle {
                    width: 40; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "📑"; color: "#A0B0C0"; font.pixelSize: 14 }
                    MouseArea { anchors.fill: parent; onClicked: showTabs() }
                }
            }
        }
    }
    
    // Loading bar
    Rectangle {
        id: progressBar
        anchors.top: topBar.bottom
        anchors.left: parent.left
        height: 2
        width: parent.width * loadProgress
        color: "#00D4FF"
        visible: isLoading
    }
    
    // Web content area placeholder
    Rectangle {
        anchors.top: progressBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomBar.top
        color: "#000000"
        
        Text {
            anchors.centerIn: parent
            text: isLoading ? "加载中..." : (currentUrl ? pageTitle : "YUNSH Browser")
            color: isLoading ? "#A0A0A0" : "#404050"
            font.pixelSize: isLoading ? 14 : 24
        }
    }
    
    // Bottom toolbar
    Rectangle {
        id: bottomBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: Qt.rgba(20, 20, 30, 0.45)
        
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Qt.rgba(255, 255, 255, 0.08)
        }
        
        Row {
            anchors.centerIn: parent
            spacing: 32
            Text { text: "← 返回首页"; color: "#A0B0C0"; font.pixelSize: 13; MouseArea{anchors.fill:parent; onClicked: browserScreen.backToHome()} }
            Text { text: "书签"; color: "#A0B0C0"; font.pixelSize: 13; MouseArea{anchors.fill:parent; onClicked: showBookmarks()} }
            Text { text: "标签页"; color: "#A0B0C0"; font.pixelSize: 13; MouseArea{anchors.fill:parent; onClicked: showTabs()} }
        }
    }
    
    // JS placeholders (to be implemented when Qt WebEngine is connected)
    function loadUrl(url) {
        console.log("Load URL: " + url)
        isLoading = true
        // WebEngine integration point
    }
    
    function browserNavBack() { console.log("Back") }
    function browserNavForward() { console.log("Forward") }
    function browserReload() { console.log("Reload") }
    function showBookmarks() { console.log("Bookmarks") }
    function showTabs() { console.log("Tabs") }
}
