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
    @Published var title: String = "New Tab"
    @Published var isLoading: Bool = false
    let webView: WKWebView
    
    init(url: URL? = nil) {
        self.url = url
        self.webView = WKWebView()
        self.webView.allowsMagnification = true
    }
    
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTab: BrowserTab?
    
    init() {
        createNewTab()
    }
    
    func createNewTab(with url: URL? = nil) {
        let homepage = UserDefaults.standard.string(forKey: "defaultHomepage") ?? "https://www.google.com"
        let tabURL = url ?? URL(string: homepage)
        let newTab = BrowserTab(url: tabURL)
        tabs.append(newTab)
        selectedTab = newTab
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
                            if let url = URL(string: bookmark.url) {
                                tabManager.selectedTab?.url = url
                            }
                        }
                    case .folder(let folder):
                        Menu(folder.name) {
                            ForEach(folder.children) { child in
                                if case .bookmark(let bookmark) = child {
                                    Button(bookmark.name) {
                                        if let url = URL(string: bookmark.url) {
                                            tabManager.selectedTab?.url = url
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
    @State private var urlString = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingAddBookmark = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Enter URL", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        loadURL()
                    }
                    .disableAutocorrection(true)
                    .onChange(of: tabManager.selectedTab) { newValue in
                        if let url = newValue?.url {
                            urlString = url.absoluteString
                        }
                    }
                
                Button("Go") {
                    loadURL()
                }
                
                Button("+") {
                    tabManager.createNewTab()
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
            
            if let selectedTab = tabManager.selectedTab {
                WebView(tab: selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if let url = tabManager.selectedTab?.url {
                urlString = url.absoluteString
            }
            isTextFieldFocused = true
        }
    }
    
    private func loadURL() {
        var urlToLoad = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        
        if let url = URL(string: urlToLoad) {
            tabManager.selectedTab?.url = url
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
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tab.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.system(size: 12))
            
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
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .onTapGesture {
            tabManager.selectedTab = tab
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
                if let url = URL(string: bookmark.url) {
                    tabManager.selectedTab?.url = url
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
                            if let url = URL(string: bookmark.url) {
                                tabManager.selectedTab?.url = url
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
        return tab.webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = tab.url,
           webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
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
            tab.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab.isLoading = false
            if let title = webView.title, !title.isEmpty {
                tab.title = title
            }
            if let url = webView.url {
                tab.url = url
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
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