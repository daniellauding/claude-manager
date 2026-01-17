import Foundation

// MARK: - Shared Snippet Model (for Firebase)

struct SharedSnippet: Identifiable, Codable {
    var id: String = ""  // Firebase key (set after decoding)
    var title: String
    var content: String
    var category: String
    var tags: [String]
    var authorDeviceId: String
    var authorNickname: String?
    var createdAt: Date
    var updatedAt: Date
    var likes: Int
    var downloads: Int
    var reports: Int

    // Custom decoding to handle Firebase structure
    enum CodingKeys: String, CodingKey {
        case id, title, content, category, tags, authorDeviceId, authorNickname
        case createdAt, updatedAt, likes, downloads, reports
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
        self.title = try container.decode(String.self, forKey: .title)
        self.content = try container.decode(String.self, forKey: .content)
        self.category = try container.decode(String.self, forKey: .category)
        self.tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        self.authorDeviceId = try container.decode(String.self, forKey: .authorDeviceId)
        self.authorNickname = try? container.decode(String.self, forKey: .authorNickname)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.likes = (try? container.decode(Int.self, forKey: .likes)) ?? 0
        self.downloads = (try? container.decode(Int.self, forKey: .downloads)) ?? 0
        self.reports = (try? container.decode(Int.self, forKey: .reports)) ?? 0
    }

    // Computed
    var displayAuthor: String {
        authorNickname ?? "Anonymous"
    }

    var categoryEnum: SnippetCategory {
        SnippetCategory(rawValue: category) ?? .other
    }

    init(from snippet: Snippet, deviceId: String, nickname: String? = nil) {
        self.id = UUID().uuidString
        self.title = snippet.title
        self.content = snippet.content
        self.category = snippet.category.rawValue
        self.tags = snippet.tags
        self.authorDeviceId = deviceId
        self.authorNickname = nickname
        self.createdAt = Date()
        self.updatedAt = Date()
        self.likes = 0
        self.downloads = 0
        self.reports = 0
    }

    // Convert back to local Snippet
    func toLocalSnippet() -> Snippet {
        Snippet(
            title: title,
            content: content,
            category: categoryEnum,
            tags: tags + ["community"],
            project: "Community",
            sourceFile: nil,
            createdAt: createdAt
        )
    }
}

// MARK: - Firebase Response Wrapper

struct FirebaseSnippetsResponse: Codable {
    // Firebase returns { "key1": {...}, "key2": {...} }
    // We decode manually
}

// MARK: - Analytics Event

struct AnalyticsEvent: Codable {
    let deviceId: String
    let event: String
    let category: String?
    let timestamp: Date
    let metadata: [String: String]?

    init(event: String, category: String? = nil, metadata: [String: String]? = nil) {
        self.deviceId = DeviceIdentity.shared.deviceId
        self.event = event
        self.category = category
        self.timestamp = Date()
        self.metadata = metadata
    }
}

// MARK: - Event Types

enum AnalyticsEventType: String {
    case appLaunch = "app_launch"
    case snippetCreated = "snippet_created"
    case snippetShared = "snippet_shared"
    case snippetDownloaded = "snippet_downloaded"
    case snippetLiked = "snippet_liked"
    case categoryViewed = "category_viewed"
    case searchPerformed = "search_performed"
    case folderWatched = "folder_watched"
    // News and Discover
    case newsViewed = "news_viewed"
    case newsArticleOpened = "news_article_opened"
    case discoverItemViewed = "discover_item_viewed"
    case discoverItemSaved = "discover_item_saved"
    // Interactions
    case itemStarred = "item_starred"
    case itemUnstarred = "item_unstarred"
    case tabSwitched = "tab_switched"
}

// MARK: - User Profile (Anonymous)

struct UserProfile: Codable {
    let deviceId: String
    var nickname: String?
    var sharedCount: Int
    var downloadCount: Int
    var firstSeen: Date
    var lastSeen: Date
    var appVersion: String?

    init(deviceId: String) {
        self.deviceId = deviceId
        self.nickname = nil
        self.sharedCount = 0
        self.downloadCount = 0
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
