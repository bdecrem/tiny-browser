# TinyBrowser - WebKit + SwiftUI Browser

## Project Overview
A minimal web browser built with SwiftUI and WebKit for macOS. Features a simple URL bar for navigation.

## Build & Run Commands
```bash
# Build the browser
xcrun swift build --configuration release

# Run the browser
./.build/release/TinyBrowser

# Or use the test script for debugging
./test_build.sh
```

## Testing & Verification
- Check if browser is running: `ps aux | grep -i tinybrowser`
- Kill existing process: `pkill -9 TinyBrowser`
- Verify window visibility: `osascript -e 'tell application "System Events" to get name of every process whose visible is true' | grep TinyBrowser`

## Project Structure
- `main.swift` - Single file containing the entire app (SwiftUI app structure, ContentView with URL bar, WebView wrapper)
- `Package.swift` - Swift Package Manager configuration
- `test_build.sh` - Comprehensive build and launch testing script

## Key Implementation Details
- Uses `WKWebView` wrapped in `NSViewRepresentable` for web rendering
- URL bar automatically prepends `https://` if no protocol specified
- Window starts with Google as default page
- Minimum window size: 800x600
- Focus automatically set to URL bar on launch

## Known Working Features
- URL input and navigation
- Basic web browsing
- Enter key to submit URL
- "Go" button for navigation