import Foundation

// MARK: - Team Invite (Magic Link Token)

struct TeamInvite: Identifiable, Codable {
    var id: String  // The token itself (Firebase key)
    var teamId: String
    var teamName: String  // Cached for display
    var createdBy: String  // deviceId of creator
    var creatorNickname: String?  // Cached for display
    var role: TeamRole  // Role to assign when accepted
    var createdAt: Date
    var expiresAt: Date
    var usageLimit: Int?  // nil = unlimited
    var usageCount: Int
    var isActive: Bool
    var acceptedBy: [String]  // deviceIds who accepted

    // MARK: - Initialization

    init(
        id: String = TeamInvite.generateToken(),
        teamId: String,
        teamName: String,
        createdBy: String = DeviceIdentity.shared.deviceId,
        creatorNickname: String? = DeviceIdentity.shared.nickname,
        role: TeamRole = .member,
        createdAt: Date = Date(),
        expiresAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        usageLimit: Int? = nil,
        usageCount: Int = 0,
        isActive: Bool = true,
        acceptedBy: [String] = []
    ) {
        self.id = id
        self.teamId = teamId
        self.teamName = teamName
        self.createdBy = createdBy
        self.creatorNickname = creatorNickname
        self.role = role
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.usageLimit = usageLimit
        self.usageCount = usageCount
        self.isActive = isActive
        self.acceptedBy = acceptedBy
    }

    // MARK: - Computed Properties

    var isExpired: Bool {
        Date() > expiresAt
    }

    var isValid: Bool {
        isActive && !isExpired && !isUsageLimitReached
    }

    var isUsageLimitReached: Bool {
        guard let limit = usageLimit else { return false }
        return usageCount >= limit
    }

    var remainingUses: Int? {
        guard let limit = usageLimit else { return nil }
        return max(0, limit - usageCount)
    }

    var expiresIn: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: expiresAt, relativeTo: Date())
    }

    var magicLink: URL? {
        // URL scheme: claudemanager://invite/{token}
        var components = URLComponents()
        components.scheme = "claudemanager"
        components.host = "invite"
        components.path = "/\(id)"
        return components.url
    }

    var webLink: String {
        // Web fallback for sharing: https://daniellauding.github.io/claude-manager/invite?token={token}
        "https://daniellauding.github.io/claude-manager/invite?token=\(id)"
    }

    var shareText: String {
        """
        Join "\(teamName)" on Claude Manager!

        Click this link to join:
        \(webLink)

        Or paste this code in the app:
        \(id)

        Expires \(expiresIn).
        """
    }

    // MARK: - Factory Methods

    static func create(
        for team: Team,
        role: TeamRole = .member,
        expiresIn days: Int = 7,
        usageLimit: Int? = nil
    ) -> TeamInvite {
        TeamInvite(
            teamId: team.id,
            teamName: team.name,
            role: role,
            expiresAt: Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date(),
            usageLimit: usageLimit
        )
    }

    // MARK: - Token Generation

    static func generateToken() -> String {
        // Generate a URL-safe random token
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let tokenLength = 12
        return String((0..<tokenLength).map { _ in characters.randomElement()! })
    }

    // MARK: - Mutation Methods

    mutating func markUsed(by deviceId: String) {
        usageCount += 1
        acceptedBy.append(deviceId)
    }

    mutating func revoke() {
        isActive = false
    }
}

// MARK: - Invite Expiration Presets

enum InviteExpiration: CaseIterable {
    case oneHour
    case oneDay
    case oneWeek
    case oneMonth
    case never

    var displayName: String {
        switch self {
        case .oneHour: return "1 hour"
        case .oneDay: return "24 hours"
        case .oneWeek: return "7 days"
        case .oneMonth: return "30 days"
        case .never: return "Never"
        }
    }

    var expirationDate: Date {
        let calendar = Calendar.current
        switch self {
        case .oneHour:
            return calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        case .oneDay:
            return calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        case .oneWeek:
            return calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        case .oneMonth:
            return calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        case .never:
            return calendar.date(byAdding: .year, value: 100, to: Date()) ?? Date()
        }
    }
}

// MARK: - Usage Limit Presets

enum InviteUsageLimit: CaseIterable {
    case one
    case five
    case ten
    case twentyFive
    case unlimited

    var displayName: String {
        switch self {
        case .one: return "1 use"
        case .five: return "5 uses"
        case .ten: return "10 uses"
        case .twentyFive: return "25 uses"
        case .unlimited: return "Unlimited"
        }
    }

    var value: Int? {
        switch self {
        case .one: return 1
        case .five: return 5
        case .ten: return 10
        case .twentyFive: return 25
        case .unlimited: return nil
        }
    }
}

// MARK: - Invite Acceptance Result

enum InviteAcceptanceResult {
    case success(Team, TeamRole)
    case alreadyMember
    case expired
    case usageLimitReached
    case revoked
    case teamNotFound
    case error(Error)

    var message: String {
        switch self {
        case .success(let team, let role):
            return "You've joined \"\(team.name)\" as a \(role.displayName)!"
        case .alreadyMember:
            return "You're already a member of this team."
        case .expired:
            return "This invite link has expired."
        case .usageLimitReached:
            return "This invite has reached its usage limit."
        case .revoked:
            return "This invite has been revoked."
        case .teamNotFound:
            return "The team for this invite no longer exists."
        case .error(let error):
            return "Failed to join team: \(error.localizedDescription)"
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
