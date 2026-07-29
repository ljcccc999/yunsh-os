// YUNSH OS binocular side-by-side compositor.
// The shell stays on a single comfortable focal plane. Applications that
// render real stereo content can provide their own left/right views.

import QtQuick 2.15

Item {
    id: compositor
    clip: true

    default property alias content: logicalScene.data

    property bool stereoEnabled: false
    property real eyeShiftPx: 0
    property int logicalWidth: 1920
    property int logicalHeight: 1080
    property bool calibrationVisible: false

    readonly property real eyeViewportWidth: stereoEnabled ? width / 2 : width
    readonly property real horizontalScale: eyeViewportWidth / logicalWidth
    readonly property real verticalScale: height / logicalHeight

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    // The left-eye surface remains the interactive source. The right-eye
    // surface is a live GPU copy, keeping both eyes frame-locked.
    Item {
        id: logicalScene
        width: compositor.logicalWidth
        height: compositor.logicalHeight
        x: compositor.stereoEnabled ? -compositor.eyeShiftPx / 2 : 0
        y: 0
        transformOrigin: Item.TopLeft
        transform: Scale {
            origin.x: 0
            origin.y: 0
            xScale: compositor.horizontalScale
            yScale: compositor.verticalScale
        }
    }

    ShaderEffectSource {
        id: rightEye
        visible: compositor.stereoEnabled
        live: true
        recursive: true
        hideSource: false
        sourceItem: logicalScene
        sourceRect: Qt.rect(0, 0, compositor.logicalWidth, compositor.logicalHeight)
        textureSize: Qt.size(compositor.logicalWidth, compositor.logicalHeight)
        smooth: true
        x: compositor.eyeViewportWidth + compositor.eyeShiftPx / 2
        y: 0
        width: compositor.eyeViewportWidth
        height: compositor.height
    }

    Rectangle {
        visible: compositor.stereoEnabled && compositor.calibrationVisible
        anchors.horizontalCenter: parent.horizontalCenter
        width: 2
        height: parent.height
        color: Qt.rgba(0, 212/255, 1, 0.55)
        z: 10000
    }

    Text {
        visible: compositor.stereoEnabled && compositor.calibrationVisible
        x: 24
        y: 18
        text: "L"
        color: "#00D4FF"
        font.pixelSize: 18
        font.weight: Font.Bold
        z: 10001
    }

    Text {
        visible: compositor.stereoEnabled && compositor.calibrationVisible
        x: compositor.eyeViewportWidth + 24
        y: 18
        text: "R"
        color: "#00D4FF"
        font.pixelSize: 18
        font.weight: Font.Bold
        z: 10001
    }
}
