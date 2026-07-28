#!/usr/bin/env python3
"""
YUNSH OS Terminal Daemon v1.0
PTY-based bash terminal backend, runs on :8593
"""

import os
import pty
import select
import struct
import fcntl
import termios
import signal
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT = 8593
MAX_OUTPUT_CHARS = 1_000_000


class PTYTerminal:
    def __init__(self):
        self.full_output = ""
        self.child_fd = None
        self._start()

    def _start(self):
        pid, fd = pty.fork()
        if pid == 0:
            # Child: start bash
            os.environ.setdefault("TERM", "xterm-256color")
            os.environ.setdefault("HOME", "/root")
            os.execve("/bin/bash", ["/bin/bash", "--login"], os.environ)
        else:
            self.child_fd = fd
            self.pid = pid
            self.full_output = ""
            # Initial resize
            self.resize(80, 24)

    def _read_all(self):
        """Read all available PTY output without blocking."""
        data = b""
        try:
            while True:
                r, _, _ = select.select([self.child_fd], [], [], 0)
                if not r:
                    break
                chunk = os.read(self.child_fd, 4096)
                if not chunk:
                    break
                data += chunk
        except (OSError, ValueError):
            pass
        return data

    def update(self):
        """Read PTY output and append to buffer."""
        data = self._read_all()
        if data:
            self.full_output += data.decode("utf-8", errors="replace")
            if len(self.full_output) > MAX_OUTPUT_CHARS:
                self.full_output = self.full_output[-MAX_OUTPUT_CHARS:]

    def write(self, text):
        """Send text to the PTY."""
        if not self.alive():
            self.close()
            self._start()
        try:
            os.write(self.child_fd, text.encode("utf-8"))
        except OSError:
            pass

    def resize(self, cols, rows):
        """Resize the PTY terminal."""
        try:
            winsize = struct.pack("HHHH", rows, cols, 0, 0)
            fcntl.ioctl(self.child_fd, termios.TIOCSWINSZ, winsize)
        except (OSError, ValueError):
            pass

    def get_output(self):
        """Get full terminal output."""
        self.update()
        return self.full_output

    def alive(self):
        if self.child_fd is None or self.pid is None:
            return False
        try:
            finished, _status = os.waitpid(self.pid, os.WNOHANG)
        except ChildProcessError:
            finished = self.pid
        if finished == 0:
            return True
        try:
            os.close(self.child_fd)
        except OSError:
            pass
        self.child_fd = None
        self.pid = None
        return False

    def close(self):
        """Kill the terminal process."""
        if self.child_fd is not None:
            try:
                if self.pid is not None:
                    os.kill(self.pid, signal.SIGKILL)
            except OSError:
                pass
            try:
                os.close(self.child_fd)
            except OSError:
                pass
            self.child_fd = None
            self.pid = None


class TerminalHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/output":
            output = self.server.terminal.get_output()
            self._send_text(output)

        elif parsed.path == "/status":
            alive = self.server.terminal.alive()
            self._send_json({"alive": alive})

        elif parsed.path.startswith("/resize"):
            qs = parse_qs(parsed.query)
            try:
                cols = max(20, min(500, int(qs.get("cols", [80])[0])))
                rows = max(5, min(200, int(qs.get("rows", [24])[0])))
            except (TypeError, ValueError):
                self.send_error(400, "Invalid terminal dimensions")
                return
            self.server.terminal.resize(cols, rows)
            self._send_text("ok")

        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        parsed = urlparse(self.path)

        if parsed.path == "/input":
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length > 65536:
                self.send_error(413, "Input too large")
                return
            body = self.rfile.read(content_length)
            self.server.terminal.write(body.decode("utf-8", errors="replace"))
            self._send_text("ok")

        elif parsed.path == "/reset":
            self.server.terminal.close()
            self.server.terminal = PTYTerminal()
            self._send_text("ok")

        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _send_text(self, text):
        body = text.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _send_json(self, obj):
        body = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


def main():
    server = HTTPServer(("127.0.0.1", PORT), TerminalHandler)
    server.terminal = PTYTerminal()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.terminal.close()
        server.server_close()


if __name__ == "__main__":
    main()
