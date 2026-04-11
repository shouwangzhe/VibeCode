#!/bin/bash
# VibeCode Hook Installation Script
# Installs the vibecode-bridge CLI to a well-known path

set -e

INSTALL_DIR="$HOME/.vibecode/bin"
BRIDGE_NAME="vibecode-bridge"

# Find the built bridge binary
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
BRIDGE_PATH=$(find "$DERIVED_DATA" -name "$BRIDGE_NAME" -path "*/Debug/*" -type f 2>/dev/null | head -1)

if [ -z "$BRIDGE_PATH" ]; then
    echo "Error: vibecode-bridge not found. Build the VibeBridge scheme first."
    exit 1
fi

# Install bridge
mkdir -p "$INSTALL_DIR"
cp "$BRIDGE_PATH" "$INSTALL_DIR/$BRIDGE_NAME"
chmod +x "$INSTALL_DIR/$BRIDGE_NAME"
echo "Installed $BRIDGE_NAME to $INSTALL_DIR"

# Verify
"$INSTALL_DIR/$BRIDGE_NAME" --help 2>/dev/null || true

echo ""
echo "Done! The VibeCode app will install Claude Code hooks when you click"
echo "'Install Hooks' from the menu bar icon."
echo ""
echo "Or run the app and it will manage hooks automatically."
