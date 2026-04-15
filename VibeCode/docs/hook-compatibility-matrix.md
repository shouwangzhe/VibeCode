# Claude Code Hook 兼容性矩阵与 VibeCode 适配方案

> 最后更新: 2026-04-15

## 一、Claude Code CLI 版本演进与 Hook 支持

Claude Code 的 hook 系统从 v1.0.38 开始引入，经历了多个阶段的扩展。截至 v2.1.109，共有 **26 个 hook 事件**。

### 1.1 版本分级（按 hook 能力划分为 5 个阶段）

| 阶段 | 版本范围 | 新增 Hook 事件 | 关键能力 |
|------|----------|---------------|---------|
| **Phase 0** | < v1.0.38 | 无 | 无 hook 支持 |
| **Phase 1** | v1.0.38 ~ v1.0.53 | PreToolUse, PostToolUse, Stop, Notification, SubagentStop, PreCompact | 基础工具拦截 + 停止通知 |
| **Phase 2** | v1.0.54 ~ v1.0.84 | UserPromptSubmit, SessionStart | 用户输入感知 + 会话生命周期开始 |
| **Phase 3** | v1.0.85 ~ v2.0.42 | SessionEnd, PostToolUseFailure, PermissionRequest | 完整会话生命周期 + 权限审批 |
| **Phase 4** | v2.0.43 ~ v2.1.32 | SubagentStart, tool_use_id, updatedInput, HTTP hooks | 子代理追踪 + 工具输入修改 |
| **Phase 5** | v2.1.33+ | TaskCreated, TaskCompleted, StopFailure, PostCompact, PermissionDenied, CwdChanged, FileChanged, WorktreeCreate/Remove, InstructionsLoaded, ConfigChange, Elicitation/ElicitationResult, TeammateIdle | 任务原生追踪 + API 错误感知 + 高级事件 |

### 1.2 详细版本 Changelog（Hook 相关）

| 版本 | 新增/变更 | 对 VibeCode 的影响 |
|------|----------|-------------------|
| v1.0.38 | 初始 hooks: PreToolUse, PostToolUse, Stop, Notification | 基础工具追踪可用 |
| v1.0.41 | Stop 拆分出 SubagentStop; 增加 `hook_event_name`; 支持 per-hook timeout | 子代理结束感知 |
| v1.0.48 | **PreCompact** hook | Compaction 状态追踪 |
| v1.0.54 | **UserPromptSubmit** hook; `cwd` 字段 | 用户输入追踪; 工作目录感知 |
| v1.0.62 | **SessionStart** hook | 会话创建感知 |
| v1.0.85 | **SessionEnd** hook | 会话结束感知 |
| v2.0.10 | PreToolUse 支持 `updatedInput` 返回 | 可修改工具输入（权限审批场景） |
| v2.0.43 | **SubagentStart** hook; `tool_use_id` 字段 | 子代理启动感知 |
| v2.1.33 | **TeammateIdle**, **TaskCompleted** hooks | 原生任务完成事件 |
| v2.1.49 | **ConfigChange** hook | 配置变更感知 |
| v2.1.50 | **WorktreeCreate**, **WorktreeRemove** hooks | Worktree 生命周期 |
| v2.1.63 | HTTP hooks (`type: "http"`) | 可用 HTTP 替代 command hook |
| v2.1.69 | **InstructionsLoaded** hook; `agent_id`/`agent_type` 全局字段 | 规则加载感知 |
| v2.1.76 | **Elicitation**, **ElicitationResult**, **PostCompact** hooks | MCP 交互 + 精确 compact 结束 |
| v2.1.78 | **StopFailure** hook (matchers: rate_limit, server_error, ...) | API 错误/重试感知 |
| v2.1.83 | **CwdChanged**, **FileChanged** hooks | 工作目录变更追踪 |
| v2.1.84 | **TaskCreated** hook | 原生任务创建事件 |
| v2.1.85 | Conditional `if` field for hooks | 条件触发 |
| v2.1.89 | **PermissionDenied** hook; `defer` permission decision | 自动模式拒绝感知 |
| v2.1.94 | UserPromptSubmit 返回 `sessionTitle` | 会话标题提取 |
| v2.1.105 | PreCompact 支持 exit code 2 阻断 | 可阻止 compaction |

