// YUNSH OS v1.0 - Application Launcher
// Launches system apps and Android apps via Waydroid

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <string>

void launch_system_app(const std::string& app_id) {
    if (app_id == "appstore") {
        printf("YUNSH: Launching App Store (应用宝)\n");
        // Launch Waydroid with App Store
        system("waydroid session start &");
        sleep(2);
        system("waydroid app launch com.tencent.android.qqdownloader");
    } else if (app_id == "files") {
        printf("YUNSH: Launching File Manager\n");
        system("/usr/bin/yunsh-filemanager &");
    } else if (app_id == "settings") {
        printf("YUNSH: Opening Settings window\n");
        // Notify compositor to show settings
        system("echo 'show_settings' | nc -U /tmp/yunsh-compositor.sock &");
    } else if (app_id == "about") {
        printf("YUNSH: Opening About window\n");
        system("echo 'show_about' | nc -U /tmp/yunsh-compositor.sock &");
    } else {
        // Try launching as Android app
        std::string cmd = "waydroid app launch " + app_id + " &";
        system(cmd.c_str());
    }
}

int main(int argc, char** argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: yunsh-launcher <app_id>\n");
        return 1;
    }
    
    launch_system_app(argv[1]);
    return 0;
}
