import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15

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

    /* ---- Data model ---- */
    property var updateHistory: [
        {
            version: "3.0.5",
            date: "2026-08-10",
            changelog: "首次安装、网络与空间输入可靠性更新。\n• 首次安装显示真实下载 MB，并区分下载、解包与配置\n• NetworkManager 自动接管、检测和恢复网络\n• 自动识别 Ethernet，并自动搜索附近 Wi-Fi\n• 设置无线区域，修复正确密码仍无法连接\n• 虚拟键盘稳定唤起，补全杠类符号与长按退格\n• 窗口打开时点击桌面临时显示 App 图标 30 秒",
            build: "build 2026.0810"
        },
        {
            version: "3.0.2",
            date: "2026-08-10",
            changelog: "空间桌面与全系统液态玻璃更新。\n• 打开任意 App 窗口时自动隐藏桌面 App 图标\n• 空白桌面可切换临时图标栏，30 秒无操作后再次隐藏\n• 图标翻页会重置计时，打开第二个 App 会立即隐藏\n• YUNSH 菜单手动隐藏后，空白桌面不会恢复\n• 激活、App、菜单、任务切换、键盘与系统工具统一明亮液态玻璃\n• 黑色保留为 AR 透明画布，亮色玻璃使用高对比深色文字",
            build: "build 2026.0810"
        },
        {
            version: "2.0.2",
            date: "2026-07-29",
            changelog: "系统世界与 Orbit 更新。\n• YUNSH META Universe 升级为系统级持续世界层，不再作为普通 App\n• Orbit 系统级 Agent 每次开机自动启动，可选 DeepSeek、Kimi 或兼容提供商与模型\n• 用户 API Key 设备级加密保存，系统权限默认开启且可随时关闭\n• 激活时可配置或跳过 Orbit，默认甜美女声并提供男声选项\n• USB/蓝牙麦克风语音识别与自然语音组件在桌面后后台准备\n• 全局 YUNSH / METAVERSE / Orbit 菜单栏与液态玻璃系统图标\n• 当前眼镜默认输出单个完整画面，由显示驱动同步到左右屏；高级 SBS 仅为未来驱动保留",
            build: "build 2026.0729"
        },
        {
            version: "2.0.0",
            date: "2026-07-29",
            changelog: "YUNSH 空间工作版本。\n• YUNSH Drop 附近加密传输、接收确认与 YUNSH Link 分享转发\n• 用户授权的 iPhone Screen Relay 空间投屏窗口\n• 多语言 Hello 激活、可跳过的眼镜/手机配对与进度\n• 不区分大小写的一次性手机配对密钥，无需二维码\n• 可转发和恢复的 SpaceCapsule 与可选 Comfort DNA\n• Side-by-Side 双目、EDID、显示校准与白色液态玻璃\n• 虚拟按钮和 iPhone 一键回正\n• 3DoF 四种空间位置、专注模式与辅助功能",
            build: "build 2026.0729"
        },
        {
            version: "1.0.3",
            date: "2026-07-27",
            changelog: "空间桌面与设备连接更新。\n• 正前、左侧、右侧、远处四种 3DoF 布局\n• YUNSH Link OS Mode 遥测与 OTA 控制接口\n• 眼镜自动重连、亮度与电量通道\n• Android 后台准备不再阻塞桌面和激活",
            build: "build 2026.0727"
        },
        {
            version: "1.0.0",
            date: "2026-06-15",
            changelog: "YUNSH OS 首个公开版本。\n• Qt Quick 空间桌面与玻璃界面\n• 浏览器、终端、相册与系统设置\n• Wi-Fi、蓝牙和 OTA 服务\n• Raspberry Pi 映像与首次启动流程",
            build: "build 2026.0615.1000"
        }
    ]

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

        /* Back button */
        GlassButton {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 20
            iconSource: "/usr/share/yunsh/icons/chevron-left-dark.svg"
            bgColor: Qt.rgba(1, 1, 1, 0.62)
            onClicked: root.backToUpdates()
        }

        Text {
            anchors.centerIn: parent
            text: "更新历史"
            color: "#17212A"
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
            color: Qt.rgba(23/255, 33/255, 42/255, 0.46)
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
                color: Qt.rgba(23/255, 33/255, 42/255, 0.12)
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
                       : Qt.rgba(70/255, 88/255, 102/255, 0.18)
                border.width: 2
                border.color: index === 0
                              ? Qt.rgba(0.345, 0.886, 0.51, 0.7)
                              : Qt.rgba(70/255, 88/255, 102/255, 0.28)

                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 3
                    color: index === 0 ? "#30D158" : Qt.rgba(23/255, 33/255, 42/255, 0.42)
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
                            color: index === 0 ? "#17212A" : Qt.rgba(23/255, 33/255, 42/255, 0.78)
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
                        color: Qt.rgba(23/255, 33/255, 42/255, 0.52)
                        font.pixelSize: 13
                        font.family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif"
                    }

                    /* Build info */
                    Text {
                        visible: modelData.build && modelData.build.length > 0
                        text: modelData.build
                        color: Qt.rgba(23/255, 33/255, 42/255, 0.42)
                        font.pixelSize: 11
                        font.family: "SF Pro Mono, Menlo, Courier, monospace"
                        font.letterSpacing: 0.5
                    }

                    /* Separator */
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(23/255, 33/255, 42/255, 0.12)
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                    }

                    /* Changelog */
                    Text {
                        text: modelData.changelog
                        color: Qt.rgba(23/255, 33/255, 42/255, 0.70)
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
                        color: Qt.rgba(23/255, 33/255, 42/255, 0.52)
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
            GradientStop { position: 1.0; color: Qt.rgba(248/255, 252/255, 255/255, 0.36) }
        }
    }
}
