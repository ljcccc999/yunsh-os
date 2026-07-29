#!/usr/bin/env python3
"""Orbit system agent runtime for YUNSH OS.

Orbit is deliberately exposed only on loopback. It stores the user's provider
credential encrypted at rest and presents a common OpenAI-compatible tool loop
for DeepSeek, Kimi, and user-supplied compatible endpoints.
"""

import json
import os
import pathlib
import re
import secrets
import shlex
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from cryptography.fernet import Fernet, InvalidToken


HOST = "127.0.0.1"
PORT = int(os.environ.get("ORBIT_PORT", "8597"))
CONFIG_DIR = pathlib.Path(os.environ.get("ORBIT_CONFIG_DIR", "/etc/yunsh/orbit"))
STATE_DIR = pathlib.Path(os.environ.get("ORBIT_STATE_DIR", "/var/lib/yunsh/orbit"))
KEY_PATH = CONFIG_DIR / "device.key"
CONFIG_PATH = CONFIG_DIR / "provider.enc"
UI_COMMAND_PATH = pathlib.Path(
    os.environ.get("YUNSH_UI_COMMAND_PATH", "/tmp/yunsh-ui-command.json")
)
MAX_BODY = 1024 * 1024
MAX_HISTORY = 24
MAX_TOOL_ROUNDS = 6
MAX_TOOL_OUTPUT = 24000
VOICE_MODEL_DIR = STATE_DIR / "voice" / "vosk-model-small-cn-0.22"
VOICE_CHOICES = {
    "sweet_female": {
        "name": "甜美女声",
        "edgeVoice": "zh-CN-XiaoxiaoNeural",
        "rate": "+4%",
        "pitch": "+5Hz",
    },
    "young_male": {
        "name": "年轻男声",
        "edgeVoice": "zh-CN-YunxiNeural",
        "rate": "+1%",
        "pitch": "+0Hz",
    },
}

PROVIDERS = {
    "deepseek": {
        "name": "DeepSeek",
        "endpoint": "https://api.deepseek.com/chat/completions",
        "models": [
            {"id": "deepseek-v4-flash", "name": "DeepSeek V4 Flash"},
            {"id": "deepseek-v4-pro", "name": "DeepSeek V4 Pro"},
        ],
    },
    "kimi": {
        "name": "Kimi",
        "endpoint": "https://api.moonshot.cn/v1/chat/completions",
        "models": [
            {"id": "kimi-k3", "name": "Kimi K3"},
            {"id": "kimi-k2.6", "name": "Kimi K2.6"},
        ],
    },
    "compatible": {
        "name": "OpenAI 兼容",
        "endpoint": "",
        "models": [],
    },
}

PERMISSION_LABELS = {
    "apps": "打开与管理应用",
    "files": "读取和修改文件",
    "shell": "运行系统命令",
    "settings": "修改系统设置",
    "network": "访问网络",
    "screen": "读取屏幕与窗口状态",
    "memory": "保存长期任务记忆",
    "world": "控制 YUNSH 世界层",
}
DEFAULT_PERMISSIONS = {name: True for name in PERMISSION_LABELS}

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "open_app",
            "description": "Open a YUNSH OS application or system panel.",
            "parameters": {
                "type": "object",
                "properties": {
                    "app_id": {
                        "type": "string",
                        "enum": [
                            "settings", "browser", "terminal", "photos",
                            "appstore", "files", "update", "network",
                            "bluetooth", "display", "spacecapsule",
                            "screenrelay", "comfortdna", "systeminfo",
                        ],
                    }
                },
                "required": ["app_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "open_world",
            "description": "Enter the system-level persistent YUNSH world layer.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "recenter",
            "description": "Recenter the current 3DoF viewing direction.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "system_status",
            "description": "Read basic local system and Orbit runtime status.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_directory",
            "description": "List a directory on the local YUNSH OS device.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string"}},
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read a UTF-8 text file from the local device.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string"}},
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Create or replace a UTF-8 text file on the local device.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "content": {"type": "string"},
                },
                "required": ["path", "content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "Run a shell command with system-level Orbit access.",
            "parameters": {
                "type": "object",
                "properties": {"command": {"type": "string"}},
                "required": ["command"],
            },
        },
    },
]


def ensure_storage():
    for directory in (CONFIG_DIR, STATE_DIR):
        directory.mkdir(parents=True, exist_ok=True)
        os.chmod(directory, 0o700)
    if not KEY_PATH.exists():
        atomic_write(KEY_PATH, Fernet.generate_key(), 0o600)


