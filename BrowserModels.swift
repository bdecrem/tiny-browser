import SwiftUI
import WebKit
import Foundation
import Combine

// MARK: - Browser Tab Management

class BrowserTab: ObservableObject, Identifiable, Equatable {
    let id = UUID()
    @Published var url: URL?
    @Published var urlString: String = ""
    @Published var title: String = "New Tab"
    @Published var isLoading: Bool = false
    @Published var hasPasswordsAvailable: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
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
        guard let splashURL = Bundle.main.url(forResource: "chin-HIRES", withExtension: "png") else {
            print("Splash image not found in bundle")
            // Fallback HTML without image
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
                </style>
            </head>
            <body>
                <div>Tiny Browser</div>
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: nil)
            title = "New Tab"
            urlString = "about:start"
            return
        }

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
                    padding: 40px;
                }
                img {
                    max-width: 150px;
                    height: auto;
                    margin-bottom: 20px;
                }
                h1 {
                    color: #333;
                    font-size: 24px;
                    font-weight: 400;
                    margin: 0;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <img src="chin-HIRES.png" alt="Tiny Browser Splash">
                <h1>Tiny browser</h1>
            </div>
        </body>
        </html>
        """

        let baseURL = splashURL.deletingLastPathComponent()
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