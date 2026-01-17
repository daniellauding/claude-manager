import Foundation
import Combine

// MARK: - Admin Manager

class AdminManager: ObservableObject {
    static let shared = AdminManager()

    // Published State
    @Published var isAdmin: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?

    // Admin data
    @Published var allUsers: [AdminUserInfo] = []
    @Published var allTeams: [Team] = []
    @Published var allProjects: [Project] = []
    @Published var allInvites: [TeamInvite] = []
    @Published var defaultNewsSources: [NewsSource] = []
    @Published var stats: AdminStats = AdminStats()

    // Private
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Firebase URLs

    private var adminsURL: String { "\(FirebaseConfig.databaseURL)/admins.json" }
    private var usersURL: String { "\(FirebaseConfig.databaseURL)/users.json" }
    private var teamsURL: String { "\(FirebaseConfig.databaseURL)/teams.json" }
    private var projectsURL: String { "\(FirebaseConfig.databaseURL)/projects.json" }
    private var invitesURL: String { "\(FirebaseConfig.databaseURL)/team_invites.json" }
    private var statsURL: String { "\(FirebaseConfig.databaseURL)/admin_stats.json" }
    private var defaultSourcesURL: String { "\(FirebaseConfig.databaseURL)/default_news_sources.json" }

    private func userURL(_ userId: String) -> String {
        "\(FirebaseConfig.databaseURL)/users/\(userId).json"
    }

    private func teamURL(_ teamId: String) -> String {
        "\(FirebaseConfig.databaseURL)/teams/\(teamId).json"
    }

    private func projectURL(_ projectId: String) -> String {
        "\(FirebaseConfig.databaseURL)/projects/\(projectId).json"
    }

    private func inviteURL(_ token: String) -> String {
        "\(FirebaseConfig.databaseURL)/team_invites/\(token).json"
    }

    private func adminURL(_ email: String) -> String {
        let encodedEmail = email.replacingOccurrences(of: ".", with: ",")
        return "\(FirebaseConfig.databaseURL)/admins/\(encodedEmail).json"
    }

    private func defaultSourceURL(_ sourceId: String) -> String {
        "\(FirebaseConfig.databaseURL)/default_news_sources/\(sourceId).json"
    }

    // MARK: - Initialization

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        // Check admin status when user auth changes
        if FirebaseConfig.isConfigured {
            checkAdminStatus()
        }

