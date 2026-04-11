#!/bin/bash
# VibeCode 远程安装脚本
# 一键安装 vibecode-agent 和 vibecode-bridge，并配置 Claude Code hooks
# 用法: bash setup-remote.sh [--port 19876] [--token TOKEN]
# 前提: Python 3.6+, Claude Code 已安装

set -e

PORT="${1:-8876}"
TOKEN=""
INSTALL_DIR="$HOME/.vibecode/bin"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port) PORT="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=================================="
echo "  VibeCode Remote Setup"
echo "=================================="
echo ""

# Check Python
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found. Please install Python 3.6+."
    exit 1
fi

PYTHON_VER=$(python3 -c "import sys; print(sys.version_info[:2])")
echo "[OK] Python3 found: $PYTHON_VER"

# Create install directory
mkdir -p "$INSTALL_DIR"
echo "[OK] Install dir: $INSTALL_DIR"

# Install agent
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/vibecode-agent.py" ]; then
    cp "$SCRIPT_DIR/vibecode-agent.py" "$INSTALL_DIR/vibecode-agent"
else
    # Inline agent — download or create
    echo "ERROR: vibecode-agent.py not found in $SCRIPT_DIR"
    echo "Please copy vibecode-agent.py and vibecode-bridge-remote.py to this directory first."
    exit 1
fi
chmod +x "$INSTALL_DIR/vibecode-agent"
echo "[OK] Installed vibecode-agent"

# Install bridge
if [ -f "$SCRIPT_DIR/vibecode-bridge-remote.py" ]; then
    cp "$SCRIPT_DIR/vibecode-bridge-remote.py" "$INSTALL_DIR/vibecode-bridge"
else
    echo "ERROR: vibecode-bridge-remote.py not found in $SCRIPT_DIR"
    exit 1
fi
chmod +x "$INSTALL_DIR/vibecode-bridge"
echo "[OK] Installed vibecode-bridge"

# Configure Claude Code hooks
echo ""
echo "Configuring Claude Code hooks..."

BRIDGE_CMD="$INSTALL_DIR/vibecode-bridge"

# Set environment variables in bridge wrapper
WRAPPER="$INSTALL_DIR/vibecode-bridge-wrapper"
cat > "$WRAPPER" << WRAPPER_EOF
#!/bin/bash
export VIBECODE_AGENT_URL="http://127.0.0.1:${PORT}"
WRAPPER_EOF

if [ -n "$TOKEN" ]; then
    echo "export VIBECODE_TOKEN=\"${TOKEN}\"" >> "$WRAPPER"
fi

cat >> "$WRAPPER" << 'WRAPPER_EOF'
exec python3 "$HOME/.vibecode/bin/vibecode-bridge" "$@"
WRAPPER_EOF

chmod +x "$WRAPPER"

# Update Claude Code settings
python3 << PYEOF
import json, os

settings_path = os.path.expanduser("$CLAUDE_SETTINGS")
bridge_cmd = "$WRAPPER"

# Read existing settings
settings = {}
if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError:
            pass

# Define all hook events
events = [
    "SessionStart", "SessionEnd",
    "PreToolUse", "PostToolUse", "PostToolUseFailure",
    "PermissionRequest", "Notification",
    "UserPromptSubmit", "Stop",
    "SubagentStart", "SubagentStop",
    "PreCompact", "PostCompact",
]

# Build hooks config
hooks = settings.get("hooks", {})
for event in events:
    timeout = 86400 if event == "PermissionRequest" else 10
    hook_entry = {
        "hooks": [{"type": "command", "command": bridge_cmd, "timeout": timeout}],
        "matcher": ""
    }
    # Merge: append if not already present
    existing = hooks.get(event, [])
    # Remove old vibecode hooks
    existing = [h for h in existing if "vibecode" not in json.dumps(h)]
    existing.append(hook_entry)
    hooks[event] = existing

settings["hooks"] = hooks

# Ensure directory exists
os.makedirs(os.path.dirname(settings_path), exist_ok=True)

# Write back
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("[OK] Claude Code hooks configured in %s" % settings_path)
PYEOF

# Start agent (if not already running)
echo ""
echo "Starting vibecode-agent..."

AGENT_PID=$(pgrep -f "vibecode-agent" 2>/dev/null || true)
if [ -n "$AGENT_PID" ]; then
    echo "[OK] Agent already running (PID: $AGENT_PID)"
else
    AGENT_CMD="python3 $INSTALL_DIR/vibecode-agent --port $PORT"
    if [ -n "$TOKEN" ]; then
        AGENT_CMD="$AGENT_CMD --token $TOKEN"
    fi
    nohup $AGENT_CMD > /tmp/vibecode-agent.log 2>&1 &
    AGENT_PID=$!
    echo "[OK] Agent started (PID: $AGENT_PID)"
    echo "     Log: /tmp/vibecode-agent.log"
fi

# Verify
echo ""
echo "Verifying agent..."
sleep 1
HEALTH=$(python3 -c "
import urllib.request, json
try:
    r = urllib.request.urlopen('http://127.0.0.1:${PORT}/health', timeout=3)
    d = json.loads(r.read())
    print('OK - ' + d.get('status', 'unknown'))
except Exception as e:
    print('FAIL - ' + str(e))
" 2>&1)
echo "  Health check: $HEALTH"

echo ""
echo "=================================="
echo "  Setup Complete!"
echo "=================================="
echo ""
echo "Agent 正在监听: http://0.0.0.0:${PORT}"
echo ""
echo "下一步: 在 Mac 上的 VibeCode 设置中添加远程源:"
echo "  名称: $(hostname)"
echo "  URL:  http://$(hostname):${PORT}"
echo ""
echo "如果需要 SSH 端口转发:"
echo "  ssh -L ${PORT}:localhost:${PORT} -J relay.baidu.com $(hostname)"
echo ""
