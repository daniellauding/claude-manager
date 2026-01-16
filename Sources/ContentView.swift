import SwiftUI

// MARK: - Color Theme (Monochrome)
extension Color {
    static let cmBackground = Color(NSColor.windowBackgroundColor)
    static let cmCardBg = Color(NSColor.controlBackgroundColor)
    static let cmBorder = Color(NSColor.separatorColor)
    static let cmText = Color(NSColor.labelColor)
    static let cmSecondary = Color(NSColor.secondaryLabelColor)
    static let cmTertiary = Color(NSColor.tertiaryLabelColor)
}

enum AppTab: String, CaseIterable {
    case home = "Home"
    case instances = "Instances"
    case snippets = "Library"
    case news = "News"

    var icon: String {
        switch self {
        case .home: return "house"
        case .instances: return "terminal"
        case .snippets: return "books.vertical"
        case .news: return "newspaper"
        }
    }

    var keyboardShortcut: String {
        switch self {
        case .home: return "0"
        case .instances: return "1"
        case .snippets: return "2"
        case .news: return "3"
        }
    }
}

struct ContentView: View {
    @ObservedObject var manager: ClaudeProcessManager
    @ObservedObject var snippetManager: SnippetManager
    @StateObject private var newsManager = NewsManager()
    @State private var showingKillConfirmation = false
    @State private var instanceToKill: ClaudeInstance?
    @State private var expandedInstances: Set<Int32> = []

    // Remember last tab
    @State private var selectedTab: AppTab = {
        if let saved = UserDefaults.standard.string(forKey: "lastTab"),
           let tab = AppTab(rawValue: saved) {
            return tab
        }
        return .home
    }()

    // New UI states
    @State private var showingSettings = false
    @State private var showingWhatsNew = false
    // Onboarding disabled for now
    @State private var showingOnboarding = false // !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    init(manager: ClaudeProcessManager, snippetManager: SnippetManager) {
        self.manager = manager
        self.snippetManager = snippetManager
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Tab bar
                tabBar

                Divider()

                // Content based on selected tab
                switch selectedTab {
                case .home:
                    DashboardView(
                        processManager: manager,
                        snippetManager: snippetManager,
                        newsManager: newsManager,
                        onNavigate: { tab in
                            selectedTab = tab
                            UserDefaults.standard.set(tab.rawValue, forKey: "lastTab")
                        }
                    )
                case .instances:
                    instancesContent
                case .snippets:
                    SnippetView(manager: snippetManager)
                case .news:
                    NewsView(manager: newsManager)
                }

                Divider()

