#!/usr/bin/env python3
# YUNSH OS v1.0 - Android Window Bridge
# Bridges Waydroid Android windows into YUNSH compositor

import subprocess
import json
import time
import signal
import sys
import os
import socket
import threading

class YunshAndroidBridge:
    """Manages Waydroid Android container and bridges app windows"""
    
    def __init__(self):
        self.running = False
        self.apps = {}
        self.socket_path = "/tmp/yunsh-android-bridge.sock"
        
    def start(self):
        """Start Waydroid session"""
        print("YUNSH: Starting Android bridge...")
        self.running = True
        
        # Check if Waydroid is installed
        try:
            subprocess.run(["waydroid", "--version"], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            print("YUNSH: Waydroid not found, skipping Android support")
            return
        
        # Start Waydroid session
        print("YUNSH: Starting Waydroid session...")
        subprocess.Popen(
            ["waydroid", "session", "start"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        
        # Wait for session
        time.sleep(5)
        
        # Start Unix socket listener
        self._start_socket_listener()
        
        # Start app monitoring
        self._start_app_monitor()
        
        print("YUNSH: Android bridge ready")
    
    def stop(self):
        """Stop Waydroid session"""
        print("YUNSH: Stopping Android bridge...")
        self.running = False
        subprocess.run(["waydroid", "session", "stop"], capture_output=True)
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)
    
    def install_apk(self, apk_path):
        """Install an APK into Waydroid"""
        print(f"YUNSH: Installing APK: {apk_path}")
        result = subprocess.run(
            ["waydroid", "app", "install", apk_path],
            capture_output=True, text=True
        )
        return result.returncode == 0
    
    def launch_app(self, package_name):
        """Launch an Android app"""
        print(f"YUNSH: Launching Android app: {package_name}")
        subprocess.Popen(
            ["waydroid", "app", "launch", package_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    
    def list_apps(self):
        """List installed Android apps"""
        result = subprocess.run(
            ["waydroid", "app", "list"],
            capture_output=True, text=True
        )
        return result.stdout
    
    def _start_socket_listener(self):
        """Start Unix socket for IPC with compositor"""
        def listen():
            if os.path.exists(self.socket_path):
                os.unlink(self.socket_path)
            
            server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            server.bind(self.socket_path)
            server.listen(5)
            server.settimeout(1.0)
            
            while self.running:
                try:
                    conn, addr = server.accept()
                    data = conn.recv(1024).decode().strip()
                    if data.startswith("launch:"):
                        pkg = data[7:]
                        self.launch_app(pkg)
                    elif data == "list":
                        apps = self.list_apps()
                        conn.send(apps.encode())
                    conn.close()
                except socket.timeout:
                    continue
                except Exception as e:
                    print(f"YUNSH: Socket error: {e}")
            
            server.close()
        
        thread = threading.Thread(target=listen, daemon=True)
        thread.start()
    
    def _start_app_monitor(self):
        """Monitor Waydroid app list for changes"""
        def monitor():
            while self.running:
                try:
                    apps = self.list_apps()
                    # Parse and cache app list
                    time.sleep(10)
                except:
                    time.sleep(5)
        
        thread = threading.Thread(target=monitor, daemon=True)
        thread.start()

def signal_handler(sig, frame):
    print("\nYUNSH: Shutting down Android bridge...")
    bridge.stop()
    sys.exit(0)

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    bridge = YunshAndroidBridge()
    bridge.start()
    
    print("YUNSH: Android bridge running. Press Ctrl+C to stop.")
    
    # Keep running
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        bridge.stop()
