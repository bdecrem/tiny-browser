import SwiftUI
import AppKit
import WebKit
import Foundation
import Combine

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

@main
struct TinyBrowserApp: App {
    @StateObject private var tabManager = TabManager()
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var showingSettings = false
    
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
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
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

struct SettingsView: View {
    @AppStorage("defaultHomepage") private var defaultHomepage = "https://www.google.com"
    @AppStorage("enableJavaScript") private var enableJavaScript = true
    @AppStorage("enablePlugins") private var enablePlugins = false
    
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
        }
        .padding()
        .frame(width: 450, height: 200)
    }
}