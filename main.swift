import SwiftUI
import AppKit  
import WebKit
import Foundation
import Combine
import UniformTypeIdentifiers

// MARK: - Browser Tab Management

class BrowserTab: ObservableObject, Identifiable, Equatable {
    let id = UUID()
    @Published var url: URL?
    @Published var urlString: String = ""
    @Published var title: String = "New Tab"
    @Published var isLoading: Bool = false
    let webView: WKWebView
    
    init(url: URL? = nil) {
        self.url = url
        self.urlString = url?.absoluteString ?? ""
        
        // Create WebView with proper configuration
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.allowsMagnification = true
        self.webView.allowsBackForwardNavigationGestures = true
    }
    
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
    
    func loadStartPage() {
        // chin.png as base64 - hardcoded directly
        let imageBase64 = "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"
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background: white;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                }
                .container {
                    text-align: center;
                }
                img {
                    width: 150px;
                    height: auto;
                    margin-bottom: 30px;
                }
                h1 {
                    color: #333;
                    font-size: 36px;
                    font-weight: 300;
                    margin: 0;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <img src="chin.png" alt="Tiny Browser">
                <h1>Tiny Browser</h1>
            </div>
        </body>
        </html>
        """
        
        let currentPath = FileManager.default.currentDirectoryPath
        let baseURL = URL(fileURLWithPath: currentPath)
        webView.loadHTMLString(html, baseURL: baseURL)
        title = "New Tab"
        urlString = "about:start"
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTab: BrowserTab?
    
    init() {
        createNewTab()
    }
    
    func createNewTab(with url: URL? = nil) {
        let newTab = BrowserTab(url: url)
        tabs.append(newTab)
        
        // If no URL provided, load custom start page
        if url == nil {
            newTab.loadStartPage()
        }
        
        print("DEBUG TAB: Created new tab with URL: \(url?.absoluteString ?? "start page")")
        print("DEBUG TAB: Total tabs: \(tabs.count)")
        selectedTab = newTab
        print("DEBUG TAB: Selected tab changed to: \(newTab.id)")
    }
    
    func closeTab(_ tab: BrowserTab) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs.remove(at: index)
            
            if tabs.isEmpty {
                createNewTab()
            } else if selectedTab?.id == tab.id {
                selectedTab = tabs[min(index, tabs.count - 1)]
            }
        }
    }
}

// MARK: - Bookmark Data Models

enum BookmarkItemType: String, Codable {
    case url = "url"
    case folder = "folder"
}

protocol BookmarkItem: Codable, Identifiable {
    var id: String { get }
    var name: String { get set }
    var type: BookmarkItemType { get }
    var dateAdded: Date { get }
    var dateModified: Date { get set }
}

struct Bookmark: BookmarkItem, Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var type: BookmarkItemType { .url }
    var url: String
    var dateAdded: Date
    var dateModified: Date
    var tags: [String]
    var description: String?
    var favicon: String?
    var visitCount: Int
    
    init(name: String, url: String, tags: [String] = [], description: String? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.url = url
        self.dateAdded = Date()
        self.dateModified = Date()
        self.tags = tags
        self.description = description
        self.favicon = nil
        self.visitCount = 0
    }
}

struct BookmarkFolder: BookmarkItem, Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var type: BookmarkItemType { .folder }
    var dateAdded: Date
    var dateModified: Date
    var children: [BookmarkNode]
    
    init(name: String, children: [BookmarkNode] = []) {
        self.id = UUID().uuidString
        self.name = name
        self.dateAdded = Date()
        self.dateModified = Date()
        self.children = children
    }
    
    mutating func addChild(_ node: BookmarkNode) {
        children.append(node)
        dateModified = Date()
    }
    
    mutating func removeChild(withId id: String) {
        children.removeAll { $0.id == id }
        dateModified = Date()
    }
    
    static func == (lhs: BookmarkFolder, rhs: BookmarkFolder) -> Bool {
        lhs.id == rhs.id
    }
}

enum BookmarkNode: Codable, Identifiable, Equatable {
    case bookmark(Bookmark)
    case folder(BookmarkFolder)
    
    var id: String {
        switch self {
        case .bookmark(let bookmark):
            return bookmark.id
        case .folder(let folder):
            return folder.id
        }
    }
    
    var name: String {
        switch self {
        case .bookmark(let bookmark):
            return bookmark.name
        case .folder(let folder):
            return folder.name
        }
    }
    
    var type: BookmarkItemType {
        switch self {
        case .bookmark:
            return .url
        case .folder:
            return .folder
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BookmarkItemType.self, forKey: .type)
        
        switch type {
        case .url:
            let bookmark = try container.decode(Bookmark.self, forKey: .data)
            self = .bookmark(bookmark)
        case .folder:
            let folder = try container.decode(BookmarkFolder.self, forKey: .data)
            self = .folder(folder)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .bookmark(let bookmark):
            try container.encode(BookmarkItemType.url, forKey: .type)
            try container.encode(bookmark, forKey: .data)
        case .folder(let folder):
            try container.encode(BookmarkItemType.folder, forKey: .type)
            try container.encode(folder, forKey: .data)
        }
    }
}

struct BookmarksRoot: Codable {
    let version: Int
    var bookmarkBar: BookmarkFolder
    var otherBookmarks: BookmarkFolder
    var dateModified: Date
    
    init() {
        self.version = 1
        self.bookmarkBar = BookmarkFolder(name: "Bookmarks Bar")
        self.otherBookmarks = BookmarkFolder(name: "Other Bookmarks")
        self.dateModified = Date()
    }
}

// MARK: - Bookmark Manager

class BookmarkManager: ObservableObject {
    @Published var bookmarksRoot: BookmarksRoot
    
    private let bookmarksFileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    static let shared = BookmarkManager()
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appSupportPath = documentsPath.appendingPathComponent("TinyBrowser", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appSupportPath, withIntermediateDirectories: true)
        
        self.bookmarksFileURL = appSupportPath.appendingPathComponent("bookmarks.json")
        
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        self.bookmarksRoot = BookmarkManager.loadBookmarks(from: bookmarksFileURL, using: decoder) ?? BookmarksRoot()
        
        if !FileManager.default.fileExists(atPath: bookmarksFileURL.path) {
            addDefaultBookmarks()
            save()
        }
    }
    
    private static func loadBookmarks(from url: URL, using decoder: JSONDecoder) -> BookmarksRoot? {
        guard let data = try? Data(contentsOf: url),
              let root = try? decoder.decode(BookmarksRoot.self, from: data) else {
            return nil
        }
        return root
    }
    
    private func addDefaultBookmarks() {
        let googleBookmark = Bookmark(name: "Google", url: "https://www.google.com", tags: ["search"])
        let githubBookmark = Bookmark(name: "GitHub", url: "https://github.com", tags: ["development"])
        let stackOverflowBookmark = Bookmark(name: "Stack Overflow", url: "https://stackoverflow.com", tags: ["development", "help"])
        
        bookmarksRoot.bookmarkBar.addChild(.bookmark(googleBookmark))
        bookmarksRoot.bookmarkBar.addChild(.bookmark(githubBookmark))
        bookmarksRoot.bookmarkBar.addChild(.bookmark(stackOverflowBookmark))
    }
    
    func save() {
        bookmarksRoot.dateModified = Date()
        
        do {
            let data = try encoder.encode(bookmarksRoot)
            try data.write(to: bookmarksFileURL)
            print("Bookmarks saved to: \(bookmarksFileURL.path)")
        } catch {
            print("Failed to save bookmarks: \(error)")
        }
    }
    
    func addBookmarkToBar(name: String, url: String, tags: [String] = []) {
        let bookmark = Bookmark(name: name, url: url, tags: tags)
        bookmarksRoot.bookmarkBar.addChild(.bookmark(bookmark))
        save()
    }
    
    func importSafariBookmarks(from fileURL: URL) throws -> Int {
        let htmlContent = try String(contentsOf: fileURL, encoding: .utf8)
        let parser = SafariBookmarkParser()
        let importedNodes = parser.parse(html: htmlContent)
        
        var importCount = 0
        
        // Create an "Imported from Safari" folder
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let importFolderName = "Safari Import - \(dateFormatter.string(from: Date()))"
        var importFolder = BookmarkFolder(name: importFolderName)
        
        // Add all imported bookmarks to the import folder
        for node in importedNodes {
            importFolder.addChild(node)
            importCount += countBookmarks(in: node)
        }
        
        // Add the import folder to the bookmark bar
        bookmarksRoot.bookmarkBar.addChild(.folder(importFolder))
        save()
        
        return importCount
    }
    
    private func countBookmarks(in node: BookmarkNode) -> Int {
        switch node {
        case .bookmark:
            return 1
        case .folder(let folder):
            return folder.children.reduce(0) { $0 + countBookmarks(in: $1) }
        }
    }
}

// MARK: - Safari Bookmark Parser

class SafariBookmarkParser {
    func parse(html: String) -> [BookmarkNode] {
        var nodes: [BookmarkNode] = []
        var folderStack: [BookmarkFolder] = []
        
        let lines = html.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for folder start
            if trimmed.contains("<H3>") && trimmed.contains("</H3>") {
                let name = extractText(from: trimmed, tag: "H3") ?? "Untitled Folder"
                let newFolder = BookmarkFolder(name: name)
                
                if !folderStack.isEmpty {
                    // This is a subfolder
                    folderStack.append(newFolder)
                } else {
                    // This is a top-level folder
                    folderStack.append(newFolder)
                }
            }
            // Check for bookmark
            else if trimmed.contains("<A HREF=") && trimmed.contains("</A>") {
                if let url = extractHref(from: trimmed),
                   let name = extractText(from: trimmed, tag: "A") {
                    let bookmark = Bookmark(name: name, url: url)
                    
                    if !folderStack.isEmpty {
                        // Add to current folder
                        folderStack[folderStack.count - 1].addChild(.bookmark(bookmark))
                    } else {
                        // Add as top-level bookmark
                        nodes.append(.bookmark(bookmark))
                    }
                }
            }
            // Check for folder end
            else if trimmed.contains("</DL>") {
                if !folderStack.isEmpty {
                    let completedFolder = folderStack.removeLast()
                    
                    if !folderStack.isEmpty {
                        // Add to parent folder
                        folderStack[folderStack.count - 1].addChild(.folder(completedFolder))
                    } else {
                        // Add as top-level folder
                        nodes.append(.folder(completedFolder))
                    }
                }
            }
        }
        
        // Add any remaining folders
        while !folderStack.isEmpty {
            let folder = folderStack.removeLast()
            if !folderStack.isEmpty {
                folderStack[folderStack.count - 1].addChild(.folder(folder))
            } else {
                nodes.append(.folder(folder))
            }
        }
        
        return nodes
    }
    
    private func extractHref(from line: String) -> String? {
        if let hrefRange = line.range(of: "HREF=\"") {
            let afterHref = String(line[hrefRange.upperBound...])
            if let endQuoteIndex = afterHref.firstIndex(of: "\"") {
                return String(afterHref[..<endQuoteIndex])
            }
        }
        return nil
    }
    
    private func extractText(from line: String, tag: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        
        if let startRange = line.range(of: openTag),
           let endRange = line.range(of: closeTag) {
            let textRange = startRange.upperBound..<endRange.lowerBound
            return String(line[textRange])
        } else if let startRange = line.range(of: ">"),
                  let endRange = line.range(of: closeTag) {
            let textRange = startRange.upperBound..<endRange.lowerBound
            return String(line[textRange])
        }
        
        return nil
    }
}

// MARK: - Main App

@main
struct TinyBrowserApp: App {
    @StateObject private var tabManager = TabManager()
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tabManager)
                .environmentObject(bookmarkManager)
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

// MARK: - Views

struct ContentView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingAddBookmark = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Enter URL", text: Binding(
                    get: { tabManager.selectedTab?.urlString ?? "" },
                    set: { tabManager.selectedTab?.urlString = $0 }
                ))
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        print("DEBUG TAB: onSubmit triggered with URL: \(tabManager.selectedTab?.urlString ?? "")")
                        loadURL()
                    }
                    .disableAutocorrection(true)
                    .onAppear {
                        print("DEBUG TAB: TextField appeared")
                    }
                    .onChange(of: tabManager.selectedTab) { newValue in
                        print("DEBUG TAB: onChange triggered, new tab: \(newValue?.id.uuidString ?? "nil")")
                        // Focus the URL field when switching tabs with a small delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                            print("DEBUG TAB: Focus set to URL field")
                        }
                    }
                
                Button("Go") {
                    loadURL()
                }
                
                Button("+") {
                    tabManager.createNewTab()
                    // The onChange handler will update urlString automatically
                    // Just focus the field after a small delay to ensure the view updates
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }
                .font(.title2)
                .buttonStyle(.plain)
                .frame(width: 30)
                
                Button(action: {
                    if let currentTab = tabManager.selectedTab,
                       let url = currentTab.url {
                        bookmarkManager.addBookmarkToBar(
                            name: currentTab.title,
                            url: url.absoluteString
                        )
                    }
                }) {
                    Image(systemName: "star")
                }
                .buttonStyle(.plain)
                .help("Bookmark this page")
            }
            .padding()
            
            TabBarView()
                .frame(height: 30)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            BookmarkBarView()
                .frame(height: 28)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Use a ZStack to layer all WebViews and only show the selected one
            ZStack {
                ForEach(tabManager.tabs) { tab in
                    WebView(tab: tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(tab.id == tabManager.selectedTab?.id ? 1 : 0)
                        .allowsHitTesting(tab.id == tabManager.selectedTab?.id)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func loadURL() {
        guard let tab = tabManager.selectedTab else { return }
        
        var urlToLoad = tab.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        
        print("DEBUG: Attempting to load URL: \(urlToLoad)")
        
        if let url = URL(string: urlToLoad) {
            print("DEBUG: Valid URL created: \(url)")
            
            // Update the tab's URL and load directly in WebView
            tab.url = url
            tab.urlString = url.absoluteString  // Update to the full URL
            let request = URLRequest(url: url)
            tab.webView.load(request)
            print("DEBUG: Load request sent to WebView")
        } else {
            print("DEBUG: Failed to create URL from: \(urlToLoad)")
        }
    }
}

struct TabBarView: View {
    @EnvironmentObject var tabManager: TabManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(tabManager.tabs) { tab in
                    TabItemView(tab: tab)
                }
            }
            .padding(.horizontal, 5)
        }
    }
}

struct TabItemView: View {
    @EnvironmentObject var tabManager: TabManager
    @ObservedObject var tab: BrowserTab
    @State private var isHovering = false
    
    var isSelected: Bool {
        tabManager.selectedTab?.id == tab.id
    }
    
    var displayTitle: String {
        let title = tab.title
        
        // Common patterns to remove
        let patterns = [
            " - Google Search",
            " - Google 搜索",
            " · GitHub",
            " - Stack Overflow",
            " | ",
            " – ",
            " — "
        ]
        
        var cleanTitle = title
        for pattern in patterns {
            if let range = cleanTitle.range(of: pattern) {
                cleanTitle = String(cleanTitle[..<range.lowerBound])
                break
            }
        }
        
        // If still too long, take first 2-3 significant words
        let words = cleanTitle.split(separator: " ")
        if words.count > 3 {
            cleanTitle = words.prefix(2).joined(separator: " ")
        }
        
        // Limit to max 20 characters
        if cleanTitle.count > 20 {
            cleanTitle = String(cleanTitle.prefix(17)) + "..."
        }
        
        return cleanTitle.isEmpty ? "New Tab" : cleanTitle
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(displayTitle)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.system(size: 12))
                .frame(minWidth: 50, maxWidth: 120, alignment: .leading)
            
            if isHovering || isSelected {
                Button(action: {
                    tabManager.closeTab(tab)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 100, maxWidth: 160)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .onTapGesture {
            print("DEBUG TAB: Tab clicked: \(tab.id), URL: \(tab.url?.absoluteString ?? "nil")")
            tabManager.selectedTab = tab
            // Force focus to the main window and URL field
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct BookmarkBarView: View {
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @EnvironmentObject var tabManager: TabManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(bookmarkManager.bookmarksRoot.bookmarkBar.children) { node in
                    BookmarkItemView(node: node)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }
}

struct BookmarkItemView: View {
    let node: BookmarkNode
    @EnvironmentObject var tabManager: TabManager
    @State private var isHovering = false
    
    var body: some View {
        switch node {
        case .bookmark(let bookmark):
            Button(action: {
                if let url = URL(string: bookmark.url),
                   let tab = tabManager.selectedTab {
                    tab.url = url
                    let request = URLRequest(url: url)
                    tab.webView.load(request)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                    Text(bookmark.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isHovering ? Color.gray.opacity(0.2) : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }
            .help(bookmark.url)
            
        case .folder(let folder):
            Menu {
                ForEach(folder.children) { child in
                    switch child {
                    case .bookmark(let bookmark):
                        Button(bookmark.name) {
                            if let url = URL(string: bookmark.url),
                               let tab = tabManager.selectedTab {
                                tab.url = url
                                let request = URLRequest(url: url)
                                tab.webView.load(request)
                            }
                        }
                    case .folder(let subfolder):
                        Menu(subfolder.name) {
                            Text("Subfolders not yet supported")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text(folder.name)
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isHovering ? Color.gray.opacity(0.2) : Color.clear)
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .onHover { hovering in
                isHovering = hovering
            }
        }
    }
}

struct WebView: NSViewRepresentable {
    @ObservedObject var tab: BrowserTab
    
    func makeNSView(context: Context) -> WKWebView {
        tab.webView.navigationDelegate = context.coordinator
        
        // Load initial URL if available
        if let url = tab.url {
            let request = URLRequest(url: url)
            tab.webView.load(request)
            print("DEBUG: Initial load in makeNSView for URL: \(url)")
        }
        
        return tab.webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Don't reload if we're already loading or if the URL hasn't actually changed
        // The webView.url check doesn't work during loading, so we need a better approach
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let tab: BrowserTab
        
        init(tab: BrowserTab) {
            self.tab = tab
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("DEBUG: Started loading: \(webView.url?.absoluteString ?? "unknown")")
            tab.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("DEBUG: Finished loading: \(webView.url?.absoluteString ?? "unknown")")
            tab.isLoading = false
            if let title = webView.title, !title.isEmpty {
                tab.title = title
            }
            if let url = webView.url {
                tab.url = url
                tab.urlString = url.absoluteString
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("DEBUG: Failed to load with error: \(error.localizedDescription)")
            tab.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("DEBUG: Failed provisional navigation with error: \(error.localizedDescription)")
            tab.isLoading = false
        }
    }
}

struct SettingsView: View {
    @AppStorage("defaultHomepage") private var defaultHomepage = "https://www.google.com"
    @AppStorage("enableJavaScript") private var enableJavaScript = true
    @AppStorage("enablePlugins") private var enablePlugins = false
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    
    var body: some View {
        Form {
            Section("General") {
                HStack {
                    Text("Homepage:")
                    TextField("Homepage URL", text: $defaultHomepage)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Section("Privacy & Security") {
                Toggle("Enable JavaScript", isOn: $enableJavaScript)
                Toggle("Enable Plugins", isOn: $enablePlugins)
            }
            
            Section("Bookmarks") {
                Button("Import Safari Bookmarks...") {
                    importSafariBookmarks()
                }
                .buttonStyle(.bordered)
                
                if showingImportResult {
                    Text(importResultMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 450, height: 300)
    }
    
    private func importSafariBookmarks() {
        let panel = NSOpenPanel()
        panel.title = "Select Safari Bookmarks File"
        panel.message = "Choose your Safari bookmarks HTML file to import"
        panel.prompt = "Import"
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let count = try BookmarkManager.shared.importSafariBookmarks(from: url)
                    importResultMessage = "✓ Successfully imported \(count) bookmark\(count == 1 ? "" : "s")"
                    showingImportResult = true
                    
                    // Hide the message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showingImportResult = false
                    }
                } catch {
                    importResultMessage = "✗ Import failed: \(error.localizedDescription)"
                    showingImportResult = true
                }
            }
        }
    }
}