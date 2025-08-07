import Foundation
import UniformTypeIdentifiers

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
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TinyBrowser", isDirectory: true)
        
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
    
    func deleteAllBookmarks() {
        // Clear all bookmarks and folders
        bookmarksRoot.bookmarkBar.children.removeAll()
        bookmarksRoot.otherBookmarks.children.removeAll()
        
        // Reset to default bookmarks
        addDefaultBookmarks()
        
        // Save the changes
        save()
        
        print("All bookmarks deleted and reset to defaults")
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
            // Check for bookmark (handle both <A HREF= and <A href=)
            else if (trimmed.contains("<A HREF=") || trimmed.contains("<A href=")) && trimmed.contains("</A>") {
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
        // Handle both HREF=" and href=" (case insensitive)
        let hrefPatterns = ["HREF=\"", "href=\""]
        
        for pattern in hrefPatterns {
            if let hrefRange = line.range(of: pattern) {
                let afterHref = String(line[hrefRange.upperBound...])
                if let endQuoteIndex = afterHref.firstIndex(of: "\"") {
                    let url = String(afterHref[..<endQuoteIndex])
                    // Basic URL validation - must contain a protocol or be relative
                    if !url.isEmpty && (url.contains("://") || url.hasPrefix("/") || url.hasPrefix("./")) {
                        return url
                    }
                }
            }
        }
        return nil
    }
    
    private func extractText(from line: String, tag: String) -> String? {
        let closeTag = "</\(tag)>"
        
        // For tags with attributes (like <A HREF="...">), find the opening bracket and closing >
        if let openBracketRange = line.range(of: "<\(tag)"),
           let closingBracketRange = line.range(of: ">", range: openBracketRange.upperBound..<line.endIndex),
           let endTagRange = line.range(of: closeTag, range: closingBracketRange.upperBound..<line.endIndex) {
            
            let textRange = closingBracketRange.upperBound..<endTagRange.lowerBound
            return String(line[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
}