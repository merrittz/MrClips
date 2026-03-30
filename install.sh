#!/bin/bash
set -e

BINARY_DIR="$HOME/.local/bin"
BINARY="$BINARY_DIR/MrClips"
PLIST_NAME="com.mrclips.agent"
PLIST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Compiling MrClips..."
swiftc -O -o "$SCRIPT_DIR/MrClips" "$SCRIPT_DIR/MrClips.swift"

echo "==> Installing binary to $BINARY..."
mkdir -p "$BINARY_DIR"
cp "$SCRIPT_DIR/MrClips" "$BINARY"
chmod +x "$BINARY"

echo "==> Installing LaunchAgent..."
# Unload existing agent if present
launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

echo "==> Loading LaunchAgent..."
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo ""
echo "Done! MrClips is running."
echo "  - Press Ctrl+Option+V to show clipboard history"
echo "  - Click 'MrClips' in the menu bar for options"
echo "  - It will auto-start on login"