### 1.3 完整 Hook 事件清单（26 个）

| # | Hook Event | 引入版本 | Matcher 支持 | 可阻断 |
|---|-----------|---------|-------------|--------|
| 1 | PreToolUse | v1.0.38 | 工具名 | Yes (exit 2) |
| 2 | PostToolUse | v1.0.38 | 工具名 | Yes (decision: block) |
| 3 | Stop | v1.0.38 | 无 | Yes (decision: block) |
| 4 | Notification | v1.0.38 | 通知类型 | No |
| 5 | SubagentStop | v1.0.41 | Agent type | Yes (decision: block) |
| 6 | PreCompact | v1.0.48 | manual/auto | Yes (exit 2, v2.1.105+) |
| 7 | UserPromptSubmit | v1.0.54 | 无 | Yes (exit 2) |
| 8 | SessionStart | v1.0.62 | startup/resume/clear/compact | No |
| 9 | SessionEnd | v1.0.85 | 结束原因 | No |
| 10 | PostToolUseFailure | v1.0.85+ | 工具名 | No |
| 11 | PermissionRequest | v1.0.85+ | 工具名 | Yes (allow/deny) |
| 12 | SubagentStart | v2.0.43 | Agent type | No |
| 13 | TeammateIdle | v2.1.33 | 无 | No |
| 14 | TaskCompleted | v2.1.33 | 无 | No |
| 15 | ConfigChange | v2.1.49 | 配置类型 | Yes (decision: block) |
| 16 | WorktreeCreate | v2.1.50 | 无 | Yes (any non-zero exit) |
| 17 | WorktreeRemove | v2.1.50 | 无 | No |
| 18 | InstructionsLoaded | v2.1.69 | 加载原因 | No |
| 19 | Elicitation | v2.1.76 | MCP server name | Yes (allow/deny) |
| 20 | ElicitationResult | v2.1.76 | MCP server name | No |
| 21 | PostCompact | v2.1.76 | manual/auto | No |
| 22 | StopFailure | v2.1.78 | rate_limit/server_error/... | No (output ignored) |
| 23 | CwdChanged | v2.1.83 | 无 | No |
| 24 | FileChanged | v2.1.83 | 文件名 | No |
| 25 | TaskCreated | v2.1.84 | 无 | No |
| 26 | PermissionDenied | v2.1.89 | 工具名 | Yes (retry: true) |

---

## 二、VibeCode 当前状态

### 2.1 已注册的 Hook 事件（13 个）

| Hook Event | 最低要求版本 | VibeCode 用途 | 状态 |
|-----------|------------|-------------|------|
| SessionStart | v1.0.62 | 创建/重用 session，清除 task 列表 | ✅ 生效 |
| SessionEnd | v1.0.85 | 设置 status → .ended | ✅ 生效 |
| PreToolUse | v1.0.38 | 工具追踪 + **TaskCreate/TaskUpdate 拦截** | ✅ 生效 |
| PostToolUse | v1.0.38 | 工具完成，status → .thinking | ✅ 生效 |
| PostToolUseFailure | v1.0.85+ | 工具失败，status 恢复 | ✅ 生效 |
| PermissionRequest | v1.0.85+ | 权限审批 UI，bridge 阻塞等响应 | ✅ 生效 |
| UserPromptSubmit | v1.0.54 | 记录 lastUserPrompt，status → .thinking | ✅ 生效 |
| Stop | v1.0.38 | status → .ready（subagentCount == 0 时） | ✅ 生效 |
| SubagentStart | v2.0.43 | subagentCount++ | ✅ 生效 |
| SubagentStop | v1.0.41 | subagentCount-- | ✅ 生效 |
| PreCompact | v1.0.48 | status → .compacting（乌龟动画） | ✅ 生效 |
| PostCompact | v2.1.76 | status → .thinking | ✅ 生效 |
| Notification | v1.0.38 | **No-op**（预留未来 macOS 通知） | ⏸ 未实现 |

