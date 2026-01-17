import Foundation
import Combine
import AppKit

// MARK: - Models

struct NewsItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let link: String
    let pubDate: Date?
    let source: String
    var isStarred: Bool
    var isRead: Bool

    init(id: String = UUID().uuidString, title: String, description: String, link: String, pubDate: Date?, source: String, isStarred: Bool = false, isRead: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.link = link
        self.pubDate = pubDate
        self.source = source
        self.isStarred = isStarred
        self.isRead = isRead
    }

    var pubDateFormatted: String {
        guard let date = pubDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct NewsSource: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var feedURL: String
    var isEnabled: Bool
    var icon: String

    init(id: UUID = UUID(), name: String, feedURL: String, isEnabled: Bool = true, icon: String = "newspaper") {
        self.id = id
        self.name = name
        self.feedURL = feedURL
        self.isEnabled = isEnabled
        self.icon = icon
    }
}

struct NewsStorage: Codable {
    var sources: [NewsSource]
    var starredItems: [NewsItem]
    var readItemIds: Set<String>
}

// MARK: - Default Sources

extension NewsSource {
    static let defaults: [NewsSource] = [
        NewsSource(
            name: "Anthropic Blog",
            feedURL: "https://www.anthropic.com/feed.xml",
            icon: "sparkles"
        ),
        NewsSource(
            name: "OpenAI Blog",
            feedURL: "https://openai.com/blog/rss.xml",
            icon: "brain"
        ),
        NewsSource(
            name: "Hacker News - AI",
            feedURL: "https://hnrss.org/newest?q=AI+OR+Claude+OR+LLM",
            icon: "y.square"
        ),
        NewsSource(
            name: "The Verge - AI",
            feedURL: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml",
            icon: "v.square"
        ),
        NewsSource(
            name: "MIT Tech Review - AI",
            feedURL: "https://www.technologyreview.com/topic/artificial-intelligence/feed",
            icon: "graduationcap"
        ),
        NewsSource(
            name: "Ars Technica - AI",
            feedURL: "https://feeds.arstechnica.com/arstechnica/technology-lab",
            icon: "atom"
        ),
        NewsSource(
            name: "Simon Willison's Blog",
            feedURL: "https://simonwillison.net/atom/everything/",
            icon: "person.circle"
        ),
        NewsSource(
            name: "Hugging Face Blog",
            feedURL: "https://huggingface.co/blog/feed.xml",
            icon: "face.smiling"
        )
    ]
}

// MARK: - News Manager

class NewsManager: ObservableObject {
    @Published var sources: [NewsSource] = []
    @Published var items: [NewsItem] = []
    @Published var starredItems: [NewsItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: NewsFilter = .all

    private var readItemIds: Set<String> = []
    private let storageURL: URL
    private var refreshTask: Task<Void, Never>?

    // Firebase URL for default sources
    private var defaultSourcesURL: String { "\(FirebaseConfig.databaseURL)/default_news_sources.json" }

    init() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        try? FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        storageURL = claudeDir.appendingPathComponent("news.json")

        loadFromDisk()

        // Set defaults if no sources
        if sources.isEmpty {
            // Try to fetch from Firebase first, fall back to hardcoded defaults
            fetchDefaultSourcesFromFirebase { [weak self] firebaseSources in
                DispatchQueue.main.async {
                    if let firebaseSources = firebaseSources, !firebaseSources.isEmpty {
                        self?.sources = firebaseSources
                    } else {
                        self?.sources = NewsSource.defaults
                    }
                    self?.saveToDisk()
                }
            }
        }
    }

    // MARK: - Firebase Default Sources

    private func fetchDefaultSourcesFromFirebase(completion: @escaping ([NewsSource]?) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(nil)
            return
        }

