import SwiftUI
import AppKit

@main
struct TinyBrowserApp: App {
    init() {
        // Ensure app runs as a proper GUI application
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

struct ContentView: View {
    @State private var urlString = "https://www.google.com"
    @State private var currentURL: URL? = URL(string: "https://www.google.com")
    @FocusState private var isTextFieldFocused: Bool
    
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
                
                Button("Go") {
                    loadURL()
                }
            }
            .padding()
            
            WebView(url: currentURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func loadURL() {
        var urlToLoad = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        
        if let url = URL(string: urlToLoad) {
            currentURL = url
        }
    }
}

import WebKit

struct WebView: NSViewRepresentable {
    let url: URL?
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsMagnification = true
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}