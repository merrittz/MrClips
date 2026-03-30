#!/bin/bash
set -e

PLIST_NAME="com.mrclips.agent"
PLIST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
BINARY="$HOME/.local/bin/MrClips"
DATA_DIR="$HOME/Library/Application Support/MrClips"

echo "==> Stopping MrClips..."
launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true

echo "==> Removing LaunchAgent..."
rm -f "$PLIST"

echo "==> Removing binary..."
rm -f "$BINARY"

echo "==> Securely removing clipboard history..."
if [ -f "$DATA_DIR/history.json" ]; then
    # Overwrite with zeros before deleting
    filesize=$(stat -f%z "$DATA_DIR/history.json" 2>/dev/null || echo 0)
    if [ "$filesize" -gt 0 ]; then
        dd if=/dev/zero of="$DATA_DIR/history.json" bs="$filesize" count=1 2>/dev/null
    fi
    rm -f "$DATA_DIR/history.json"
fi
rmdir "$DATA_DIR" 2>/dev/null || true

echo "Done! MrClips has been fully removed."
