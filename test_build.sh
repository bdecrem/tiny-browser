#!/bin/bash

echo "=== Build Test Script ==="
echo ""

# Check if old process is running
echo "1. Checking for existing processes..."
if pgrep -x "TinyBrowser" > /dev/null; then
    echo "   ✓ TinyBrowser is running (PID: $(pgrep -x TinyBrowser))"
    echo "   Killing old process..."
    pkill -9 TinyBrowser
    sleep 1
else
    echo "   × No TinyBrowser process found"
fi

# Clean build
echo ""
echo "2. Cleaning old build..."
rm -rf .build

# Build with verbose output
echo ""
echo "3. Building application..."
if xcrun swift build --configuration release 2>&1; then
    echo "   ✓ Build successful"
else
    echo "   × Build failed!"
    exit 1
fi

# Check binary exists
echo ""
echo "4. Verifying binary..."
if [ -f ".build/release/TinyBrowser" ]; then
    echo "   ✓ Binary exists at .build/release/TinyBrowser"
    echo "   Binary info:"
    file .build/release/TinyBrowser
    echo "   Size: $(du -h .build/release/TinyBrowser | cut -f1)"
else
    echo "   × Binary not found!"
    exit 1
fi

# Launch with output capture
echo ""
echo "5. Launching application..."
echo "   Running: .build/release/TinyBrowser"

# Launch in background and capture output
.build/release/TinyBrowser > app.log 2>&1 &
APP_PID=$!

echo "   Launched with PID: $APP_PID"

# Wait a moment and check if still running
sleep 2

if ps -p $APP_PID > /dev/null; then
    echo "   ✓ Application is running"
    echo ""
    echo "6. Application output (first 20 lines):"
    head -20 app.log
else
    echo "   × Application crashed or exited!"
    echo ""
    echo "6. Error output:"
    cat app.log
    exit 1
fi

echo ""
echo "=== Test Complete ==="
echo "App should be running. Check your screen for the window."
echo "Logs are being written to: app.log"