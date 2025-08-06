#!/bin/bash

echo "=== TinyBrowser Tab Test ==="
echo "Starting browser..."

# Kill any existing instances
pkill -9 TinyBrowser 2>/dev/null

# Start the browser in background and capture output
./TinyBrowser 2>&1 | tee tinybrowser.log &
BROWSER_PID=$!

# Wait for browser to start
sleep 3

echo "Testing tab functionality with AppleScript..."

# Test 1: Check if browser is running
osascript -e 'tell application "System Events"
    if exists (process "TinyBrowser") then
        return "✓ Browser is running"
    else
        return "✗ Browser not found"
    end if
end tell'

# Test 2: Create new tab with Cmd+T
echo "Creating new tab with Cmd+T..."
osascript -e 'tell application "System Events"
    tell process "TinyBrowser"
        keystroke "t" using command down
    end tell
end tell'

sleep 1

# Test 3: Type a URL in the new tab
echo "Typing URL in new tab..."
osascript -e 'tell application "System Events"
    tell process "TinyBrowser"
        keystroke "github.com"
        delay 0.5
        key code 36 -- Enter key
    end tell
end tell'

sleep 3

# Test 4: Create another tab and test
echo "Creating another tab..."
osascript -e 'tell application "System Events"
    tell process "TinyBrowser"
        keystroke "t" using command down
        delay 1
        keystroke "stackoverflow.com"
        delay 0.5
        key code 36 -- Enter key
    end tell
end tell'

sleep 3

echo ""
echo "=== Debug Output from Browser ==="
grep "DEBUG TAB" tinybrowser.log | tail -20

echo ""
echo "=== URL Loading Debug ==="
grep "DEBUG:" tinybrowser.log | grep -E "load|URL" | tail -10

# Keep browser running for 5 more seconds
sleep 5

# Clean up
kill $BROWSER_PID 2>/dev/null

echo ""
echo "Test complete. Check tinybrowser.log for full output."