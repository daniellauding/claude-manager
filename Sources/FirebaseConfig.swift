import Foundation

// MARK: - Firebase Configuration
//
// SETUP INSTRUCTIONS:
// 1. Go to https://console.firebase.google.com/
// 2. Create a new project (or use existing)
// 3. Click "Build" → "Realtime Database" → "Create Database"
// 4. Choose "Start in test mode" for now (we'll secure it later)
// 5. Copy your database URL (e.g., https://your-project.firebaseio.com)
// 6. Go to Project Settings → General → Web API Key
// 7. Update the values below
//
// SECURITY RULES (paste in Firebase Console → Realtime Database → Rules):
// {
//   "rules": {
//     "shared_snippets": {
//       ".read": true,
//       ".write": true,
//       ".indexOn": ["category", "createdAt", "likes"]
//     },
//     "analytics": {
//       ".read": false,
//       ".write": true
//     },
//     "users": {
//       "$deviceId": {
//         ".read": "auth == null",
//         ".write": "auth == null"
//       }
//     }
//   }
// }

struct FirebaseConfig {
    // TODO: Replace with your Firebase project values
    static let databaseURL = "https://claude-manager-f2f10-default-rtdb.firebaseio.com"
    static let apiKey = "AIzaSyBBbOAoykgj8DHVnZVZHG0t5cGc1MjPYWc"

    // Endpoints
    static var sharedSnippetsURL: String { "\(databaseURL)/shared_snippets.json" }
    static var analyticsURL: String { "\(databaseURL)/analytics.json" }
    static func userURL(deviceId: String) -> String { "\(databaseURL)/users/\(deviceId).json" }

    // Check if Firebase is configured
    static var isConfigured: Bool {
        return apiKey != "YOUR_WEB_API_KEY" && !databaseURL.contains("your-project")
    }
}

// MARK: - Device Identity (Anonymous)

class DeviceIdentity {
    static let shared = DeviceIdentity()

    private let deviceIdKey = "com.claudemanager.deviceId"
    private let userDefaultsKey = "firebase_device_id"

    var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: userDefaultsKey) {
            return existing
        }

        // Generate new anonymous ID
        let newId = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        UserDefaults.standard.set(newId, forKey: userDefaultsKey)
        return newId
    }

    // Optional: nickname for attribution
    var nickname: String? {
        get { UserDefaults.standard.string(forKey: "firebase_nickname") }
        set { UserDefaults.standard.set(newValue, forKey: "firebase_nickname") }
    }
}
