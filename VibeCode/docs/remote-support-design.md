# VibeCode 远程容器支持 — 技术文档

## 1. 概述

VibeCode 远程支持功能允许用户在 Mac 上的 VibeCode.app 中监控和操作运行在远程服务器/Docker 容器中的 Claude Code 会话。支持：

- **会话状态实时监控** — SessionStart/End、工具执行、思考状态等
- **权限审批** — 远程 Claude Code 的 Bash/Edit/Write 等操作可在 Mac 上 allow/deny
- **AskUserQuestion 交互** — Claude Code 提出的选项问题可直接在 VibeCode UI 中选择回答
- **多远程源管理** — 同时监控多个远程环境

## 2. 架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────┐
│  远程容器 (Docker)                                    │
│                                                       │
│  Claude Code                                          │
│    ↓ hook 触发                                        │
│  vibecode-bridge-wrapper (bash)                       │
│    ↓ 设置环境变量                                     │
│  vibecode-bridge (Python)                             │
│    ↓ POST /event                                      │
│  vibecode-agent (Python HTTP server, :8876)           │
│    ↑ GET /events    ↑ POST /approve/{id}              │
└────┼────────────────┼─────────────────────────────────┘
     │  (端口暴露)      │
     ↓                ↓
┌─────────────────────────────────────────────────────┐
│  Mac (VibeCode.app)                                   │
│                                                       │
│  RemoteSourceManager                                  │
│    - 每 0.5s 轮询 GET /events                         │
│    - 事件 → SessionManager.handleEvent()              │
│    - PermissionRequest → 弹出审批面板                  │
│    - AskUserQuestion → 弹出选项 UI                    │
│    - 用户操作后 → POST /approve/{id} 回传结果          │
└─────────────────────────────────────────────────────┘
```

### 2.2 为什么选择「容器暴露 HTTP + Mac 轮询」

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| SSH 反向隧道 | 实时推送 | 隧道不稳定，多跳更难 | 弃用 |
| SSH -L 正向转发 | 简单 | 依赖 SSH 保持 | 备选 |
| **容器 HTTP + Mac 轮询** | **无需隧道，容错好** | 轮询有微小延迟 | **采用** |

核心原因：Mac 是动态 IP 无法被容器主动连接，但 Mac 可以访问容器暴露的端口。

## 3. 组件详解

### 3.1 容器端：vibecode-agent.py

纯 Python 标准库 HTTP 服务，零依赖。

**文件位置**：`scripts/vibecode-agent.py` → 安装到 `~/.vibecode/bin/vibecode-agent`

**API 端点**：

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /health | 健康检查，返回 uptime、队列状态 |
| POST | /event | bridge 发送 hook 事件 |
| GET | /events | VibeCode 轮询获取新事件（返回后清空队列） |
| POST | /approve/{id} | VibeCode 发送审批结果（含 updatedInput） |
| GET | /pending/{id} | bridge 轮询等待审批结果 |

**核心数据结构**：
```python
_event_queue = []           # 待 VibeCode 拉取的事件
_pending_approvals = {}     # id → event（等待审批）
_approval_results = {}      # id → {"decision": "allow", "updatedInput": {...}}
```

**运行方式**：
```bash
nohup python3 ~/.vibecode/bin/vibecode-agent --port 8876 > /tmp/vibecode-agent.log 2>&1 &
```

**注意事项**：
- 默认端口 8876（在 8000-8999 暴露端口范围内）
- 绑定 0.0.0.0（容器需要外部访问）
- 后台清理线程每 5 分钟清理超过 24 小时的 stale approvals
- 支持可选 `--token` 认证

### 3.2 容器端：vibecode-bridge-remote.py

Claude Code hook 处理脚本，每次 hook 触发时被调用。

**文件位置**：`scripts/vibecode-bridge-remote.py` → 安装到 `~/.vibecode/bin/vibecode-bridge`

**流程**：
```
1. 从 stdin 读取 Claude Code hook JSON
2. 解析 hook_event_name, session_id, tool_name, tool_input 等
3. 构造 IPCMessage 格式的事件 JSON
4. POST 到 http://127.0.0.1:8876/event（本地 agent）
5. 如果是 PermissionRequest：
   a. 循环 GET /pending/{id}，每 0.5s 轮询
   b. 收到 resolved 后，格式化为 Claude Code 期望的 stdout JSON
   c. 支持 updatedInput 透传（AskUserQuestion 的选项回答）
6. 其他事件：直接退出（exit 0）
```

**关键：PermissionRequest 响应格式**：
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedInput": {
        "answers": {"问题文本": "选中的选项标签"}
      }
    }
  }
}
```