        // Listen for login changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userAuthChanged),
            name: NSNotification.Name("UserAuthChanged"),
            object: nil
        )
    }

    @objc private func userAuthChanged() {
        checkAdminStatus()
    }

    // MARK: - Admin Check

    func checkAdminStatus() {
        guard FirebaseConfig.isConfigured,
              let email = UserAuth.shared.currentUser?.email else {
            isAdmin = false
            return
        }

        guard let url = URL(string: adminURL(email)) else {
            isAdmin = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let isAdminValue = try? JSONSerialization.jsonObject(with: data) as? Bool else {
                    self?.isAdmin = false
                    return
                }
                self?.isAdmin = isAdminValue
            }
        }.resume()
    }

    // MARK: - Fetch All Data (Admin Only)

    func fetchAllData() {
        guard isAdmin, FirebaseConfig.isConfigured else { return }

        isLoading = true
        error = nil

        let group = DispatchGroup()

        group.enter()
        fetchAllUsers { group.leave() }

        group.enter()
        fetchAllTeams { group.leave() }

        group.enter()
        fetchAllProjects { group.leave() }

        group.enter()
        fetchAllInvites { group.leave() }

        group.enter()
        fetchDefaultNewsSources { group.leave() }

        group.enter()
        fetchStats { group.leave() }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }

    // MARK: - Users Management

    func fetchAllUsers(completion: @escaping () -> Void = {}) {
        guard let url = URL(string: usersURL) else {
            completion()
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                defer { completion() }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }

                var users: [AdminUserInfo] = []

                for (userId, value) in json {
                    guard let dict = value as? [String: Any],
                          let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                          let user = try? self?.decoder.decode(SyncedUser.self, from: jsonData) else {
                        continue
                    }

                    let adminUser = AdminUserInfo(
                        id: userId,
                        user: user,
                        teamCount: 0,  // Will be populated separately
                        snippetCount: 0
                    )
                    users.append(adminUser)
                }

                self?.allUsers = users.sorted { ($0.user.lastSeenAt ?? $0.user.createdAt) > ($1.user.lastSeenAt ?? $1.user.createdAt) }
            }
        }.resume()
    }

    func deleteUser(_ userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
            return
        }

        guard let url = URL(string: userURL(userId)) else {
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

                // Remove from local state
                self?.allUsers.removeAll { $0.id == userId }

                // Update stats
                self?.updateStats()

                completion(.success(()))
            }
        }.resume()
    }

    // MARK: - Teams Management

    func fetchAllTeams(completion: @escaping () -> Void = {}) {
        guard let url = URL(string: teamsURL) else {
            completion()
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                defer { completion() }

                guard let self = self, let data = data else { return }

                let teams = self.parseTeamsResponse(data)
                self.allTeams = teams.sorted { $0.createdAt > $1.createdAt }
            }
        }.resume()
    }

    private func parseTeamsResponse(_ data: Data) -> [Team] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var teams: [Team] = []

        for (key, value) in json {
            guard let dict = value as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                continue
            }

            if var team = try? decoder.decode(Team.self, from: jsonData) {
                team.id = key
                teams.append(team)
            }
        }

        return teams
    }

    func deleteTeam(_ teamId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
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

                self?.allTeams.removeAll { $0.id == teamId }
                self?.updateStats()
                completion(.success(()))
            }
        }.resume()
    }

    // MARK: - Projects Management

    func fetchAllProjects(completion: @escaping () -> Void = {}) {
        guard let url = URL(string: projectsURL) else {
            completion()
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                defer { completion() }

                guard let self = self, let data = data else { return }

                let projects = self.parseProjectsResponse(data)
                self.allProjects = projects.sorted { $0.createdAt > $1.createdAt }
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

    func deleteProject(_ projectId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
            return
        }

        guard let url = URL(string: projectURL(projectId)) else {
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

                self?.allProjects.removeAll { $0.id == projectId }
                completion(.success(()))
            }
        }.resume()
    }

    // MARK: - Invites Management

    func fetchAllInvites(completion: @escaping () -> Void = {}) {
        guard let url = URL(string: invitesURL) else {
            completion()
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                defer { completion() }

                guard let self = self, let data = data else { return }

                let invites = self.parseInvitesResponse(data)
                self.allInvites = invites.sorted { $0.createdAt > $1.createdAt }
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

    func revokeInvite(_ token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
            return
        }

        let url = "\(FirebaseConfig.databaseURL)/team_invites/\(token)/isActive.json"
        guard let requestURL = URL(string: url) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "false".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Update local state
                if let index = self?.allInvites.firstIndex(where: { $0.id == token }) {
                    self?.allInvites[index].isActive = false
                }

                completion(.success(()))
            }
        }.resume()
    }

    func deleteInvite(_ token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
            return
        }

        guard let url = URL(string: inviteURL(token)) else {
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

                self?.allInvites.removeAll { $0.id == token }
                completion(.success(()))
            }
        }.resume()
    }

    // MARK: - Default News Sources Management

    func fetchDefaultNewsSources(completion: @escaping () -> Void = {}) {
        guard let url = URL(string: defaultSourcesURL) else {
            completion()
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                defer { completion() }

                guard let self = self, let data = data else { return }

                let sources = self.parseNewsSourcesResponse(data)
                self.defaultNewsSources = sources.sorted { $0.name < $1.name }
            }
        }.resume()
    }

    private func parseNewsSourcesResponse(_ data: Data) -> [NewsSource] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var sources: [NewsSource] = []

        for (key, value) in json {
            guard let dict = value as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                continue
            }

            if var source = try? decoder.decode(NewsSource.self, from: jsonData) {
                source = NewsSource(
                    id: UUID(uuidString: key) ?? UUID(),
                    name: source.name,
                    feedURL: source.feedURL,
                    isEnabled: source.isEnabled,
                    icon: source.icon
                )
                sources.append(source)
            }
        }

        return sources
    }

    func addDefaultNewsSource(_ source: NewsSource, completion: @escaping (Result<NewsSource, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
            return
        }

        guard let url = URL(string: defaultSourceURL(source.id.uuidString)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(source) else {
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

                self?.defaultNewsSources.append(source)
                self?.defaultNewsSources.sort { $0.name < $1.name }
                completion(.success(source))
            }
        }.resume()
    }

    func updateDefaultNewsSource(_ source: NewsSource, completion: @escaping (Result<NewsSource, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
            return
        }

        guard let url = URL(string: defaultSourceURL(source.id.uuidString)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(source) else {
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

                if let index = self?.defaultNewsSources.firstIndex(where: { $0.id == source.id }) {
                    self?.defaultNewsSources[index] = source
                }

                completion(.success(source))
            }
        }.resume()
    }

    func deleteDefaultNewsSource(_ sourceId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
            return
        }

        guard let url = URL(string: defaultSourceURL(sourceId.uuidString)) else {
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

                self?.defaultNewsSources.removeAll { $0.id == sourceId }
                completion(.success(()))
            }
        }.resume()
    }

    // MARK: - Stats

    func fetchStats(completion: @escaping () -> Void = {}) {
        guard let url = URL(string: statsURL) else {
            completion()
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                defer { completion() }

                guard let data = data,
                      let stats = try? self?.decoder.decode(AdminStats.self, from: data) else {
                    return
                }

                self?.stats = stats
            }
        }.resume()
    }

    func updateStats() {
        let newStats = AdminStats(
            totalUsers: allUsers.count,
            totalTeams: allTeams.count,
            totalProjects: allProjects.count,
            totalInvites: allInvites.count,
            activeInvites: allInvites.filter { $0.isActive && !$0.isExpired }.count,
            lastUpdated: Date()
        )

        guard let url = URL(string: statsURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(newStats) else { return }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.stats = newStats
            }
        }.resume()
    }

    // MARK: - Admin Management (Super Admin)

    func addAdmin(_ email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
            return
        }

        guard let url = URL(string: adminURL(email)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "true".data(using: .utf8)

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

    func removeAdmin(_ email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isAdmin else {
            completion(.failure(AdminError.notAuthorized))
            return
        }

        // Prevent removing self
        if email == UserAuth.shared.currentUser?.email {
            completion(.failure(AdminError.cannotRemoveSelf))
            return
        }

        guard let url = URL(string: adminURL(email)) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

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
}

// MARK: - Admin Models

struct AdminUserInfo: Identifiable {
    let id: String
    let user: SyncedUser
    var teamCount: Int
    var snippetCount: Int

    var displayName: String { user.displayName }
    var email: String { user.email }
    var deviceCount: Int { user.deviceIds.count }
    var lastSeen: Date? { user.lastSeenAt }
    var createdAt: Date { user.createdAt }
}

struct AdminStats: Codable {
    var totalUsers: Int
    var totalTeams: Int
    var totalProjects: Int
    var totalInvites: Int
    var activeInvites: Int
    var lastUpdated: Date

    init(
        totalUsers: Int = 0,
        totalTeams: Int = 0,
        totalProjects: Int = 0,
        totalInvites: Int = 0,
        activeInvites: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.totalUsers = totalUsers
        self.totalTeams = totalTeams
        self.totalProjects = totalProjects
        self.totalInvites = totalInvites
        self.activeInvites = activeInvites
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Admin Errors

enum AdminError: LocalizedError {
    case notAuthorized
    case cannotRemoveSelf
    case invalidOperation

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "You don't have admin permissions"
        case .cannotRemoveSelf: return "You cannot remove your own admin access"
        case .invalidOperation: return "Invalid admin operation"
        }
    }
}
