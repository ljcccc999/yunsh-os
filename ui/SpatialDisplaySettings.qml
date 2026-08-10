// Spatial display, binocular calibration, comfort and accessibility settings.

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    color: "transparent"

    property bool stereoEnabled: false
    property real ipdMm: 63
    property real eyeShiftPx: 0
    property real fieldOfView: 50
    property real trackingSmoothing: 0.35
    property bool reduceMotion: false
    property bool reduceTransparency: false
    property bool highContrast: false
    property bool focusMode: false
    property bool headTrackingConnected: false
    property int outputWidth: 1920
    property int outputHeight: 1080

    signal backToSettings()
    signal preferencesChanged()
    signal calibrationRequested()
    signal recenterRequested()

    function commit() {
        preferencesChanged()
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 62
        color: "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 88
            height: 34
            radius: 17
            color: backMouse.pressed
                ? Qt.rgba(0, 212/255, 1, 0.22)
                : Qt.rgba(0, 212/255, 1, 0.1)
            border.width: 1
            border.color: Qt.rgba(0, 212/255, 1, 0.2)

            Text {
                anchors.centerIn: parent
                text: "← 设置"
                color: "#00D4FF"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                onClicked: root.backToSettings()
            }
        }

        Text {
            anchors.centerIn: parent
            text: "空间显示"
            color: "#17212A"
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }

    Flickable {
        anchors.top: parent.top
        anchors.topMargin: 62
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        clip: true
        contentHeight: settingsColumn.height + 30

        Column {
            id: settingsColumn
            width: parent.width
            spacing: 10

            Text {
                text: "眼镜输出"
                color: "#8E8EA8"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                leftPadding: 14
            }

            GlassCard {
                width: parent.width
                height: 66
                title: "高级 Side-by-Side"
                subtitle: stereoEnabled
                    ? "未来独立左右眼驱动 · 每眼 "
                      + Math.round(outputWidth / 2) + " × " + outputHeight
                    : "当前硬件 · 单画面同步到左右屏"
                isToggle: true
                toggleState: root.stereoEnabled
                onToggled: function(state) {
                    root.stereoEnabled = state
                    root.commit()
                }
            }

            GlassCard {
                width: parent.width
                height: 60
                title: "打开双目校准画面"
                subtitle: "检查中心重合、裁切、比例和左右眼顺序"
                showArrow: true
                onClicked: root.calibrationRequested()
            }

            SliderRow {
                width: parent.width
                title: "瞳距"
                suffix: " mm"
                from: 50
                to: 75
                stepSize: 0.5
                value: root.ipdMm
                onValueEdited: function(newValue) {
                    root.ipdMm = newValue
                    root.commit()
                }
            }

            SliderRow {
                width: parent.width
                title: "水平融合"
                suffix: " px"
                from: -40
                to: 40
                stepSize: 1
                value: root.eyeShiftPx
                onValueEdited: function(newValue) {
                    root.eyeShiftPx = newValue
                    root.commit()
                }
            }

            SliderRow {
                width: parent.width
                title: "水平视场角"
                suffix: "°"
                from: 30
                to: 80
                stepSize: 1
                value: root.fieldOfView
                onValueEdited: function(newValue) {
                    root.fieldOfView = newValue
                    root.commit()
                }
            }

            Text {
                text: "头部追踪"
                color: "#8E8EA8"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                leftPadding: 14
                topPadding: 10
            }

            GlassCard {
                width: parent.width
                height: 60
                title: "重新居中"
                subtitle: headTrackingConnected
                    ? "将当前朝向设为正前方"
                    : "追踪设备未连接；连接后可用"
                showArrow: headTrackingConnected
                enabled: headTrackingConnected
                onClicked: root.recenterRequested()
            }

            SliderRow {
                width: parent.width
                title: "稳定程度"
                suffix: "%"
                from: 0
                to: 90
                stepSize: 5
                value: root.trackingSmoothing * 100
                onValueEdited: function(newValue) {
                    root.trackingSmoothing = newValue / 100
                    root.commit()
                }
            }

            Text {
                text: "舒适度与辅助功能"
                color: "#8E8EA8"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                leftPadding: 14
                topPadding: 10
            }

            GlassCard {
                width: parent.width
                height: 60
                title: "专注模式"
                subtitle: "隐藏非必要状态和桌面控件，减少视觉干扰"
                isToggle: true
                toggleState: root.focusMode
                onToggled: function(state) {
                    root.focusMode = state
                    root.commit()
                }
            }

            GlassCard {
                width: parent.width
                height: 60
                title: "减少动态效果"
                subtitle: "使用短淡入淡出，关闭弹性和大范围移动"
                isToggle: true
                toggleState: root.reduceMotion
                onToggled: function(state) {
                    root.reduceMotion = state
                    root.commit()
                }
            }

            GlassCard {
                width: parent.width
                height: 60
                title: "降低透明度"
                subtitle: "让玻璃表面更实，提升复杂背景上的可读性"
                isToggle: true
                toggleState: root.reduceTransparency
                onToggled: function(state) {
                    root.reduceTransparency = state
                    root.commit()
                }
            }

            GlassCard {
                width: parent.width
                height: 60
                title: "增强对比度"
                subtitle: "提高文字、边框和控件的区分度"
                isToggle: true
                toggleState: root.highContrast
                onToggled: function(state) {
                    root.highContrast = state
                    root.commit()
                }
            }

            Rectangle {
                width: parent.width
                height: 94
                radius: 18
                color: Qt.rgba(0, 212/255, 1, 0.055)
                border.width: 1
                border.color: Qt.rgba(0, 212/255, 1, 0.14)

                Text {
                    anchors.fill: parent
                    anchors.margins: 16
                    text: "桌面以舒适的共享焦平面输出，远近布局使用缩放和角度提示。"
                          + "真正的双目 3D 内容仍需后续应用级左右眼渲染通道；当前 3DoF 不等于房间级 6DoF 锚定。"
                    color: "#B8DCE5"
                    font.pixelSize: 13
                    lineHeight: 1.25
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }
}
