# TinyBrowser - WebKit + SwiftUI Browser

## Project Overview
A feature-rich web browser built with SwiftUI and WebKit for macOS. Includes tabs, bookmarks, and Safari bookmark import.

## Build & Run Commands
```bash
# Build the browser
xcrun swift build --configuration release

# Run the browser (command line)
./.build/release/TinyBrowser

# Launch as proper macOS app with dock icon
open TinyBrowser.app

# Or double-click TinyBrowser.app in Finder

# Or use the test script for debugging
./test_build.sh

# Clean build
rm -rf .build
```

## Testing & Verification
- Check if browser is running: `ps aux | grep -i tinybrowser`
- Kill existing process: `pkill -9 TinyBrowser`
- Verify window visibility: `osascript -e 'tell application "System Events" to get name of every process whose visible is true' | grep TinyBrowser`
- View bookmarks file: `cat ~/Library/Application\ Support/TinyBrowser/bookmarks.json`

## Project Structure
- `main.swift` - Monolithic file containing entire application
  - Browser tab management
  - Bookmark system with JSON persistence
  - Safari HTML bookmark parser
  - SwiftUI views and navigation
- `Package.swift` - Swift Package Manager configuration
- `test_build.sh` - Comprehensive build and launch testing script
- `launch.sh` - Quick launch script
- `random/Safari-bookmarks/Bookmarks.html` - Sample Safari bookmarks for testing

## Features

### Core Browsing
- URL input with auto-prepend https://
- Basic web navigation with WKWebView
- Keyboard shortcuts (Enter to submit URL)
- Minimum window size: 900x600

### Tab System (Safari-style)
- Multiple tabs with independent browsing sessions
- Tab bar below URL bar (Safari layout)
- Tab titles show page titles
- Close tabs with X button (on hover/selection)
- New tab button (+) and Cmd+T shortcut
- Persistent WebViews (no reload on tab switch)
- URL bar syncs with active tab

### Bookmark System
- **Data Format**: JSON with hierarchical structure
- **Storage**: `~/Library/Application Support/TinyBrowser/bookmarks.json`
- **Features**:
  - Bookmark bar below tabs
  - Star button to bookmark current page (Cmd+D)
  - Nested folder support
  - Tags and metadata support
  - Default bookmarks (Google, GitHub, Stack Overflow)
  - Bookmarks menu in menu bar

### Safari Bookmark Import
- **Location**: Settings → Bookmarks → Import Safari Bookmarks
- **Parser**: Handles Netscape HTML bookmark format
- **Features**:
  - File picker for .html selection
  - Preserves folder hierarchy
  - Creates timestamped import folder
  - Shows import success/failure message
  - Counts imported bookmarks

### Settings
- **Access**: Cmd+, or TinyBrowser → Settings
- **Options**:
  - Homepage configuration
  - JavaScript toggle
  - Plugins toggle
  - Bookmark import

## Coding Best Practices

### Architecture Principles
1. **Monolithic First**: Start with single file, refactor when needed
2. **Progressive Enhancement**: Add features incrementally, test each addition
3. **User-Centric Design**: Features driven by actual use cases
4. **Defensive Coding**: Handle edge cases gracefully (empty states, missing files)

### Development Practices
1. **Testing Strategy**:
   - Created `test_build.sh` for comprehensive build verification
   - Test script checks process, binary, and launch status
   - Manual testing for UI features

2. **Data Persistence**:
   - JSON for human-readable configuration
   - ISO 8601 dates for standards compliance
   - Automatic directory creation for app support

3. **Error Handling**:
   - Graceful fallbacks (default bookmarks if none exist)
   - User-friendly error messages
   - Try-catch for file operations

4. **Code Organization**:
   - MARK comments for section navigation
   - Logical grouping (Models, Manager, Views)
   - Protocol-oriented design for bookmark items

5. **SwiftUI Best Practices**:
   - @StateObject for shared managers
   - @EnvironmentObject for dependency injection
   - @AppStorage for user preferences
   - Proper scene management for Settings

6. **User Experience**:
   - Native macOS patterns (Settings window, menu bar)
   - Visual feedback (hover states, selection)
   - Keyboard shortcuts for power users
   - Progress indication (import success messages)

### Future Improvements
- [ ] History tracking
- [ ] Private browsing mode
- [ ] Download manager
- [ ] Password manager integration
- [ ] Bookmark search UI
- [ ] Favicon support
- [ ] Bookmark export
- [ ] Chrome bookmark import
- [ ] Sync across devices

## Known Issues
- Settings window command appears after About menu (macOS convention)
- Subfolders in bookmark menus show "not yet supported"
- No bookmark editing UI yet

## Dependencies
- SwiftUI
- WebKit
- Foundation
- Combine
- UniformTypeIdentifiers