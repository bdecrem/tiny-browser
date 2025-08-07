import SwiftUI
import WebKit
import AuthenticationServices
import Foundation

// MARK: - Password Management

@MainActor
class PasswordManager: NSObject, ObservableObject {
    static let shared = PasswordManager()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Password AutoFill Support
    
    func requestPasswordSuggestions(for domain: String) async -> [ASPasswordCredential] {
        return await withCheckedContinuation { continuation in
            let passwordProvider = ASAuthorizationPasswordProvider()
            let request = passwordProvider.createRequest()
            
            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = PasswordAuthDelegate { credentials in
                continuation.resume(returning: credentials)
            }
            authController.presentationContextProvider = PasswordPresentationContextProvider()
            authController.performRequests()
        }
    }
    
    // MARK: - Save Password to Keychain
    
    func savePassword(username: String, password: String, domain: String) {
        SecAddSharedWebCredential(
            domain as CFString,
            username as CFString,
            password as CFString
        ) { error in
            if let error = error {
                print("Failed to save password: \(error)")
            } else {
                print("Password saved successfully for \(username)@\(domain)")
            }
        }
    }
    
    // MARK: - Request Saved Passwords
    
    func requestSavedPassword(for domain: String, completion: @escaping (String?, String?) -> Void) {
        // Use newer ASAuthorizationController approach
        let passwordProvider = ASAuthorizationPasswordProvider()
        let request = passwordProvider.createRequest()
        
        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = PasswordAuthDelegate { credentials in
            if let credential = credentials.first {
                completion(credential.user, credential.password)
            } else {
                completion(nil, nil)
            }
        }
        authController.presentationContextProvider = PasswordPresentationContextProvider()
        authController.performRequests()
    }
}

// MARK: - Authorization Delegate

private class PasswordAuthDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: ([ASPasswordCredential]) -> Void
    
    init(completion: @escaping ([ASPasswordCredential]) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let passwordCredential = authorization.credential as? ASPasswordCredential {
            completion([passwordCredential])
        } else {
            completion([])
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Password authorization failed: \(error)")
        completion([])
    }
}

// MARK: - Presentation Context Provider

private class PasswordPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return NSApp.windows.first ?? NSWindow()
    }
}

// MARK: - WebView Password Detection

extension WKWebView {
    func injectPasswordDetectionScript() {
        let script = """
        (function() {
            // Check if we've already injected
            if (window.tinyBrowserPasswordManager) return;
            window.tinyBrowserPasswordManager = true;
            
            // Detect login forms and notify immediately
            function detectLoginForm() {
                const forms = document.querySelectorAll('form');
                let foundLoginForm = false;
                
                forms.forEach(form => {
                    const inputs = form.querySelectorAll('input');
                    let usernameField = null;
                    let passwordField = null;
                    
                    inputs.forEach(input => {
                        // Find username/email fields
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
                        
                        // Find password fields
                        if (!passwordField && input.type === 'password') {
                            passwordField = input;
                        }
                    });
                    
                    // Handle EITHER password fields OR email-only forms (like Amazon step 1)
                    if (passwordField || usernameField) {
                        foundLoginForm = true;
                        
                        // Notify that we found a login form immediately
                        window.webkit.messageHandlers.passwordHandler.postMessage({
                            type: 'loginFormDetected',
                            domain: window.location.hostname,
                            hasPassword: !!passwordField,
                            hasEmail: !!usernameField
                        });
                        
                        // Add handlers to EMAIL/USERNAME field for autofill
                        if (usernameField) {
                            usernameField.addEventListener('click', function() {
                                window.webkit.messageHandlers.passwordHandler.postMessage({
                                    type: 'emailFieldClicked',
                                    domain: window.location.hostname
                                });
                            });
                            
                            usernameField.addEventListener('focus', function() {
                                window.webkit.messageHandlers.passwordHandler.postMessage({
                                    type: 'emailFieldFocused',
                                    domain: window.location.hostname
                                });
                            });
                        }
                        
                        // Add handlers to PASSWORD field if it exists
                        if (passwordField) {
                            // Add submit handler for saving
                            form.addEventListener('submit', function(e) {
                                let username = usernameField ? usernameField.value : '';
                                let password = passwordField.value;
                                
                                if (username && password) {
                                    window.webkit.messageHandlers.passwordHandler.postMessage({
                                        type: 'loginDetected',
                                        domain: window.location.hostname,
                                        username: username,
                                        password: password
                                    });
                                }
                            });
                            
                            passwordField.addEventListener('click', function() {
                                window.webkit.messageHandlers.passwordHandler.postMessage({
                                    type: 'passwordFieldClicked',
                                    domain: window.location.hostname
                                });
                            });
                            
                            passwordField.addEventListener('focus', function() {
                                window.webkit.messageHandlers.passwordHandler.postMessage({
                                    type: 'passwordFieldFocused',
                                    domain: window.location.hostname
                                });
                            });
                        }
                    }
                });
            }
            
            // Run detection when page loads and when DOM changes
            detectLoginForm();
            
            // Watch for dynamically added forms
            const observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                    if (mutation.addedNodes.length > 0) {
                        detectLoginForm();
                    }
                });
            });
            
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        })();
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)
    }
}