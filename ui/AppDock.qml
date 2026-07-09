// YUNSH OS v1.0 - App Dock Component (visionOS / macOS Fusion)
// Floating dock with 3D icons, hover magnification, app library

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: appDock
    height: 80
    
    property var dockApps: [
        { name: "设置", icon: "/usr/share/yunsh/icons/settings.svg", appId: "settings", color: Qt.rgba(0/255, 212/255, 255/255, 0.5) },
        { name: "Browser", icon: "/usr/share/yunsh/icons/settings.svg", appId: "browser", color: Qt.rgba(76/255, 175/255, 80/255, 0.5) },
        { name: "Metaverse", icon: "/usr/share/yunsh/icons/metaverse.svg", appId: "metaverse", color: Qt.rgba(156/255, 39/255, 176/255, 0.5) },
        { name: "应用宝", icon: "/usr/share/yunsh/icons/appstore.svg", appId: "appstore", color: Qt.rgba(255/255, 152/255, 0/255, 0.5) },
        { name: "更新", icon: "/usr/share/yunsh/icons/update.svg", appId: "update", color: Qt.rgba(0/255, 200/255, 83/255, 0.5) },
        { name: "关于", icon: "/usr/share/yunsh/icons/about.svg", appId: "about", color: Qt.rgba(96/255, 125/255, 139/255, 0.5) }
    ]
    
    signal appLaunched(string appId)
    signal openAppLibrary()
    
    // visionOS floating dock - pill shape (not full width, centered)
    Rectangle {
        anchors.centerIn: parent
        width: dockContent.width + 32
        height: 72
        radius: 36
        color: Qt.rgba(12/255, 12/255, 28/255, 0.5)
        
        // Frost layers
        Rectangle {
            anchors.fill: parent; radius: 36
            color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
        }
        
        // Top highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.right: parent.right; anchors.rightMargin: 20
            height: 1
            color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
        }
        
        // Border
        Rectangle {
            anchors.fill: parent; radius: 36
            color: "transparent"
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
            border.width: 1
        }
    }
    
    // Dock items row
    Row {
        id: dockContent
        anchors.centerIn: parent
        spacing: 4
        
        Repeater {
            model: dockApps.length + 1  // +1 for app library
            
            Rectangle {
                width: 48
                height: 48
                radius: 14
                color: Qt.rgba(255/255, 255/255, 255/255, 0.02)
                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
                border.width: 1
                
                // Hover scale effect (macOS dock zoom)
                property real hoverScale: 1.0
                transform: Scale { origin.x: 24; origin.y: 24; xScale: hoverScale; yScale: hoverScale }
                
                Behavior on hoverScale {
                    NumberAnimation { duration: 100; easing.type: Easing.OutBack }
                }
                
                Image {
                    anchors.centerIn: parent
                    source: index < dockApps.length ? dockApps[index].icon : ""
                    width: 22
                    height: 22
                    sourceSize.width: 44
                    sourceSize.height: 44
                    fillMode: Image.PreserveAspectFit
                    visible: index < dockApps.length
                }
                
                // App Library icon (grid)
                Text {
                    anchors.centerIn: parent
                    text: "⬡"
                    font.pixelSize: 20
                    color: "#8888A0"
                    visible: index >= dockApps.length
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        parent.color = Qt.rgba(0/255, 212/255, 255/255, 0.08)
                        parent.hoverScale = 1.12
                    }
                    onExited: {
                        parent.color = Qt.rgba(255/255, 255/255, 255/255, 0.02)
                        parent.hoverScale = 1.0
                    }
                    onClicked: {
                        if (index < dockApps.length) {
                            appDock.appLaunched(dockApps[index].appId)
                        } else {
                            appDock.openAppLibrary()
                        }
                    }
                }
                
                // Tooltip label
                Rectangle {
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tooltipText.width + 16
                    height: 22
                    radius: 11
                    color: Qt.rgba(0/255, 0/255, 0/255, 0.6)
                    visible: parent.containsMouse
                    
                    Text {
                        id: tooltipText
                        anchors.centerIn: parent
                        text: index < dockApps.length ? dockApps[index].name : "App Library"
                        color: "#FFFFFF"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