**环境变量**：
- `VIBECODE_AGENT_URL` — agent 地址（默认 http://127.0.0.1:8876）
- `VIBECODE_TOKEN` — 认证 token（可选）

### 3.3 容器端：vibecode-bridge-wrapper

Bash 封装脚本，设置环境变量后调用 Python bridge。

**文件位置**：安装时自动生成到 `~/.vibecode/bin/vibecode-bridge-wrapper`

```bash
#!/bin/bash
export VIBECODE_AGENT_URL="http://127.0.0.1:8876"
exec python3 "$HOME/.vibecode/bin/vibecode-bridge" "$@"
```

Claude Code 的 hooks 配置指向这个 wrapper。

### 3.4 容器端：setup-remote.sh

一键安装脚本。

**文件位置**：`scripts/setup-remote.sh`

**执行步骤**：
1. 检查 Python 3 可用性
2. 创建 `~/.vibecode/bin/` 目录
3. 安装 vibecode-agent 和 vibecode-bridge
4. 生成 vibecode-bridge-wrapper（含端口配置）
5. 配置 `~/.claude/settings.json` 的 hooks（所有 13 种事件类型）
6. 启动 agent 后台进程
7. 验证 health check

**用法**：
```bash
bash setup-remote.sh              # 默认端口 8876
bash setup-remote.sh --port 8876  # 指定端口
bash setup-remote.sh --token xxx  # 带认证
```

### 3.5 Mac 端：RemoteSourceManager.swift

远程源管理器，负责轮询和审批。

**文件位置**：`VibeCode/Services/RemoteSourceManager.swift`

**核心功能**：
- 存储远程源列表（UserDefaults 持久化）
- 每个远程源独立 Timer 轮询（0.5s 间隔）
- 将远程事件转换为 IPCMessage 注入 SessionManager
- PermissionRequest 注册回调，用户审批后 POST /approve/{id}
- AskUserQuestion 通过 `respondToQuestion` 传递 `updatedInput`

**关键方法**：
```swift
// 轮询 → 处理事件
poll(sourceId:) → handlePollResponse → processRemoteEvent

// 审批回调
sessionManager.registerPermissionCallback(requestId:) { response in
    sendApproval(sourceId:, eventId:, decision:, updatedInput: response.updatedInput)
}
```

### 3.6 Mac 端：RemoteSource.swift

远程源数据模型。

```swift
struct RemoteSource: Codable, Identifiable {
    let id: UUID
    var name: String        // 显示名称
    var url: String         // HTTP URL (如 http://10.251.114.155:8876)
    var isEnabled: Bool     // 启用/禁用
    var token: String?      // 可选认证 token
    var sshCommand: String? // 可选 SSH 命令（暂未使用）
}
```

### 3.7 Mac 端：AskUserQuestionView.swift

AskUserQuestion 的 UI 组件。

**关键发现**：Claude Code 的 `AskUserQuestion` 是一种特殊的 `PermissionRequest`，其中 `tool_name == "AskUserQuestion"`，选项数据在 `tool_input.questions` 中。

**tool_input 格式**：
```json
{
  "questions": [
    {
      "question": "你的使用场景是什么?",
      "header": "使用场景",
      "options": [
        {"label": "Linux 服务器", "description": "Web服务等"},
        {"label": "开发机", "description": "编译构建等"}
      ],
      "multiSelect": false
    }
  ]
}
```

**UI 功能**：
- 渲染问题列表（支持 header 标签）
- 单选/多选支持（`multiSelect` 字段）
- FlowLayout 自动换行的选项按钮
- 全部回答后启用 Submit 按钮

**响应格式**：
用户点击 Submit 后，调用 `onSubmit(permissionId, answers)`，answers 格式为：
```swift
["answers": .dictionary(["问题文本": .string("选中的标签")])]
```

### 3.8 Mac 端：IPCResponse 扩展

为支持 AskUserQuestion，IPCResponse 新增了 `updatedInput` 字段：

```swift
public struct IPCResponse: Codable {
    public let id: String
    public let decision: String?
    public let reason: String?
    public let updatedInput: [String: AnyCodableValue]?  // 新增
}
```

### 3.9 Mac 端：VibeBridge 更新

本地 VibeBridge（Swift 二进制）也更新了，支持 `updatedInput` 透传：

```swift
// 从 IPCResponse 中提取 updatedInput
let updatedInput = responseJson["updatedInput"] as? [String: Any]

// 放入 Claude Code 期望的 decision 字典中
var decisionDict: [String: Any] = ["behavior": behavior]
if let updatedInput = updatedInput {
    decisionDict["updatedInput"] = updatedInput
}
```

## 4. 数据流详解

### 4.1 普通事件流（SessionStart/PreToolUse 等）

