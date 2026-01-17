import Foundation
import Combine

// MARK: - Team Manager

class TeamManager: ObservableObject {
    static let shared = TeamManager()

    // Published State
    @Published var teams: [Team] = []
    @Published var projects: [Project] = []
    @Published var teamSnippets: [TeamSnippet] = []
    @Published var pendingInvites: [TeamInvite] = []
    @Published var currentTeam: Team?
    @Published var currentProject: Project?

    @Published var isLoading = false
    @Published var error: String?

    // Private
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cancellables = Set<AnyCancellable>()
    private let deviceId = DeviceIdentity.shared.deviceId

    // MARK: - Firebase URLs

    private var teamsURL: String { "\(FirebaseConfig.databaseURL)/teams.json" }
    private var projectsURL: String { "\(FirebaseConfig.databaseURL)/projects.json" }
    private var teamSnippetsURL: String { "\(FirebaseConfig.databaseURL)/team_snippets.json" }
    private var invitesURL: String { "\(FirebaseConfig.databaseURL)/team_invites.json" }
    private var userTeamsURL: String { "\(FirebaseConfig.databaseURL)/user_teams/\(deviceId).json" }

    private func teamURL(_ teamId: String) -> String {
        "\(FirebaseConfig.databaseURL)/teams/\(teamId).json"
    }

    private func projectURL(_ projectId: String) -> String {
        "\(FirebaseConfig.databaseURL)/projects/\(projectId).json"
    }

    private func teamSnippetURL(_ snippetId: String) -> String {
        "\(FirebaseConfig.databaseURL)/team_snippets/\(snippetId).json"
    }

    private func inviteURL(_ token: String) -> String {
        "\(FirebaseConfig.databaseURL)/team_invites/\(token).json"
    }

