// YUNSH OS v1.0 - Qt6 QML Application Entry
// Launches the YUNSH OS user interface with glassmorphism

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSurfaceFormat>
#include <QQuickWindow>
#include <QScreen>
#include <QDir>
#include <QDebug>

int main(int argc, char *argv[])
{
    // Set up high-dpi support
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QCoreApplication::setAttribute(Qt::AA_UseSoftwareOpenGL);

    // Create application with platform-appropriate settings
    QGuiApplication app(argc, argv);
    app.setApplicationName("YUNSH OS");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("YUNSH");
    app.setOrganizationDomain("yunsh.tech");

    // Set default style
    QQuickStyle::setStyle("Fusion");

    // Configure OpenGL surface format
    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    format.setDepthBufferSize(24);
    format.setStencilBufferSize(8);
    format.setSamples(4);
    format.setSwapInterval(1);
    QSurfaceFormat::setDefaultFormat(format);

    // Set Qt Quick scene graph settings
    qputenv("QSG_INFO", "1");
    qputenv("QT_QUICK_CONTROLS_STYLE", "Fusion");
    qputenv("QT_LOGGING_RULES", "qt.qml.connections=false");

    // Create QML engine
    QQmlApplicationEngine engine;

    // Add import paths
    QStringList importPaths = engine.importPathList();
    importPaths.prepend(QCoreApplication::applicationDirPath() + "/qml");
    importPaths.prepend("/usr/share/yunsh/ui");
    engine.setImportPathList(importPaths);

    // Load main QML file
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "YUNSH: Failed to load QML UI";
        // Try loading from filesystem
        QUrl fsUrl = QUrl::fromLocalFile("/usr/share/yunsh/ui/main.qml");
        engine.load(fsUrl);
    }

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "YUNSH: Cannot load UI from any location";
        return -1;
    }

    // Get the window and set to full screen
    for (auto *obj : engine.rootObjects()) {
        QQuickWindow *window = qobject_cast<QQuickWindow*>(obj);
        if (window) {
            window->setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint);
            window->setProperty("color", QColor(0, 0, 0, 0));  // Transparent
            window->showFullScreen();
            qDebug() << "YUNSH: UI window shown fullscreen";
        }
    }

    qDebug() << "YUNSH: UI application started";
    return app.exec();
}
