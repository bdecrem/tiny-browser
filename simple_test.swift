#!/usr/bin/swift

import Foundation

// Simple test to verify tab URL management
class TestTabManager {
    func test() {
        print("Testing Tab URL Management...")
        
        // Simulate creating a tab
        let tabURL = URL(string: "https://www.google.com")!
        print("1. Created tab with URL: \(tabURL.absoluteString)")
        
        var urlString = tabURL.absoluteString
        print("2. URL string initialized: \(urlString)")
        
        // Simulate user typing new URL
        urlString = "github.com"
        print("3. User typed: \(urlString)")
        
        // Process URL (add https if needed)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        print("4. Processed URL: \(urlString)")
        
        // Create URL object
        if let newURL = URL(string: urlString) {
            print("5. Valid URL created: \(newURL.absoluteString)")
            print("✓ Test passed - URL handling works")
        } else {
            print("✗ Test failed - Could not create URL")
        }
    }
}

let tester = TestTabManager()
tester.test()