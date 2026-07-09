import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15

import Yunsh.Components 1.0

/* ==========================================================================
   UpdateHistoryScreen.qml — YUNSH OS Update History
   Displays a chronological list of past system updates.
   visionOS glassmorphism style, pure black background for AR transparency.
   ========================================================================== */

Item {
    id: root

    anchors.fill: parent

    /* ---- Signals ---- */
    signal backToUpdates()

    /* ---- Data model (hardcoded for v1.0) ---- */
    property var updateHistory: [
        {
            version: "1.0.0",
            date: "2026-06-15",
            changelog: "YUNSH OS 首个正式版本。\n• 基于 Linux 6.6 LTS 内核\n• visionOS 风格沉浸式 UI\n• 手势导航与空间交互\n• 多模态 AI 助手集成\n• OTA 在线更新系统\n• AR 眼镜原生支持\n• 安全启动与加密存储",
            build: "build 2026.0615.1000"
        }
    ]

    /* ---- Background ---- */
    Rectangle {
        anchors.fill: parent
        color: "#000000" // transparent in AR
    }

    /* ---- Header ---- */
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 88

        /* Back button */
        GlassButton {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 20
            iconSource: "qrc:/icons/chevron-left-white.svg"
            bgColor: Qt.rgba(1, 1, 1, 0.15)
            onClicked: root.backToUpdates()
        }

        Text {
            anchors.centerIn: parent
            text: "更新历史"
            color: "#FFFFFF"
            font.pixelSize: 28
            font.weight: Font.Medium
            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
            opacity: 0.95
        }

        /* Subtitle: count of updates */
        Text {
            anchors.top: parent.bottom
            anchors.topMargin: -4
            anchors.horizontalCenter: parent.horizontalCenter
            text: updateHistory.length + " 个版本"
            color: Qt.rgba(1, 1, 1, 0.35)
            font.pixelSize: 13
            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
        }
    }

    /* ---- Timeline ---- */
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 28
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 40

        model: updateHistory
        spacing: 20
        clip: true
        boundsBehavior: Flickable.OvershootBounds

        delegate: Item {
            width: listView.width
            implicitHeight: cardColumn.implicitHeight + 28

            /* Timeline connector line */
            Rectangle {
                id: timelineLine
                x: 20
                y: 24
                width: 2
                height: parent.height + listView.spacing - 32
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: index < updateHistory.length - 1
            }

            /* Timeline dot */
            Rectangle {
                x: 12
                y: 24
                width: 18
                height: 18
                radius: 9
                color: index === 0
                       ? Qt.rgba(0.345, 0.886, 0.51, 0.4)
                       : Qt.rgba(1, 1, 1, 0.15)
                border.width: 2
                border.color: index === 0
                              ? Qt.rgba(0.345, 0.886, 0.51, 0.7)
                              : Qt.rgba(1, 1, 1, 0.2)

                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 3
                    color: index === 0 ? "#30D158" : Qt.rgba(1, 1, 1, 0.3)
                }
            }

            /* Version card */
            GlassCard {
                id: versionCard
                anchors.left: parent.left
                anchors.leftMargin: 44
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 4
                implicitHeight: cardColumn.implicitHeight + 32

                /* Glow on latest version card */
                layer.enabled: index === 0
                layer.effect: GlassEffect {
                    blurRadius: 16
                    color: Qt.rgba(0.345, 0.886, 0.51, 0.12)
                }

                contentItem: ColumnLayout {
                    id: cardColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8

                    /* Header row: version + badge */
                    RowLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        Text {
                            text: "YUNSH OS v" + modelData.version
                            color: index === 0 ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.8)
                            font.pixelSize: index === 0 ? 22 : 20
                            font.weight: index === 0 ? Font.Bold : Font.Medium
                            font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                            Layout.fillWidth: true
                        }

                        /* Current version badge */
                        GlassPanel {
                            id: badge
                            visible: index === 0
                            implicitWidth: badgeLabel.implicitWidth + 16
                            implicitHeight: 24
                            radius: 12
                            panelColor: Qt.rgba(0.345, 0.886, 0.51, 0.2)

                            contentItem: Text {
                                id: badgeLabel
                                anchors.centerIn: parent
                                text: "当前版本"
                                color: "#30D158"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                            }
                        }
                    }

                    /* Date */
                    Text {
                        text: modelData.date
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 13
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                    }

                    /* Build info */
                    Text {
                        visible: modelData.build && modelData.build.length > 0
                        text: modelData.build
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font.pixelSize: 11
                        font.family: "SF Pro Mono, Menlo, Courier, monospace"
                        font.letterSpacing: 0.5
                    }

                    /* Separator */
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                    }

                    /* Changelog */
                    Text {
                        text: modelData.changelog
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 13
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                        lineHeight: 1.6
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        /* Empty state */
        Component {
            id: emptyState

            Item {
                anchors.centerIn: parent

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "📋"
                        font.pixelSize: 48
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "暂无更新记录"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 17
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                    }
                }
            }
        }
    }

    /* ---- Subtle gradient at bottom for scroll hint ---- */
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 30
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }
}