### 2.2 功能 → Hook 依赖矩阵

```
功能                    所需 Hooks                              最低版本
───────────────────────────────────────────────────────────────────────
会话生命周期管理         SessionStart + SessionEnd                v1.0.85
工具执行追踪            PreToolUse + PostToolUse + PostToolUseFail  v1.0.85+
权限审批 UI             PermissionRequest                        v1.0.85+
状态推断               全部（综合各事件切换状态）                   v2.0.43
音效反馈               SessionStart/End + PostToolUse + Stop + Permission  v1.0.85+
用户 Prompt 展示        UserPromptSubmit                         v1.0.54
Task 进度追踪          PreToolUse (拦截 TaskCreate/TaskUpdate)    v1.0.38
子代理计数             SubagentStart + SubagentStop              v2.0.43
Compaction 状态        PreCompact + PostCompact                  v2.1.76
```

### 2.3 已知兼容性问题

| 运行环境 | 版本 | Hook 支持 | VibeCode 降级策略 |
|---------|------|----------|-----------------|
| 标准 `claude` CLI | v2.1.85+ | ✅ 全部 13 个事件 | 正常模式（IPC + bridge） |
| Ducc (baidu-cc) | v2.1.71 | ❌ 不触发任何 hook | TranscriptWatcher 文件监听回退 |
| Phase 1 CLI | v1.0.38~v1.0.53 | 仅 4 个基础事件 | 无会话生命周期；无用户输入追踪 |
| Phase 2 CLI | v1.0.54~v1.0.84 | 7 个事件 | 无 SessionEnd；无权限审批 |

---

## 三、适配方案：新增 Hook 事件支持

### 3.1 优先级矩阵

| 优先级 | Hook Event | 引入版本 | 预期功能 | 实现复杂度 | 价值 |
|-------|-----------|---------|---------|----------|-----|
| **P0** | StopFailure | v2.1.78 | API 错误/重试感知，面板展示等待原因 | 低 | **高** — 解决用户"为什么一直 thinking"的困惑 |
| **P0** | TaskCreated | v2.1.84 | 原生任务创建事件，替代 PreToolUse 拦截 | 低 | **高** — 数据更准确，不依赖 toolInput 解析 |
| **P0** | TaskCompleted | v2.1.33 | 原生任务完成事件 | 低 | **高** — 直接感知任务完成，无需 PreToolUse 拦截 |
| **P1** | PermissionDenied | v2.1.89 | Auto 模式下拒绝工具的通知 | 低 | 中 — 提升 auto 模式可见性 |
| **P1** | CwdChanged | v2.1.83 | 实时更新 session 工作目录 | 低 | 中 — 面板显示更准确的 project 路径 |
| **P2** | WorktreeCreate/Remove | v2.1.50 | Worktree 生命周期追踪 | 中 | 低 — 使用频率不高 |
| **P2** | Notification (实际实现) | v1.0.38 | macOS 原生通知转发 | 中 | 中 — 需要 UNUserNotification 集成 |
| **P3** | TeammateIdle | v2.1.33 | 多代理空闲感知 | 低 | 低 — 当前无多代理 UI |
| **P3** | ConfigChange | v2.1.49 | 配置变更感知 | 低 | 低 — 当前无需求 |
| **P3** | InstructionsLoaded | v2.1.69 | CLAUDE.md 加载追踪 | 低 | 低 — 诊断用途 |
| **P3** | FileChanged | v2.1.83 | 文件变更感知 | 低 | 低 — 当前无需求 |
| **P3** | Elicitation/Result | v2.1.76 | MCP 交互 UI | 高 | 低 — MCP 使用率低 |

