#!/usr/bin/env python3
"""Send test IPC messages to VibeCode to verify features."""
import socket
import json
import struct
import time
import uuid
import sys

SOCKET_PATH = "/tmp/vibecode.sock"

def send_message(msg: dict) -> dict | None:
    """Send a length-prefixed JSON message to VibeCode and optionally read response."""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(SOCKET_PATH)

    data = json.dumps(msg).encode("utf-8")
    header = struct.pack(">I", len(data))
    sock.sendall(header + data)

    # For permission requests, read response
    if msg.get("eventType") == "PermissionRequest":
        sock.settimeout(30)
        try:
            resp_header = sock.recv(4)
            if len(resp_header) == 4:
                resp_len = struct.unpack(">I", resp_header)[0]
                resp_data = sock.recv(resp_len)
                sock.close()
                return json.loads(resp_data)
        except socket.timeout:
            print("  ⏰ Timeout waiting for response (expected if no UI interaction)")
        except Exception as e:
            print(f"  ⚠️  Error reading response: {e}")

    sock.close()
    return None

def test_session_lifecycle():
    """Test 1: Session start/end."""
    sid = str(uuid.uuid4())
    print(f"\n🔵 Test 1: Session lifecycle (sid={sid[:8]}...)")

    send_message({
        "id": str(uuid.uuid4()),
        "eventType": "SessionStart",
        "source": "claude",
        "sessionId": sid,
        "cwd": "/Users/lvpengbin/vibecode",
        "timestamp": time.time()
    })
    print("  ✅ SessionStart sent — check notch panel shows session")
    time.sleep(2)
    return sid

def test_bash_permission(sid: str):
    """Test 2: Bash tool permission (BashCommandView)."""
    req_id = str(uuid.uuid4())
    print(f"\n🟡 Test 2: Bash permission request")
    print("  📌 请在通知面板中点击 Allow/Deny/Always 来响应")

    resp = send_message({
        "id": req_id,
        "eventType": "PermissionRequest",
        "source": "claude",
        "sessionId": sid,
        "cwd": "/Users/lvpengbin/vibecode",
        "toolName": "Bash",
        "toolInput": {
            "command": "git status && echo 'hello world' | grep -i hello",
            "description": "Check git status and search output"
        },
        "timestamp": time.time()
    })
    if resp:
        print(f"  ✅ Got response: {resp}")
    return resp

def test_edit_permission(sid: str):
    """Test 3: Edit tool permission (EditDiffView)."""
    req_id = str(uuid.uuid4())
    print(f"\n🟢 Test 3: Edit permission request")
    print("  📌 请在通知面板中点击 Allow/Deny/Always 来响应")

    resp = send_message({
        "id": req_id,
        "eventType": "PermissionRequest",
        "source": "claude",
        "sessionId": sid,
        "cwd": "/Users/lvpengbin/vibecode",
        "toolName": "Edit",
        "toolInput": {
            "file_path": "/Users/lvpengbin/vibecode/VibeCode/VibeCode/App/AppDelegate.swift",
            "old_string": "func applicationDidFinishLaunching(_ notification: Notification) {\n    setupStatusItem()",
            "new_string": "func applicationDidFinishLaunching(_ notification: Notification) {\n    CrashReporter.shared.initialize()\n    setupStatusItem()"
        },
        "timestamp": time.time()
    })
    if resp:
        print(f"  ✅ Got response: {resp}")
    return resp

