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
MAX_TOOL_ROUNDS = 16
MAX_TOOL_OUTPUT = 24000
PENDING_APPROVALS = {}
PENDING_LOCK = threading.Lock()
UI_STATE_PATH = pathlib.Path(
    os.environ.get("YUNSH_UI_STATE_PATH", "/tmp/yunsh-ui-state.json")
)
LOCK_STATE_PATH = pathlib.Path(
    os.environ.get("YUNSH_LOCK_STATE_PATH", "/run/yunsh/screen-lock.json")
)
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
    "microphone": "使用麦克风进行语音识别",
    "memory": "保存长期任务记忆",
    "world": "控制 YUNSH 世界层",
}
DEFAULT_PERMISSIONS = {name: True for name in PERMISSION_LABELS}
TOOL_PERMISSION = {
    "open_app": "apps",
    "open_world": "world",
    "recenter": "settings",
    "ui_action": "apps",
    "system_status": "screen",
    "ui_state": "screen",
    "capture_screen": "screen",
    "start_screen_recording": "screen",
    "stop_screen_recording": "screen",
    "recording_status": "screen",
    "list_directory": "files",
    "read_file": "files",
    "write_file": "files",
    "run_command": "shell",
    "update_plan": "memory",
    "remember": "memory",
    "wait": "apps",
    "power_action": "settings",
    "voice_listen": "microphone",
}
ALWAYS_CONFIRM_TOOLS = {"power_action"}

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
            "name": "ui_action",
            "description": "Control the YUNSH shell semantically without guessing screen coordinates.",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": [
                            "home", "task_switcher", "close_active",
                            "minimize_active", "toggle_keyboard", "lock",
                        ],
                    }
                },
                "required": ["action"],
            },
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
    {
        "type": "function",
        "function": {
            "name": "ui_state",
            "description": "Observe the active app, open windows, world layer, focus mode, and recording state.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "capture_screen",
            "description": "Capture the current display for verification and return OCR text when available.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "start_screen_recording",
            "description": "Start visibly indicated screen recording.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "stop_screen_recording",
            "description": "Stop screen recording and return the saved video path.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "recording_status",
            "description": "Check whether screen recording is active.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "update_plan",
            "description": "Create or update the explicit plan for a multi-step task.",
            "parameters": {
                "type": "object",
                "properties": {
                    "objective": {"type": "string"},
                    "steps": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "step": {"type": "string"},
                                "status": {
                                    "type": "string",
                                    "enum": ["pending", "in_progress", "completed"],
                                },
                            },
                            "required": ["step", "status"],
                        },
                    },
                },
                "required": ["objective", "steps"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "remember",
            "description": "Save a durable user-approved fact or task note.",
            "parameters": {
                "type": "object",
                "properties": {"text": {"type": "string"}},
                "required": ["text"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "wait",
            "description": "Wait briefly for a background action, then continue observing.",
            "parameters": {
                "type": "object",
                "properties": {
                    "seconds": {"type": "number", "minimum": 0.2, "maximum": 15}
                },
                "required": ["seconds"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "power_action",
            "description": "Restart, shut down, or factory-reset YUNSH OS. Always needs fresh approval.",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["restart", "shutdown", "factory_reset"],
                    }
                },
                "required": ["action"],
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
        "alwaysAllowedTools": [],
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
    allowed_tools = config.get("alwaysAllowedTools")
    config["alwaysAllowedTools"] = (
        [str(name) for name in allowed_tools if str(name) in TOOL_PERMISSION]
        if isinstance(allowed_tools, list) else []
    )
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
        "alwaysAllowedTools": config.get("alwaysAllowedTools", []),
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

    permissions = dict(existing.get("permissions", DEFAULT_PERMISSIONS))
    supplied_permissions = payload.get("permissions")
    if isinstance(supplied_permissions, dict):
        for name in permissions:
            if isinstance(supplied_permissions.get(name), bool):
                permissions[name] = supplied_permissions[name]

    voice = str(payload.get("voice", existing.get("voice", "sweet_female")))
    if voice not in VOICE_CHOICES:
        raise ValueError("不支持的 Orbit 声音")

    allowed_tools = [
        name for name in existing.get("alwaysAllowedTools", [])
        if permissions.get(TOOL_PERMISSION.get(name, ""), True)
    ]
    config = {
        "provider": provider,
        "model": model,
        "apiKey": api_key,
        "endpoint": endpoint,
        "permissions": permissions,
        "alwaysAllowedTools": allowed_tools,
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


def screen_is_locked():
    try:
        state = json.loads(LOCK_STATE_PATH.read_text(encoding="utf-8"))
        return bool(state.get("locked"))
    except (OSError, ValueError, TypeError):
        return False


def require_screen_unlocked():
    if screen_is_locked():
        raise PermissionError("设备已锁定，请先在眼镜本机输入密码解锁")


def clean_path(value):
    value = os.path.abspath(os.path.expanduser(str(value)))
    if "\0" in value:
        raise ValueError("路径无效")
    return pathlib.Path(value)


def run_helper(command, timeout=30):
    completed = subprocess.run(
        command, capture_output=True, text=True, timeout=timeout
    )
    output = completed.stdout.strip()
    try:
        result = json.loads(output) if output else {}
    except json.JSONDecodeError:
        result = {"output": output}
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or output or "系统操作失败")
    return result


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
    if name == "ui_action":
        require_permission(config, "apps")
        action = str(arguments.get("action", ""))
        allowed = {
            "home", "task_switcher", "close_active",
            "minimize_active", "toggle_keyboard", "lock",
        }
        if action not in allowed:
            raise ValueError("未知界面操作")
        return write_ui_command("ui_action", uiAction=action)
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
    if name == "ui_state":
        require_permission(config, "screen")
        if not UI_STATE_PATH.exists():
            return {"available": False, "message": "桌面状态尚未上报"}
        state = json.loads(UI_STATE_PATH.read_text(encoding="utf-8"))
        state["available"] = True
        return state
    if name == "capture_screen":
        require_permission(config, "screen")
        capture_dir = STATE_DIR / "screen"
        capture_dir.mkdir(parents=True, exist_ok=True)
        os.chmod(capture_dir, 0o700)
        capture_env = dict(os.environ)
        capture_env["YUNSH_SCREENSHOT_DIR"] = str(capture_dir)
        captured = subprocess.run(
            ["/usr/bin/yunsh-screenshotd", "full"],
            capture_output=True, text=True, timeout=30, env=capture_env,
        )
        if captured.returncode != 0:
            raise RuntimeError(captured.stderr.strip() or "屏幕捕获失败")
        path = captured.stdout.strip().splitlines()[-1]
        result = {"path": path, "ocrAvailable": False, "text": ""}
        if shutil.which("tesseract"):
            ocr = subprocess.run(
                ["tesseract", path, "stdout", "-l", "chi_sim+eng"],
                capture_output=True, text=True, timeout=45,
            )
            if ocr.returncode == 0:
                result.update({
                    "ocrAvailable": True,
                    "text": ocr.stdout[-MAX_TOOL_OUTPUT:],
                })
        captures = sorted(
            capture_dir.glob("Screenshot_*.png"),
            key=lambda item: item.stat().st_mtime,
            reverse=True,
        )
        for old_capture in captures[3:]:
            try:
                old_capture.unlink()
            except OSError:
                pass
        return result
    if name in {"start_screen_recording", "stop_screen_recording", "recording_status"}:
        require_permission(config, "screen")
        operation = {
            "start_screen_recording": "start",
            "stop_screen_recording": "stop",
            "recording_status": "status",
        }[name]
        return run_helper(["/usr/bin/yunsh-recordingd", operation], timeout=40)
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
    if name == "update_plan":
        require_permission(config, "memory")
        objective = str(arguments.get("objective", "")).strip()[:1000]
        steps = arguments.get("steps")
        if not objective or not isinstance(steps, list) or len(steps) > 30:
            raise ValueError("任务计划无效")
        normalized = []
        in_progress = 0
        for item in steps:
            step = str(item.get("step", "")).strip()[:500]
            status = str(item.get("status", "pending"))
            if not step or status not in {"pending", "in_progress", "completed"}:
                raise ValueError("任务计划步骤无效")
            in_progress += status == "in_progress"
            normalized.append({"step": step, "status": status})
        if in_progress > 1:
            raise ValueError("同时只能有一个进行中的步骤")
        record = {
            "objective": objective,
            "steps": normalized,
            "updatedAt": time.time(),
        }
        atomic_write(
            STATE_DIR / "current-plan.json",
            json.dumps(record, ensure_ascii=False).encode("utf-8"),
            0o600,
        )
        return record
    if name == "remember":
        require_permission(config, "memory")
        text = str(arguments.get("text", "")).strip()
        if not text or len(text) > 4000:
            raise ValueError("记忆内容无效")
        memory_dir = STATE_DIR / "memory"
        memory_dir.mkdir(parents=True, exist_ok=True)
        entry = json.dumps(
            {"text": text, "createdAt": time.time()}, ensure_ascii=False
        ) + "\n"
        with open(memory_dir / "orbit-memory.jsonl", "a", encoding="utf-8") as handle:
            handle.write(entry)
        return {"saved": True}
    if name == "wait":
        seconds = min(15.0, max(0.2, float(arguments.get("seconds", 1))))
        time.sleep(seconds)
        return {"waitedSeconds": seconds}
    if name == "power_action":
        require_permission(config, "settings")
        action = str(arguments.get("action", ""))
        if action not in {"restart", "shutdown", "factory_reset"}:
            raise ValueError("未知电源操作")
        return write_ui_command("confirm_system_action", systemAction=action)
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


def grant_capability(payload):
    name = str(payload.get("name", ""))
    if name not in {"voice_listen"}:
        raise ValueError("未知权限")
    config = load_config()
    require_permission(config, TOOL_PERMISSION[name])
    allowed = set(config.get("alwaysAllowedTools", []))
    allowed.add(name)
    config["alwaysAllowedTools"] = sorted(allowed)
    save_config(config)
    return {"granted": name}


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
    if config["provider"] == "deepseek":
        # DeepSeek thinking-mode tool calls require reasoning_content to be
        # preserved between tool rounds; continue_agent appends the complete
        # assistant message, including that field, without stripping it.
        body["thinking"] = {"type": "enabled"}
        body["reasoning_effort"] = "max"
    request = urllib.request.Request(
        provider_endpoint(config),
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {config['apiKey']}",
            "Content-Type": "application/json",
            "User-Agent": "Orbit-YUNSH-OS/3.0.4",
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
你像 Codex 一样工作：先理解目标；复杂任务先用 update_plan 建立可核对的计划；
然后连续使用工具推进，读取工具结果，必要时等待、观察界面或截图验证，遇到失败先诊断并重试。
不要在仍有安全可行的下一步时提前停下，也不要仅凭工具已调用就声称成功。
用户当前授予的权限决定哪些工具能够执行。需要操作时优先调用工具，不要假装执行。
一次只发起一个工具调用，以便权限确认和执行状态始终清晰。
截图、录屏、文件修改、Shell、记忆等能力在首次使用时会由系统请求确认；
关机、重启和破坏性命令永远需要新确认。拒绝后尊重用户决定并提供安全替代方案。
YUNSH 世界是系统层，不要称其为普通 App。当前显示硬件把一个完整画面同步到左右屏，
不把 SBS 当作默认模式。用简洁自然的中文回复，明确说明执行结果和失败原因。"""

REASONING_GUIDANCE = {
    "low": "本轮使用 Low 推理强度：优先快速完成直接任务，减少不必要的展开。",
    "medium": "本轮使用 Medium 推理强度：在速度、核验和分析深度之间保持平衡。",
    "high": "本轮使用 High 推理强度：复杂任务先充分检查前提、替代方案和执行结果。",
}


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


def tool_approval(config, name, arguments):
    permission = TOOL_PERMISSION.get(name)
    if permission:
        require_permission(config, permission)
    command = str(arguments.get("command", "")) if name == "run_command" else ""
    destructive_shell = bool(re.search(
        r"(^|[;&|]\s*)(rm|dd|mkfs|shutdown|reboot|poweroff)\b|"
        r"\bsystemctl\s+(reboot|poweroff)\b|git\s+reset\s+--hard",
        command,
        re.IGNORECASE,
    ))
    always = name in ALWAYS_CONFIRM_TOOLS or destructive_shell
    allowed = name in config.get("alwaysAllowedTools", [])
    if not always and allowed:
        return None
    summaries = {
        "open_app": f"允许 Orbit 打开 {arguments.get('app_id', '系统面板')}",
        "open_world": "允许 Orbit 进入 YUNSH META Universe",
        "recenter": "允许 Orbit 调整当前观看方向",
        "ui_action": f"允许 Orbit 操作界面：{arguments.get('action', '')}",
        "system_status": "允许 Orbit 读取设备状态",
        "ui_state": "允许 Orbit 查看当前界面与窗口状态",
        "capture_screen": "允许 Orbit 截取并识别当前屏幕",
        "start_screen_recording": "允许 Orbit 开始录制屏幕",
        "stop_screen_recording": "允许 Orbit 停止并保存录屏",
        "recording_status": "允许 Orbit 查看录屏状态",
        "list_directory": f"允许 Orbit 查看目录：{arguments.get('path', '')}",
        "read_file": f"允许 Orbit 读取文件：{arguments.get('path', '')}",
        "write_file": f"允许 Orbit 修改文件：{arguments.get('path', '')}",
        "run_command": f"允许 Orbit 执行命令：{command[:180]}",
        "update_plan": "允许 Orbit 保存当前任务计划",
        "remember": "允许 Orbit保存一条长期记忆",
        "wait": "允许 Orbit 等待后台任务完成",
        "power_action": (
            "允许 Orbit 请求重启系统"
            if arguments.get("action") == "restart"
            else ("允许 Orbit 请求恢复出厂设置"
                  if arguments.get("action") == "factory_reset"
                  else "允许 Orbit 请求关闭系统")
        ),
    }
    return {
        "summary": summaries.get(name, f"允许 Orbit 使用 {name}"),
        "permission": permission or "system",
        "permissionLabel": PERMISSION_LABELS.get(permission, "系统操作"),
        "alwaysConfirm": always,
    }


def save_pending(state, approval):
    request_id = secrets.token_urlsafe(18)
    state["createdAt"] = time.time()
    with PENDING_LOCK:
        now = time.time()
        for key in list(PENDING_APPROVALS):
            if now - PENDING_APPROVALS[key].get("createdAt", now) > 600:
                PENDING_APPROVALS.pop(key, None)
        PENDING_APPROVALS[request_id] = state
    return {
        "reply": "需要你的确认后我才能继续。",
        "tools": state["executed"],
        "usage": state.get("usage", {}),
        "approval": {"requestId": request_id, **approval},
    }


def continue_agent(state, approved_call_id=None, approved=False):
    config = state["config"]
    messages = state["messages"]
    executed = state["executed"]
    usage = state.get("usage", {})
    pending = state.get("pending", [])
    rounds = int(state.get("rounds", 0))
    while rounds < MAX_TOOL_ROUNDS:
        if not pending:
            assistant, usage = upstream_request(config, messages)
            pending = list(assistant.get("tool_calls") or [])
            if not pending:
                return {
                    "reply": assistant.get("content") or "任务已完成。",
                    "tools": executed,
                    "usage": usage,
                }
            messages.append(assistant)
            rounds += 1
        call = pending.pop(0)
        function = call.get("function") or {}
        name = str(function.get("name", ""))
        call_id = call.get("id", secrets.token_hex(4))
        try:
            arguments = json.loads(function.get("arguments") or "{}")
        except json.JSONDecodeError:
            arguments = {}
        if call_id == approved_call_id:
            if approved:
                approval = None
            else:
                result = {"error": "用户拒绝了这项操作"}
                executed.append({"name": name, "success": False, "denied": True})
                messages.append({
                    "role": "tool", "tool_call_id": call_id,
                    "content": json.dumps(result, ensure_ascii=False),
                })
                continue
        else:
            approval = tool_approval(config, name, arguments)
        if approval:
            return save_pending({
                "config": config,
                "messages": messages,
                "executed": executed,
                "usage": usage,
                "pending": [call] + pending,
                "rounds": rounds,
            }, approval)
        try:
            result = execute_tool(config, name, arguments)
            success = True
        except Exception as exc:
            result = {"error": str(exc)}
            success = False
        executed.append({"name": name, "success": success})
        messages.append({
            "role": "tool",
            "tool_call_id": call_id,
            "content": json.dumps(result, ensure_ascii=False)[:MAX_TOOL_OUTPUT],
        })
    return {
        "reply": "本轮已达到安全执行上限。我已保留完成的结果，可以继续完成剩余步骤。",
        "tools": executed,
        "usage": usage,
    }


def chat(payload):
    message = str(payload.get("message", "")).strip()
    if not message or len(message) > 32000:
        raise ValueError("请输入有效内容")
    reasoning_effort = str(payload.get("reasoningEffort", "medium")).lower()
    if reasoning_effort not in REASONING_GUIDANCE:
        raise ValueError("不支持的推理强度")
    messages = [{
        "role": "system",
        "content": SYSTEM_PROMPT + "\n" + REASONING_GUIDANCE[reasoning_effort],
    }]
    messages.extend(sanitize_history(payload.get("history")))
    messages.append({"role": "user", "content": message})
    return continue_agent({
        "config": load_config(),
        "messages": messages,
        "executed": [],
        "usage": {},
        "pending": [],
        "rounds": 0,
    })


def approve(payload):
    request_id = str(payload.get("requestId", ""))
    decision = str(payload.get("decision", "deny"))
    with PENDING_LOCK:
        state = PENDING_APPROVALS.pop(request_id, None)
    if not state:
        raise ValueError("这项确认已失效，请重新发起任务")
    call = state.get("pending", [{}])[0]
    function = call.get("function") or {}
    name = str(function.get("name", ""))
    if decision == "always":
        if name in ALWAYS_CONFIRM_TOOLS:
            raise ValueError("破坏性操作不能设为始终允许")
        config = load_config()
        allowed = set(config.get("alwaysAllowedTools", []))
        allowed.add(name)
        config["alwaysAllowedTools"] = sorted(allowed)
        save_config(config)
        state["config"] = config
    return continue_agent(
        state,
        approved_call_id=call.get("id"),
        approved=decision in {"once", "always"},
    )


class Handler(BaseHTTPRequestHandler):
    server_version = "Orbit/3.0.4"

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
                    "screenLocked": screen_is_locked(),
                    "name": "Orbit",
                    "scope": "system",
                    "agentMode": "plan-act-observe-verify",
                    "approvalMode": "first-use-and-always-for-destructive",
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
            if self.path in {
                "/v1/config", "/v1/chat", "/v1/approve",
                "/v1/voice/speak", "/v1/voice/listen",
                "/v1/permissions/grant",
            }:
                require_screen_unlocked()
            if self.path == "/v1/config":
                result = update_config(payload)
            elif self.path == "/v1/chat":
                result = chat(payload)
            elif self.path == "/v1/approve":
                result = approve(payload)
            elif self.path == "/v1/voice/speak":
                result = speak_text(payload)
            elif self.path == "/v1/voice/listen":
                config = load_config()
                require_permission(config, "microphone")
                if (
                    "voice_listen" not in config.get("alwaysAllowedTools", [])
                    and payload.get("approved") is not True
                ):
                    result = {
                        "approvalRequired": True,
                        "permission": "microphone",
                        "permissionLabel": PERMISSION_LABELS["microphone"],
                        "summary": "允许 Orbit 使用麦克风聆听 8 秒并在本机识别语音",
                    }
                else:
                    result = listen_once()
            elif self.path == "/v1/permissions/grant":
                result = grant_capability(payload)
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
