import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers
import AuthenticationServices

// MARK: - Password Fill Delegate

private class PasswordFillDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (ASPasswordCredential?) -> Void
    
    init(completion: @escaping (ASPasswordCredential?) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let passwordCredential = authorization.credential as? ASPasswordCredential {
            completion(passwordCredential)
        } else {
            completion(nil)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Password autofill error: \(error)")
        completion(nil)
    }
}

// MARK: - Presentation Context Provider (moved to WebView file for better access)

private class PasswordPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return NSApp.windows.first ?? NSWindow()
    }
}

struct WebView: NSViewRepresentable {
    @ObservedObject var tab: BrowserTab
    
    func makeNSView(context: Context) -> WKWebView {
        tab.webView.navigationDelegate = context.coordinator
        
        // Add password management message handler
        tab.webView.configuration.userContentController.add(context.coordinator, name: "passwordHandler")
        
        // Inject password detection script
        tab.webView.injectPasswordDetectionScript()
        
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
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let tab: BrowserTab
        private let passwordManager = PasswordManager.shared
        
        init(tab: BrowserTab) {
            self.tab = tab
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("DEBUG: Started loading: \(webView.url?.absoluteString ?? "unknown")")
            tab.isLoading = true
            tab.hasPasswordsAvailable = false // Reset password indicator
            // Update navigation state
            tab.canGoBack = webView.canGoBack
            tab.canGoForward = webView.canGoForward
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
            // Update navigation state
            tab.canGoBack = webView.canGoBack
            tab.canGoForward = webView.canGoForward
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("DEBUG: Failed to load with error: \(error.localizedDescription)")
            tab.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("DEBUG: Failed provisional navigation with error: \(error.localizedDescription)")
            tab.isLoading = false
        }
        
        // MARK: - Password Management
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "passwordHandler",
                  let messageBody = message.body as? [String: Any],
                  let type = messageBody["type"] as? String else {
                return
            }
            
            switch type {
            case "loginDetected":
                handleLoginDetected(messageBody)
            case "passwordFieldFocused", "passwordFieldClicked":
                handlePasswordFieldFocused(messageBody)
            case "emailFieldFocused", "emailFieldClicked":
                handleEmailFieldFocused(messageBody)
            case "loginFormDetected":
                handleLoginFormDetected(messageBody)
            default:
                break
            }
        }
        
        private func handleLoginDetected(_ messageBody: [String: Any]) {
            guard let domain = messageBody["domain"] as? String,
                  let username = messageBody["username"] as? String,
                  let password = messageBody["password"] as? String else {
                return
            }
            
            print("Login detected for \(username)@\(domain)")
            
            // Show password save prompt
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Save Password?"
                alert.informativeText = "Would you like to save the password for \(username) on \(domain)?"
                alert.addButton(withTitle: "Save")
                alert.addButton(withTitle: "Not Now")
                alert.alertStyle = .informational
                
                if let window = NSApp.windows.first {
                    alert.beginSheetModal(for: window) { response in
                        if response == .alertFirstButtonReturn {
                            self.passwordManager.savePassword(username: username, password: password, domain: domain)
                        }
                    }
                }
            }
        }
        
        private func handleLoginFormDetected(_ messageBody: [String: Any]) {
            guard let domain = messageBody["domain"] as? String else { return }
            
            print("Login form detected on \(domain)")
            
            // Check if we have saved passwords for this domain
            // We'll store this state to show a visual indicator
            DispatchQueue.main.async {
                self.tab.hasPasswordsAvailable = true
            }
        }
        
        private func handleEmailFieldFocused(_ messageBody: [String: Any]) {
            guard let domain = messageBody["domain"] as? String else { return }
            
            print("Email field focused on \(domain)")
            
            // Try to use system password autofill for email too!
            trySystemPasswordAutofill(for: domain)
        }
        
        private func handlePasswordFieldFocused(_ messageBody: [String: Any]) {
            guard let domain = messageBody["domain"] as? String else { return }
            
            print("Password field focused on \(domain)")
            
            // Try to use system password autofill first
            trySystemPasswordAutofill(for: domain)
        }
        
        private func trySystemPasswordAutofill(for domain: String) {
            // Use ASAuthorizationController for proper system integration
            DispatchQueue.main.async {
                let passwordProvider = ASAuthorizationPasswordProvider()
                let request = passwordProvider.createRequest()
                
                let authController = ASAuthorizationController(authorizationRequests: [request])
                
                // Create a strong reference to the delegate
                let delegate = PasswordFillDelegate { [weak self] credential in
                    if let credential = credential {
                        self?.fillPassword(username: credential.user, password: credential.password)
                    }
                }
                
                // Store delegate to keep it alive
                objc_setAssociatedObject(authController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
                authController.delegate = delegate
                
                let contextProvider = PasswordPresentationContextProvider()
                objc_setAssociatedObject(authController, "contextProvider", contextProvider, .OBJC_ASSOCIATION_RETAIN)
                authController.presentationContextProvider = contextProvider
                
                authController.performRequests()
            }
        }
        
        private func fillPassword(username: String, password: String) {
            let script = """
            (function() {
                const forms = document.querySelectorAll('form');
                forms.forEach(form => {
                    const inputs = form.querySelectorAll('input');
                    let usernameField = null;
                    let passwordField = null;
                    
                    inputs.forEach(input => {
                        // Find email/username fields
                        if (!usernameField && (
                            input.type === 'email' || 
                            (input.type === 'text' && (
                                input.name?.toLowerCase().includes('user') ||
                                input.name?.toLowerCase().includes('email') ||
                                input.name?.toLowerCase().includes('login') ||
                                input.id?.toLowerCase().includes('user') ||
                                input.id?.toLowerCase().includes('email') ||
                                input.id?.toLowerCase().includes('login') ||
                                input.placeholder?.toLowerCase().includes('email') ||
                                input.placeholder?.toLowerCase().includes('username') ||
                                input.autocomplete?.includes('username') ||
                                input.autocomplete?.includes('email'))))) {
                            usernameField = input;
                        }
                        
                        if (input.type === 'password' && !passwordField) {
                            passwordField = input;
                        }
                    });
                    
                    // Fill whatever fields are available
                    if (usernameField) {
                        usernameField.value = '\(username)';
                        usernameField.dispatchEvent(new Event('input', { bubbles: true }));
                        usernameField.dispatchEvent(new Event('change', { bubbles: true }));
                        
                        // For Amazon-style forms, try to auto-submit if there's only email field
                        if (!passwordField) {
                            const submitButton = form.querySelector('input[type="submit"], button[type="submit"], button:not([type])');
                            if (submitButton && submitButton.textContent?.includes('Continue')) {
                                console.log('Auto-clicking Continue button after filling email');
                                // Don't auto-submit, just focus the button so user can press Enter
                                submitButton.focus();
                            }
                        }
                    }
                    
                    if (passwordField) {
                        passwordField.value = '\(password)';
                        passwordField.dispatchEvent(new Event('input', { bubbles: true }));
                        passwordField.dispatchEvent(new Event('change', { bubbles: true }));
                    }
                });
            })();
            """
            
            tab.webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("Failed to fill credentials: \(error)")
                } else {
                    print("Credentials filled successfully")
                }
            }
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
            
            Section("Password Management") {
                Text("TinyBrowser integrates with macOS Passwords for secure autofill and password saving.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Passwords are stored securely in your macOS keychain and shared across your devices.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .frame(width: 450, height: 450)
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