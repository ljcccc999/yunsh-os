import QtQuick 2.15

// Qt 6 embedded builds require offline-compiled QSB shaders. Keep the glass
// layer portable on EGLFS/KMS by using a lightweight translucent material.
Rectangle {
    property var source
    property real blurRadius: 20

    radius: Math.max(1, Math.min(width, height) * 0.04)
    color: Qt.rgba(0.05, 0.07, 0.12, 0.46)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
}
