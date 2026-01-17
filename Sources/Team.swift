import Foundation

// MARK: - Team Role

enum TeamRole: String, Codable, CaseIterable {
    case owner
    case admin
    case member
    case viewer

    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }

    var icon: String {
        switch self {
        case .owner: return "crown"
        case .admin: return "shield"
        case .member: return "person"
        case .viewer: return "eye"
        }
    }

    var canManageMembers: Bool {
        self == .owner || self == .admin
    }

    var canCreateProjects: Bool {
        self == .owner || self == .admin || self == .member
    }

    var canEditSnippets: Bool {
        self == .owner || self == .admin || self == .member
    }

    var canDeleteSnippets: Bool {
        self == .owner || self == .admin
    }

    var canInviteMembers: Bool {
        self == .owner || self == .admin
    }
}

// MARK: - Team Member

struct TeamMember: Identifiable, Codable, Hashable {
    let id: String  // deviceId
    var nickname: String?
    var role: TeamRole
    var joinedAt: Date
    var lastActiveAt: Date?
    var invitedBy: String?  // deviceId of inviter

    var displayName: String {
        nickname ?? "Anonymous"
    }

    init(
        id: String,
        nickname: String? = nil,
        role: TeamRole = .member,
        joinedAt: Date = Date(),
        lastActiveAt: Date? = nil,
        invitedBy: String? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.role = role
        self.joinedAt = joinedAt
        self.lastActiveAt = lastActiveAt
        self.invitedBy = invitedBy
    }

    // Create owner member from current device
    static func createOwner() -> TeamMember {
        TeamMember(
            id: DeviceIdentity.shared.deviceId,
            nickname: DeviceIdentity.shared.nickname,
            role: .owner,
            joinedAt: Date()
        )
    }
}

// MARK: - Team

struct Team: Identifiable, Codable, Hashable {
    var id: String  // Firebase key
    var name: String
    var description: String?
    var icon: String  // SF Symbol name
    var color: String  // Hex color code
    var members: [String: TeamMember]  // deviceId -> member
    var projectIds: [String]  // Associated project IDs
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String  // deviceId of creator
    var isPublic: Bool  // Allow discovery in community
    var settings: TeamSettings

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        icon: String = "person.3",
        color: String = "#007AFF",
        members: [String: TeamMember] = [:],
        projectIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String = DeviceIdentity.shared.deviceId,
        isPublic: Bool = false,
        settings: TeamSettings = TeamSettings()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.members = members
        self.projectIds = projectIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.isPublic = isPublic
        self.settings = settings
    }

    // MARK: - Computed Properties

    var memberCount: Int {
        members.count
    }

    var membersList: [TeamMember] {
        Array(members.values).sorted { $0.role.rawValue < $1.role.rawValue }
    }

    var owner: TeamMember? {
        members.values.first { $0.role == .owner }
    }

    var admins: [TeamMember] {
        members.values.filter { $0.role == .admin }
    }

    // MARK: - Permission Checks

    func role(for deviceId: String) -> TeamRole? {
        members[deviceId]?.role
    }

    func isMember(_ deviceId: String) -> Bool {
        members[deviceId] != nil
    }

    func canManage(_ deviceId: String) -> Bool {
        guard let role = role(for: deviceId) else { return false }
        return role.canManageMembers
    }

    func canInvite(_ deviceId: String) -> Bool {
        guard let role = role(for: deviceId) else { return false }
        return role.canInviteMembers
    }

    // MARK: - Factory Methods

    static func create(name: String, description: String? = nil) -> Team {
        var team = Team(name: name, description: description)
        let ownerMember = TeamMember.createOwner()
        team.members[ownerMember.id] = ownerMember
        return team
    }
}

// MARK: - Team Settings

struct TeamSettings: Codable, Hashable {
    var allowMemberInvites: Bool  // Can members (not just admins) invite?
    var requireApproval: Bool  // Require admin approval for new members?
    var defaultMemberRole: TeamRole  // Default role for new members
    var snippetVisibilityDefault: PrivacyLevel  // Default privacy for team snippets

    init(
        allowMemberInvites: Bool = false,
        requireApproval: Bool = false,
        defaultMemberRole: TeamRole = .member,
        snippetVisibilityDefault: PrivacyLevel = .team
    ) {
        self.allowMemberInvites = allowMemberInvites
        self.requireApproval = requireApproval
        self.defaultMemberRole = defaultMemberRole
        self.snippetVisibilityDefault = snippetVisibilityDefault
    }
}

// MARK: - Privacy Level

enum PrivacyLevel: String, Codable, CaseIterable {
    case `private`  // Only creator can see
    case team       // Team members can see
    case `public`   // Everyone can see

    var displayName: String {
        switch self {
        case .private: return "Private"
        case .team: return "Team"
        case .public: return "Public"
        }
    }

    var icon: String {
        switch self {
        case .private: return "lock"
        case .team: return "person.2"
        case .public: return "globe"
        }
    }

    var description: String {
        switch self {
        case .private: return "Only you can see this"
        case .team: return "Visible to team members"
        case .public: return "Visible to everyone"
        }
    }
}

// MARK: - User Team Membership (Index)

struct UserTeamMembership: Codable {
    var teamIds: [String]  // Teams the user belongs to
    var pendingInvites: [String]  // Invite tokens waiting to be accepted
    var lastUpdated: Date

    init(teamIds: [String] = [], pendingInvites: [String] = [], lastUpdated: Date = Date()) {
        self.teamIds = teamIds
        self.pendingInvites = pendingInvites
        self.lastUpdated = lastUpdated
    }
}