### 3.2 P0 方案详细设计

#### 3.2.1 StopFailure — API 错误感知

**背景**：后端 Bedrock Runtime 返回 429 限流时，oneapi-comate 包装为 500。Claude Code 内部重试（最多 10 次，指数退避），用户可能等待 60s+ 且面板无任何提示。

**Hook 输入**（stdin JSON）：
```json
{
  "session_id": "...",
  "hook_event_name": "StopFailure",
  "error": "rate_limit",       // matcher 值
  "message": "Too many tokens, please wait before trying again.",
  "retry_attempt": 3,
  "max_retries": 10
}
```

**Matcher 支持**：`rate_limit`, `server_error`, `authentication_failed`, `overloaded`, `context_window_overflow`, `unknown`

**实现要点**：
1. `HookEventType` 新增 `.stopFailure` case
2. `IPCMessage` 解析 `error` + `retry_attempt` 字段
3. `ClaudeSession` 新增属性：`apiError: String?`, `retryAttempt: Int?`
4. `SessionManager.handleEventImmediate` 新增 `.stopFailure` case：
   - 设置 `session.apiError` 和 `session.retryAttempt`
   - status 保持 `.thinking`（Claude 在自动重试中）
5. UI 展示：CollapsedView pill 显示 `"Retrying (3/10)..."` 或 `"API Error: rate_limit"`
6. 重试成功后（下一个正常事件到达）自动清除 `apiError`
7. **注意**：StopFailure 的 output 和 exit code 被忽略，bridge 只需读取 stdin 并转发

**版本兼容**：
- 需要 **v2.1.78+**（标准 claude 已满足）
- ducc v2.1.71 不支持 → TranscriptWatcher 也无法感知（transcript 中无对应条目）
- 需要在 HookInstaller 中注册，但做好版本检测优雅降级

#### 3.2.2 TaskCreated + TaskCompleted — 原生任务事件

**背景**：当前 VibeCode 通过 PreToolUse 拦截 `toolName == "TaskCreate"` 的方式获取任务信息。这是一种 hack — 依赖工具名和 toolInput 结构。Claude Code v2.1.33+ 和 v2.1.84+ 分别原生支持了 TaskCompleted 和 TaskCreated 事件。

**TaskCreated Hook 输入**：
```json
{
  "session_id": "...",
  "hook_event_name": "TaskCreated",
  "task_id": "3",
  "task_subject": "Fix authentication bug",
  "task_description": "...",
  "teammate_name": "...",   // 多代理场景
  "team_name": "..."
}
```

**TaskCompleted Hook 输入**：
```json
{
  "session_id": "...",
  "hook_event_name": "TaskCompleted",
  "task_id": "3",
  "task_subject": "Fix authentication bug"
}
```

**实现要点**：
1. `HookEventType` 新增 `.taskCreated`, `.taskCompleted`
2. `IPCMessage` 解析 `taskId`, `taskSubject`, `taskDescription` 字段
3. `SessionManager.handleEventImmediate` 新增：
   - `.taskCreated`：直接创建 TaskItem，不再依赖 PreToolUse 拦截
   - `.taskCompleted`：直接标记任务完成
4. **向后兼容**：保留 PreToolUse 中的 TaskCreate/TaskUpdate 拦截逻辑，作为老版本 fallback
5. 去重：如果 taskCreated 和 PreToolUse 都触发了同一个 task，用 taskId 去重

**版本兼容**：
- TaskCompleted: **v2.1.33+**
- TaskCreated: **v2.1.84+**
- 老版本 fallback: PreToolUse 拦截继续工作

### 3.3 P1 方案概要

#### PermissionDenied
- 仅在 auto 模式（`--dangerously-skip-permissions` 或 `--allowedTools`）下触发
- 场景：面板显示 "Permission denied: Bash(rm -rf /)" 的通知
- 可选 `retry: true` 让 Claude 重试
- 实现简单：新增 event type + UI 气泡通知

