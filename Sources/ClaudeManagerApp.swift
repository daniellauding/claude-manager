import SwiftUI
import AppKit
import ServiceManagement

@main
struct ClaudeManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// Notification for magic link invites
extension Notification.Name {
    static let teamInviteReceived = Notification.Name("teamInviteReceived")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var badgeTimer: Timer?
    var processManager: ClaudeProcessManager!
    var snippetManager: SnippetManager!
    var eventMonitor: Any?

    // Pending invite token from URL scheme
    static var pendingInviteToken: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance check - quit if already running
        let runningApps = NSWorkspace.shared.runningApplications
        let isAlreadyRunning = runningApps.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }.count > 0

        if isAlreadyRunning {
            NSApp.terminate(nil)
            return
        }

        // Register URL scheme handler
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        // Initialize network monitoring (starts automatically)
        _ = NetworkMonitor.shared

        // Create shared managers
        processManager = ClaudeProcessManager()
        snippetManager = SnippetManager()

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateMenuBarIcon(count: 0)
            button.action = #selector(handleStatusBarClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create floating panel (resizable window)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Claude Manager"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 400, height: 400)
        panel.maxSize = NSSize(width: 1200, height: 1200)
        panel.contentViewController = NSHostingController(
            rootView: ContentView(manager: processManager, snippetManager: snippetManager)
        )

        // Monitor for clicks outside to close
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return }
            // Check if click is outside the panel
            let clickLocation = event.locationInWindow
            if !self.panel.frame.contains(NSEvent.mouseLocation) {
                self.panel.orderOut(nil)
            }
        }

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Start badge update timer
        startBadgeTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc func handleStatusBarClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func showContextMenu() {
        let menu = NSMenu()

        // Instance count
        let instanceCount = processManager.instances.count
        let instanceItem = NSMenuItem(title: "\(instanceCount) Claude instance\(instanceCount == 1 ? "" : "s")", action: nil, keyEquivalent: "")
        instanceItem.isEnabled = false
        menu.addItem(instanceItem)

        menu.addItem(NSMenuItem.separator())

        // Quick actions
        menu.addItem(NSMenuItem(title: "New Claude Session", action: #selector(launchNewClaude), keyEquivalent: "n"))

        if instanceCount > 0 {
            menu.addItem(NSMenuItem(title: "Stop All Instances", action: #selector(stopAllInstances), keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())

        // Launch at Login
        let launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        // About
        menu.addItem(NSMenuItem(title: "About Claude Manager", action: #selector(showAbout), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit Claude Manager", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // Reset to allow left-click popover
    }

    @objc func launchNewClaude() {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "open -a Terminal && sleep 0.5 && osascript -e 'tell application \"Terminal\" to do script \"claude\"'"]
        try? task.run()
    }

    @objc func stopAllInstances() {
        processManager.killAll()
    }

    @objc func toggleLaunchAtLogin() {
        let currentValue = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let newValue = !currentValue
        UserDefaults.standard.set(newValue, forKey: "launchAtLogin")

        // Use SMAppService for macOS 13+
        if #available(macOS 13.0, *) {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Claude Manager"
        alert.informativeText = "Version 1.4.2\n\nManage Claude CLI instances and snippets from your menu bar.\n\ngithub.com/daniellauding/claude-manager"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func startBadgeTimer() {
        // Update badge every 5 seconds
        badgeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBadge()
        }
        // Initial update
        updateBadge()
    }

    func updateBadge() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let count = self.processManager.instances.count
            self.updateMenuBarIcon(count: count)
        }
    }

    func updateMenuBarIcon(count: Int) {
        guard let button = statusItem.button else { return }

        if count == 0 {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Claude Manager")
            button.title = ""
        } else {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Claude Manager")
            button.title = " \(count)"
        }
    }

    @objc func togglePopover() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            // Position panel below status bar item
            if let button = statusItem.button, let window = button.window {
                let buttonRect = button.convert(button.bounds, to: nil)
                let screenRect = window.convertToScreen(buttonRect)
                let panelWidth = panel.frame.width
                let panelHeight = panel.frame.height
                let x = screenRect.midX - panelWidth / 2
                let y = screenRect.minY - panelHeight - 5
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - URL Scheme Handling

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        handleIncomingURL(url)
    }

    func handleIncomingURL(_ url: URL) {
        // Handle claudemanager://invite/{token} URLs
        guard url.scheme == "claudemanager" else { return }

        if url.host == "invite" {
            // Extract token from path: /token
            let token = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            if !token.isEmpty {
                AppDelegate.pendingInviteToken = token

                // Post notification for the UI to handle
                NotificationCenter.default.post(
                    name: .teamInviteReceived,
                    object: nil,
                    userInfo: ["token": token]
                )

                // Show the panel and switch to Teams tab
                showPanelWithInvite()
            }
        }
    }

    func showPanelWithInvite() {
        // Show the panel
        if !panel.isVisible {
            togglePopover()
        }

        // Post a notification to switch to Teams tab
        NotificationCenter.default.post(
            name: Notification.Name("switchToTeamsTab"),
            object: nil
        )
    }
}
