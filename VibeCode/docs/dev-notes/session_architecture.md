# Session Architecture

## Session 发现机制

1. **IPC 事件驱动**（主要）：Claude Code hooks → VibeBridge → Unix socket → SessionManager
2. **ensureSession**：收到任何未知 sessionId 的事件时自动创建 session（解决 VibeCode 重启后恢复）
3. **文件扫描**（辅助）：每 10s 扫描 `~/.claude/sessions/*.json`（ducc 不写这些文件，所以主要靠 IPC）

## TTY 获取

- **本地**：VibeBridge 通过进程树 walk（bridge → shell(PPID) → claude(PPID's PPID)）获取 TTY
- **远程**：vibecode-bridge-remote.py 同样通过 `ps -o ppid=,tty=` 获取
- TTY 随 IPCMessage 的 `tty` 字段传递，存储在 `ClaudeSession.tty` 上

## Reply 输入注入

- **本地**：AppleScript `write text` (iTerm2) / `do script` (Terminal.app) 通过 TTY 匹配找到窗口
- **远程**：POST /input/{sessionId} → agent 查 `_session_ttys` → 写入 `/dev/<tty>`

## Remote 架构

```
Mac (VibeCode) ←HTTP polling→ 容器 (vibecode-agent.py :8876)
                                 ↑ POST /event
                              vibecode-bridge-remote.py ← Claude Code hooks
```
- 审批：POST /approve/{id} + bridge 轮询 GET /pending/{id}
- 输入：POST /input/{sessionId} → agent 写 TTY
