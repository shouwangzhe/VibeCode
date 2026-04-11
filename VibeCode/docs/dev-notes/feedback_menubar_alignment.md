---
name: menu-bar-pill-alignment
description: How to align the collapsed notch pill with macOS menu bar for different Mac models (notch vs non-notch)
type: feedback
---

## Menu Bar Pill Alignment Strategy

### Key Principle
The collapsed pill must visually fill the entire menu bar height. Use `NSScreen.visibleFrame` to compute menu bar height dynamically, NOT hardcoded values.

### How It Works (NotchGeometry.swift)
```
menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
```

**Non-notch Macs** (MacBook Pro 13" M2, MacBook Air, external displays):
- `auxiliaryTopLeftArea` returns width=0
- Menu bar height is typically **30pt**
- Pill frame: `y = screenFrame.maxY - menuH`, `height = menuH`
- Use `MenuBarPillShape` (flat rectangle, no rounded corners) so the pill's edges perfectly match the menu bar boundaries
- **Do NOT** add extra offset (+1/-1) — it shifts the pill visibly

**Notch Macs** (MacBook Pro 14"/16" 2021+):
- `auxiliaryTopLeftArea` returns width > 0
- Pill sits flush at screen top: `y = screenFrame.maxY - collapsedH`
- Use `TrapezoidShape` (narrower at top, rounded bottom corners) for the Dynamic Island look

### Debugging Tips
- Check `/tmp/vibecode-ipc.log` for `repositionPanel` logs showing exact frame values
- Use `screencapture -x -R x,y,w,h /tmp/test.png` to capture specific screen regions
- On Retina displays, pixel count = 2x logical points
- `visibleFrame` is affected by Stage Manager (x offset) and Dock — only use maxY for menu bar height

### User's Machine
MacBook Pro 13-inch M2 2022 (NO notch), 2560x1600 Retina, logical 1440x900, menu bar = 30pt.

**Why:** Early attempts used hardcoded heights (24pt, 37pt) and various offsets which all looked wrong. The only correct approach is reading the actual menu bar height from the OS and making the pill exactly that tall.

**How to apply:** When adapting for a new Mac, just run the app — `menuBarHeight(for:)` auto-computes. If visual misalignment appears, capture screenshots and check pixel boundaries before changing constants.