def test_write_permission(sid: str):
    """Test 4: Write tool permission (WritePreviewView)."""
    req_id = str(uuid.uuid4())
    print(f"\n🟠 Test 4: Write permission request")
    print("  📌 请在通知面板中点击 Allow/Deny/Always 来响应")

    resp = send_message({
        "id": req_id,
        "eventType": "PermissionRequest",
        "source": "claude",
        "sessionId": sid,
        "cwd": "/Users/lvpengbin/vibecode",
        "toolName": "Write",
        "toolInput": {
            "file_path": "/Users/lvpengbin/vibecode/VibeCode/VibeCode/Models/NewModel.swift",
            "content": "import Foundation\n\nstruct NewModel: Codable {\n    let id: String\n    let name: String\n    let value: Int\n    let isActive: Bool\n    \n    var displayName: String {\n        \"\\(name) (\\(id))\"\n    }\n    \n    func validate() -> Bool {\n        !name.isEmpty && value > 0\n    }\n}"
        },
        "timestamp": time.time()
    })
    if resp:
        print(f"  ✅ Got response: {resp}")
    return resp

def test_webfetch_permission(sid: str):
    """Test 5: WebFetch permission (WebFetchView)."""
    req_id = str(uuid.uuid4())
    print(f"\n🟣 Test 5: WebFetch permission request")
    print("  📌 请在通知面板中点击 Allow/Deny/Always 来响应")

    resp = send_message({
        "id": req_id,
        "eventType": "PermissionRequest",
        "source": "claude",
        "sessionId": sid,
        "cwd": "/Users/lvpengbin/vibecode",
        "toolName": "WebFetch",
        "toolInput": {
            "url": "https://docs.swift.org/swift-book/documentation/the-swift-programming-language",
            "prompt": "Extract the main sections and API reference links"
        },
        "timestamp": time.time()
    })
    if resp:
        print(f"  ✅ Got response: {resp}")
    return resp

def test_tool_running(sid: str):
    """Test 6: Tool running state (Read tool)."""
    print(f"\n🔷 Test 6: Read tool running state")

    send_message({
        "id": str(uuid.uuid4()),
        "eventType": "PreToolUse",
        "source": "claude",
        "sessionId": sid,
        "cwd": "/Users/lvpengbin/vibecode",
        "toolName": "Read",
        "toolInput": {
            "file_path": "/Users/lvpengbin/vibecode/VibeCode/VibeCode/App/AppDelegate.swift",
            "offset": 1,
            "limit": 50
        },
        "timestamp": time.time()
    })
    print("  ✅ PreToolUse(Read) sent — check collapsed view shows 'Read: AppDelegate.swift'")
    time.sleep(2)

    send_message({
        "id": str(uuid.uuid4()),
        "eventType": "PostToolUse",
        "source": "claude",
        "sessionId": sid,
        "cwd": "/Users/lvpengbin/vibecode",
        "toolName": "Read",
        "timestamp": time.time()
    })
    print("  ✅ PostToolUse(Read) sent")

def test_session_end(sid: str):
    """Test 7: End session."""
    print(f"\n⬛ Test 7: Session end")
    send_message({
        "id": str(uuid.uuid4()),
        "eventType": "SessionEnd",
        "source": "claude",
        "sessionId": sid,
        "cwd": "/Users/lvpengbin/vibecode",
        "timestamp": time.time()
    })
    print("  ✅ SessionEnd sent — session should show as 'Ended' then disappear")

def main():
    print("=" * 50)
    print("VibeCode Feature Verification")
    print("=" * 50)

    if len(sys.argv) > 1 and sys.argv[1] == "--quick":
        # Quick test: just session lifecycle + tool running, no permissions
        sid = test_session_lifecycle()
        time.sleep(1)
        test_tool_running(sid)
        time.sleep(2)
        test_session_end(sid)
        return

    # Full test with permission requests (requires UI interaction)
    sid = test_session_lifecycle()
    time.sleep(2)

    test_bash_permission(sid)
    time.sleep(1)

    test_edit_permission(sid)
    time.sleep(1)

    test_write_permission(sid)
    time.sleep(1)

    test_webfetch_permission(sid)
    time.sleep(1)

    test_tool_running(sid)
    time.sleep(2)

    test_session_end(sid)

    print("\n" + "=" * 50)
    print("✅ All tests completed!")
    print("=" * 50)

if __name__ == "__main__":
    main()
