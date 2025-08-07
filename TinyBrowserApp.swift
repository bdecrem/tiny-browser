import SwiftUI
import AppKit

@main
struct TinyBrowserApp: App {
    @StateObject private var tabManager = TabManager()
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var passwordManager = PasswordManager.shared
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true
    
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tabManager)
                .environmentObject(bookmarkManager)
                .environmentObject(passwordManager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    tabManager.createNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            
            CommandGroup(after: .appInfo) {
                // Settings menu is handled by the Settings scene
            }
            
            CommandGroup(after: .toolbar) {
                Button(showBookmarkBar ? "Hide Favorites Toolbar" : "Show Favorites Toolbar") {
                    showBookmarkBar.toggle()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
            
            CommandMenu("Bookmarks") {
                Button("Add Bookmark") {
                    if let currentTab = tabManager.selectedTab,
                       let url = currentTab.url {
                        bookmarkManager.addBookmarkToBar(
                            name: currentTab.title,
                            url: url.absoluteString
                        )
                    }
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Divider()
                
                ForEach(bookmarkManager.bookmarksRoot.bookmarkBar.children) { node in
                    switch node {
                    case .bookmark(let bookmark):
                        Button(bookmark.name) {
                            if let url = URL(string: bookmark.url),
                               let tab = tabManager.selectedTab {
                                tab.url = url
                                let request = URLRequest(url: url)
                                tab.webView.load(request)
                            }
                        }
                    case .folder(let folder):
                        Menu(folder.name) {
                            ForEach(folder.children) { child in
                                if case .bookmark(let bookmark) = child {
                                    Button(bookmark.name) {
                                        if let url = URL(string: bookmark.url),
                                           let tab = tabManager.selectedTab {
                                            tab.url = url
                                            let request = URLRequest(url: url)
                                            tab.webView.load(request)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}