import Foundation

// MARK: - Snippet Model

struct Snippet: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var category: SnippetCategory
    var tags: [String]
    var project: String?
    var isFavorite: Bool
    var sourceFile: String?  // Path if synced from folder
    var createdAt: Date
    var lastUsedAt: Date?
    var useCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: SnippetCategory = .other,
        tags: [String] = [],
        project: String? = nil,
        isFavorite: Bool = false,
        sourceFile: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        useCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.tags = tags
        self.project = project
        self.isFavorite = isFavorite
        self.sourceFile = sourceFile
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }

    // MARK: - Computed Properties

    var tagsDisplay: String {
        tags.joined(separator: " · ")
    }

    var lastUsedFormatted: String? {
        guard let lastUsed = lastUsedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastUsed, relativeTo: Date())
    }

    var contentPreview: String {
        let lines = content.components(separatedBy: .newlines)
        let preview = lines.prefix(5).joined(separator: "\n")
        if lines.count > 5 {
            return preview + "\n..."
        }
        return preview
    }

    var isSynced: Bool {
        sourceFile != nil
    }

    // MARK: - Mutation Methods

    mutating func markUsed() {
        lastUsedAt = Date()
        useCount += 1
    }

    mutating func toggleFavorite() {
        isFavorite.toggle()
    }
}

// MARK: - Snippet Category

enum SnippetCategory: String, Codable, CaseIterable, Identifiable {
    case agent
    case skill
    case prompt
    case template
    case instruction
    case mcp
    case hook
    case workflow
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .agent: return "Agent"
        case .skill: return "Skill"
        case .prompt: return "Prompt"
        case .template: return "Template"
        case .instruction: return "Instruction"
        case .mcp: return "MCP"
        case .hook: return "Hook"
        case .workflow: return "Workflow"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .agent: return "person.circle"
        case .skill: return "star.circle"
        case .prompt: return "text.bubble"
        case .template: return "doc.text"
        case .instruction: return "list.bullet.rectangle"
        case .mcp: return "cable.connector"
        case .hook: return "arrow.triangle.2.circlepath"
        case .workflow: return "flowchart"
        case .other: return "folder"
        }
    }

    // Infer category from file content
    static func infer(from content: String, filename: String) -> SnippetCategory {
        let lowercased = content.lowercased() + filename.lowercased()

        if lowercased.contains("hook") || lowercased.contains("pretooluse") || lowercased.contains("posttooluse") || lowercased.contains("sessionstart") || lowercased.contains("sessionend") {
            return .hook
        } else if lowercased.contains("workflow") || lowercased.contains("step 1") && lowercased.contains("step 2") || lowercased.contains("## steps") {
            return .workflow
        } else if lowercased.contains("mcp") || lowercased.contains("model context protocol") {
            return .mcp
        } else if lowercased.contains("agent") {
            return .agent
        } else if lowercased.contains("skill") {
            return .skill
        } else if lowercased.contains("prompt") || lowercased.contains("sample prompt") {
            return .prompt
        } else if lowercased.contains("template") || lowercased.contains("output format") {
            return .template
        } else if lowercased.contains("instruction") || lowercased.contains("## instructions") {
            return .instruction
        }
        return .other
    }
}

// MARK: - Snippet Storage

struct SnippetStorage: Codable {
    var snippets: [Snippet]
    var watchedFolders: [String]
    var recentProjects: [String]

    init(snippets: [Snippet] = [], watchedFolders: [String] = [], recentProjects: [String] = []) {
        self.snippets = snippets
        self.watchedFolders = watchedFolders
        self.recentProjects = recentProjects
    }
}

// MARK: - Filter Options

enum SnippetFilter: Equatable {
    case all
    case favorites
    case recent
    case category(SnippetCategory)
    case tag(String)
    case project(String)

    var displayName: String {
        switch self {
        case .all: return "All"
        case .favorites: return "Favorites"
        case .recent: return "Recent"
        case .category(let cat): return cat.displayName
        case .tag(let tag): return "#\(tag)"
        case .project(let proj): return proj
        }
    }
}

enum SnippetSort: String, CaseIterable {
    case title
    case recent
    case mostUsed
    case created

    var displayName: String {
        switch self {
        case .title: return "Title"
        case .recent: return "Recently Used"
        case .mostUsed: return "Most Used"
        case .created: return "Date Created"
        }
    }
}
