import SwiftUI
import AppKit

struct ContentView: View {
    @State private var urlString = "https://www.apple.com"
    @State private var currentURL: URL?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Enter URL", text: $urlString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        loadURL()
                    }
                    .disableAutocorrection(true)
                
                Button("Go") {
                    loadURL()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
            
            WebView(url: currentURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadURL()
            isTextFieldFocused = true
        }
    }
    
    private func loadURL() {
        var urlToLoad = urlString
        
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        
        if let url = URL(string: urlToLoad) {
            currentURL = url
        }
    }
}