                // Footer
                footerView
            }

            // Overlay views
            if showingSettings {
                SettingsView(snippetManager: snippetManager, isPresented: $showingSettings)
                    .transition(.move(edge: .trailing))
            }

            if showingWhatsNew {
                WhatsNewView(isPresented: $showingWhatsNew)
                    .transition(.move(edge: .trailing))
            }

            if showingOnboarding {
                OnboardingView(isPresented: $showingOnboarding)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 520, maxWidth: 800, minHeight: 450, maxHeight: 900)
        .background(Color.cmBackground)
        .onAppear {
            manager.refresh()
        }
        .alert("Stop Instance?", isPresented: $showingKillConfirmation, presenting: instanceToKill) { instance in
            Button("Cancel", role: .cancel) {}
            Button("Stop", role: .destructive) {
                manager.killInstance(instance)
            }
        } message: { instance in
            Text("Stop Claude process \(instance.pid)?")
        }
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))

                        // Badge for instances
                        if tab == .instances && !manager.instances.isEmpty {
                            Text("\(manager.instances.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(selectedTab == tab ? .cmBackground : .cmSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(selectedTab == tab ? Color.cmText : Color.cmBorder)
                                .cornerRadius(8)
                        }

                        // Badge for snippets
                        if tab == .snippets && !snippetManager.snippets.isEmpty {
                            Text("\(snippetManager.snippets.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(selectedTab == tab ? .cmBackground : .cmSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(selectedTab == tab ? Color.cmText : Color.cmBorder)
                                .cornerRadius(8)
                        }
                    }
                    .foregroundColor(selectedTab == tab ? .cmText : .cmSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Color.cmBorder.opacity(0.3) : Color.clear)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(tab.keyboardShortcut)), modifiers: .command)
                .onChange(of: selectedTab) { newTab in
                    UserDefaults.standard.set(newTab.rawValue, forKey: "lastTab")
                }
            }

            Spacer()

            // Actions for current tab
            if selectedTab == .instances {
                Button(action: { launchClaude() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.cmText)
                .keyboardShortcut("n", modifiers: .command)
                .help("New Claude session (Cmd+N)")

                Button(action: { manager.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .rotationEffect(.degrees(manager.isLoading ? 360 : 0))
                        .animation(manager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isLoading)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.cmText)
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh (Cmd+R)")
                .padding(.trailing, 16)
            }
        }
    }

    // MARK: - Instances Content
    private var instancesContent: some View {
        VStack(spacing: 0) {
            // Header with stats
            if !manager.instances.isEmpty {
                HStack {
                    let totalCPU = manager.instances.reduce(0.0) { $0 + $1.cpuPercent }
                    let totalMem = manager.instances.reduce(0) { $0 + $1.memoryKB }
                    Text("\(manager.instances.count) instances \u{00B7} \(String(format: "%.0f%%", totalCPU)) CPU \u{00B7} \(formatMemory(totalMem))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.cmSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.cmBorder.opacity(0.1))
            }

            // Content
            if manager.instances.isEmpty {
                emptyStateView
            } else {
                instanceListView
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.cmTertiary)

            Text("No Claude instances running")
                .font(.system(size: 13))
                .foregroundColor(.cmSecondary)

            Button(action: { launchClaude() }) {
                Text("Start Claude")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cmBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cmText)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Text("⌘N")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.cmTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Instance List
    private var instanceListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(manager.instances) { instance in
                    InstanceRow(
                        instance: instance,
                        isExpanded: expandedInstances.contains(instance.pid),
                        onToggleExpand: {
                            if expandedInstances.contains(instance.pid) {
                                expandedInstances.remove(instance.pid)
                            } else {
                                expandedInstances.insert(instance.pid)
                            }
                        },
                        onFocus: { focusInstance($0) },
                        onKill: { inst, force in
                            if force {
                                manager.killInstance(inst, force: true)
                            } else {
                                instanceToKill = inst
                                showingKillConfirmation = true
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack(spacing: 12) {
            // Left side - context actions
            if selectedTab == .instances {
                if !manager.instances.isEmpty {
                    Button(action: {
                        if expandedInstances.isEmpty {
                            expandedInstances = Set(manager.instances.map { $0.pid })
                        } else {
                            expandedInstances.removeAll()
                        }
                    }) {
                        Text(expandedInstances.isEmpty ? "Expand All" : "Collapse All")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.cmSecondary)

                    Button(action: { manager.killAll() }) {
                        Text("Stop All")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.cmSecondary)
                }
            } else {
                // Library tab footer
                if !snippetManager.watchedFolders.isEmpty {
                    Text("\(snippetManager.watchedFolders.count) folder(s) watched")
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary)
                }
            }

            Spacer()

            // What's New button
            Button(action: { showingWhatsNew = true }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.cmSecondary)
            .help("What's New")

            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.cmSecondary)
            .help("Settings")

            // Quit button
            Button(action: { NSApp.terminate(nil) }) {
                Text("Quit")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.cmSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions
    private func launchClaude() {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "open -a Terminal && sleep 0.5 && osascript -e 'tell application \"Terminal\" to do script \"claude\"'"]
        try? task.run()
    }

    private func focusInstance(_ instance: ClaudeInstance) {
        let terminalScript: String
        if instance.type == .happy {
            terminalScript = "tell application \"Warp\" to activate"
        } else {
            terminalScript = """
            tell application "Terminal"
                activate
                set windowList to every window
                repeat with w in windowList
                    try
                        if tty of w contains "\(instance.tty ?? "")" then
                            set frontmost of w to true
                            exit repeat
                        end if
                    end try
                end repeat
            end tell
            """
        }

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", terminalScript]
        try? task.run()
    }

    private func formatMemory(_ kb: Int) -> String {
        if kb > 1_048_576 {
            return String(format: "%.1fG", Double(kb) / 1_048_576)
        } else if kb > 1024 {
            return String(format: "%.0fM", Double(kb) / 1024)
        } else {
            return "\(kb)K"
        }
    }
}

// MARK: - Instance Row
struct InstanceRow: View {
    let instance: ClaudeInstance
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onFocus: (ClaudeInstance) -> Void
    let onKill: (ClaudeInstance, Bool) -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row - clickable
            HStack(spacing: 10) {
                // Expand/collapse chevron
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cmTertiary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                // Index badge
                Text("\(instance.index)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cmTertiary)
                    .frame(width: 14)

                // PID
                Text("\(instance.pid)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.cmText)

                // Type badge with tooltip
                HStack(spacing: 4) {
                    if instance.isSSH {
                        Image(systemName: "network")
                            .font(.system(size: 9))
                    }
                    Text(instance.type.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.cmSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.cmBorder.opacity(0.5))
                .cornerRadius(3)
                .help(instance.type.description)

                // Session title (if available)
                if let title = instance.sessionTitle {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                // Duration
                Text(instance.elapsed)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cmSecondary)

                // Stats
                HStack(spacing: 8) {
                    Text(String(format: "%.0f%%", instance.cpuPercent))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.cmTertiary)
                    Text(formatMemory(instance.memoryKB))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.cmTertiary)
                }
                .frame(width: 70, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onFocus(instance)
            }
            .padding(.vertical, 8)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .padding(.leading, 36)

                    // Time info
                    DetailRow(icon: "clock", label: "Started", value: instance.startTimeFormatted)

                    // TTY
                    if let tty = instance.tty, tty != "??" {
                        DetailRow(icon: "terminal", label: "TTY", value: tty)
                    }

                    // Working directory
                    if let folder = instance.folder {
                        DetailRow(icon: "folder", label: "Directory", value: folder, selectable: true)
                    }

                    // Git branch
                    if let branch = instance.gitBranch {
                        DetailRow(icon: "arrow.triangle.branch", label: "Branch", value: branch)
                    }

                    // Session ID
                    if let sessionId = instance.sessionId {
                        DetailRow(icon: "number", label: "Session", value: sessionId, selectable: true)
                    }

                    // First prompt
                    if let prompt = instance.prompt {
                        DetailRow(icon: "text.quote", label: "Prompt", value: "\"\(prompt)\"", italic: true)
                    }

                    // Parent process chain
                    if let chain = instance.parentChain {
                        DetailRow(icon: "arrow.right.arrow.left", label: "Parents", value: chain)
                    }

                    // SSH indicator with more info
                    if instance.isSSH {
                        DetailRow(icon: "network", label: "SSH", value: "Running over SSH connection")
                    }

                    // Type explanation
                    DetailRow(icon: "info.circle", label: "Type Info", value: instance.type.description)

                    Divider()
                        .padding(.leading, 36)

                    // Actions row
                    HStack(spacing: 12) {
                        // Focus Terminal disabled - needs terminal integration
                        // Button(action: { onFocus(instance) }) { ... }

                        Button(action: { copyLaunchCommand() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                Text("Copy Launch Cmd")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.cmSecondary)

                        if let folder = instance.folder {
                            Button(action: { copyToClipboard(folder) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 10))
                                    Text("Copy Path")
                                        .font(.system(size: 10, weight: .medium))
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.cmSecondary)
                        }

                        Spacer()

                        Button(action: { onKill(instance, false) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop")
                                    .font(.system(size: 10))
                                Text("Stop")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.cmSecondary)

                        Button(action: { onKill(instance, true) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10))
                                Text("Force Kill")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.cmSecondary.opacity(0.8))
                    }
                    .padding(.leading, 36)
                    .padding(.top, 4)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 16)
        .background(isHovering ? Color.cmBorder.opacity(0.2) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func formatMemory(_ kb: Int) -> String {
        if kb > 1_048_576 {
            return String(format: "%.1fG", Double(kb) / 1_048_576)
        } else if kb > 1024 {
            return String(format: "%.0fM", Double(kb) / 1024)
        } else {
            return "\(kb)K"
        }
    }

    private func copyLaunchCommand() {
        copyToClipboard(instance.launchCommand)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var selectable: Bool = false
    var italic: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.cmTertiary)
                .frame(width: 12)

            Text(label + ":")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.cmTertiary)
                .frame(width: 60, alignment: .leading)

            if selectable {
                Text(value)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cmSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.system(size: 10))
                    .italic(italic)
                    .foregroundColor(.cmSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.leading, 36)
    }
}

#Preview {
    ContentView(manager: ClaudeProcessManager(), snippetManager: SnippetManager())
}
