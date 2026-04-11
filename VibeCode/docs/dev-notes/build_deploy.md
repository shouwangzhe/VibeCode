# Build & Deploy Notes

## VibeBridge (容器/本地 bridge 二进制)

- **SPM 构建**：`swift build --product VibeBridge`（不是 xcodebuild）
- **手动部署**：`cp .build/debug/VibeBridge ~/.vibecode/bin/vibecode-bridge`
- xcodebuild 只构建 VibeCode.app，不会重新编译 VibeBridge

## VibeCode.app

- `xcodebuild -scheme VibeCode -configuration Debug build`
- 产物在 DerivedData：`~/Library/Developer/Xcode/DerivedData/VibeCode-xxx/Build/Products/Debug/VibeCode.app`
- 重启：`pkill -f "VibeCode.app/Contents/MacOS/VibeCode" && sleep 1 && open <app_path>`

## Ducc (百度版 Claude Code)

- 从 `~/.comate/extensions/baidu.baidu-cc-*/resources/claude-code/claude` 启动
- 使用 `--settings` 指向独立 settings.json（含 env、ducc 自己的 hooks）
- Claude Code 会**合并** `--settings` 和 `~/.claude/settings.json` 中的 hooks
- 所以 vibecode-bridge 的 hooks 在 `~/.claude/settings.json` 中注册即可，ducc 也会触发
