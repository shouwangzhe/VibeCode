#!/usr/bin/env python3
"""Functional test for VibeCode — tests each feature one at a time.
Each permission request blocks until you click Allow/Deny/Always on the panel."""
import socket, json, struct, time, uuid, sys

SOCKET_PATH = "/tmp/vibecode.sock"
SID = str(uuid.uuid4())

def send(msg, wait_response=False):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(SOCKET_PATH)
    data = json.dumps(msg).encode()
    sock.sendall(struct.pack(">I", len(data)) + data)
    if wait_response:
        sock.settimeout(120)
        try:
            h = sock.recv(4)
            if len(h) == 4:
                r = sock.recv(struct.unpack(">I", h)[0])
                sock.close()
                return json.loads(r)
        except Exception as e:
            print(f"  ⚠️ {e}")
    sock.close()
    return None

def base_msg(**kwargs):
    m = {"id": str(uuid.uuid4()), "source": "claude", "sessionId": SID,
         "cwd": "/Users/lvpengbin/vibecode", "timestamp": time.time()}
    m.update(kwargs)
    return m

# 1. Session Start
print("=" * 50)
print("1️⃣  Session Start")
send(base_msg(eventType="SessionStart"))
print("   ✅ Session created — pill 应显示 session")
time.sleep(2)

# 2. Tool Running (Read)
print("\n2️⃣  Tool Running — Read")
send(base_msg(eventType="PreToolUse", toolName="Read",
     toolInput={"file_path": "/Users/lvpengbin/vibecode/VibeCode/README.md"}))
print("   ✅ pill 应显示 'Read: README.md'")
time.sleep(2)
send(base_msg(eventType="PostToolUse", toolName="Read"))
print("   ✅ Tool 完成")
time.sleep(1)

# 3. Bash Permission
print("\n3️⃣  Bash Permission — 请在面板上点击 Allow/Deny/Always")
resp = send(base_msg(eventType="PermissionRequest", toolName="Bash",
     toolInput={"command": "npm install && npm run build", "description": "Install deps and build"}), wait_response=True)
print(f"   ✅ 响应: {resp}")
time.sleep(1)

# 4. Edit Permission
print("\n4️⃣  Edit Permission — 请在面板上点击")
resp = send(base_msg(eventType="PermissionRequest", toolName="Edit",
     toolInput={"file_path": "/Users/lvpengbin/vibecode/VibeCode/README.md",
                "old_string": "# VibeCode\nA Dynamic Island for Claude Code",
                "new_string": "# VibeCode\nA Dynamic Island for AI Coding Tools\n\nSupports Claude Code, Copilot, and more."}), wait_response=True)
print(f"   ✅ 响应: {resp}")
time.sleep(1)

# 5. Write Permission
print("\n5️⃣  Write Permission — 请在面板上点击")
resp = send(base_msg(eventType="PermissionRequest", toolName="Write",
     toolInput={"file_path": "/Users/lvpengbin/vibecode/VibeCode/NewFile.swift",
                "content": "import Foundation\n\nstruct Config {\n    let apiKey: String\n    let baseURL: URL\n    var timeout: TimeInterval = 30\n\n    func validate() -> Bool {\n        !apiKey.isEmpty\n    }\n}"}), wait_response=True)
print(f"   ✅ 响应: {resp}")
time.sleep(1)

# 6. WebFetch Permission
print("\n6️⃣  WebFetch Permission — 请在面板上点击")
resp = send(base_msg(eventType="PermissionRequest", toolName="WebFetch",
     toolInput={"url": "https://developer.apple.com/documentation/swiftui",
                "prompt": "Get SwiftUI view lifecycle docs"}), wait_response=True)
print(f"   ✅ 响应: {resp}")
time.sleep(1)

# 7. WebSearch Permission
print("\n7️⃣  WebSearch Permission — 请在面板上点击")
resp = send(base_msg(eventType="PermissionRequest", toolName="WebSearch",
     toolInput={"query": "macOS NSPanel window level above menu bar"}), wait_response=True)
print(f"   ✅ 响应: {resp}")
time.sleep(1)

# 8. Subagent
print("\n8️⃣  Subagent Start/Stop")
send(base_msg(eventType="SubagentStart"))
print("   ✅ Subagent +1 — 展开面板应显示 subagent 计数")
time.sleep(2)
send(base_msg(eventType="SubagentStop"))
print("   ✅ Subagent -1")
time.sleep(1)

# 9. Compacting
print("\n9️⃣  Context Compacting")
send(base_msg(eventType="PreCompact"))
print("   ✅ 状态应变为 'Compacting'")
time.sleep(2)
send(base_msg(eventType="PostCompact"))
print("   ✅ 状态应恢复 'Ready'")
time.sleep(1)

# 10. Session End
print("\n🔟  Session End")
send(base_msg(eventType="SessionEnd"))
print("   ✅ Session 应显示 'Ended' 然后消失")

print("\n" + "=" * 50)
print("🎉 功能测试完成！")
