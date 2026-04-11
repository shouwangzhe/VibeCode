---
name: panel-collapse-permission-logic
description: Panel auto-collapse suppression and stale permission clearing — two interrelated mechanisms that must stay in sync
type: feedback
---

## Panel 收缩与权限清除的联动逻辑

### 规则：有 pending permissions 时不自动收缩
`NotchPanelController` 的两条自动收缩路径都必须检查 `hasPending`：
1. `startOutsideCheck` 定时器回调
2. `mouseExited` 事件处理

检查方式：
```swift
let hasPending = sessionManager.sessions.values.contains { !$0.pendingPermissions.isEmpty }
```

### 规则：Stale permission 清除必须检查 callback 是否存在
`SessionManager.handleEventImmediate` 中清除 pending permissions 时，只清除 `permissionCallbacks[id] == nil` 的。callback 存在说明 bridge 还在阻塞等响应。

**Why:** 第一轮修复"从 shell 回答后面板提示不消失"时用了无条件清除，导致了"权限审批内容消失"的新 bug。两个机制必须配合：收缩抑制保证用户能看到审批 UI，callback 检查保证不误删正在等待的权限。

**How to apply:** 修改面板收缩逻辑或权限清除逻辑时，必须同时考虑另一侧的影响。测试时用 Python 脚本发送 PermissionRequest 模拟（见 Scripts/ 或本 session 的测试脚本模式）。