#### CwdChanged
- 当 Claude 在 session 中 `cd` 到新目录时触发
- 更新 `session.cwd` → 面板 projectName 实时变化
- 实现简单：新增 event type + 更新 session.cwd

### 3.4 版本检测与分级降级策略

```
┌──────────────────────────────────────────────────────────────┐
│                    VibeCode 兼容性策略                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Claude Code v2.1.85+                                        │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Full hooks (13 current + new P0/P1)                     │ │
│  │ → IPC bridge pipeline                                   │ │
│  │ → 全部功能可用                                           │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Claude Code v1.0.85 ~ v2.1.84                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Partial hooks (Phase 3-4)                               │ │
│  │ → IPC bridge pipeline                                   │ │
│  │ → 基础功能可用：session 生命周期、工具追踪、权限审批     │ │
│  │ → 缺失：StopFailure、原生 Task 事件、CwdChanged 等      │ │
│  │ → Task 进度通过 PreToolUse 拦截 fallback                │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Claude Code < v1.0.85 / Ducc v2.1.71 (hooks 不触发)         │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ No hooks / hooks broken                                 │ │
│  │ → TranscriptWatcher JSONL 文件监听                       │ │
│  │ → 功能：状态推断、工具追踪、Task 进度、Compact 状态       │ │
│  │ → 缺失：权限审批（无法阻塞）、StopFailure               │ │
│  │ → 状态更新延迟 ~300ms（debounce）                        │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  无 Claude Code 进程                                         │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Process scanning (ps + CPU%) every 10s                  │ │
│  │ → 仅 session 发现 + Thinking/Ready 二态推断              │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 四、Hook 输入/输出协议参考

### 4.1 通用输入字段（所有事件）

```json
{
  "session_id": "uuid",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/project/dir",
  "permission_mode": "default|plan|auto",
  "hook_event_name": "PreToolUse",
  "agent_id": "...",        // v2.1.69+
  "agent_type": "..."       // v2.1.69+
}
```

### 4.2 各事件特有字段

| Event | 特有输入字段 |
|-------|------------|
| PreToolUse | `tool_name`, `tool_input`, `tool_use_id` |
| PostToolUse | `tool_name`, `tool_input`, `tool_use_id`, `tool_response` |
| PostToolUseFailure | `tool_name`, `tool_input`, `tool_use_id`, `tool_response` |
| UserPromptSubmit | `prompt` |
| Stop | `last_assistant_message`, `stop_hook_active` |
| StopFailure | `error`, `message` |
| SessionStart | `source` (startup/resume/clear/compact), `model` |
| SessionEnd | `source` (clear/resume/logout/...) |
| PermissionRequest | `tool_name`, `tool_input` |
| PermissionDenied | `tool_name`, `tool_input`, `permission_decision_reason` |
| SubagentStart | `agent_type` |
| SubagentStop | `agent_type`, `agent_transcript_path` |
| Notification | `message`, `title`, `notification_type` |
| TaskCreated | `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name` |
| TaskCompleted | `task_id`, `task_subject` |
| PreCompact/PostCompact | `trigger` (manual/auto) |
| CwdChanged | `new_cwd`, `old_cwd` |
| FileChanged | `file_path` |
| ConfigChange | `config_type` |
| WorktreeCreate/Remove | `worktree_path`, `branch` |
| InstructionsLoaded | `file_path`, `memory_type`, `load_reason` |
| Elicitation | `server_name`, `message` |
| ElicitationResult | `server_name`, `result` |

### 4.3 Hook 输出协议

| 场景 | Exit Code | 输出 JSON |
|------|----------|----------|
| 正常处理 | 0 | `{"continue": true}` |
| 阻断操作 | 2 | stderr 作为错误信息 |
| 允许权限 | 0 | `{"hookSpecificOutput": {"permissionDecision": "allow"}}` |
| 拒绝权限 | 0 | `{"hookSpecificOutput": {"permissionDecision": "deny"}}` |
| 修改输入 | 0 | `{"hookSpecificOutput": {"updatedInput": {...}}}` |
| 非阻断错误 | 1 | 日志记录，继续执行 |

---

## 五、TranscriptWatcher 事件映射对照

对于 hooks 不可用的场景（ducc v2.1.71），TranscriptWatcher 通过 JSONL 解析模拟等效事件：

| Transcript JSONL 条件 | 等效 Hook Event | 数据完整度 | 延迟 |
|----------------------|----------------|----------|------|
| `type=="user"` + string content | UserPromptSubmit | ✅ prompt text | ~300ms |
| `type=="assistant"` + `stop_reason!=null` + `tool_use` block | PreToolUse | ✅ toolName + toolInput | ~300ms |
| `type=="user"` + `tool_result` array | PostToolUse / PostToolUseFailure | ⚠️ 无 tool_response 内容 | ~300ms |
| `type=="assistant"` + `stop_reason=="end_turn"` + no tool_use | Stop | ✅ assistant text | ~300ms |
| `type=="system"` + `subtype=="compact_boundary"` | PreCompact + PostCompact | ⚠️ 合并为一次 | ~300ms |
| 无对应 | SessionStart / SessionEnd | ❌ 不可感知 | - |
| 无对应 | PermissionRequest | ❌ 不可感知（无法阻塞） | - |
| 无对应 | StopFailure | ❌ 不可感知 | - |
| 无对应 | SubagentStart / SubagentStop | ❌ 不可感知 | - |

**关键限制**：TranscriptWatcher 无法替代 PermissionRequest（需要阻塞 bridge 等待用户响应）和 StopFailure（transcript 中无对应条目）。

---

## 六、实施路线图

### Phase A（短期，1-2 天）— 已完成 ✅
- [x] 13 个基础 hook 注册 + bridge pipeline
- [x] TranscriptWatcher 回退方案（ducc v2.1.71）
- [x] 进程扫描兜底

### Phase B（中期，等 ducc 升级）— P0
- [ ] 注册 StopFailure hook → API 错误/重试状态展示
- [ ] 注册 TaskCreated + TaskCompleted hooks → 替代 PreToolUse 拦截
- [ ] HookInstaller 注册新事件（从 13 → 16）
- [ ] IPCProtocol 新增 3 个 HookEventType
- [ ] SessionManager 新增 3 个 case handler
- [ ] CollapsedView 增加 retry 状态展示 UI

### Phase C（长期）— P1/P2
- [ ] PermissionDenied 通知（auto 模式可见性）
- [ ] CwdChanged → 实时 projectName 更新
- [ ] Notification → macOS UNUserNotification 转发
- [ ] WorktreeCreate/Remove 生命周期追踪

### Phase D（远期）— P3
- [ ] TeammateIdle 多代理感知
- [ ] InstructionsLoaded 诊断信息
- [ ] Elicitation MCP 交互 UI
- [ ] HTTP hooks 替代 command hooks（减少进程开销）

---

## 七、附录：Ducc 版本跟踪

| Ducc 版本 | 基于 Claude Code | Hooks 状态 | VibeCode 策略 |
|----------|-----------------|-----------|--------------|
| v2.1.71-rc.0 | ~v1.0.x 内核 | ❌ 不触发 | TranscriptWatcher + 进程扫描 |
| (待升级) | v2.1.85+ | ✅ 预期可用 | Hook bridge 全功能 |
| (待升级) | v2.1.109+ | ✅ 全部 26 事件 | Hook bridge + Phase B/C 新功能 |

> **Action Item**: 持续跟踪 ducc 升级到新版 Claude Code 内核的计划，一旦确认支持 hooks，立即验证并启用 Phase B 功能。