```
Claude Code hook 触发
  → bridge 读 stdin JSON
  → POST /event 到 agent
  → agent 存入 event_queue
  → VibeCode GET /events 拉取
  → RemoteSourceManager.processRemoteEvent()
  → SessionManager.handleEvent()
  → UI 更新（pill 状态变化）
```

### 4.2 权限审批流（PermissionRequest）

```
Claude Code 触发 PermissionRequest hook
  → bridge POST /event 到 agent（含 toolName, toolInput）
  → bridge 开始循环 GET /pending/{id}
  → agent 存入 event_queue + pending_approvals
  → VibeCode GET /events 拉取
  → RemoteSourceManager 注册 callback，展开面板
  → 用户在 UI 点击 Allow/Deny
  → SessionManager.respondToPermission() 调用 callback
  → RemoteSourceManager.sendApproval() POST /approve/{id}
  → agent 存入 approval_results
  → bridge GET /pending/{id} 收到 resolved
  → bridge 格式化输出到 stdout
  → Claude Code 收到 allow/deny 决策
```

### 4.3 AskUserQuestion 流

```
Claude Code 触发 AskUserQuestion（特殊 PermissionRequest）
  → bridge POST /event（toolName="AskUserQuestion", toolInput 含 questions）
  → bridge 开始循环 GET /pending/{id}
  → VibeCode 拉取事件
  → ExpandedView 检测 toolName=="AskUserQuestion"
  → 渲染 AskUserQuestionView（问题 + 选项按钮）
  → 用户选择选项，点击 Submit
  → SessionManager.respondToQuestion(answers)
  → IPCResponse(updatedInput: ["answers": {...}])
  → RemoteSourceManager.sendApproval(updatedInput: ...)
  → POST /approve/{id} body: {"decision":"allow","updatedInput":{"answers":{...}}}
  → bridge 收到 resolved，包含 updatedInput
  → bridge 输出: {"hookSpecificOutput":{"decision":{"behavior":"allow","updatedInput":{...}}}}
  → Claude Code 收到用户选择
```

## 5. 配置与部署

### 5.1 容器端部署

```bash
# 1. 将 scripts/ 目录复制到容器
scp -r scripts/ user@container:/path/to/scripts/

# 2. 在容器内执行安装
cd /path/to/scripts && bash setup-remote.sh --port 8876

# 3. 验证
curl http://127.0.0.1:8876/health
```

### 5.2 Mac 端配置

1. 打开 VibeCode → Settings → Remote Sources
2. 点击 "Add Remote Source"
3. 填写：
   - Name: 任意名称（如 "dev容器"）
   - URL: `http://<容器IP>:8876`
   - Token: 如果 agent 启动时指定了 --token，这里填写
4. 添加后自动开始轮询

### 5.3 端口选择

默认使用 8876 端口。选择此端口的原因：
- 用户的开发机只暴露了 8000-8999 端口范围
- 避免与常用服务冲突

### 5.4 网络要求

- Mac 能访问容器的 HTTP 端口（直连或通过 SSH 转发）
- 容器内 bridge 通过 localhost 连接 agent（docker exec 共享网络栈）

## 6. 文件清单

### 新增文件

| 文件 | 位置 | 说明 |
|------|------|------|
| vibecode-agent.py | scripts/ | 容器端 HTTP agent |
| vibecode-bridge-remote.py | scripts/ | 容器端 hook bridge |
| setup-remote.sh | scripts/ | 容器端一键安装脚本 |
| RemoteSourceManager.swift | VibeCode/Services/ | Mac 端远程源管理 |
| RemoteSource.swift | VibeCode/Models/ | 远程源数据模型 |
| AskUserQuestionView.swift | VibeCode/Views/ | AskUserQuestion UI |
| RemoteInteractionView.swift | VibeCode/Views/ | 远程交互提醒（已弃用） |
| remote-support-design.md | docs/ | 本文档 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| IPCProtocol.swift | IPCResponse 新增 updatedInput 字段 |
| AnyCodableValue.swift | 新增 from(Any) 静态方法 |
| SessionManager.swift | 新增 respondToQuestion() 方法 |
| AppDelegate.swift | 初始化 RemoteSourceManager |
| SettingsView.swift | 新增远程源管理 UI |
| ExpandedView.swift | 区分 AskUserQuestion 和普通 PermissionRequest |
| NotchContentView.swift | 新增 onQuestionSubmit 回调 |
| NotchPanelController.swift | 新增 handleQuestionSubmit 方法 |
| ClaudeSession.swift | 新增 isRemote, remoteSourceId 字段 |
| VibeBridge/main.swift | 支持 updatedInput 透传 |

## 7. 关键设计决策

### 7.1 AskUserQuestion 是特殊的 PermissionRequest

