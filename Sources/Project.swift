import Foundation

// MARK: - Project Model

struct Project: Identifiable, Codable, Hashable {
    var id: String  // Firebase key
    var name: String
    var description: String?
    var icon: String  // SF Symbol name
    var color: String  // Hex color code
    var teamId: String?  // nil = personal project
    var ownerId: String  // deviceId of creator
    var snippetIds: [String]  // Snippet IDs in this project
    var privacy: PrivacyLevel
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var tags: [String]
    var settings: ProjectSettings

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        icon: String = "folder",
        color: String = "#007AFF",
        teamId: String? = nil,
        ownerId: String = DeviceIdentity.shared.deviceId,
        snippetIds: [String] = [],
        privacy: PrivacyLevel = .private,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        tags: [String] = [],
        settings: ProjectSettings = ProjectSettings()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.teamId = teamId
        self.ownerId = ownerId
        self.snippetIds = snippetIds
        self.privacy = privacy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.tags = tags
        self.settings = settings
    }

    // MARK: - Computed Properties

    var snippetCount: Int {
        snippetIds.count
    }

    var isPersonal: Bool {
        teamId == nil
    }

    var isTeamProject: Bool {
        teamId != nil
    }

    var isOwnedByCurrentUser: Bool {
        ownerId == DeviceIdentity.shared.deviceId
    }

    var tagsDisplay: String {
        tags.joined(separator: " · ")
    }

    // MARK: - Permission Checks

    func canEdit(deviceId: String, team: Team?) -> Bool {
        // Owner can always edit
        if ownerId == deviceId { return true }

        // For team projects, check team permissions
        if let team = team, let role = team.role(for: deviceId) {
            return role.canEditSnippets
        }

        return false
    }

    func canDelete(deviceId: String, team: Team?) -> Bool {
        // Owner can always delete
        if ownerId == deviceId { return true }

        // For team projects, only admins/owners can delete
        if let team = team, let role = team.role(for: deviceId) {
            return role.canDeleteSnippets
        }

        return false
    }

    func canView(deviceId: String, team: Team?) -> Bool {
        switch privacy {
        case .public:
            return true
        case .team:
            guard let team = team else { return ownerId == deviceId }
            return team.isMember(deviceId)
        case .private:
            return ownerId == deviceId
        }
    }

    // MARK: - Factory Methods

    static func createPersonal(name: String, description: String? = nil) -> Project {
        Project(name: name, description: description, privacy: .private)
    }

    static func createTeam(name: String, teamId: String, description: String? = nil) -> Project {
        Project(name: name, description: description, teamId: teamId, privacy: .team)
    }
}

// MARK: - Project Settings

struct ProjectSettings: Codable, Hashable {
    var defaultSnippetCategory: SnippetCategory
    var defaultSnippetPrivacy: PrivacyLevel
    var autoTagNewSnippets: Bool
    var customTags: [String]

    init(
        defaultSnippetCategory: SnippetCategory = .other,
        defaultSnippetPrivacy: PrivacyLevel = .team,
        autoTagNewSnippets: Bool = true,
        customTags: [String] = []
    ) {
        self.defaultSnippetCategory = defaultSnippetCategory
        self.defaultSnippetPrivacy = defaultSnippetPrivacy
        self.autoTagNewSnippets = autoTagNewSnippets
        self.customTags = customTags
    }
}

// MARK: - Project Filter

enum ProjectFilter: Equatable {
    case all
    case personal
    case team(String)  // teamId
    case archived

    var displayName: String {
        switch self {
        case .all: return "All Projects"
        case .personal: return "Personal"
        case .team: return "Team"
        case .archived: return "Archived"
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.2"
        case .personal: return "person"
        case .team: return "person.3"
        case .archived: return "archivebox"
        }
    }
}

// MARK: - Project Sort

enum ProjectSort: String, CaseIterable {
    case name
    case updated
    case created
    case snippetCount

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .updated: return "Last Updated"
        case .created: return "Date Created"
        case .snippetCount: return "Snippet Count"
        }
    }
}

// MARK: - Project Icon Presets

enum ProjectIcon: String, CaseIterable {
    case folder = "folder"
    case folderFill = "folder.fill"
    case doc = "doc"
    case book = "book"
    case tray = "tray"
    case archivebox = "archivebox"
    case star = "star"
    case bookmark = "bookmark"
    case tag = "tag"
    case flame = "flame"
    case bolt = "bolt"
    case gearshape = "gearshape"
    case wrench = "wrench"
    case hammer = "hammer"
    case terminal = "terminal"
    case network = "network"
    case globe = "globe"
    case cloud = "cloud"
    case server = "server.rack"
    case cpu = "cpu"

    var icon: String { rawValue }
}

// MARK: - Project Color Presets

enum ProjectColor: String, CaseIterable {
    case blue = "#007AFF"
    case purple = "#AF52DE"
    case pink = "#FF2D55"
    case red = "#FF3B30"
    case orange = "#FF9500"
    case yellow = "#FFCC00"
    case green = "#34C759"
    case teal = "#5AC8FA"
    case indigo = "#5856D6"
    case gray = "#8E8E93"

    var hex: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        case .gray: return "Gray"
        }
    }
}
