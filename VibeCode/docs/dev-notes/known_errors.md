# Known Errors & Patterns

## Bug: AskUserQuestion 从 Shell 回答后面板提示不消失

**现象**：Claude 通过 AskUserQuestion 提问时，VibeCode 面板弹出选项 UI。如果用户直接在终端 shell 中回答（而不是通过 VibeCode 面板），面板上的提示永远不会消失。

**原因**：`pendingPermissions` 只在 VibeCode 的 `respondToPermission`/`respondToQuestion` 回调中被清除。当用户从 shell 回答时，Claude Code 直接处理了回答并继续执行，后续的 hook 事件（PostToolUse/Stop 等）不会清除 VibeCode 中残留的 pending permission。

**修复**：SessionManager 在收到非 PermissionRequest 的后续事件时，自动清除该 session 中 callback 已不存在的 stale pendingPermissions。只清除 `permissionCallbacks[id]` 为 nil 的（说明已在终端回答），保留 callback 仍存在的（bridge 还在等响应，权限确实在等用户操作）。

**状态**：已修复（两轮迭代）

**第一轮**：无条件清除所有 pending permissions → 导致下面的"权限审批内容消失"bug
**第二轮**：只清除 callback 已不存在的 permissions（当前方案）

## Bug: 权限审批内容消失（面板收起再展开后）

**现象**：权限请求弹出后，面板收起再展开，审批内容（Allow/Deny 按钮）消失了。或者面板还没收起，审批内容就突然没了。

**根因**：`SessionManager.handleEventImmediate` 中的 stale permission 清除逻辑太激进 — 收到任何非 PermissionRequest 事件就无条件清除该 session 的所有 `pendingPermissions`。但 PreToolUse 等事件可能在 PermissionRequest 之前的 in-flight 事件到达后触发清除。

**修复**（`SessionManager.swift`）：清除前检查 `permissionCallbacks[permission.id]` 是否存在。callback 存在说明 bridge 还在阻塞等待响应，权限确实 pending，不应清除。只清除 callback 已不存在的真正 stale permissions。

**状态**：已修复

## Bug: 面板在有待确认项时自动收缩

**现象**：权限请求或 AskUserQuestion 弹出后，鼠标移出面板区域，面板自动收缩，用户还没来得及操作。

**根因**：面板有两条自动收缩路径，都没有检查是否有 pending permissions：
1. `startOutsideCheck` 定时器（0.3s 轮询鼠标位置，3 ticks 后收缩）
2. `mouseExited` 事件 → 0.5s 后调用 `collapse()`

**修复**（`NotchPanelController.swift`）：两条路径都加了 `hasPending` 检查：
```swift
let hasPending = sessionManager.sessions.values.contains { !$0.pendingPermissions.isEmpty }
```
有 pending permissions 时不触发自动收缩。

**状态**：已修复

## Bug: 面板点击外部不收起

**现象**：展开面板后，点击面板外任何区域，面板不收起。

**根因**：`toggle()`（由 `onTapGesture` 触发）直接修改 `isExpanded` 并调用 `animateTransition()`，完全绕过了 `expand()`/`collapse()` 方法，导致 outsideCheck timer 从未启动。

**修复**：`toggle()` 改为调用 `expand()`/`collapse()` 而不是直接操作状态。收起机制用定时器检测鼠标位置（0.3s 轮询，鼠标离开面板 ~0.9s 后自动收起）。

**经验**：`nonactivatingPanel` 场景下，`addGlobalMonitorForEvents` 需要辅助功能权限，`didResignKeyNotification` 和 `didActivateApplicationNotification` 对非激活面板无效。定时轮询鼠标位置是最可靠的方案。

**状态**：已修复

## API Throttling (429)

**现象**：
```
500 {"error":{"message":"InvokeModelWithResponseStream: ... ThrottlingException: Too many tokens, please wait before trying again."}}
Retrying in 9 seconds… (attempt 6/10)
```

**来源**：后端 Bedrock Runtime 的 429 限流，被 oneapi-comate 包装为 500 返回。
Claude Code 内部有重试机制（最多 10 次，指数退避）。

**影响**：用户等待时间长（可能 60s+），VibeCode 面板上看不到任何提示，session 状态显示为 thinking/ready 但实际在重试中。

**待改进**：VibeCode 应能感知并展示这类 API 错误/重试状态，让用户知道为什么等待时间长。

**Hook 支持情况**：
- Claude Code 新版有 `StopFailure` hook（支持 `rate_limit` / `server_error` 等 matcher），可以感知 API 错误
- 但 ducc 当前基于 **v2.1.71**，不支持 `StopFailure`（曾注册过，因不兼容已删除）
- **等 ducc 升级后**再注册 `StopFailure` hook 来捕获 429/500 错误

## Build 踩坑

- VibeBridge 通过 SPM 构建（`swift build --product VibeBridge`），不是 `xcodebuild -scheme VibeCode`
- 构建后必须手动部署：`cp .build/debug/VibeBridge ~/.vibecode/bin/vibecode-bridge`
- ducc 使用 `--settings` 参数指向独立的 settings.json，但 hooks 会与 `~/.claude/settings.json` 合并