def atomic_write(path, data, mode=0o600):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def default_config():
    return {
        "provider": "deepseek",
        "model": "deepseek-v4-flash",
        "apiKey": "",
        "endpoint": "",
        "permissions": dict(DEFAULT_PERMISSIONS),
        "voice": "sweet_female",
        "speakResponses": True,
        "updatedAt": 0,
    }


def load_config():
    ensure_storage()
    config = default_config()
    if CONFIG_PATH.exists():
        try:
            key = KEY_PATH.read_bytes()
            decrypted = Fernet(key).decrypt(CONFIG_PATH.read_bytes())
            loaded = json.loads(decrypted.decode("utf-8"))
            if isinstance(loaded, dict):
                config.update(loaded)
        except (OSError, ValueError, InvalidToken, json.JSONDecodeError):
            pass
    permissions = dict(DEFAULT_PERMISSIONS)
    supplied = config.get("permissions")
    if isinstance(supplied, dict):
        for name in permissions:
            if isinstance(supplied.get(name), bool):
                permissions[name] = supplied[name]
    config["permissions"] = permissions
    return config


def save_config(config):
    ensure_storage()
    payload = json.dumps(config, ensure_ascii=False, separators=(",", ":")).encode()
    encrypted = Fernet(KEY_PATH.read_bytes()).encrypt(payload)
    atomic_write(CONFIG_PATH, encrypted, 0o600)


def public_config(config):
    return {
        "provider": config["provider"],
        "model": config["model"],
        "endpoint": config.get("endpoint", ""),
        "hasApiKey": bool(config.get("apiKey")),
        "apiKeyHint": (
            "••••" + config["apiKey"][-4:] if len(config.get("apiKey", "")) >= 4 else ""
        ),
        "permissions": config["permissions"],
        "permissionLabels": PERMISSION_LABELS,
        "voice": config.get("voice", "sweet_female"),
        "voiceChoices": [
            {"id": voice_id, "name": value["name"]}
            for voice_id, value in VOICE_CHOICES.items()
        ],
        "speakResponses": config.get("speakResponses", True) is not False,
        "updatedAt": config.get("updatedAt", 0),
    }


def validate_endpoint(value):
    parsed = urllib.parse.urlparse(str(value).strip())
    if parsed.scheme == "https" and parsed.netloc:
        return parsed.geturl().rstrip("/")
    if parsed.scheme == "http" and parsed.hostname in {"127.0.0.1", "localhost", "::1"}:
        return parsed.geturl().rstrip("/")
    raise ValueError("自定义提供商必须使用 HTTPS，或使用本机回环地址")


def update_config(payload):
    provider = str(payload.get("provider", "")).lower()
    if provider not in PROVIDERS:
        raise ValueError("不支持的 API 提供商")
    model = str(payload.get("model", "")).strip()
    if not re.fullmatch(r"[A-Za-z0-9._:/-]{1,128}", model):
        raise ValueError("模型版本格式不正确")
    known_models = {item["id"] for item in PROVIDERS[provider]["models"]}
    if known_models and model not in known_models:
        raise ValueError("请选择该提供商支持的模型版本")
    endpoint = ""
    if provider == "compatible":
        endpoint = validate_endpoint(payload.get("endpoint", ""))
        if not endpoint.endswith("/chat/completions"):
            endpoint += "/chat/completions"

    existing = load_config()
    api_key = payload.get("apiKey")
    if api_key is None or api_key == "":
        api_key = (
            existing.get("apiKey", "")
            if existing.get("provider") == provider
            else ""
        )
    api_key = str(api_key).strip()
    if api_key and (len(api_key) < 8 or len(api_key) > 512 or any(c in api_key for c in "\r\n\0")):
        raise ValueError("API Key 格式不正确")

    permissions = dict(DEFAULT_PERMISSIONS)
    supplied_permissions = payload.get("permissions")
    if isinstance(supplied_permissions, dict):
        for name in permissions:
            if isinstance(supplied_permissions.get(name), bool):
                permissions[name] = supplied_permissions[name]

    voice = str(payload.get("voice", existing.get("voice", "sweet_female")))
    if voice not in VOICE_CHOICES:
        raise ValueError("不支持的 Orbit 声音")

    config = {
        "provider": provider,
        "model": model,
        "apiKey": api_key,
        "endpoint": endpoint,
        "permissions": permissions,
        "voice": voice,
        "speakResponses": payload.get(
            "speakResponses", existing.get("speakResponses", True)
        ) is not False,
        "updatedAt": time.time(),
    }
    save_config(config)
    return public_config(config)


