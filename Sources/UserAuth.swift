import Foundation
import Combine

// MARK: - User Authentication Manager

class UserAuth: ObservableObject {
    static let shared = UserAuth()

    // Published State
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: SyncedUser?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var syncEnabled: Bool = false

    // Private
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cancellables = Set<AnyCancellable>()

    // UserDefaults keys
    private let userIdKey = "synced_user_id"
    private let userEmailKey = "synced_user_email"
    private let syncEnabledKey = "sync_enabled"
    private let lastSyncKey = "last_sync_timestamp"

    // MARK: - Firebase URLs

    private var usersURL: String { "\(FirebaseConfig.databaseURL)/users.json" }

    private func userURL(_ userId: String) -> String {
        "\(FirebaseConfig.databaseURL)/users/\(userId).json"
    }

    private func userByEmailURL(_ email: String) -> String {
        let encodedEmail = email.replacingOccurrences(of: ".", with: ",")
        return "\(FirebaseConfig.databaseURL)/user_emails/\(encodedEmail).json"
    }

    // MARK: - Initialization

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        // Load saved state
        syncEnabled = UserDefaults.standard.bool(forKey: syncEnabledKey)

        // Try to restore session
        if let savedUserId = UserDefaults.standard.string(forKey: userIdKey) {
            restoreSession(userId: savedUserId)
        }
    }

    // MARK: - Authentication

    /// Sign up or sign in with email (passwordless - magic link style)
    func signInWithEmail(_ email: String, completion: @escaping (Result<SyncedUser, Error>) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.failure(AuthError.notConfigured))
            return
        }

        isLoading = true
        error = nil

        // Check if user exists by email
        checkUserByEmail(email) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let existingUserId):
                if let userId = existingUserId {
                    // User exists, fetch and login
                    self.fetchUser(userId) { fetchResult in
                        self.isLoading = false
                        switch fetchResult {
                        case .success(let user):
                            self.completeLogin(user)
                            completion(.success(user))
                        case .failure(let error):
                            self.error = error.localizedDescription
                            completion(.failure(error))
                        }
                    }
                } else {
                    // New user, create account
                    self.createUser(email: email) { createResult in
                        self.isLoading = false
                        switch createResult {
                        case .success(let user):
                            self.completeLogin(user)
                            completion(.success(user))
                        case .failure(let error):
                            self.error = error.localizedDescription
                            completion(.failure(error))
                        }
                    }
                }

            case .failure(let error):
                self.isLoading = false
                self.error = error.localizedDescription
                completion(.failure(error))
            }
        }
    }

    /// Sign out
    func signOut() {
        currentUser = nil
        isLoggedIn = false
        syncEnabled = false

        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.set(false, forKey: syncEnabledKey)

        // Clear device link (keep deviceId for local use)
        // Don't remove the device entirely so local data is preserved
    }

    /// Link current device to existing account
    func linkDevice(to userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let deviceId = DeviceIdentity.shared.deviceId

        fetchUser(userId) { [weak self] result in
            switch result {
            case .success(var user):
                // Add device to user's devices
                if !user.deviceIds.contains(deviceId) {
                    user.deviceIds.append(deviceId)
                    user.updatedAt = Date()

                    self?.updateUser(user) { updateResult in
                        switch updateResult {
                        case .success:
                            self?.completeLogin(user)
                            completion(.success(()))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    self?.completeLogin(user)
                    completion(.success(()))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Sync Control

    func enableSync(_ enable: Bool) {
        syncEnabled = enable
        UserDefaults.standard.set(enable, forKey: syncEnabledKey)

        if enable && isLoggedIn {
            // Trigger initial sync
            SyncManager.shared.syncAll()
        }
    }

    // MARK: - Private Methods

    private func checkUserByEmail(_ email: String, completion: @escaping (Result<String?, Error>) -> Void) {
        guard let url = URL(string: userByEmailURL(email)) else {
            completion(.failure(AuthError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.success(nil))
                    return
                }

                // Check if we got a userId back
                if let userId = try? JSONSerialization.jsonObject(with: data) as? String {
                    completion(.success(userId))
                } else {
                    completion(.success(nil))
                }
            }
        }.resume()
    }

    private func createUser(email: String, completion: @escaping (Result<SyncedUser, Error>) -> Void) {
        let deviceId = DeviceIdentity.shared.deviceId
        let userId = UUID().uuidString.lowercased()

        let user = SyncedUser(
            id: userId,
            email: email,
            nickname: DeviceIdentity.shared.nickname,
            deviceIds: [deviceId],
            createdAt: Date(),
            updatedAt: Date()
        )

        guard let url = URL(string: userURL(userId)) else {
            completion(.failure(AuthError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(user) else {
            completion(.failure(AuthError.encodingFailed))
            return
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            // Also save email -> userId mapping
            self?.saveEmailMapping(email: email, userId: userId)

            DispatchQueue.main.async {
                completion(.success(user))
            }
        }.resume()
    }

    private func saveEmailMapping(email: String, userId: String) {
        guard let url = URL(string: userByEmailURL(email)) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "\"\(userId)\"".data(using: .utf8)

        URLSession.shared.dataTask(with: request).resume()
    }

    private func fetchUser(_ userId: String, completion: @escaping (Result<SyncedUser, Error>) -> Void) {
        guard let url = URL(string: userURL(userId)) else {
            completion(.failure(AuthError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data,
                      let user = try? self?.decoder.decode(SyncedUser.self, from: data) else {
                    completion(.failure(AuthError.userNotFound))
                    return
                }

                completion(.success(user))
            }
        }.resume()
    }

    private func updateUser(_ user: SyncedUser, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: userURL(user.id)) else {
            completion(.failure(AuthError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(user) else {
            completion(.failure(AuthError.encodingFailed))
            return
        }
        request.httpBody = body

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

    private func completeLogin(_ user: SyncedUser) {
        currentUser = user
        isLoggedIn = true

        UserDefaults.standard.set(user.id, forKey: userIdKey)
        UserDefaults.standard.set(user.email, forKey: userEmailKey)

        // Update last seen
        var updatedUser = user
        updatedUser.lastSeenAt = Date()
        updateUser(updatedUser) { _ in }

        // Track analytics
        FirebaseManager.shared.trackEvent(.userLoggedIn, metadata: ["userId": user.id])
    }

    private func restoreSession(userId: String) {
        fetchUser(userId) { [weak self] result in
            if case .success(let user) = result {
                self?.completeLogin(user)

                // Auto-sync if enabled
                if self?.syncEnabled == true {
                    SyncManager.shared.syncAll()
                }
            }
        }
    }
}

// MARK: - Synced User Model

struct SyncedUser: Identifiable, Codable {
    var id: String
    var email: String
    var nickname: String?
    var avatarURL: String?
    var deviceIds: [String]
    var createdAt: Date
    var updatedAt: Date
    var lastSeenAt: Date?
    var preferences: UserPreferences?

    var displayName: String {
        nickname ?? email.components(separatedBy: "@").first ?? "User"
    }

    var deviceCount: Int {
        deviceIds.count
    }
}

// MARK: - User Preferences (Synced)

struct UserPreferences: Codable {
    var defaultPrivacy: PrivacyLevel
    var defaultCategory: SnippetCategory
    var showBadges: Bool
    var autoSync: Bool
    var theme: String?  // For future use

    init(
        defaultPrivacy: PrivacyLevel = .private,
        defaultCategory: SnippetCategory = .other,
        showBadges: Bool = true,
        autoSync: Bool = true,
        theme: String? = nil
    ) {
        self.defaultPrivacy = defaultPrivacy
        self.defaultCategory = defaultCategory
        self.showBadges = showBadges
        self.autoSync = autoSync
        self.theme = theme
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case notConfigured
    case invalidURL
    case encodingFailed
    case userNotFound
    case invalidEmail
    case alreadyLinked

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Cloud sync is not configured"
        case .invalidURL: return "Invalid request URL"
        case .encodingFailed: return "Failed to encode data"
        case .userNotFound: return "User account not found"
        case .invalidEmail: return "Invalid email address"
        case .alreadyLinked: return "This device is already linked to an account"
        }
    }
}

// MARK: - Analytics Extension

extension AnalyticsEventType {
    static let userLoggedIn = AnalyticsEventType(rawValue: "user_logged_in")!
    static let userLoggedOut = AnalyticsEventType(rawValue: "user_logged_out")!
    static let syncCompleted = AnalyticsEventType(rawValue: "sync_completed")!
}
