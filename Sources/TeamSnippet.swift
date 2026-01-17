import Foundation

// MARK: - Team Snippet Model (Privacy-Aware)

struct TeamSnippet: Identifiable, Codable, Hashable {
    var id: String  // Firebase key
    var title: String
    var content: String
    var category: String
    var tags: [String]

    // Ownership & Attribution
    var authorDeviceId: String
    var authorNickname: String?

    // Team & Project Context
    var teamId: String?  // nil = personal/public
    var projectId: String?
    var privacy: PrivacyLevel

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // Engagement Metrics
    var likes: Int
    var downloads: Int
    var views: Int
    var reports: Int

    // Collaboration
    var lastEditedBy: String?  // deviceId
    var editHistory: [EditRecord]?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        category: String = SnippetCategory.other.rawValue,
        tags: [String] = [],
        authorDeviceId: String = DeviceIdentity.shared.deviceId,
        authorNickname: String? = DeviceIdentity.shared.nickname,
        teamId: String? = nil,
        projectId: String? = nil,
        privacy: PrivacyLevel = .private,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        likes: Int = 0,
        downloads: Int = 0,
        views: Int = 0,
        reports: Int = 0,
        lastEditedBy: String? = nil,
        editHistory: [EditRecord]? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.tags = tags
        self.authorDeviceId = authorDeviceId
        self.authorNickname = authorNickname
        self.teamId = teamId
        self.projectId = projectId
        self.privacy = privacy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likes = likes
        self.downloads = downloads
        self.views = views
        self.reports = reports
        self.lastEditedBy = lastEditedBy
        self.editHistory = editHistory
    }

    // MARK: - Computed Properties

    var displayAuthor: String {
        authorNickname ?? "Anonymous"
    }

    var categoryEnum: SnippetCategory {
        SnippetCategory(rawValue: category) ?? .other
    }

    var isTeamSnippet: Bool {
        teamId != nil
    }

    var isPersonal: Bool {
        teamId == nil && privacy == .private
    }

    var isOwnedByCurrentUser: Bool {
        authorDeviceId == DeviceIdentity.shared.deviceId
    }

    var contentPreview: String {
        let lines = content.components(separatedBy: .newlines)
        let preview = lines.prefix(5).joined(separator: "\n")
        if lines.count > 5 {
            return preview + "\n..."
        }
        return preview
    }

    var engagementScore: Int {
        // Simple engagement score for sorting
        return likes * 3 + downloads * 2 + views
    }

    // MARK: - Permission Checks

    func canView(deviceId: String, team: Team?) -> Bool {
        switch privacy {
        case .public:
            return true
        case .team:
            guard let team = team else { return authorDeviceId == deviceId }
            return team.isMember(deviceId)
        case .private:
            return authorDeviceId == deviceId
        }
    }

    func canEdit(deviceId: String, team: Team?) -> Bool {
        // Author can always edit
        if authorDeviceId == deviceId { return true }

        // For team snippets, check team permissions
        if let team = team, let role = team.role(for: deviceId) {
            return role.canEditSnippets
        }

        return false
    }

    func canDelete(deviceId: String, team: Team?) -> Bool {
        // Author can always delete
        if authorDeviceId == deviceId { return true }

        // For team snippets, only admins/owners can delete others' snippets
        if let team = team, let role = team.role(for: deviceId) {
            return role.canDeleteSnippets
        }

        return false
    }

    // MARK: - Factory Methods

    static func fromLocalSnippet(_ snippet: Snippet, teamId: String? = nil, projectId: String? = nil, privacy: PrivacyLevel = .private) -> TeamSnippet {
        TeamSnippet(
            title: snippet.title,
            content: snippet.content,
            category: snippet.category.rawValue,
            tags: snippet.tags,
            teamId: teamId,
            projectId: projectId,
            privacy: privacy
        )
    }

    static func fromSharedSnippet(_ shared: SharedSnippet) -> TeamSnippet {
        TeamSnippet(
            id: shared.id,
            title: shared.title,
            content: shared.content,
            category: shared.category,
            tags: shared.tags,
            authorDeviceId: shared.authorDeviceId,
            authorNickname: shared.authorNickname,
            privacy: .public,
            createdAt: shared.createdAt,
            updatedAt: shared.updatedAt,
            likes: shared.likes,
            downloads: shared.downloads
        )
    }

    // Convert back to local Snippet
    func toLocalSnippet() -> Snippet {
        Snippet(
            title: title,
            content: content,
            category: categoryEnum,
            tags: tags + (isTeamSnippet ? ["team"] : []),
            project: projectId,
            sourceFile: nil,
            createdAt: createdAt
        )
    }

    // Convert to SharedSnippet for Firebase community sharing
    func toSharedSnippet() -> SharedSnippet {
        SharedSnippet(
            from: toLocalSnippet(),
            deviceId: authorDeviceId,
            nickname: authorNickname
        )
    }

    // MARK: - Mutation Methods

    mutating func recordEdit(by deviceId: String, nickname: String? = nil) {
        lastEditedBy = deviceId
        updatedAt = Date()

        let record = EditRecord(
            deviceId: deviceId,
            nickname: nickname,
            timestamp: Date()
        )

        if editHistory == nil {
            editHistory = [record]
        } else {
            editHistory?.append(record)
        }
    }
}

// MARK: - Edit Record

struct EditRecord: Codable, Hashable {
    let deviceId: String
    let nickname: String?
    let timestamp: Date

    var displayName: String {
        nickname ?? "Anonymous"
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Team Snippet Filter

enum TeamSnippetFilter: Equatable {
    case all
    case mine
    case teamOnly(String)  // teamId
    case projectOnly(String)  // projectId
    case privacy(PrivacyLevel)
    case category(SnippetCategory)

    var displayName: String {
        switch self {
        case .all: return "All"
        case .mine: return "Mine"
        case .teamOnly: return "Team"
        case .projectOnly: return "Project"
        case .privacy(let level): return level.displayName
        case .category(let cat): return cat.displayName
        }
    }
}

// MARK: - Team Snippet Sort

enum TeamSnippetSort: String, CaseIterable {
    case updated
    case created
    case title
    case engagement
    case downloads

    var displayName: String {
        switch self {
        case .updated: return "Recently Updated"
        case .created: return "Date Created"
        case .title: return "Title"
        case .engagement: return "Most Popular"
        case .downloads: return "Most Downloaded"
        }
    }
}

// MARK: - Batch Operations

struct SnippetBatchOperation: Codable {
    enum Operation: String, Codable {
        case move
        case copy
        case updatePrivacy
        case delete
        case addTags
        case removeTags
    }

    let operation: Operation
    let snippetIds: [String]
    let targetTeamId: String?
    let targetProjectId: String?
    let targetPrivacy: PrivacyLevel?
    let tags: [String]?
}
