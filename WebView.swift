import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

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
    @State private var showingDeleteConfirmation = false
    
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
            
            Section("Data Management") {
                Button("Delete All Bookmarks") {
                    showingDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 450, height: 380)
        .alert("Delete All Bookmarks", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                BookmarkManager.shared.deleteAllBookmarks()
            }
        } message: {
            Text("This will permanently delete all your bookmarks and reset to defaults. This action cannot be undone.")
        }
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