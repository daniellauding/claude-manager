import Foundation
import Network
import Combine

// MARK: - Connection Type

enum ConnectionType: String {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case wired = "Wired"
    case unknown = "Unknown"
}

// MARK: - Network Monitor

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive: Bool = false // Cellular/hotspot
    @Published var isConstrained: Bool = false // Low data mode

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }

    private func updateConnectionStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wired
        } else {
            connectionType = .unknown
        }

        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .networkStatusChanged,
            object: nil,
            userInfo: ["isConnected": isConnected, "connectionType": connectionType.rawValue]
        )
    }

    // MARK: - Public Methods

    /// Check if we can perform network operations
    var canPerformNetworkOperations: Bool {
        return isConnected
    }

    /// Check if we should defer large downloads (on cellular/constrained)
    var shouldDeferLargeOperations: Bool {
        return isExpensive || isConstrained
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}