        guard let url = URL(string: defaultSourcesURL) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            let sources = self.parseSourcesFromFirebase(data)
            completion(sources.isEmpty ? nil : sources)
        }.resume()
    }

    private func parseSourcesFromFirebase(_ data: Data) -> [NewsSource] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var sources: [NewsSource] = []
        let decoder = JSONDecoder()

        for (key, value) in json {
            guard let dict = value as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                continue
            }

            if let source = try? decoder.decode(NewsSource.self, from: jsonData) {
                // Reconstruct with the Firebase key as UUID if possible
                let newSource = NewsSource(
                    id: UUID(uuidString: key) ?? source.id,
                    name: source.name,
                    feedURL: source.feedURL,
                    isEnabled: source.isEnabled,
                    icon: source.icon
                )
                sources.append(newSource)
            }
        }

        return sources.sorted { $0.name < $1.name }
    }

    /// Refreshes default sources from Firebase (for admins to push updates)
    func refreshDefaultSourcesFromFirebase() {
        fetchDefaultSourcesFromFirebase { [weak self] firebaseSources in
            guard let self = self, let firebaseSources = firebaseSources else { return }

            DispatchQueue.main.async {
                // Merge: add new sources from Firebase that aren't already present
                let existingURLs = Set(self.sources.map { $0.feedURL })
                let newSources = firebaseSources.filter { !existingURLs.contains($0.feedURL) }

                if !newSources.isEmpty {
                    self.sources.append(contentsOf: newSources)
                    self.saveToDisk()
                }
            }
        }
    }

    // MARK: - Filtering

    var filteredItems: [NewsItem] {
        var result: [NewsItem]

        switch selectedFilter {
        case .all:
            result = items
        case .starred:
            result = starredItems
        case .unread:
            result = items.filter { !readItemIds.contains($0.id) }
        case .source(let sourceName):
            result = items.filter { $0.source == sourceName }
        }

        return result.sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
    }

    // MARK: - Feed Operations

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil

            var allItems: [NewsItem] = []

            for source in sources where source.isEnabled {
                do {
                    let feedItems = try await fetchFeed(source)
                    allItems.append(contentsOf: feedItems)
                } catch {
                    // Continue with other sources even if one fails
                    print("Failed to fetch \(source.name): \(error)")
                }
            }

            // Merge with existing starred status
            items = allItems.map { item in
                var mutableItem = item
                mutableItem.isStarred = starredItems.contains { $0.id == item.id || $0.link == item.link }
                mutableItem.isRead = readItemIds.contains(item.id)
                return mutableItem
            }

            isLoading = false
        }
    }

    private func fetchFeed(_ source: NewsSource) async throws -> [NewsItem] {
        guard let url = URL(string: source.feedURL) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return parseRSS(data: data, source: source.name)
    }

    private func parseRSS(data: Data, source: String) -> [NewsItem] {
        let parser = RSSParser(source: source)
        return parser.parse(data: data)
    }

    // MARK: - Item Actions

    func toggleStar(_ item: NewsItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isStarred.toggle()

            if items[index].isStarred {
                if !starredItems.contains(where: { $0.id == item.id }) {
                    starredItems.append(items[index])
                }
            } else {
                starredItems.removeAll { $0.id == item.id }
            }

            saveToDisk()
        }
    }

    func markAsRead(_ item: NewsItem) {
        readItemIds.insert(item.id)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isRead = true
        }
        saveToDisk()
    }

    func openInBrowser(_ item: NewsItem) {
        markAsRead(item)
        if let url = URL(string: item.link) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Source Management

    func addSource(_ source: NewsSource) {
        sources.append(source)
        saveToDisk()
        refresh()
    }

    func updateSource(_ source: NewsSource) {
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index] = source
            saveToDisk()
        }
    }

    func deleteSource(_ source: NewsSource) {
        sources.removeAll { $0.id == source.id }
        items.removeAll { $0.source == source.name }
        saveToDisk()
    }

    func toggleSourceEnabled(_ source: NewsSource) {
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index].isEnabled.toggle()
            saveToDisk()
            refresh()
        }
    }

    func resetToDefaults() {
        sources = NewsSource.defaults
        saveToDisk()
        refresh()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let storage = try? JSONDecoder().decode(NewsStorage.self, from: data) else {
            return
        }

        sources = storage.sources
        starredItems = storage.starredItems
        readItemIds = storage.readItemIds
    }

    private func saveToDisk() {
        let storage = NewsStorage(
            sources: sources,
            starredItems: starredItems,
            readItemIds: readItemIds
        )

        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

// MARK: - News Filter

enum NewsFilter: Equatable {
    case all
    case starred
    case unread
    case source(String)

    var displayName: String {
        switch self {
        case .all: return "All"
        case .starred: return "Starred"
        case .unread: return "Unread"
        case .source(let name): return name
        }
    }
}

// MARK: - RSS Parser

class RSSParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var isInItem = false
    private let source: String

    init(source: String) {
        self.source = source
    }

    func parse(data: Data) -> [NewsItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "item" || elementName == "entry" {
            isInItem = true
            currentTitle = ""
            currentDescription = ""
            currentLink = ""
            currentPubDate = ""
        }

        // Handle Atom link format
        if elementName == "link" && isInItem {
            if let href = attributeDict["href"] {
                currentLink = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInItem else { return }

        switch currentElement {
        case "title":
            currentTitle += string
        case "description", "summary", "content":
            currentDescription += string
        case "link":
            currentLink += string
        case "pubDate", "published", "updated":
            currentPubDate += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = cleanHTML(currentDescription.trimmingCharacters(in: .whitespacesAndNewlines))
            let link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            let pubDate = parseDate(currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines))

            if !title.isEmpty && !link.isEmpty {
                let item = NewsItem(
                    id: link, // Use link as unique ID
                    title: title,
                    description: String(description.prefix(300)),
                    link: link,
                    pubDate: pubDate,
                    source: source
                )
                items.append(item)
            }

            isInItem = false
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private func cleanHTML(_ string: String) -> String {
        // Remove HTML tags
        var result = string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }
}
