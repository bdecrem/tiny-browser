#!/bin/bash

echo "=== Tab Focus Test ==="

# Kill old instances
pkill -9 TinyBrowser

# Start browser with output capture
./TinyBrowser 2>&1 > test_output.log &
PID=$!

sleep 3

echo "1. Testing initial state..."
ps aux | grep TinyBrowser | grep -v grep && echo "✓ Browser running"

echo ""
echo "2. Creating new tab with keyboard shortcut..."
osascript <<EOF
tell application "System Events"
    tell process "TinyBrowser"
        set frontmost to true
        delay 0.5
        -- Create new tab
        keystroke "t" using command down
        delay 1
        -- Type a URL
        keystroke "example.com"
        delay 0.5
        -- Press Enter
        key code 36
        delay 2
        return "Tab created and URL entered"
    end tell
end tell
EOF

echo ""
echo "3. Creating another tab..."
osascript <<EOF
tell application "System Events"
    tell process "TinyBrowser"
        -- Create another tab
        keystroke "t" using command down
        delay 1
        keystroke "github.com"
        key code 36
        return "Second tab created"
    end tell
end tell
EOF

sleep 3

echo ""
echo "4. Checking debug output..."
tail -20 test_output.log | grep "DEBUG TAB" || echo "No debug output found"

echo ""
echo "5. Checking URL loading..."
tail -20 test_output.log | grep "DEBUG:" || echo "No URL debug output found"

# Keep running for observation
echo ""
echo "Browser is running. Press Ctrl+C to stop..."
wait $PID