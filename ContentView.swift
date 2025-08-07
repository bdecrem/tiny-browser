import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingAddBookmark = false
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true
    
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
            
            if showBookmarkBar {
                BookmarkBarView()
                    .frame(height: 28)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                Divider()
            }
            
            TabBarView()
                .frame(height: 30)
                .background(Color(NSColor.controlBackgroundColor))
            
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