def write_ui_command(action, **values):
    record = {"id": secrets.token_hex(8), "action": action, "createdAt": time.time()}
    record.update(values)
    atomic_write(UI_COMMAND_PATH, json.dumps(record).encode(), 0o600)
    return {"success": True, "queued": action}


def require_permission(config, permission):
    if not config["permissions"].get(permission):
        raise PermissionError(f"Orbit 的“{PERMISSION_LABELS[permission]}”权限已关闭")


def clean_path(value):
    value = os.path.abspath(os.path.expanduser(str(value)))
    if "\0" in value:
        raise ValueError("路径无效")
    return pathlib.Path(value)


def execute_tool(config, name, arguments):
    if name == "open_app":
        require_permission(config, "apps")
        app_id = str(arguments.get("app_id", ""))
        allowed = TOOLS[0]["function"]["parameters"]["properties"]["app_id"]["enum"]
        if app_id not in allowed:
            raise ValueError("未知系统面板")
        return write_ui_command("open_app", appId=app_id)
    if name == "open_world":
        require_permission(config, "world")
        return write_ui_command("open_world")
    if name == "recenter":
        require_permission(config, "settings")
        return write_ui_command("recenter")
    if name == "system_status":
        require_permission(config, "screen")
        uptime = pathlib.Path("/proc/uptime")
        return {
            "hostname": socket.gethostname(),
            "uptimeSeconds": float(uptime.read_text().split()[0]) if uptime.exists() else None,
            "provider": config["provider"],
            "model": config["model"],
            "worldLayer": "system",
            "displayMode": "single-frame mirrored to both eye displays",
        }
    if name == "list_directory":
        require_permission(config, "files")
        path = clean_path(arguments.get("path", ""))
        entries = []
        for item in sorted(path.iterdir(), key=lambda candidate: candidate.name.lower())[:200]:
            entries.append({
                "name": item.name,
                "path": str(item),
                "directory": item.is_dir(),
                "size": item.stat().st_size if item.is_file() else None,
            })
        return {"path": str(path), "entries": entries}
    if name == "read_file":
        require_permission(config, "files")
        path = clean_path(arguments.get("path", ""))
        if path.stat().st_size > 1024 * 1024:
            raise ValueError("单次读取文件不能超过 1 MiB")
        return {"path": str(path), "content": path.read_text(encoding="utf-8")}
    if name == "write_file":
        require_permission(config, "files")
        path = clean_path(arguments.get("path", ""))
        content = str(arguments.get("content", ""))
        if len(content.encode("utf-8")) > 1024 * 1024:
            raise ValueError("单次写入不能超过 1 MiB")
        path.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(path, content.encode("utf-8"), 0o600)
        return {"success": True, "path": str(path), "bytes": len(content.encode("utf-8"))}
    if name == "run_command":
        require_permission(config, "shell")
        command = str(arguments.get("command", "")).strip()
        if not command or len(command) > 4096 or "\0" in command:
            raise ValueError("命令无效")
        completed = subprocess.run(
            command,
            shell=True,
            executable="/bin/bash",
            cwd="/home/yunsh",
            capture_output=True,
            text=True,
            timeout=30,
            env={
                "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "LANG": "C.UTF-8",
                "HOME": "/home/yunsh",
            },
        )
        return {
            "command": shlex.join(["/bin/bash", "-lc", command]),
            "exitCode": completed.returncode,
            "stdout": completed.stdout[-MAX_TOOL_OUTPUT:],
            "stderr": completed.stderr[-MAX_TOOL_OUTPUT:],
        }
    raise ValueError("Orbit 不支持该工具")


def provider_endpoint(config):
    if config["provider"] == "compatible":
        return config["endpoint"]
    return PROVIDERS[config["provider"]]["endpoint"]


def voice_status():
    microphone = False
    if shutil.which("arecord"):
        checked = subprocess.run(
            ["arecord", "-l"], capture_output=True, text=True, timeout=5
        )
        microphone = checked.returncode == 0 and "card " in checked.stdout.lower()
    return {
        "microphone": microphone,
        "recognitionReady": VOICE_MODEL_DIR.exists() and shutil.which("arecord") is not None,
        "naturalVoiceReady": shutil.which("edge-tts") is not None and shutil.which("mpv") is not None,
        "offlineVoiceReady": shutil.which("espeak-ng") is not None,
    }


