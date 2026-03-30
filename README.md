Simple, minimalistic clip board extender. Thanks, Claude.
This definitely already exists as an open source project in some form that I used long ago but couldn't find it.
There are many existing apps similar to this but they are too complicated!

1. Polls the system clipboard every 0.5s, stores the last 5 unique text copies
2. Ctrl+Option+V shows a floating popup near your cursor with the history
3. Click an item to place it on the clipboard; click Clear to securely wipe all history
4. History persists to ~/Library/Application Support/MrClips/history.json (survives restarts)
5. Runs as a menu bar app ("MrClips") with no Dock icon
6. Global hotkey uses the Carbon API (no accessibility permissions needed)

To install and start:

cd ~/Documents/Mr_Clips && ./install.sh

To uninstall:

cd ~/Documents/Mr_Clips && ./uninstall.sh
