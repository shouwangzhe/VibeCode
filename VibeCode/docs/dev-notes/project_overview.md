---
name: vibecode-project-overview
description: Comprehensive overview of VibeCode — macOS Dynamic Island app for Claude Code session monitoring
type: project
---

# VibeCode Project Overview

## What It Is
VibeCode is a macOS native app that displays a "Dynamic Island" in the MacBook notch area to monitor Claude Code sessions in real-time. It shows session status, handles permission approvals, and provides terminal integration.

## Architecture
```
Claude Code → hooks → vibecode-bridge (CLI, stdin) → Unix Socket (/tmp/vibecode.sock) → VibeCode.app (NotchPanel)
```

**Why:** Claude Code has a hook system that invokes external scripts on events. VibeBridge is a Swift CLI that acts as the middleman, parsing hook JSON from stdin and relaying it to the app via IPC.

## Tech Stack
- **Language:** Swift 5.10+
- **UI:** SwiftUI + AppKit (hybrid for panel control)
- **Platform:** macOS 14.0+, Universal Binary (Intel + ARM)
- **Build:** XcodeGen (project.yml → .xcodeproj) + SPM (Package.swift for VibeBridge)
- **Dependencies:** Sparkle 2.6.0 (auto-updates)

## Project Location
`/Users/lvpengbin/vibecode/VibeCode/` — not a git repo at the top level

## Targets
1. **VibeCode.app** (XcodeGen target, SwiftUI app) — the macOS menu bar app
2. **VibeBridge** (SPM executable target) — CLI bridge invoked by Claude Code hooks

## Key Modules

### App Layer (`VibeCode/App/`)
- `VibeCodeApp.swift` — @main entry, SwiftUI App
- `AppDelegate.swift` — NSApplicationDelegate, initializes services (IPCServer, SessionManager, NotchPanelController, HotkeyService, UpdateService, etc.)

### Panel Layer (`VibeCode/Panel/`)
- `NotchPanel.swift` — NSPanel subclass (borderless, non-activating, always on top)
- `NotchPanelController.swift` — manages panel lifecycle, expand/collapse, mouse tracking, permission handling, session jump, reply
- `NotchGeometry.swift` — computes panel frames for notch/non-notch Macs using OS screen geometry

### Views (`VibeCode/Views/`)
- `NotchContentView.swift` — root SwiftUI view, switches between collapsed/expanded, uses MenuBarPillShape (non-notch) or TrapezoidShape (notch)
- `CollapsedView.swift` — pill showing session count + status dot
- `ExpandedView.swift` — full panel with session list + details
- `SessionRowView.swift` — individual session row
- `PermissionApprovalView.swift` — Allow/Deny/Always buttons for tool permissions
- `AskUserQuestionView.swift` — UI for AskUserQuestion hook events
- `SettingsView.swift` — preferences UI (launch at login, sounds, display, hooks, privacy)
- `PixelMascotView.swift` + `PixelMascotData.swift` — pixel art mascot decoration
- `RemoteInteractionView.swift` — remote session interaction
- `ToolViews/` — 5 tool-specific views (BashCommand, EditDiff, WritePreview, ReadFile, WebFetch)

### Services (`VibeCode/Services/`)
- `IPCServer.swift` — Unix socket server, accepts connections, reads length-prefixed JSON messages, routes to SessionManager
- `SessionManager.swift` — @Observable, manages all sessions, handles events, permission callbacks, transcript parsing, session discovery (JSON files + process scanning)
- `SoundService.swift` — audio feedback per event type
- `SoundPackStore.swift` — manages built-in + custom sound packs
- `HotkeyService.swift` — global keyboard shortcuts (Ctrl+Shift+V/A/D)
- `HookInstaller.swift` — modifies ~/.claude/settings.json to register hooks
- `TerminalService.swift` — jumps to terminal windows (iTerm2/Terminal.app) via AppleScript, sends input via TTY
- `ScreenSelector.swift` — multi-display support, auto-detects notch screen
- `LaunchAtLoginService.swift` — SMAppService for launch at login
- `UpdateService.swift` — Sparkle auto-update integration
- `CrashReporter.swift` — Sentry stub (interface only, not activated)
- `DiagnosticExporter.swift` — exports diagnostic info
- `RemoteSourceManager.swift` — manages remote session sources (HTTP polling to vibecode-agent)
- `UserDefaultsBacked.swift` — property wrapper for UserDefaults persistence

### Models (`VibeCode/Models/`)
- `ClaudeSession.swift` — session state: id, cwd, status, tty, pid, pendingPermissions, currentTool, lastToolOutput, lastUserPrompt, lastAssistantResponse, subagentCount, remoteSourceId
- `PermissionRequest.swift` — permission request model
- `SoundPack.swift` — sound pack definition
- `RemoteSource.swift` — remote session source config

### Shared (`Shared/`)
- `IPCProtocol.swift` — HookEventType enum, HookInput, IPCMessage, IPCResponse structs
- `Constants.swift` — socket path (/tmp/vibecode.sock), panel dimensions, bundle IDs
- `AnyCodableValue.swift` — type-erased JSON value wrapper

### VibeBridge (`VibeBridge/`)
- `main.swift` — reads stdin JSON, walks process tree for TTY, builds IPCMessage, sends via socket, blocks for permission responses
- `EventParser.swift` — parses hook_event_name to HookEventType enum
- `SocketClient.swift` — Unix socket client with length-prefixed protocol

### Scripts (`Scripts/`)
- `install-hooks.sh` — registers VibeBridge hooks in ~/.claude/settings.json
- `generate_icon.py` — generates app icon PNGs
- `test_*.py` — various test scripts
- `setup-remote.sh` — remote session setup
- `vibecode-bridge-remote.py` — remote bridge (Python, for container environments)
- `vibecode-agent.py` — HTTP agent running on remote containers

## IPC Protocol
Length-prefixed JSON over Unix socket:
```
[4 bytes big-endian length] + [JSON payload]
```

## Hook Events
SessionStart, SessionEnd, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, Stop, PermissionRequest, SubagentStart, SubagentStop, PreCompact, PostCompact, Notification

## Session States
ready (green), thinking (cyan), runningTool (cyan), waitingForApproval (yellow), compacting (orange), ended

## Global Hotkeys
- Ctrl+Shift+V — toggle panel
- Ctrl+Shift+A — approve permission
- Ctrl+Shift+D — deny permission

## App Behavior
- LSUIElement=true (no Dock icon, menu bar only)
- Panel uses nonactivatingPanel (doesn't steal focus)
- Collapse: timer-based mouse position polling (0.3s interval, ~0.9s to collapse)
- Collapse blocked when any session has pendingPermissions (both mouseExited and outsideCheck paths)
- Stale permission clearing: only clears permissions whose callback is gone (bridge no longer waiting); keeps genuinely pending ones
- Log file: /tmp/vibecode-ipc.log (5MB rotation)

## How to apply
When working on this project, understand that changes often span multiple layers (e.g., a new hook event needs changes in IPCProtocol → EventParser → SessionManager → Views). The bridge is built separately via SPM and must be manually copied to ~/.vibecode/bin/.
