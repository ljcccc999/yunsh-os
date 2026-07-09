# YUNSH OS v1.0 - Qt6 QML UI CMakeLists (visionOS Ultimate)

cmake_minimum_required(VERSION 3.20)
project(yunsh-ui LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core Gui Quick QuickControls2 QuickWidgets
    Svg OpenGL WebEngineQuick
)

qt_add_resources(yunsh_ui_resources "yunsh_ui"
    PREFIX "/"
    FILES
        main.qml
        HomeScreen.qml
        SettingsScreen.qml
        AboutScreen.qml
        AppDock.qml
        AppIcon.qml
        GlassPanel.qml
        GlassCard.qml
        GlassEffect.qml
        DropShadowEffect.qml
        StatusBar.qml
        ControlCenter.qml
        NetworkScreen.qml
        BluetoothScreen.qml
        UpdateScreen.qml
        UpdateHistoryScreen.qml
        YunshBrowser.qml
        YunshMetaverse.qml
        ScreenshotOverlay.qml
        ActivationScreen.qml
        SystemInfoScreen.qml
        VirtualKeyboard.qml
        Screensaver.qml
)

set(SOURCES main.cpp)

add_executable(yunsh-ui ${SOURCES} ${yunsh_ui_resources})

target_link_libraries(yunsh-ui
    Qt6::Core Qt6::Gui Qt6::Quick Qt6::QuickControls2
    Qt6::QuickWidgets Qt6::Svg Qt6::OpenGL Qt6::WebEngineQuick
)

install(TARGETS yunsh-ui RUNTIME DESTINATION /usr/bin)

install(FILES
    main.qml HomeScreen.qml SettingsScreen.qml AboutScreen.qml
    AppDock.qml AppIcon.qml GlassPanel.qml GlassCard.qml
    GlassEffect.qml DropShadowEffect.qml StatusBar.qml
    ControlCenter.qml NetworkScreen.qml BluetoothScreen.qml
    UpdateScreen.qml UpdateHistoryScreen.qml
    YunshBrowser.qml YunshMetaverse.qml ScreenshotOverlay.qml
    ActivationScreen.qml SystemInfoScreen.qml VirtualKeyboard.qml Screensaver.qml
    DESTINATION /usr/share/yunsh/ui
)
