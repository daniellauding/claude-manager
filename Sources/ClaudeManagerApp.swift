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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var badgeTimer: Timer?
    var processManager: ClaudeProcessManager!
    var snippetManager: SnippetManager!
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        // Create popover with shared managers
        popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 500)
        popover.behavior = .transient  // Close when clicking outside
        popover.contentViewController = NSHostingController(
            rootView: ContentView(manager: processManager, snippetManager: snippetManager)
        )

        // Monitor for clicks outside popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
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
        alert.informativeText = "Version 1.3.1\n\nManage Claude CLI instances and snippets from your menu bar.\n\ngithub.com/daniellauding/claude-manager"
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
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
