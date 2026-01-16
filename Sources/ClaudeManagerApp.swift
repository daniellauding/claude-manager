import SwiftUI
import AppKit

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create shared managers
        processManager = ClaudeProcessManager()
        snippetManager = SnippetManager()

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateMenuBarIcon(count: 0)
            button.action = #selector(togglePopover)
        }

        // Create popover with shared managers
        popover = NSPopover()
        popover.contentSize = NSSize(width: 520, height: 550)
        popover.behavior = .applicationDefined  // Don't close when clicking outside
        popover.contentViewController = NSHostingController(
            rootView: ContentView(manager: processManager, snippetManager: snippetManager)
        )

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Start badge update timer
        startBadgeTimer()
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