    // MARK: - Initialization

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        if FirebaseConfig.isConfigured {
            fetchMyTeams()
            fetchMyProjects()
        }
    }

    // MARK: - Team Operations

    func createTeam(name: String, description: String? = nil, isPublic: Bool = false, completion: @escaping (Result<Team, Error>) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.failure(FirebaseError.notConfigured))
            return
        }

        var team = Team.create(name: name, description: description)
        team.isPublic = isPublic

        guard let url = URL(string: teamURL(team.id)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(team) else {
            completion(.failure(FirebaseError.encodingFailed))
            return
        }
        request.httpBody = body

        isLoading = true

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Update user's team index
                self?.addTeamToUserIndex(team.id)

                // Add to local state
                self?.teams.append(team)

                // Track analytics
                FirebaseManager.shared.trackEvent(.teamCreated, metadata: ["teamId": team.id])

                completion(.success(team))
            }
        }.resume()
    }

    func updateTeam(_ team: Team, completion: @escaping (Result<Team, Error>) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.failure(FirebaseError.notConfigured))
            return
        }

        var updatedTeam = team
        updatedTeam.updatedAt = Date()

        guard let url = URL(string: teamURL(team.id)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(updatedTeam) else {
            completion(.failure(FirebaseError.encodingFailed))
            return
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Update local state
                if let index = self?.teams.firstIndex(where: { $0.id == team.id }) {
                    self?.teams[index] = updatedTeam
                }

                completion(.success(updatedTeam))
            }
        }.resume()
    }

    func deleteTeam(_ teamId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.failure(FirebaseError.notConfigured))
            return
        }

        guard let url = URL(string: teamURL(teamId)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Remove from user index
                self?.removeTeamFromUserIndex(teamId)

                // Remove from local state
                self?.teams.removeAll { $0.id == teamId }

                // Also delete associated projects and snippets
                self?.deleteTeamProjects(teamId)
                self?.deleteTeamSnippets(teamId)

                completion(.success(()))
            }
        }.resume()
    }

    func fetchMyTeams() {
        guard FirebaseConfig.isConfigured else { return }

        isLoading = true

        // First fetch user's team index
        guard let url = URL(string: userTeamsURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data,
                  let membership = try? self?.decoder.decode(UserTeamMembership.self, from: data) else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                return
            }

            // Fetch each team
            let group = DispatchGroup()
            var fetchedTeams: [Team] = []

            for teamId in membership.teamIds {
                group.enter()
                self?.fetchTeam(teamId) { result in
                    if case .success(let team) = result {
                        fetchedTeams.append(team)
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self?.teams = fetchedTeams.sorted { $0.name < $1.name }
                self?.isLoading = false
            }
        }.resume()
    }

    func fetchTeam(_ teamId: String, completion: @escaping (Result<Team, Error>) -> Void) {
        guard let url = URL(string: teamURL(teamId)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let team = try? self?.decoder.decode(Team.self, from: data) else {
                completion(.failure(FirebaseError.invalidResponse))
                return
            }

            completion(.success(team))
        }.resume()
    }

    // MARK: - Member Operations

    func addMember(_ deviceId: String, to teamId: String, role: TeamRole = .member, nickname: String? = nil, completion: @escaping (Result<TeamMember, Error>) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.failure(FirebaseError.notConfigured))
            return
        }

        fetchTeam(teamId) { [weak self] result in
            switch result {
            case .success(var team):
                let member = TeamMember(
                    id: deviceId,
                    nickname: nickname,
                    role: role,
                    invitedBy: self?.deviceId
                )

                team.members[deviceId] = member
                team.updatedAt = Date()

                self?.updateTeam(team) { updateResult in
                    switch updateResult {
                    case .success:
                        // Also update the user's team index
                        self?.addTeamToUserIndex(teamId, for: deviceId)
                        completion(.success(member))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func removeMember(_ deviceId: String, from teamId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        fetchTeam(teamId) { [weak self] result in
            switch result {
            case .success(var team):
                guard team.members[deviceId] != nil else {
                    completion(.failure(TeamError.memberNotFound))
                    return
                }

                // Can't remove the owner
                if team.members[deviceId]?.role == .owner {
                    completion(.failure(TeamError.cannotRemoveOwner))
                    return
                }

                team.members.removeValue(forKey: deviceId)
                team.updatedAt = Date()

                self?.updateTeam(team) { updateResult in
                    switch updateResult {
                    case .success:
                        self?.removeTeamFromUserIndex(teamId, for: deviceId)
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func updateMemberRole(_ deviceId: String, in teamId: String, to role: TeamRole, completion: @escaping (Result<Void, Error>) -> Void) {
        fetchTeam(teamId) { [weak self] result in
            switch result {
            case .success(var team):
                guard team.members[deviceId] != nil else {
                    completion(.failure(TeamError.memberNotFound))
                    return
                }

                // Can't demote the owner
                if team.members[deviceId]?.role == .owner && role != .owner {
                    completion(.failure(TeamError.cannotDemoteOwner))
                    return
                }

                team.members[deviceId]?.role = role
                team.updatedAt = Date()

                self?.updateTeam(team) { updateResult in
                    switch updateResult {
                    case .success:
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Invite Operations

    func createInvite(for team: Team, role: TeamRole = .member, expiration: InviteExpiration = .oneWeek, usageLimit: InviteUsageLimit = .unlimited, completion: @escaping (Result<TeamInvite, Error>) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.failure(FirebaseError.notConfigured))
            return
        }

        let invite = TeamInvite(
            teamId: team.id,
            teamName: team.name,
            role: role,
            expiresAt: expiration.expirationDate,
            usageLimit: usageLimit.value
        )

        guard let url = URL(string: inviteURL(invite.id)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(invite) else {
            completion(.failure(FirebaseError.encodingFailed))
            return
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                FirebaseManager.shared.trackEvent(.inviteCreated, metadata: [
                    "teamId": team.id,
                    "role": role.rawValue
                ])

                completion(.success(invite))
            }
        }.resume()
    }

    func acceptInvite(token: String, completion: @escaping (InviteAcceptanceResult) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.error(FirebaseError.notConfigured))
            return
        }

        // Fetch the invite
        guard let url = URL(string: inviteURL(token)) else {
            completion(.error(FirebaseError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async { completion(.error(error)) }
                return
            }

            guard let data = data,
                  var invite = try? self.decoder.decode(TeamInvite.self, from: data) else {
                DispatchQueue.main.async { completion(.error(FirebaseError.invalidResponse)) }
                return
            }

            // Validate invite
            if !invite.isActive {
                DispatchQueue.main.async { completion(.revoked) }
                return
            }

            if invite.isExpired {
                DispatchQueue.main.async { completion(.expired) }
                return
            }

            if invite.isUsageLimitReached {
                DispatchQueue.main.async { completion(.usageLimitReached) }
                return
            }

            // Check if already a member
            self.fetchTeam(invite.teamId) { teamResult in
                switch teamResult {
                case .success(let team):
                    if team.isMember(self.deviceId) {
                        DispatchQueue.main.async { completion(.alreadyMember) }
                        return
                    }

                    // Add member to team
                    self.addMember(self.deviceId, to: invite.teamId, role: invite.role, nickname: DeviceIdentity.shared.nickname) { memberResult in
                        switch memberResult {
                        case .success:
                            // Update invite usage
                            invite.markUsed(by: self.deviceId)
                            self.updateInvite(invite)

                            // Track analytics
                            FirebaseManager.shared.trackEvent(.inviteAccepted, metadata: [
                                "teamId": invite.teamId,
                                "role": invite.role.rawValue
                            ])

                            DispatchQueue.main.async {
                                self.fetchMyTeams()
                                completion(.success(team, invite.role))
                            }

                        case .failure(let error):
                            DispatchQueue.main.async { completion(.error(error)) }
                        }
                    }

                case .failure:
                    DispatchQueue.main.async { completion(.teamNotFound) }
                }
            }
        }.resume()
    }

    func revokeInvite(_ token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: inviteURL(token)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        // Just update isActive to false
        var request = URLRequest(url: URL(string: "\(FirebaseConfig.databaseURL)/team_invites/\(token)/isActive.json")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "false".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }.resume()
    }

    private func updateInvite(_ invite: TeamInvite) {
        guard let url = URL(string: inviteURL(invite.id)) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? encoder.encode(invite)

        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: - Project Operations

    func createProject(name: String, teamId: String? = nil, description: String? = nil, privacy: PrivacyLevel = .private, completion: @escaping (Result<Project, Error>) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.failure(FirebaseError.notConfigured))
            return
        }

        let project = Project(
            name: name,
            description: description,
            teamId: teamId,
            privacy: teamId != nil ? .team : privacy
        )

        guard let url = URL(string: projectURL(project.id)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(project) else {
            completion(.failure(FirebaseError.encodingFailed))
            return
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                self?.projects.append(project)

                // If team project, update team's projectIds
                if let teamId = teamId {
                    self?.addProjectToTeam(project.id, teamId: teamId)
                }

                completion(.success(project))
            }
        }.resume()
    }

    func fetchMyProjects() {
        guard FirebaseConfig.isConfigured else { return }

        // Fetch all projects where user is owner or is in the team
        guard let url = URL(string: "\(projectsURL)?orderBy=\"ownerId\"&equalTo=\"\(deviceId)\"") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data else { return }

            let fetchedProjects = self.parseProjectsResponse(data)

            DispatchQueue.main.async {
                self.projects = fetchedProjects.sorted { $0.name < $1.name }
            }
        }.resume()
    }

    private func parseProjectsResponse(_ data: Data) -> [Project] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var projects: [Project] = []

        for (key, value) in json {
            guard let dict = value as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                continue
            }

            if var project = try? decoder.decode(Project.self, from: jsonData) {
                project.id = key
                projects.append(project)
            }
        }

        return projects
    }

    // MARK: - Team Snippet Operations

    func createTeamSnippet(_ snippet: TeamSnippet, completion: @escaping (Result<TeamSnippet, Error>) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.failure(FirebaseError.notConfigured))
            return
        }

        guard let url = URL(string: teamSnippetURL(snippet.id)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(snippet) else {
            completion(.failure(FirebaseError.encodingFailed))
            return
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                self?.teamSnippets.append(snippet)
                completion(.success(snippet))
            }
        }.resume()
    }

    func fetchTeamSnippets(for teamId: String) {
        guard FirebaseConfig.isConfigured else { return }

        guard let url = URL(string: "\(teamSnippetsURL)?orderBy=\"teamId\"&equalTo=\"\(teamId)\"") else { return }

        isLoading = true

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data else {
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }

            let snippets = self.parseTeamSnippetsResponse(data)

            DispatchQueue.main.async {
                self.teamSnippets = snippets
                self.isLoading = false
            }
        }.resume()
    }

    private func parseTeamSnippetsResponse(_ data: Data) -> [TeamSnippet] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var snippets: [TeamSnippet] = []

        for (key, value) in json {
            guard let dict = value as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                continue
            }

            if var snippet = try? decoder.decode(TeamSnippet.self, from: jsonData) {
                snippet.id = key
                snippets.append(snippet)
            }
        }

        return snippets.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Helper Methods

    private func addTeamToUserIndex(_ teamId: String, for userId: String? = nil) {
        let targetUserId = userId ?? deviceId
        let url = "\(FirebaseConfig.databaseURL)/user_teams/\(targetUserId)/teamIds.json"

        guard let requestURL = URL(string: url) else { return }

        // Get current teams and append
        URLSession.shared.dataTask(with: requestURL) { [weak self] data, _, _ in
            var currentTeams: [String] = []
            if let data = data,
               let teams = try? JSONSerialization.jsonObject(with: data) as? [String] {
                currentTeams = teams
            }

            if !currentTeams.contains(teamId) {
                currentTeams.append(teamId)
            }

            var request = URLRequest(url: requestURL)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: currentTeams)

            URLSession.shared.dataTask(with: request).resume()
        }.resume()
    }

    private func removeTeamFromUserIndex(_ teamId: String, for userId: String? = nil) {
        let targetUserId = userId ?? deviceId
        let url = "\(FirebaseConfig.databaseURL)/user_teams/\(targetUserId)/teamIds.json"

        guard let requestURL = URL(string: url) else { return }

        URLSession.shared.dataTask(with: requestURL) { data, _, _ in
            var currentTeams: [String] = []
            if let data = data,
               let teams = try? JSONSerialization.jsonObject(with: data) as? [String] {
                currentTeams = teams
            }

            currentTeams.removeAll { $0 == teamId }

            var request = URLRequest(url: requestURL)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: currentTeams)

            URLSession.shared.dataTask(with: request).resume()
        }.resume()
    }

    private func addProjectToTeam(_ projectId: String, teamId: String) {
        fetchTeam(teamId) { [weak self] result in
            if case .success(var team) = result {
                if !team.projectIds.contains(projectId) {
                    team.projectIds.append(projectId)
                    self?.updateTeam(team) { _ in }
                }
            }
        }
    }

    private func deleteTeamProjects(_ teamId: String) {
        // Delete all projects associated with team
        let projectsToDelete = projects.filter { $0.teamId == teamId }
        for project in projectsToDelete {
            guard let url = URL(string: projectURL(project.id)) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            URLSession.shared.dataTask(with: request).resume()
        }
        projects.removeAll { $0.teamId == teamId }
    }

    private func deleteTeamSnippets(_ teamId: String) {
        // Delete all snippets associated with team
        let snippetsToDelete = teamSnippets.filter { $0.teamId == teamId }
        for snippet in snippetsToDelete {
            guard let url = URL(string: teamSnippetURL(snippet.id)) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            URLSession.shared.dataTask(with: request).resume()
        }
        teamSnippets.removeAll { $0.teamId == teamId }
    }

    // MARK: - Leave Team

    func leaveTeam(_ teamId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        fetchTeam(teamId) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let team):
                // Check if user is the owner
                if team.members[self.deviceId]?.role == .owner {
                    // Owner can't leave - must transfer ownership or delete team
                    completion(.failure(TeamError.ownerCannotLeave))
                    return
                }

                // Remove self from team
                self.removeMember(self.deviceId, from: teamId) { removeResult in
                    switch removeResult {
                    case .success:
                        // Remove from local state
                        self.teams.removeAll { $0.id == teamId }

                        // Track analytics
                        FirebaseManager.shared.trackEvent(.memberLeft, metadata: ["teamId": teamId])

                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Fetch Pending Invitations

    @Published var receivedInvitations: [ReceivedInvitation] = []

    func fetchPendingInvitations() {
        guard FirebaseConfig.isConfigured else { return }

        // Query invites that haven't been accepted by this device
        guard let url = URL(string: invitesURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data else { return }

            let invites = self.parseInvitesResponse(data)

            // Filter to invites that:
            // 1. Are still valid (not expired, not revoked)
            // 2. Haven't been accepted by this device yet
            // 3. Are for teams the user isn't already in
            let myTeamIds = Set(self.teams.map { $0.id })
            let validInvites = invites.filter { invite in
                invite.isValid &&
                !invite.acceptedBy.contains(self.deviceId) &&
                !myTeamIds.contains(invite.teamId)
            }

            // Convert to received invitations with team info
            var received: [ReceivedInvitation] = []
            let group = DispatchGroup()

            for invite in validInvites {
                group.enter()
                self.fetchTeam(invite.teamId) { result in
                    if case .success(let team) = result {
                        let receivedInvite = ReceivedInvitation(
                            invite: invite,
                            team: team
                        )
                        received.append(receivedInvite)
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.receivedInvitations = received.sorted { $0.invite.createdAt > $1.invite.createdAt }
            }
        }.resume()
    }

    private func parseInvitesResponse(_ data: Data) -> [TeamInvite] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var invites: [TeamInvite] = []

        for (key, value) in json {
            guard let dict = value as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                continue
            }

            if var invite = try? decoder.decode(TeamInvite.self, from: jsonData) {
                invite.id = key
                invites.append(invite)
            }
        }

        return invites
    }

    // MARK: - Get Team Invites (created by user)

    func fetchMyCreatedInvites(for teamId: String, completion: @escaping ([TeamInvite]) -> Void) {
        guard let url = URL(string: "\(invitesURL)?orderBy=\"teamId\"&equalTo=\"\(teamId)\"") else {
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let invites = self.parseInvitesResponse(data)
            let myInvites = invites.filter { $0.createdBy == self.deviceId }

            DispatchQueue.main.async {
                completion(myInvites.sorted { $0.createdAt > $1.createdAt })
            }
        }.resume()
    }
}

// MARK: - Received Invitation Model

struct ReceivedInvitation: Identifiable {
    var id: String { invite.id }
    let invite: TeamInvite
    let team: Team

    var isExpired: Bool { invite.isExpired }
    var role: TeamRole { invite.role }
    var inviterName: String { invite.creatorNickname ?? "Someone" }
}

// MARK: - Team Errors

enum TeamError: LocalizedError {
    case memberNotFound
    case cannotRemoveOwner
    case cannotDemoteOwner
    case insufficientPermissions
    case teamNotFound
    case projectNotFound
    case ownerCannotLeave

    var errorDescription: String? {
        switch self {
        case .memberNotFound: return "Member not found in team"
        case .cannotRemoveOwner: return "Cannot remove the team owner"
        case .cannotDemoteOwner: return "Cannot demote the team owner"
        case .insufficientPermissions: return "You don't have permission for this action"
        case .teamNotFound: return "Team not found"
        case .projectNotFound: return "Project not found"
        case .ownerCannotLeave: return "As owner, you must transfer ownership or delete the team"
        }
    }
}

// MARK: - Additional Analytics Events

extension AnalyticsEventType {
    static let teamCreated = AnalyticsEventType(rawValue: "team_created")!
    static let teamDeleted = AnalyticsEventType(rawValue: "team_deleted")!
    static let memberAdded = AnalyticsEventType(rawValue: "member_added")!
    static let memberRemoved = AnalyticsEventType(rawValue: "member_removed")!
    static let memberLeft = AnalyticsEventType(rawValue: "member_left")!
    static let inviteCreated = AnalyticsEventType(rawValue: "invite_created")!
    static let inviteAccepted = AnalyticsEventType(rawValue: "invite_accepted")!
    static let projectCreated = AnalyticsEventType(rawValue: "project_created")!
}
