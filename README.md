# VibeCode

A macOS Dynamic Island for Claude Code — monitor your AI coding sessions in the notch area.

![VibeCode Demo](docs/demo.png)

## Features

- **Notch Integration** — Displays a pill-shaped panel in your MacBook's notch area
- **Session Tracking** — Real-time monitoring of all active Claude Code sessions
- **Status Indicators** — Color-coded dots show session state (Ready/Thinking/Running/Waiting)
- **Permission Approval** — Interactive UI for approving tool permissions
- **Terminal Jump** — Click a session to jump to its terminal window (iTerm2/Terminal.app)
- **Sound Notifications** — Audio feedback for session events
- **Global Hotkeys** — Keyboard shortcuts for quick access

## Architecture

```
Claude Code → hooks → vibecode-bridge (CLI) → Unix Socket → VibeCode.app (NotchPanel)
                                              /tmp/vibecode.sock
```

- **VibeCode.app** — SwiftUI + AppKit native macOS app (LSUIElement, no Dock icon)
- **vibecode-bridge** — Swift CLI tool that receives hook events via stdin and forwards to app
- **IPC** — Unix Domain Socket for bidirectional communication (supports permission request/response)

## Installation

### 1. Build the Project

```bash
cd VibeCode
xcodegen generate
xcodebuild -project VibeCode.xcodeproj -scheme VibeCode -configuration Debug build
xcodebuild -project VibeCode.xcodeproj -scheme VibeBridge -configuration Debug build
```

### 2. Install the Bridge

```bash
mkdir -p ~/.vibecode/bin
cp ~/Library/Developer/Xcode/DerivedData/VibeCode-*/Build/Products/Debug/vibecode-bridge ~/.vibecode/bin/
chmod +x ~/.vibecode/bin/vibecode-bridge
```

### 3. Launch the App

```bash
open ~/Library/Developer/Xcode/DerivedData/VibeCode-*/Build/Products/Debug/VibeCode.app
```

The app will appear in your menu bar and notch area.

### 4. Install Claude Code Hooks

Click the menu bar icon → "Install Hooks", or run from the app's menu.

This modifies `~/.claude/settings.json` to register hooks for all Claude Code events.

## Usage

### Basic Operation

1. **Launch VibeCode** — The app runs in the background (no Dock icon)
2. **Start Claude Code** — Run `claude` in any terminal
3. **Monitor Sessions** — The notch pill shows active session count and status
4. **Expand Panel** — Hover over the pill to see session details
5. **Jump to Terminal** — Click a session row to focus its terminal window

### Session States

- **Ready** (green) — Session idle, waiting for input
- **Thinking** (cyan) — Claude is processing
- **Running tool** (cyan) — Executing a tool (Bash, Read, etc.)
- **Needs approval** (yellow) — Permission request pending
- **Compacting** (orange) — Context window compaction in progress

### Global Hotkeys

- `Ctrl+Shift+V` — Toggle panel expand/collapse
- `Ctrl+Shift+A` — Approve current permission request
- `Ctrl+Shift+D` — Deny current permission request

## Project Structure

```
VibeCode/
├── VibeCode/                   # Main app target
│   ├── App/                    # App lifecycle
│   ├── Panel/                  # NotchPanel + geometry
│   ├── Views/                  # SwiftUI views
│   ├── Models/                 # Data models
│   ├── Services/               # IPC, session manager, sounds, hotkeys
│   └── Resources/              # Assets, sounds
├── VibeBridge/                 # CLI bridge target
│   ├── main.swift              # stdin → socket relay
│   ├── SocketClient.swift      # Unix socket client
│   └── EventParser.swift       # Hook JSON parser
├── Shared/                     # Shared code
│   ├── IPCProtocol.swift       # Message types
│   ├── Constants.swift         # App constants
│   └── AnyCodableValue.swift   # JSON helpers
└── Scripts/
    └── install-hooks.sh        # Hook installer script
```

## Development

### Requirements

- macOS 14.0+
- Xcode 16.4+
- Swift 5.10+

### Building

```bash
xcodegen generate
xcodebuild -project VibeCode.xcodeproj -scheme VibeCode build
```

### Debugging

IPC logs are written to `/tmp/vibecode-ipc.log`:

```bash
tail -f /tmp/vibecode-ipc.log
```

Bridge logs go to stderr when invoked by Claude Code hooks.

### Uninstalling Hooks

Remove the `hooks` section from `~/.claude/settings.json`, or use the app's "Uninstall Hooks" menu item (if implemented).

## Technical Details

### Hook Events

VibeCode listens to these Claude Code hook events:

- `SessionStart` / `SessionEnd` — Session lifecycle
- `UserPromptSubmit` — User sends a message
- `PreToolUse` / `PostToolUse` / `PostToolUseFailure` — Tool execution
- `Stop` — Claude finishes responding
- `PermissionRequest` — Tool needs approval
- `SubagentStart` / `SubagentStop` — Subagent lifecycle
- `PreCompact` / `PostCompact` — Context compaction

### IPC Protocol

Messages are length-prefixed JSON over Unix socket:

```
[4 bytes: big-endian length] + [JSON payload]
```

**Request** (bridge → app):
```json
{
  "id": "uuid",
  "eventType": "SessionStart",
  "source": "claude",
  "sessionId": "session-uuid",
  "cwd": "/path/to/project",
  "toolName": "Bash",
  "toolInput": {...},
  "timestamp": 1234567890.0
}
```

**Response** (app → bridge, for permission requests):
```json
{
  "id": "uuid",
  "decision": "allow",
  "reason": null
}
```

### Notch Detection

Uses `NSScreen.auxiliaryTopLeftArea` to detect the notch. Falls back to centered top-of-screen positioning on external displays.

## Verified Features

✅ **Session Tracking** — Real-time monitoring of all Claude Code sessions
✅ **Status Updates** — Color-coded status indicators (Ready/Thinking/Running/Waiting)
✅ **Expand/Collapse** — Hover to expand, auto-collapse on mouse exit
✅ **Permission Approval** — Interactive UI with Allow/Deny/Always buttons
✅ **IPC Communication** — Bidirectional Unix socket with proper response format
✅ **Hook Integration** — All Claude Code events captured and processed
✅ **Sound Notifications** — System sounds for session events
✅ **Global Hotkeys** — Keyboard shortcuts for panel control

## Troubleshooting

### App doesn't show in notch

- Check if running on a MacBook with notch (2021+ models)
- External displays fall back to top-center positioning
- Verify app is running: `ps aux | grep VibeCode`

### Sessions not appearing

- Check socket exists: `ls -la /tmp/vibecode.sock`
- Verify hooks installed: `cat ~/.claude/settings.json | grep vibecode`
- Check IPC log: `cat /tmp/vibecode-ipc.log`
- Ensure bridge is executable: `ls -la ~/.vibecode/bin/vibecode-bridge`

### Permission requests not working

- Ensure app is running and panel is visible
- Check that `PermissionRequest` hook is registered
- Verify bridge response format in IPC log
- Response must be: `{"hookSpecificOutput":{"decision":{"behavior":"allow"},"hookEventName":"PermissionRequest"}}`

### Debug Logging

All IPC communication is logged to `/tmp/vibecode-ipc.log`:

```bash
tail -f /tmp/vibecode-ipc.log
```

Look for:
- `[IPC] Event: PermissionRequest` — Request received
- `[NotchPanel] handlePermission called` — User clicked button
- `[IPC] Callback invoked` — Response being sent
- `[IPC] Response sent` — Response delivered to bridge

## License

MIT

## Credits

Built with Claude Code by Claude Opus 4.6