def speak_text(payload):
    text = str(payload.get("text", "")).strip()
    if not text or len(text) > 4000:
        raise ValueError("语音内容无效")
    config = load_config()
    voice_id = str(payload.get("voice", config.get("voice", "sweet_female")))
    if voice_id not in VOICE_CHOICES:
        raise ValueError("不支持的 Orbit 声音")
    voice = VOICE_CHOICES[voice_id]
    if shutil.which("edge-tts") and shutil.which("mpv"):
        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as audio:
            audio_path = audio.name
        try:
            generated = subprocess.run(
                [
                    "edge-tts",
                    "--voice", voice["edgeVoice"],
                    "--rate", voice["rate"],
                    "--pitch", voice["pitch"],
                    "--text", text,
                    "--write-media", audio_path,
                ],
                capture_output=True,
                text=True,
                timeout=75,
            )
            if generated.returncode != 0:
                raise RuntimeError(generated.stderr.strip() or "自然语音生成失败")
            def play_and_remove():
                try:
                    subprocess.run(
                        ["mpv", "--no-video", "--really-quiet", audio_path],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=180,
                    )
                finally:
                    try:
                        os.unlink(audio_path)
                    except OSError:
                        pass

            threading.Thread(target=play_and_remove, daemon=True).start()
            return {"speaking": True, "voice": voice_id, "engine": "neural"}
        except Exception:
            try:
                os.unlink(audio_path)
            except OSError:
                pass
    if shutil.which("espeak-ng"):
        subprocess.Popen(
            ["espeak-ng", "-v", "cmn", "-s", "165", text],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return {"speaking": True, "voice": voice_id, "engine": "offline"}
    raise RuntimeError("Orbit 语音输出组件尚未准备完成")


def listen_once():
    status = voice_status()
    if not status["microphone"]:
        raise RuntimeError("没有检测到 USB 或蓝牙麦克风")
    if not status["recognitionReady"]:
        raise RuntimeError("Orbit 离线语音识别模型仍在后台准备")
    try:
        import vosk
        import wave
    except ImportError as exc:
        raise RuntimeError("Orbit 离线语音识别组件尚未安装") from exc
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as audio:
        audio_path = audio.name
    try:
        recorded = subprocess.run(
            [
                "arecord", "-q", "-D", "default", "-f", "S16_LE",
                "-r", "16000", "-c", "1", "-d", "8", audio_path,
            ],
            capture_output=True,
            text=True,
            timeout=12,
        )
        if recorded.returncode != 0:
            raise RuntimeError(recorded.stderr.strip() or "麦克风录音失败")
        model = vosk.Model(str(VOICE_MODEL_DIR))
        recognizer = vosk.KaldiRecognizer(model, 16000)
        with wave.open(audio_path, "rb") as handle:
            while True:
                data = handle.readframes(4000)
                if not data:
                    break
                recognizer.AcceptWaveform(data)
        result = json.loads(recognizer.FinalResult())
        text = str(result.get("text", "")).strip()
        if not text:
            raise RuntimeError("没有识别到清晰语音")
        return {"text": text, "seconds": 8, "engine": "vosk-local"}
    finally:
        try:
            os.unlink(audio_path)
        except OSError:
            pass


def upstream_request(config, messages):
    require_permission(config, "network")
    if not config.get("apiKey"):
        raise ValueError("请先在 Orbit 设置中输入 API Key")
    body = {
        "model": config["model"],
        "messages": messages,
        "tools": TOOLS,
        "tool_choice": "auto",
        "stream": False,
    }
    request = urllib.request.Request(
        provider_endpoint(config),
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {config['apiKey']}",
            "Content-Type": "application/json",
            "User-Agent": "Orbit-YUNSH-OS/2.0.1",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=75) as response:
            result = json.loads(response.read(MAX_BODY).decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read(4096).decode("utf-8", "replace")
        try:
            detail = json.loads(detail).get("error", {}).get("message", detail)
        except (ValueError, AttributeError):
            pass
        raise RuntimeError(f"提供商返回 HTTP {exc.code}：{detail}") from exc
    except (urllib.error.URLError, TimeoutError) as exc:
        raise RuntimeError(f"无法连接 API 提供商：{exc}") from exc
    try:
        return result["choices"][0]["message"], result.get("usage", {})
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError("API 提供商返回了无法识别的响应") from exc


SYSTEM_PROMPT = """你是 Orbit，YUNSH OS 的系统级 AI Agent。
你不是普通聊天 App，而是桌面、设备互联和持续存在虚拟世界的系统入口。
你可以像 Codex 或 OpenClaw 一样理解任务、使用工具、检查结果并继续执行。
用户当前授予的权限决定哪些工具能够执行。需要操作时优先调用工具，不要假装执行。
YUNSH 世界是系统层，不要称其为普通 App。当前显示硬件把一个完整画面同步到左右屏，
不把 SBS 当作默认模式。用简洁自然的中文回复，明确说明执行结果和失败原因。"""


def sanitize_history(history):
    cleaned = []
    if not isinstance(history, list):
        return cleaned
    for item in history[-MAX_HISTORY:]:
        if not isinstance(item, dict):
            continue
        role = item.get("role")
        content = item.get("content")
        if role in {"user", "assistant"} and isinstance(content, str):
            cleaned.append({"role": role, "content": content[:16000]})
    return cleaned


def chat(payload):
    config = load_config()
    message = str(payload.get("message", "")).strip()
    if not message or len(message) > 32000:
        raise ValueError("请输入有效内容")
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    messages.extend(sanitize_history(payload.get("history")))
    messages.append({"role": "user", "content": message})
    executed = []
    usage = {}
    for _round in range(MAX_TOOL_ROUNDS):
        assistant, usage = upstream_request(config, messages)
        tool_calls = assistant.get("tool_calls") or []
        if not tool_calls:
            return {
                "reply": assistant.get("content") or "任务已完成。",
                "tools": executed,
                "usage": usage,
            }
        messages.append(assistant)
        for call in tool_calls:
            function = call.get("function") or {}
            name = str(function.get("name", ""))
            try:
                arguments = json.loads(function.get("arguments") or "{}")
                result = execute_tool(config, name, arguments)
                success = True
            except Exception as exc:
                result = {"error": str(exc)}
                success = False
            executed.append({"name": name, "success": success})
            messages.append({
                "role": "tool",
                "tool_call_id": call.get("id", secrets.token_hex(4)),
                "content": json.dumps(result, ensure_ascii=False)[:MAX_TOOL_OUTPUT],
            })
    return {
        "reply": "已达到本次任务的工具调用上限。我保留了已完成的操作，请继续告诉我下一步。",
        "tools": executed,
        "usage": usage,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "Orbit/2.0.1"

    def send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_json(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as exc:
            raise ValueError("请求长度无效") from exc
        if length < 0 or length > MAX_BODY:
            raise ValueError("请求过大")
        return json.loads(self.rfile.read(length).decode("utf-8") or "{}")

    def do_GET(self):
        try:
            if self.path == "/v1/status":
                config = load_config()
                self.send_json(200, {
                    "success": True,
                    "running": True,
                    "name": "Orbit",
                    "scope": "system",
                    "config": public_config(config),
                })
                return
            if self.path == "/v1/providers":
                self.send_json(200, {
                    "success": True,
                    "providers": [
                        {"id": key, **value} for key, value in PROVIDERS.items()
                    ],
                })
                return
            if self.path == "/v1/voice/status":
                self.send_json(200, {"success": True, **voice_status()})
                return
            self.send_json(404, {"success": False, "error": "Not found"})
        except Exception as exc:
            self.send_json(500, {"success": False, "error": str(exc)})

    def do_POST(self):
        try:
            payload = self.read_json()
            if self.path == "/v1/config":
                result = update_config(payload)
            elif self.path == "/v1/chat":
                result = chat(payload)
            elif self.path == "/v1/voice/speak":
                result = speak_text(payload)
            elif self.path == "/v1/voice/listen":
                result = listen_once()
            else:
                self.send_json(404, {"success": False, "error": "Not found"})
                return
            self.send_json(200, {"success": True, **result})
        except (ValueError, PermissionError) as exc:
            self.send_json(400, {"success": False, "error": str(exc)})
        except Exception as exc:
            self.send_json(502, {"success": False, "error": str(exc)})

    def log_message(self, _format, *_args):
        return


if __name__ == "__main__":
    ensure_storage()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.daemon_threads = True
    server.serve_forever()
