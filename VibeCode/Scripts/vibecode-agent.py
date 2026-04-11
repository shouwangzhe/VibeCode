#!/usr/bin/env python3
"""
VibeCode Remote Agent
=====================
容器内运行的 HTTP 服务，收集 Claude Code hook 事件，
暴露 API 给 Mac 上的 VibeCode.app 轮询。

用法:
    python3 vibecode-agent.py [--port 19876] [--token TOKEN]

API:
    POST /event          — bridge 发送 hook 事件
    GET  /events         — VibeCode 轮询获取新事件
    POST /approve/{id}   — VibeCode 发送审批结果
    GET  /pending/{id}   — bridge 轮询等待审批结果
    GET  /health         — 健康检查

零依赖，仅使用 Python 标准库。
"""

import argparse
import json
import sys
import threading
import time
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

# Thread-safe storage
_lock = threading.Lock()
_event_queue = []           # events waiting to be polled by VibeCode
_pending_approvals = {}     # id -> event (waiting for user to approve)
_approval_results = {}      # id -> {"decision": "allow"/"deny"/...}
_session_ttys = {}          # sessionId -> tty device name (e.g. "pts/0" or "ttys000")
_auth_token = None          # optional auth token


class AgentHandler(BaseHTTPRequestHandler):
    """HTTP request handler for the VibeCode remote agent."""

    def log_message(self, format, *args):
        """Override to use timestamp prefix."""
        sys.stderr.write("[%s] %s\n" % (
            time.strftime("%Y-%m-%d %H:%M:%S"), format % args))

    def _check_auth(self):
        """Check authorization token if configured."""
        if _auth_token is None:
            return True
        token = self.headers.get("Authorization", "").replace("Bearer ", "")
        if token != _auth_token:
            self._respond(403, {"error": "forbidden"})
            return False
        return True

    def _respond(self, code, data):
        """Send JSON response."""
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        """Read request body as JSON."""
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw)

    def do_GET(self):
        path = urlparse(self.path).path.rstrip("/")

        if path == "/health":
            self._respond(200, {
                "status": "ok",
                "version": "1.0.0",
                "uptime": time.time() - _start_time,
                "pending_approvals": len(_pending_approvals),
                "queued_events": len(_event_queue),
            })
            return

        if path == "/events":
            if not self._check_auth():
                return
            with _lock:
                events = list(_event_queue)
                _event_queue.clear()
            self._respond(200, {"events": events})
            return

        # GET /pending/{id} — bridge polls for approval result
        if path.startswith("/pending/"):
            event_id = path[len("/pending/"):]
            with _lock:
                if event_id in _approval_results:
                    result = _approval_results.pop(event_id)
                    _pending_approvals.pop(event_id, None)
                    self._respond(200, {"status": "resolved", "result": result})
                    return
                if event_id in _pending_approvals:
                    self._respond(200, {"status": "pending"})
                    return
            self._respond(404, {"error": "not found"})
            return

        self._respond(404, {"error": "not found"})

    def do_POST(self):
        path = urlparse(self.path).path.rstrip("/")

        if path == "/event":
            if not self._check_auth():
                return
            try:
                event = self._read_body()
            except (json.JSONDecodeError, ValueError) as e:
                self._respond(400, {"error": str(e)})
                return

            event_id = event.get("id", str(uuid.uuid4()))
            event["id"] = event_id

            with _lock:
                _event_queue.append(event)
                # Track session TTY for remote input
                tty = event.get("tty")
                session_id = event.get("sessionId")
                if tty and session_id:
                    _session_ttys[session_id] = tty
                # If it's a permission request, also track it for approval
                if event.get("eventType") == "PermissionRequest":
                    _pending_approvals[event_id] = event

            self._respond(200, {"id": event_id, "status": "queued"})
            return

        # POST /approve/{id} — VibeCode sends approval decision
        if path.startswith("/approve/"):
            if not self._check_auth():
                return
            event_id = path[len("/approve/"):]
            try:
                body = self._read_body()
            except (json.JSONDecodeError, ValueError) as e:
                self._respond(400, {"error": str(e)})
                return

            with _lock:
                if event_id not in _pending_approvals:
                    self._respond(404, {"error": "no pending approval with this id"})
                    return
                _approval_results[event_id] = body

            sys.stderr.write("[agent] approve %s body: %s\n" % (event_id, json.dumps(body, ensure_ascii=False)))
            self._respond(200, {"status": "approved", "id": event_id})
            return

        # POST /input/{sessionId} — VibeCode sends text input to a session's terminal
        if path.startswith("/input/"):
            if not self._check_auth():
                return
            session_id = path[len("/input/"):]
            try:
                body = self._read_body()
            except (json.JSONDecodeError, ValueError) as e:
                self._respond(400, {"error": str(e)})
                return

            text = body.get("text", "")
            if not text:
                self._respond(400, {"error": "missing text"})
                return

            with _lock:
                tty_name = _session_ttys.get(session_id)

            if not tty_name:
                self._respond(404, {"error": "no TTY known for session %s" % session_id})
                return

            # Write to the terminal device
            tty_path = "/dev/" + tty_name
            try:
                with open(tty_path, "w") as f:
                    f.write(text + "\n")
                sys.stderr.write("[agent] input sent to %s for session %s: %s\n" % (tty_path, session_id, text[:100]))
                self._respond(200, {"status": "sent", "tty": tty_path})
            except (IOError, OSError) as e:
                sys.stderr.write("[agent] input error for %s: %s\n" % (tty_path, e))
                self._respond(500, {"error": "failed to write to TTY: %s" % str(e)})
            return

        self._respond(404, {"error": "not found"})

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()


def cleanup_stale_approvals():
    """Periodically clean up approvals older than 24 hours."""
    while True:
        time.sleep(300)  # every 5 minutes
        cutoff = time.time() - 86400
        with _lock:
            stale_ids = [
                eid for eid, ev in _pending_approvals.items()
                if ev.get("timestamp", 0) < cutoff
            ]
            for eid in stale_ids:
                _pending_approvals.pop(eid, None)
                _approval_results.pop(eid, None)
                sys.stderr.write("[cleanup] Removed stale approval: %s\n" % eid)


def main():
    global _auth_token, _start_time

    parser = argparse.ArgumentParser(description="VibeCode Remote Agent")
    parser.add_argument("--port", type=int, default=8876, help="HTTP port (default: 8876)")
    parser.add_argument("--host", default="0.0.0.0", help="Bind address (default: 0.0.0.0)")
    parser.add_argument("--token", default=None, help="Auth token (optional)")
    args = parser.parse_args()

    _auth_token = args.token
    _start_time = time.time()

    # Start cleanup thread
    cleaner = threading.Thread(target=cleanup_stale_approvals, daemon=True)
    cleaner.start()

    server = HTTPServer((args.host, args.port), AgentHandler)
    sys.stderr.write("VibeCode Agent listening on %s:%d\n" % (args.host, args.port))
    if _auth_token:
        sys.stderr.write("Auth token: %s\n" % _auth_token)
    sys.stderr.write("Press Ctrl+C to stop.\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        sys.stderr.write("\nShutting down.\n")
        server.shutdown()


if __name__ == "__main__":
    main()
