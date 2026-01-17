import Foundation
import Combine

// MARK: - Sync Manager

class SyncManager: ObservableObject {
    static let shared = SyncManager()

    // Published State
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncStatus: SyncStatus = .idle

    // Private
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?

    // UserDefaults keys
    private let lastSyncKey = "last_sync_timestamp"
    private let syncedSnippetsKey = "synced_snippet_ids"

    // MARK: - Firebase URLs

    private func userDataURL(_ userId: String) -> String {
        "\(FirebaseConfig.databaseURL)/user_data/\(userId).json"
    }

    private func userSnippetsURL(_ userId: String) -> String {
        "\(FirebaseConfig.databaseURL)/user_snippets/\(userId).json"
    }

    private func userSettingsURL(_ userId: String) -> String {
        "\(FirebaseConfig.databaseURL)/user_settings/\(userId).json"
    }

    // MARK: - Initialization

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        // Load last sync date
        if let timestamp = UserDefaults.standard.object(forKey: lastSyncKey) as? TimeInterval {
            lastSyncDate = Date(timeIntervalSince1970: timestamp)
        }

        // Start auto-sync timer if enabled
        startAutoSyncIfEnabled()
    }

    // MARK: - Sync Operations

    /// Sync all data (snippets + settings)
    func syncAll() {
        guard FirebaseConfig.isConfigured,
              UserAuth.shared.isLoggedIn,
              UserAuth.shared.syncEnabled,
              let userId = UserAuth.shared.currentUser?.id else {
            return
        }

        isSyncing = true
        syncStatus = .syncing
        syncError = nil

        let group = DispatchGroup()

        // Sync snippets
        group.enter()
        syncSnippets(userId: userId) { _ in
            group.leave()
        }

        // Sync settings
        group.enter()
        syncSettings(userId: userId) { _ in
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            self?.isSyncing = false
            self?.lastSyncDate = Date()
            self?.syncStatus = .completed
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self?.lastSyncKey ?? "")

            FirebaseManager.shared.trackEvent(.syncCompleted)
        }
    }

    /// Sync snippets bidirectionally
    func syncSnippets(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: userSnippetsURL(userId)) else {
            completion(.failure(SyncError.invalidURL))
            return
        }

        // First, fetch remote snippets
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.syncError = error.localizedDescription
                    completion(.failure(error))
                }
                return
            }

            var remoteSnippets: [SyncedSnippet] = []
            if let data = data {
                remoteSnippets = self.parseSnippetsResponse(data)
            }

            // Merge with local snippets
            DispatchQueue.main.async {
                let localSnippets = SnippetManager().snippets
                let merged = self.mergeSnippets(local: localSnippets, remote: remoteSnippets)

                // Upload merged result
                self.uploadSnippets(merged, userId: userId) { uploadResult in
                    switch uploadResult {
                    case .success:
                        // Update local storage with merged data
                        self.updateLocalSnippets(merged)
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }

    /// Sync settings
    func syncSettings(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: userSettingsURL(userId)) else {
            completion(.failure(SyncError.invalidURL))
            return
        }

        // Get local settings
        let localSettings = SyncedSettings.current()

        // Fetch remote settings
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            var remoteSettings: SyncedSettings?
            if let data = data {
                remoteSettings = try? self.decoder.decode(SyncedSettings.self, from: data)
            }

            // Use remote if newer, otherwise upload local
            let settingsToUse: SyncedSettings
            if let remote = remoteSettings, remote.updatedAt > localSettings.updatedAt {
                settingsToUse = remote
                // Apply remote settings locally
                DispatchQueue.main.async {
                    self.applySettings(remote)
                }
            } else {
                settingsToUse = localSettings
            }

            // Upload current settings
            self.uploadSettings(settingsToUse, userId: userId, completion: completion)
        }.resume()
    }

    // MARK: - Upload Operations

    private func uploadSnippets(_ snippets: [SyncedSnippet], userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: userSnippetsURL(userId)) else {
            completion(.failure(SyncError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert to dictionary for Firebase
        var snippetsDict: [String: SyncedSnippet] = [:]
        for snippet in snippets {
            snippetsDict[snippet.id] = snippet
        }

        guard let body = try? encoder.encode(snippetsDict) else {
            completion(.failure(SyncError.encodingFailed))
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

    private func uploadSettings(_ settings: SyncedSettings, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: userSettingsURL(userId)) else {
            completion(.failure(SyncError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(settings) else {
            completion(.failure(SyncError.encodingFailed))
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

    // MARK: - Merge Logic

    private func mergeSnippets(local: [Snippet], remote: [SyncedSnippet]) -> [SyncedSnippet] {
        var merged: [String: SyncedSnippet] = [:]

        // Add remote snippets
        for snippet in remote {
            merged[snippet.id] = snippet
        }

        // Merge local snippets (newer wins)
        for snippet in local {
            let synced = SyncedSnippet.from(snippet)
            if let existing = merged[synced.id] {
                // Keep the newer one
                if synced.updatedAt > existing.updatedAt {
                    merged[synced.id] = synced
                }
            } else {
                merged[synced.id] = synced
            }
        }

        return Array(merged.values)
    }

    private func updateLocalSnippets(_ synced: [SyncedSnippet]) {
        // This would update the local SnippetManager
        // For now, we'll just track synced IDs
        let ids = synced.map { $0.id }
        UserDefaults.standard.set(ids, forKey: syncedSnippetsKey)
    }

    private func applySettings(_ settings: SyncedSettings) {
        // Apply synced settings to local UserDefaults
        UserDefaults.standard.set(settings.launchAtLogin, forKey: "launchAtLogin")
        if let nickname = settings.nickname {
            DeviceIdentity.shared.nickname = nickname
        }
    }

    // MARK: - Helpers

    private func parseSnippetsResponse(_ data: Data) -> [SyncedSnippet] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var snippets: [SyncedSnippet] = []

        for (_, value) in json {
            guard let dict = value as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                continue
            }

            if let snippet = try? decoder.decode(SyncedSnippet.self, from: jsonData) {
                snippets.append(snippet)
            }
        }

        return snippets
    }

    private func startAutoSyncIfEnabled() {
        guard UserAuth.shared.syncEnabled else { return }

        // Sync every 5 minutes
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.syncAll()
        }
    }

    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
}

// MARK: - Sync Status

enum SyncStatus: String {
    case idle = "Not synced"
    case syncing = "Syncing..."
    case completed = "Synced"
    case error = "Sync failed"

    var icon: String {
        switch self {
        case .idle: return "icloud.slash"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        }
    }
}

// MARK: - Synced Snippet Model

struct SyncedSnippet: Identifiable, Codable {
    var id: String
    var title: String
    var content: String
    var category: String
    var tags: [String]
    var project: String?
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var useCount: Int
    var sourceDeviceId: String

    static func from(_ snippet: Snippet) -> SyncedSnippet {
        SyncedSnippet(
            id: snippet.id.uuidString,
            title: snippet.title,
            content: snippet.content,
            category: snippet.category.rawValue,
            tags: snippet.tags,
            project: snippet.project,
            isFavorite: snippet.isFavorite,
            createdAt: snippet.createdAt,
            updatedAt: snippet.lastUsedAt ?? snippet.createdAt,
            useCount: snippet.useCount,
            sourceDeviceId: DeviceIdentity.shared.deviceId
        )
    }

    func toSnippet() -> Snippet {
        Snippet(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            content: content,
            category: SnippetCategory(rawValue: category) ?? .other,
            tags: tags,
            project: project,
            isFavorite: isFavorite,
            createdAt: createdAt,
            lastUsedAt: updatedAt,
            useCount: useCount
        )
    }
}

// MARK: - Synced Settings Model

struct SyncedSettings: Codable {
    var launchAtLogin: Bool
    var nickname: String?
    var defaultCategory: String
    var defaultPrivacy: String
    var watchedFolders: [String]
    var updatedAt: Date

    static func current() -> SyncedSettings {
        SyncedSettings(
            launchAtLogin: UserDefaults.standard.bool(forKey: "launchAtLogin"),
            nickname: DeviceIdentity.shared.nickname,
            defaultCategory: SnippetCategory.other.rawValue,
            defaultPrivacy: PrivacyLevel.private.rawValue,
            watchedFolders: [],  // Don't sync folder paths (device-specific)
            updatedAt: Date()
        )
    }
}

// MARK: - Sync Errors

enum SyncError: LocalizedError {
    case notLoggedIn
    case syncDisabled
    case invalidURL
    case encodingFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "Please sign in to sync"
        case .syncDisabled: return "Sync is disabled"
        case .invalidURL: return "Invalid sync URL"
        case .encodingFailed: return "Failed to encode data"
        case .networkError: return "Network error during sync"
        }
    }
}
