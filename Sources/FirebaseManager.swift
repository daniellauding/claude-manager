import Foundation
import Combine

// MARK: - Firebase Manager (REST API)

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    @Published var communitySnippets: [SharedSnippet] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isConfigured: Bool = FirebaseConfig.isConfigured

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        // Register device on first launch
        if FirebaseConfig.isConfigured {
            registerDevice()
        }
    }

    // MARK: - Device Registration

    private func registerDevice() {
        let deviceId = DeviceIdentity.shared.deviceId

        guard let url = URL(string: FirebaseConfig.userURL(deviceId: deviceId)) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let updateData: [String: Any] = [
            "lastSeen": Date().timeIntervalSince1970 * 1000,
            "firstSeen": ["sv": "timestamp"]  // Server value for first time only
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: updateData)

        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: - Fetch Community Snippets

    func fetchCommunitySnippets(category: SnippetCategory? = nil) {
        guard FirebaseConfig.isConfigured else {
            self.error = "Firebase not configured"
            return
        }

        isLoading = true
        error = nil

        var urlString = FirebaseConfig.sharedSnippetsURL
        if let cat = category {
            urlString += "?orderBy=\"category\"&equalTo=\"\(cat.rawValue)\""
        } else {
            urlString += "?orderBy=\"createdAt\"&limitToLast=100"
        }

        guard let url = URL(string: urlString) else {
            isLoading = false
            error = "Invalid URL"
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = err.localizedDescription
                }
            } receiveValue: { [weak self] data in
                self?.parseSnippetsResponse(data)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func parseSnippetsResponse(_ data: Data) {
        // Firebase returns { "key1": { snippet }, "key2": { snippet } }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            communitySnippets = []
            return
        }

        var snippets: [SharedSnippet] = []

        for (key, value) in json {
            guard let dict = value as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                continue
            }

            if var snippet = try? decoder.decode(SharedSnippet.self, from: jsonData) {
                snippet.id = key
                snippets.append(snippet)
            }
        }

        // Sort by creation date (newest first)
        communitySnippets = snippets.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Share Snippet

    func shareSnippet(_ snippet: Snippet, completion: @escaping (Result<String, Error>) -> Void) {
        guard FirebaseConfig.isConfigured else {
            completion(.failure(FirebaseError.notConfigured))
            return
        }

        let sharedSnippet = SharedSnippet(
            from: snippet,
            deviceId: DeviceIdentity.shared.deviceId,
            nickname: DeviceIdentity.shared.nickname
        )

        guard let url = URL(string: FirebaseConfig.sharedSnippetsURL) else {
            completion(.failure(FirebaseError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? encoder.encode(sharedSnippet) else {
            completion(.failure(FirebaseError.encodingFailed))
            return
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Firebase returns { "name": "generated-key" }
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let key = json["name"] as? String {
                    self.trackEvent(.snippetShared, category: snippet.category.rawValue)
                    completion(.success(key))
                } else {
                    completion(.failure(FirebaseError.invalidResponse))
                }
            }
        }.resume()
    }

    // MARK: - Download (Import) Snippet

    func downloadSnippet(_ shared: SharedSnippet) -> Snippet {
        // Increment download count
        incrementCounter(snippetId: shared.id, field: "downloads")
        trackEvent(.snippetDownloaded, category: shared.category)
        return shared.toLocalSnippet()
    }

    // MARK: - Like Snippet

    func likeSnippet(_ snippetId: String) {
        incrementCounter(snippetId: snippetId, field: "likes")
        trackEvent(.snippetLiked, metadata: ["snippetId": snippetId])

        // Track individual like for analytics
        trackInteraction(type: "like", itemId: snippetId, itemType: "snippet")
    }

    // MARK: - Star/Favorite Item (for popularity tracking)

    func starItem(itemId: String, itemType: String, title: String? = nil) {
        trackEvent(.itemStarred, metadata: [
            "itemId": itemId,
            "itemType": itemType,
            "title": title ?? ""
        ])
        trackInteraction(type: "star", itemId: itemId, itemType: itemType)
    }

    func unstarItem(itemId: String, itemType: String) {
        trackEvent(.itemUnstarred, metadata: [
            "itemId": itemId,
            "itemType": itemType
        ])
    }

    // MARK: - Track Interaction (for popularity metrics)

    private func trackInteraction(type: String, itemId: String, itemType: String) {
        guard FirebaseConfig.isConfigured else { return }

        let deviceId = DeviceIdentity.shared.deviceId
        let interactionURL = "\(FirebaseConfig.databaseURL)/interactions/\(itemType)/\(itemId)/\(deviceId).json"

        guard let url = URL(string: interactionURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let interaction: [String: Any] = [
            "type": type,
            "timestamp": Date().timeIntervalSince1970 * 1000
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: interaction)
        URLSession.shared.dataTask(with: request).resume()

        // Also update popularity counter
        updatePopularityScore(itemId: itemId, itemType: itemType)
    }

    private func updatePopularityScore(itemId: String, itemType: String) {
        let popularityURL = "\(FirebaseConfig.databaseURL)/popularity/\(itemType)/\(itemId).json"
        guard let url = URL(string: popularityURL) else { return }

        // Get current score and increment
        URLSession.shared.dataTask(with: url) { data, _, _ in
            var currentScore = 0
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let score = json["score"] as? Int {
                currentScore = score
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let update: [String: Any] = [
                "score": currentScore + 1,
                "lastInteraction": Date().timeIntervalSince1970 * 1000,
                "itemId": itemId,
                "itemType": itemType
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: update)
            URLSession.shared.dataTask(with: request).resume()
        }.resume()
    }

    // MARK: - Report Snippet

    func reportSnippet(_ snippetId: String, reason: String) {
        incrementCounter(snippetId: snippetId, field: "reports")

        // Also log the report for review
        let reportURL = "\(FirebaseConfig.databaseURL)/reports.json"
        guard let url = URL(string: reportURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let report: [String: Any] = [
            "snippetId": snippetId,
            "reason": reason,
            "reporterDeviceId": DeviceIdentity.shared.deviceId,
            "timestamp": Date().timeIntervalSince1970 * 1000
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: report)
        URLSession.shared.dataTask(with: request).resume()
    }

    private func incrementCounter(snippetId: String, field: String) {
        let url = "\(FirebaseConfig.databaseURL)/shared_snippets/\(snippetId)/\(field).json"
        guard let requestURL = URL(string: url) else { return }

        // First get current value
        URLSession.shared.dataTask(with: requestURL) { data, _, _ in
            let currentValue = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? Int }) ?? 0

            var request = URLRequest(url: requestURL)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = "\(currentValue + 1)".data(using: .utf8)

            URLSession.shared.dataTask(with: request).resume()
        }.resume()
    }

    // MARK: - Analytics

    func trackEvent(_ eventType: AnalyticsEventType, category: String? = nil, metadata: [String: String]? = nil) {
        guard FirebaseConfig.isConfigured else { return }

        let event = AnalyticsEvent(event: eventType.rawValue, category: category, metadata: metadata)

        guard let url = URL(string: FirebaseConfig.analyticsURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? encoder.encode(event)

        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: - Search Community

    func searchCommunity(query: String) {
        // For simple search, fetch all and filter locally
        // For production, consider Algolia or Firebase Extensions
        fetchCommunitySnippets()

        // Filter will be applied via UI
    }

    var filteredCommunitySnippets: (String) -> [SharedSnippet] = { query in
        return []
    }

    func filterCommunity(by query: String) -> [SharedSnippet] {
        guard !query.isEmpty else { return communitySnippets }

        let lowercased = query.lowercased()
        return communitySnippets.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.content.lowercased().contains(lowercased) ||
            $0.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }
}

// MARK: - Errors

enum FirebaseError: LocalizedError {
    case notConfigured
    case invalidURL
    case encodingFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Firebase is not configured. Update FirebaseConfig.swift"
        case .invalidURL: return "Invalid Firebase URL"
        case .encodingFailed: return "Failed to encode data"
        case .invalidResponse: return "Invalid response from Firebase"
        }
    }
}
