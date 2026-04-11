---
name: vibecode-file-map
description: Complete file map of all Swift source files in VibeCode with one-line descriptions
type: project
---

# VibeCode Source File Map

## VibeCode App Target (VibeCode/VibeCode/)

### App/
- `VibeCodeApp.swift` — @main SwiftUI entry point
- `AppDelegate.swift` — NSApplicationDelegate, wires up all services (IPC, sessions, panel, hotkeys, updates)

### Panel/
- `NotchPanel.swift` — NSPanel subclass: borderless, .statusBar level, non-activating
- `NotchPanelController.swift` — expand/collapse, animation, mouse tracking, permission/question handlers, terminal jump
- `NotchGeometry.swift` — computes collapsed/expanded frames using NSScreen geometry, notch detection

### Views/
- `NotchContentView.swift` — root view, switches collapsed/expanded, pill shape selection
- `CollapsedView.swift` — pill showing session count + colored status dot
- `ExpandedView.swift` — session list + detail (current tool, last prompt/response, permissions)
- `SessionRowView.swift` — single session row with status indicator
- `PermissionApprovalView.swift` — Allow/Deny/Always UI, dispatches to tool-specific views
- `AskUserQuestionView.swift` — renders AskUserQuestion hook with radio/checkbox options
- `SettingsView.swift` — tabbed preferences (general, sounds, display, hooks, privacy)
- `PixelMascotView.swift` — pixel art mascot SwiftUI view
- `PixelMascotData.swift` — pixel grid data for mascot
- `RemoteInteractionView.swift` — UI for remote session interaction

### Views/ToolViews/
- `BashCommandView.swift` — green monospace command with copy button
- `EditDiffView.swift` — red/green diff with file header
- `WritePreviewView.swift` — file content preview with line numbers
- `ReadFileView.swift` — compact file path + line range
- `WebFetchView.swift` — URL/query display

### Services/
- `IPCServer.swift` — Unix socket server, length-prefixed JSON, routes events to SessionManager
- `SessionManager.swift` — @Observable, session CRUD, event handling, permission callbacks, discovery (JSON + process scan), transcript parsing
- `SoundService.swift` — plays sounds per event type from active sound pack
- `SoundPackStore.swift` — manages 3 built-in + custom sound packs (~/.vibecode/sounds/)
- `HotkeyService.swift` — Ctrl+Shift+V/A/D global shortcuts
- `HookInstaller.swift` — writes hook config to ~/.claude/settings.json
- `TerminalService.swift` — AppleScript-based terminal jump (iTerm2/Terminal.app) + input injection
- `ScreenSelector.swift` — multi-display: auto/specific, notch detection
- `LaunchAtLoginService.swift` — SMAppService toggle
- `UpdateService.swift` — Sparkle auto-update
- `CrashReporter.swift` — Sentry stub (breadcrumbs + error capture interface)
- `DiagnosticExporter.swift` — exports diagnostic data
- `RemoteSourceManager.swift` — HTTP polling to remote vibecode-agent, manages remote sessions
- `UserDefaultsBacked.swift` — @propertyWrapper for UserDefaults

### Models/
- `ClaudeSession.swift` — id, cwd, status, tty, pid, pendingPermissions, currentTool, lastToolOutput, lastUserPrompt, lastAssistantResponse, subagentCount, isRemote, remoteSourceId
- `PermissionRequest.swift` — id, sessionId, toolName, toolInput, timestamp
- `SoundPack.swift` — id, name, description, author, sounds dict
- `RemoteSource.swift` — remote agent connection config

## VibeBridge Target (VibeBridge/)
- `main.swift` — stdin → parse → TTY walk → IPC message → socket send → (block for permission response)
- `EventParser.swift` — hook_event_name string → HookEventType enum
- `SocketClient.swift` — Unix socket client, connect/send/read with length-prefix

## Shared (Shared/)
- `IPCProtocol.swift` — HookEventType, HookInput, IPCMessage, IPCResponse
- `Constants.swift` — paths, dimensions, bundle IDs
- `AnyCodableValue.swift` — type-erased JSON value (string/int/double/bool/array/dict/null)

## Scripts (Scripts/)
- `install-hooks.sh` — register hooks in settings.json
- `generate_icon.py` — create app icon PNGs
- `setup-remote.sh` — set up remote bridge
- `vibecode-bridge-remote.py` — Python bridge for containers
- `vibecode-agent.py` — HTTP agent on remote hosts
- `test_*.py` — test scripts (features, functional, pill states, multi-session)
