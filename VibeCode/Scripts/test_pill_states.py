#!/usr/bin/env python3
"""
Pill 状态切换测试脚本
====================
逐步测试 collapsed pill 中像素小动物 + 文字的状态切换。
每步等待用户确认后再继续，确保视觉效果正确。

用法:
    python3 scripts/test_pill_states.py

前置条件:
    - VibeCode.app 已启动且 IPC server 正在监听 /tmp/vibecode.sock
    - 没有其他活跃的测试 session（否则会显示 [N] 计数）

测试覆盖的状态转换:
    1. SessionStart      → ready    (猫坐着摇尾巴 + ✓ 项目名)
    2. UserPromptSubmit   → thinking (兔子耳朵抖 + 用户prompt)
    3. PreToolUse         → running  (兔子跑 + 工具名 — 参数)
    4. PostToolUse        → thinking (兔子耳朵抖 + 用户prompt)
    5. PreCompact         → compact  (龟慢走 + Compacting context...)
    6. PostCompact        → ready    (猫坐着 + ✓ 项目名)
    7. Stop               → ready    (猫坐着 + ✓ 项目名)
    8. SessionEnd         → ended    (猫趴着灰色 + Ended → 5秒后消失)
    9. (无session)        → idle     (猫趴着呼吸 + VibeCode)
"""

import socket, json, struct, time, uuid, sys

SOCKET_PATH = "/tmp/vibecode.sock"
SESSION_ID = f"pill-test-{uuid.uuid4().hex[:8]}"
PROJECT_DIR = "/Users/lvpengbin/vibecode/VibeCode"


def send(msg):
    """Send IPC message to VibeCode app."""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect(SOCKET_PATH)
    except ConnectionRefusedError:
        print("  ERROR: Cannot connect to /tmp/vibecode.sock")
        print("  Please make sure VibeCode.app is running.")
        sys.exit(1)
    data = json.dumps(msg).encode()
    sock.sendall(struct.pack(">I", len(data)) + data)
    time.sleep(0.3)
    sock.close()


def make_msg(**kwargs):
    """Build IPC message with defaults."""
    m = {
        "id": str(uuid.uuid4()),
        "source": "claude",
        "sessionId": SESSION_ID,
        "cwd": PROJECT_DIR,
        "timestamp": time.time(),
    }
    m.update(kwargs)
    return m


def wait_confirm(step, expected_mascot, expected_text):
    """Wait for user to visually confirm the pill state."""
    print(f"\n{'='*55}")
    print(f"  Step {step}")
    print(f"  期望小动物: {expected_mascot}")
    print(f"  期望文字:   {expected_text}")
    print(f"{'='*55}")
    result = input("  是否正确? [Y/n/q] ").strip().lower()
    if result == "q":
        print("\n测试中止。正在清理 session...")
        send(make_msg(eventType="SessionEnd"))
        sys.exit(0)
    if result == "n":
        note = input("  说明问题: ").strip()
        return False, note
    return True, ""


def main():
    print("=" * 55)
    print("  VibeCode Pill 状态切换测试")
    print(f"  Session ID: {SESSION_ID}")
    print("=" * 55)
    print("\n请观察菜单栏 pill 的变化，每步确认后按 Enter 继续。")
    print("输入 n 表示不对，q 退出测试。\n")

    results = []

    # --- Step 1: SessionStart → ready ---
    send(make_msg(eventType="SessionStart"))
    ok, note = wait_confirm(
        "1/9: SessionStart → Ready",
        "猫坐着摇尾巴 (绿色)",
        "✓ VibeCode",
    )
    results.append(("SessionStart → Ready", ok, note))

    # --- Step 2: UserPromptSubmit → thinking ---
    send(make_msg(eventType="UserPromptSubmit", prompt="帮我写个排序算法"))
    ok, note = wait_confirm(
        "2/9: UserPromptSubmit → Thinking",
        "兔子耳朵抖 (蓝色)",
        "帮我写个排序算法",
    )
    results.append(("UserPromptSubmit → Thinking", ok, note))

    # --- Step 3: PreToolUse → running ---
    send(make_msg(
        eventType="PreToolUse",
        toolName="Read",
        toolInput={"file_path": "main.swift"},
    ))
    ok, note = wait_confirm(
        "3/9: PreToolUse → Running Tool",
        "兔子跑 (蓝色)",
        "Read — main.swift",
    )
    results.append(("PreToolUse → Running Tool", ok, note))

    # --- Step 4: PostToolUse → thinking ---
    send(make_msg(eventType="PostToolUse"))
    ok, note = wait_confirm(
        "4/9: PostToolUse → Thinking",
        "兔子耳朵抖 (蓝色)",
        "帮我写个排序算法",
    )
    results.append(("PostToolUse → Thinking", ok, note))

    # --- Step 5: PreCompact → compacting ---
    send(make_msg(eventType="PreCompact"))
    ok, note = wait_confirm(
        "5/9: PreCompact → Compacting",
        "龟慢走 (橙色)",
        "Compacting context...",
    )
    results.append(("PreCompact → Compacting", ok, note))

    # --- Step 6: PostCompact → ready ---
    send(make_msg(eventType="PostCompact"))
    ok, note = wait_confirm(
        "6/9: PostCompact → Ready",
        "猫坐着摇尾巴 (绿色)",
        "✓ VibeCode",
    )
    results.append(("PostCompact → Ready", ok, note))

    # --- Step 7: Extra cycle: prompt → tool → stop ---
    send(make_msg(eventType="UserPromptSubmit", prompt="修复登录bug"))
    time.sleep(0.5)
    send(make_msg(
        eventType="PreToolUse",
        toolName="Bash",
        toolInput={"command": "npm test"},
    ))
    time.sleep(0.5)
    send(make_msg(eventType="PostToolUse"))
    time.sleep(0.5)
    send(make_msg(eventType="Stop"))
    ok, note = wait_confirm(
        "7/9: Prompt→Tool→Stop → Ready",
        "猫坐着摇尾巴 (绿色)",
        "✓ VibeCode (不是'修复登录bug')",
    )
    results.append(("Stop → Ready (not showing old prompt)", ok, note))

    # --- Step 8: SessionEnd → ended ---
    send(make_msg(eventType="SessionEnd"))
    ok, note = wait_confirm(
        "8/9: SessionEnd → Ended",
        "猫趴着灰色",
        "Ended",
    )
    results.append(("SessionEnd → Ended", ok, note))

    # --- Step 9: Wait for cleanup → idle ---
    print("\n  等待 6 秒让 session 自动清理...")
    time.sleep(6)
    ok, note = wait_confirm(
        "9/9: Session清理后 → Idle",
        "猫趴着呼吸 (绿色)",
        "VibeCode",
    )
    results.append(("Session Cleanup → Idle", ok, note))

    # --- Summary ---
    print("\n" + "=" * 55)
    print("  测试结果汇总")
    print("=" * 55)
    passed = 0
    failed = 0
    for name, ok, note in results:
        status = "PASS" if ok else "FAIL"
        if ok:
            passed += 1
        else:
            failed += 1
        line = f"  [{status}] {name}"
        if note:
            line += f"  -- {note}"
        print(line)

    print(f"\n  总计: {passed} passed, {failed} failed, {len(results)} total")
    if failed == 0:
        print("  All tests passed!")
    else:
        print("  Some tests failed. Please investigate.")
    print("=" * 55)


if __name__ == "__main__":
    main()
