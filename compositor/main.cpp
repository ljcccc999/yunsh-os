// YUNSH OS v1.0 - Compositor Main Entry
// Starts the display compositor and launches the Qt6 QML UI

#include "compositor.h"
#include <cstdio>
#include <cstdlib>
#include <csignal>
#include <unistd.h>
#include <sys/wait.h>

static YUNSHCompositor* g_compositor = nullptr;

void signal_handler(int sig) {
    printf("YUNSH: Signal %d received, shutting down\n", sig);
    if (g_compositor) {
        g_compositor->shutdown();
    }
    exit(0);
}

int main(int argc, char** argv) {
    printf("=== YUNSH OS v1.0 Compositor ===\n");
    printf("Target: 1080p AR Glasses (Black=Transparent)\n\n");

    // Setup signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    // Initialize compositor
    YUNSHCompositor compositor;
    g_compositor = &compositor;

    if (!compositor.init(argc, argv)) {
        fprintf(stderr, "YUNSH: Failed to initialize compositor\n");
        return 1;
    }

    // Fork: compositor in parent, UI in child
    pid_t ui_pid = fork();
    if (ui_pid == 0) {
        // Child: Launch Qt6 QML UI
        printf("YUNSH: Launching Qt6 QML UI...\n");
        
        // Set EGLFS platform for Qt
        setenv("QT_QPA_PLATFORM", "eglfs", 1);
        setenv("QT_QPA_EGLFS_INTEGRATION", "eglfs_kms", 1);
        setenv("QT_QPA_EGLFS_KMS_CONFIG", "/etc/yunsh/kms-config.json", 1);
        setenv("QT_QPA_EGLFS_ALWAYS_SET_MODE", "1", 1);
        setenv("QT_QPA_EGLFS_FORCE8888", "1", 1);
        setenv("QT_QUICK_BACKEND", "software", 1);
        setenv("QMLSCENE_DEVICE", "softwarecontext", 1);
        setenv("QT_QPA_EGLFS_PHYSICAL_WIDTH", "1920", 1);
        setenv("QT_QPA_EGLFS_PHYSICAL_HEIGHT", "1080", 1);
        setenv("DISPLAY", "", 1);
        setenv("WAYLAND_DISPLAY", "", 1);
        setenv("YUNSH_COMPOSITOR_SOCKET", "/tmp/yunsh-compositor.sock", 1);

        // Start the QML app
        execl("/usr/bin/yunsh-ui", "yunsh-ui", nullptr);
        
        // If execl fails
        fprintf(stderr, "YUNSH: Failed to launch UI: ");
        perror("");
        _exit(1);
    }

    // Parent: Run compositor
    printf("YUNSH: Compositor running (PID=%d, UI PID=%d)\n", getpid(), ui_pid);
    int ret = compositor.run();

    // Wait for UI process
    int status;
    waitpid(ui_pid, &status, 0);

    printf("YUNSH: Compositor exited with code %d\n", ret);
    return ret;
}
