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

struct ContentView: View {
    @StateObject private var manager = ClaudeProcessManager()
    @State private var showingKillConfirmation = false
    @State private var instanceToKill: ClaudeInstance?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            if manager.instances.isEmpty {
                emptyStateView
            } else {
                instanceListView
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 440, height: 540)
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

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.cmText)

            Text("Claude Manager")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.cmText)

            Spacer()

            // Stats summary
            if !manager.instances.isEmpty {
                let totalCPU = manager.instances.reduce(0.0) { $0 + $1.cpuPercent }
                let totalMem = manager.instances.reduce(0) { $0 + $1.memoryKB }
                Text("\(manager.instances.count) · \(String(format: "%.0f%%", totalCPU)) · \(formatMemory(totalMem))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cmSecondary)
            }

            Button(action: { launchClaude() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.cmText)
            .help("New Claude session (⌘N)")

            Button(action: { manager.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .rotationEffect(.degrees(manager.isLoading ? 360 : 0))
                    .animation(manager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isLoading)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.cmText)
            .help("Refresh")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        HStack(spacing: 16) {
            if !manager.instances.isEmpty {
                Button(action: { manager.killAll() }) {
                    Text("Stop All")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.cmSecondary)
            }

            Spacer()

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
    let onFocus: (ClaudeInstance) -> Void
    let onKill: (ClaudeInstance, Bool) -> Void

    @State private var isHovering = false
    @State private var showActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main row - clickable
            HStack(spacing: 12) {
                // Index badge
                Text("\(instance.index)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cmTertiary)
                    .frame(width: 16)

                // PID
                Text("\(instance.pid)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.cmText)

                // Type badge
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

            // Details (shown on hover or always for info)
            if isHovering || instance.folder != nil || instance.prompt != nil {
                VStack(alignment: .leading, spacing: 4) {
                    // Started time
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(instance.startTimeFormatted)
                            .font(.system(size: 10))
                        if let tty = instance.tty, tty != "??" {
                            Text("·")
                            Text(tty)
                                .font(.system(size: 10, design: .monospaced))
                        }
                    }
                    .foregroundColor(.cmTertiary)

                    // Folder
                    if let folder = instance.folder {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: 9))
                            Text(folder)
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .foregroundColor(.cmTertiary)
                    }

                    // Prompt
                    if let prompt = instance.prompt {
                        HStack(spacing: 6) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 9))
                            Text("\"\(prompt)\"")
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .italic()
                        }
                        .foregroundColor(.cmTertiary)
                    }
                }
                .padding(.leading, 28)
            }

            // Actions (shown on hover)
            if isHovering {
                HStack(spacing: 12) {
                    Button(action: { onFocus(instance) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10))
                            Text("Focus")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.cmSecondary)

                    Button(action: { copyLaunchCommand() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Copy")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.cmSecondary)

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
                            Text("Force")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.cmSecondary)
                }
                .padding(.leading, 28)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovering ? Color.cmBorder.opacity(0.3) : Color.clear)
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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(instance.launchCommand, forType: .string)
    }
}

#Preview {
    ContentView()
}
