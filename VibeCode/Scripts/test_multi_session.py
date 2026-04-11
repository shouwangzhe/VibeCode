#!/usr/bin/env python3
"""
多 Session 优先级切换测试脚本
===============================
测试多个 session 同时存在时，pill 是否正确显示最高优先级状态的 session，
同状态时是否显示最近活动的 session。

用法:
    python3 scripts/test_multi_session.py

前置条件:
    - VibeCode.app 已启动且 IPC server 正在监听 /tmp/vibecode.sock

测试覆盖的场景:
    1. 创建 3 个 session，都是 ready → 显示最后创建的
    2. Session A 进入 thinking → pill 切到 A（thinking > ready）
    3. Session B 进入 running tool → pill 切到 B（running > thinking）
    4. Session B 回到 thinking → A、B 都是 thinking，显示最近活动的 B
    5. Session B stop → pill 切回 A（唯一 thinking）
    6. Session A stop → 全部 ready，显示最近活动的 A
    7. 清理所有测试 session
"""

import socket, json, struct, time, uuid, sys

SOCKET_PATH = "/tmp/vibecode.sock"


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


def make_msg(session_id, cwd, **kwargs):
    """Build IPC message with defaults."""
    m = {
        "id": str(uuid.uuid4()),
        "source": "claude",
        "sessionId": session_id,
        "cwd": cwd,
        "timestamp": time.time(),
    }
    m.update(kwargs)
    return m


def wait_confirm(step, expected_mascot, expected_text):
    """Wait for user to visually confirm the pill state."""
    print(f"\n{'='*60}")
    print(f"  Step {step}")
    print(f"  期望小动物: {expected_mascot}")
    print(f"  期望文字:   {expected_text}")
    print(f"{'='*60}")
    result = input("  是否正确? [Y/n/q] ").strip().lower()
    if result == "q":
        return None, "quit"
    if result == "n":
        note = input("  说明问题: ").strip()
        return False, note
    return True, ""


def main():
    tag = uuid.uuid4().hex[:6]
    S_A = f"multi-{tag}-A"
    S_B = f"multi-{tag}-B"
    S_C = f"multi-{tag}-C"
    CWD_A = "/Users/test/project-alpha"
    CWD_B = "/Users/test/project-beta"
    CWD_C = "/Users/test/project-gamma"

    print("=" * 60)
    print("  VibeCode 多 Session 优先级切换测试")
    print(f"  Session A: {S_A}")
    print(f"  Session B: {S_B}")
    print(f"  Session C: {S_C}")
    print("=" * 60)
    print("\n请观察菜单栏 pill 的变化，每步确认后按 Enter 继续。")
    print("输入 n 表示不对，q 退出测试。\n")

    results = []

    def cleanup():
        """End all test sessions."""
        print("\n  正在清理测试 session...")
        for sid, cwd in [(S_A, CWD_A), (S_B, CWD_B), (S_C, CWD_C)]:
            try:
                send(make_msg(sid, cwd, eventType="SessionEnd"))
            except Exception:
                pass
        print("  清理完成。")

    def check(step, mascot, text):
        ok, note = wait_confirm(step, mascot, text)
        if ok is None:
            cleanup()
            sys.exit(0)
        results.append((step, ok, note))

    # --- Step 1: Create 3 sessions, all ready ---
    send(make_msg(S_A, CWD_A, eventType="SessionStart"))
    time.sleep(0.3)
    send(make_msg(S_B, CWD_B, eventType="SessionStart"))
    time.sleep(0.3)
    send(make_msg(S_C, CWD_C, eventType="SessionStart"))
    check(
        "1/7: 创建 3 个 session (A,B,C 都是 ready)",
        "猫坐着摇尾巴",
        "✓ project-gamma [N] (最后创建的 C)",
    )

    # --- Step 2: Session A → thinking ---
    send(make_msg(S_A, CWD_A, eventType="UserPromptSubmit", prompt="修复alpha的bug"))
    check(
        "2/7: Session A → thinking (B,C 仍是 ready)",
        "兔子耳朵抖",
        "修复alpha的bug [N]",
    )

    # --- Step 3: Session B → running tool (priority > thinking) ---
    send(make_msg(S_B, CWD_B, eventType="UserPromptSubmit", prompt="部署beta服务"))
    time.sleep(0.3)
    send(make_msg(S_B, CWD_B, eventType="PreToolUse", toolName="Bash",
                  toolInput={"command": "npm run deploy"}))
    check(
        "3/7: Session B → running tool (优先级高于 A 的 thinking)",
        "兔子跑",
        "Bash — npm run deploy [N]",
    )

    # --- Step 4: Session B → thinking (A,B both thinking, B more recent) ---
    send(make_msg(S_B, CWD_B, eventType="PostToolUse"))
    check(
        "4/7: Session B → thinking (A,B 都 thinking，B 更近)",
        "兔子耳朵抖",
        "部署beta服务 [N] (不是'修复alpha的bug')",
    )

    # --- Step 5: Session B → ready, only A thinking ---
    send(make_msg(S_B, CWD_B, eventType="Stop"))
    check(
        "5/7: Session B → ready (只剩 A 在 thinking)",
        "兔子耳朵抖",
        "修复alpha的bug [N]",
    )

    # --- Step 6: Session A → ready, all ready ---
    send(make_msg(S_A, CWD_A, eventType="Stop"))
    check(
        "6/7: Session A → ready (全部 ready，A 最近活动)",
        "猫坐着摇尾巴",
        "✓ project-alpha [N]",
    )

    # --- Step 7: Cleanup ---
    cleanup()
    time.sleep(6)
    check(
        "7/7: 所有测试 session 结束",
        "取决于是否还有其他真实 session",
        "无测试 session 残留",
    )

    # --- Summary ---
    print("\n" + "=" * 60)
    print("  测试结果汇总")
    print("=" * 60)
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
    print("=" * 60)


if __name__ == "__main__":
    main()