通过逆向分析 Claude Code 二进制发现，`AskUserQuestion` 工具在 hook 系统中表现为 `PermissionRequest` 事件，`tool_name` 为 `"AskUserQuestion"`。用户的选择通过 `decision.updatedInput.answers` 返回。

这意味着不需要新的 hook 事件类型，只需在现有的 PermissionRequest 流程中识别并特殊处理。

### 7.2 HTTP 轮询 vs WebSocket

选择 HTTP 轮询（0.5s 间隔）而非 WebSocket，原因：
- 零依赖（Python 标准库即可）
- 天然容错（连接断开自动恢复）
- 实现简单（约 200 行 Python）
- 延迟可接受（最大 0.5s）

### 7.3 事件队列的一次性消费

GET /events 返回队列内容后立即清空。这简化了实现但意味着：
- 只支持一个 VibeCode 客户端轮询同一个 agent
- 如果网络中断，中间的事件会丢失（可接受，因为下次事件会更新状态）

### 7.4 SessionStart 前置条件

PermissionRequest 需要对应 session 已存在才能显示 UI。在正常使用中，Claude Code 会在会话开始时触发 SessionStart hook，所以不会有问题。但手动测试时需要注意先发 SessionStart。

## 8. 测试方法

### 8.1 Agent 单元测试

```bash
# 启动 agent
python3 scripts/vibecode-agent.py --port 8876 &

# 健康检查
curl http://127.0.0.1:8876/health

# 发送事件
curl -X POST http://127.0.0.1:8876/event \
  -H "Content-Type: application/json" \
  -d '{"id":"test-1","eventType":"SessionStart","sessionId":"s1","cwd":"/tmp","timestamp":0}'

# 拉取事件
curl http://127.0.0.1:8876/events
```

### 8.2 Bridge 单元测试

```bash
echo '{"session_id":"s1","hook_event_name":"SessionStart","cwd":"/tmp"}' \
  | python3 scripts/vibecode-bridge-remote.py 2>&1
```

### 8.3 权限审批往返测试

```bash
# 1. bridge 后台发送 PermissionRequest
(echo '{"session_id":"s1","hook_event_name":"PermissionRequest","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/test"}}' \
  | python3 scripts/vibecode-bridge-remote.py > /tmp/stdout.json 2>/dev/null) &

# 2. 拉取事件获取 ID
EVENTS=$(curl -s http://127.0.0.1:8876/events)
EVENT_ID=$(echo "$EVENTS" | python3 -c "import sys,json; print(json.load(sys.stdin)['events'][0]['id'])")

# 3. 发送审批
curl -X POST "http://127.0.0.1:8876/approve/$EVENT_ID" \
  -H "Content-Type: application/json" \
  -d '{"decision":"allow"}'

# 4. 检查 bridge 输出
sleep 1 && cat /tmp/stdout.json | python3 -m json.tool
```

### 8.4 AskUserQuestion 往返测试

```bash
# 同上，但 body 包含 updatedInput
curl -X POST "http://127.0.0.1:8876/approve/$EVENT_ID" \
  -H "Content-Type: application/json" \
  -d '{"decision":"allow","updatedInput":{"answers":{"问题":"选项A"}}}'
```

### 8.5 端到端测试

1. 容器内 `bash setup-remote.sh --port 8876`
2. Mac 上 VibeCode Settings → 添加远程源 URL
3. 容器内启动 Claude Code
4. 验证：SessionStart → pill 显示新 session
5. 触发 PermissionRequest → pill 展开，点击 Allow
6. 触发 AskUserQuestion → 选项 UI 显示，选择并 Submit

## 9. 已知限制

1. **单客户端**：同一个 agent 只支持一个 VibeCode 轮询（事件消费后清空）
2. **文本输入**：Claude Code 等待用户文本输入（`Stop` 事件）时，无法通过 VibeCode 远程输入，需要直接在终端操作
3. **断线恢复**：网络中断期间的事件会丢失，但不影响后续事件
4. **无加密**：HTTP 明文传输，生产环境建议通过 SSH 隧道或 VPN

## 10. 后续优化方向

- [ ] Agent 支持事件持久化（重启不丢失）
- [ ] 支持多 VibeCode 客户端同时轮询
- [ ] 添加 WebSocket 通道减少延迟
- [ ] Token 认证默认开启
- [ ] VibeCode 中远程源编辑功能（目前只能删除重建）
- [ ] 升级 ducc 内核后注册 `StopFailure` hook 捕获 API 429/500 错误

## 11. 参考文档

- [Claude Code Hooks 官方文档](https://code.claude.com/docs/en/hooks) — 所有 hook 事件类型、matcher、输入输出格式的权威参考
