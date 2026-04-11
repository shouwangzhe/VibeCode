#!/usr/bin/env python3
"""
VibeCode Remote Bridge
======================
Claude Code hook 处理脚本。每次 hook 触发时被调用，
读取 stdin JSON，发送到本地 vibecode-agent HTTP 服务。
对于 PermissionRequest，轮询等待审批结果并返回给 Claude Code。

用法（由 Claude Code hooks 自动调用）:
    echo '{"session_id":"...","hook_event_name":"SessionStart",...}' | vibecode-bridge

环境变量:
    VIBECODE_AGENT_URL  — agent 地址 (默认 http://127.0.0.1:19876)
    VIBECODE_TOKEN      — 认证 token (可选)

零依赖，仅使用 Python 标准库。兼容 Python 3.6+。
"""

import json
import os
import subprocess
import sys
import time
import uuid

# Python 3 stdlib HTTP client
try:
    from urllib.request import Request, urlopen
    from urllib.error import URLError, HTTPError
except ImportError:
    sys.exit(0)  # Python 2 — fail silently

AGENT_URL = os.environ.get("VIBECODE_AGENT_URL", "http://127.0.0.1:8876")
AUTH_TOKEN = os.environ.get("VIBECODE_TOKEN", "")

VALID_EVENTS = {
    "SessionStart", "SessionEnd",
    "PreToolUse", "PostToolUse", "PostToolUseFailure",
    "PermissionRequest", "Notification",
    "UserPromptSubmit", "Stop",
    "SubagentStart", "SubagentStop",
    "PreCompact", "PostCompact",
}


def http_post(path, data):
    """POST JSON to agent, return parsed response."""
    url = AGENT_URL.rstrip("/") + path
    body = json.dumps(data, ensure_ascii=False).encode("utf-8")
    req = Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    if AUTH_TOKEN:
        req.add_header("Authorization", "Bearer " + AUTH_TOKEN)
    try:
        resp = urlopen(req, timeout=5)
        return json.loads(resp.read())
    except (URLError, HTTPError, OSError) as e:
        sys.stderr.write("[vibecode-bridge] HTTP error: %s\n" % e)
        return None


def http_get(path, timeout=5):
    """GET from agent, return parsed response."""
    url = AGENT_URL.rstrip("/") + path
    req = Request(url)
    if AUTH_TOKEN:
        req.add_header("Authorization", "Bearer " + AUTH_TOKEN)
    try:
        resp = urlopen(req, timeout=timeout)
        return json.loads(resp.read())
    except (URLError, HTTPError, OSError) as e:
        sys.stderr.write("[vibecode-bridge] HTTP error: %s\n" % e)
        return None


def main():
    # Read stdin
    try:
        raw = sys.stdin.buffer.read()
    except Exception:
        raw = sys.stdin.read().encode("utf-8")

    if not raw:
        sys.exit(0)

    # Parse hook input
    try:
        hook_input = json.loads(raw)
    except json.JSONDecodeError as e:
        sys.stderr.write("[vibecode-bridge] JSON parse error: %s\n" % e)
        sys.exit(1)

    event_name = hook_input.get("hook_event_name", "")
    if event_name not in VALID_EVENTS:
        sys.stderr.write("[vibecode-bridge] Unknown event: %s\n" % event_name)
        sys.exit(0)

    session_id = hook_input.get("session_id", "unknown")
    event_id = str(uuid.uuid4())

    # Build event message (matches IPCMessage format)
    # Detect TTY by walking up the process tree (bridge → shell → claude)
    tty = None
    try:
        ppid = os.getppid()
        result = subprocess.run(
            ['ps', '-o', 'ppid=,tty=', '-p', str(ppid)],
            capture_output=True, text=True, timeout=2
        )
        parts = result.stdout.strip().split()
        if len(parts) >= 2 and parts[1] != '??':
            tty = parts[1]
        elif len(parts) >= 1:
            gppid = parts[0].strip()
            result2 = subprocess.run(
                ['ps', '-o', 'tty=', '-p', gppid],
                capture_output=True, text=True, timeout=2
            )
            t = result2.stdout.strip()
            if t and t != '??':
                tty = t
    except Exception:
        pass

    event = {
        "id": event_id,
        "eventType": event_name,
        "source": "claude",
        "sessionId": session_id,
        "cwd": hook_input.get("cwd"),
        "toolName": hook_input.get("tool_name"),
        "toolInput": hook_input.get("tool_input"),
        "prompt": hook_input.get("prompt"),
        "transcriptPath": hook_input.get("transcript_path"),
        "tty": tty,
        "timestamp": time.time(),
    }

    # Send event to agent
    result = http_post("/event", event)
    if result is None:
        # Agent not running — fail silently so Claude Code continues
        sys.exit(0)

    sys.stderr.write("[vibecode-bridge] sent %s for session %s\n" % (event_name, session_id))

    # For permission requests, poll for approval result
    if event_name == "PermissionRequest":
        poll_interval = 0.5  # seconds
        max_wait = 86400     # 24 hours
        start = time.time()

        while time.time() - start < max_wait:
            resp = http_get("/pending/%s" % event_id)
            if resp is None:
                # Agent went down — let Claude Code handle timeout
                sys.exit(2)

            if resp.get("status") == "resolved":
                approval = resp.get("result", {})
                decision = approval.get("decision", "deny")
                updated_input = approval.get("updatedInput")

                # Map to Claude Code behavior
                if decision in ("allow", "always_allow"):
                    behavior = "allow"
                else:
                    behavior = "deny"

                # Build decision dict
                decision_dict = {"behavior": behavior}
                if updated_input:
                    decision_dict["updatedInput"] = updated_input

                # Output in Claude Code's expected format
                output = {
                    "hookSpecificOutput": {
                        "hookEventName": "PermissionRequest",
                        "decision": decision_dict
                    }
                }
                sys.stdout.buffer.write(json.dumps(output).encode("utf-8"))
                sys.stdout.flush()
                sys.exit(0)

            # Still pending — wait and retry
            time.sleep(poll_interval)

        # Timed out
        sys.stderr.write("[vibecode-bridge] approval timed out for %s\n" % event_id)
        sys.exit(2)


if __name__ == "__main__":
    main()
