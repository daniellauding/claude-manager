import SwiftUI
import AppKit

// MARK: - App Info

struct AppInfo {
    static let version = "1.1.0"
    static let build = "2"
    static let author = "Daniel Lauding"
    static let email = "daniel@lauding.se"
    static let website = "https://www.daniellauding.se"
    static let github = "https://github.com/daniellauding/claude-manager"
}

// MARK: - Settings View (About, Export/Import)

struct SettingsView: View {
    @ObservedObject var snippetManager: SnippetManager
    @Binding var isPresented: Bool
    @State private var exportMessage: String?
    @State private var importMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11))
                        Text("Back")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Settings")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                // Spacer for balance
                Color.clear.frame(width: 50, height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.cmBackground)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // About Section
                    aboutSection

                    Divider().padding(.horizontal, 20)

                    // Export/Import Section
                    exportImportSection

                    Divider().padding(.horizontal, 20)

                    // Links Section
                    linksSection

                    Divider().padding(.horizontal, 20)

                    // Reset Section
                    resetSection

                    Divider().padding(.horizontal, 20)

                    // AI Helper Beta
                    aiHelperSection
                }
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cmBackground)
        .sheet(isPresented: $showingAIHelper) {
            AIHelperView(snippetManager: snippetManager, apiKeys: $apiKeys, isPresented: $showingAIHelper)
        }
    }

    // MARK: - AI Helper State

    @State private var showingAIHelper = false
    @State private var apiKeys = APIKeys.load()

    // MARK: - AI Helper Section

    private var aiHelperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Helper")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.cmText)

                Text("Beta")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.cmTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cmBorder.opacity(0.3))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                // API Keys config
                apiKeyField(provider: "Anthropic", key: $apiKeys.anthropic, placeholder: "sk-ant-...")
                apiKeyField(provider: "OpenAI", key: $apiKeys.openai, placeholder: "sk-...")
                apiKeyField(provider: "Google", key: $apiKeys.google, placeholder: "AIza...")
                apiKeyField(provider: "Ollama", key: $apiKeys.ollamaURL, placeholder: "http://localhost:11434")

                // Launch AI Helper
                Button(action: {
                    apiKeys.save()
                    showingAIHelper = true
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Open AI Helper")
                            .font(.system(size: 13))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundColor(.cmTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.cmText.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!apiKeys.hasAnyKey)
            }
            .padding(.horizontal, 20)

            Text("Add your API keys to use AI to improve prompts. Keys stored locally.")
                .font(.system(size: 11))
                .foregroundColor(.cmTertiary)
                .padding(.horizontal, 20)
        }
    }

    private func apiKeyField(provider: String, key: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(provider)
                .font(.system(size: 12))
                .foregroundColor(.cmSecondary)
                .frame(width: 70, alignment: .leading)

            SecureField(placeholder, text: key)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.cmBorder.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Reset Section

    @State private var showingResetConfirmation = false

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.cmText)
                .padding(.horizontal, 20)

            VStack(spacing: 8) {
                Button(action: { showingResetConfirmation = true }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.cmSecondary)
                        Text("Reset All Settings")
                            .font(.system(size: 13))
                            .foregroundColor(.cmSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.cmSecondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .alert("Reset All Settings?", isPresented: $showingResetConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        resetAllSettings()
                    }
                } message: {
                    Text("This will clear your library, news sources, and preferences. This cannot be undone.")
                }
            }
            .padding(.horizontal, 20)

            Text("Clears library, news settings, and preferences.")
                .font(.system(size: 11))
                .foregroundColor(.cmTertiary)
                .padding(.horizontal, 20)
        }
    }

    private func resetAllSettings() {
        // Clear UserDefaults
        let domain = Bundle.main.bundleIdentifier ?? "com.daniellauding.claude-manager"
        UserDefaults.standard.removePersistentDomain(forName: domain)

        // Clear data files
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        try? FileManager.default.removeItem(at: claudeDir.appendingPathComponent("snippets.json"))
        try? FileManager.default.removeItem(at: claudeDir.appendingPathComponent("news.json"))

        // Reset managers
        snippetManager.snippets.removeAll()
        snippetManager.watchedFolders.removeAll()

        // Close settings
        isPresented = false
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 16) {
            // App Icon & Name
            VStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.cmText)

                Text("Claude Manager")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cmText)

                Text("Version \(AppInfo.version) (\(AppInfo.build))")
                    .font(.system(size: 12))
                    .foregroundColor(.cmTertiary)
            }

            // Description
            Text("A menu bar app for managing Claude CLI instances and building your prompt library.")
                .font(.system(size: 12))
                .foregroundColor(.cmSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Author
            VStack(spacing: 4) {
                Text("Created by")
                    .font(.system(size: 11))
                    .foregroundColor(.cmTertiary)

                Button(action: {
                    if let url = URL(string: AppInfo.website) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text(AppInfo.author)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.cmText)
                }
                .buttonStyle(.plain)

                Text("Design Engineer")
                    .font(.system(size: 11))
                    .foregroundColor(.cmTertiary)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Export/Import Section

    private var exportImportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Library Backup")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.cmText)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                // Export Button
                Button(action: exportLibrary) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("Export Library")
                            .font(.system(size: 13))
                        Spacer()
                        Text("\(snippetManager.snippets.count) items")
                            .font(.system(size: 11))
                            .foregroundColor(.cmTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.cmBorder.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Import Button
                Button(action: importLibrary) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        Text("Import Library")
                            .font(.system(size: 13))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(.cmTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.cmBorder.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Status messages
                if let message = exportMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.cmText)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(.cmSecondary)
                    }
                }

                if let message = importMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.cmText)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(.cmSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            Text("Export creates a .cmlib file you can share or back up. Import merges with your existing library.")
                .font(.system(size: 11))
                .foregroundColor(.cmTertiary)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Links Section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Links")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.cmText)
                .padding(.horizontal, 20)

            VStack(spacing: 8) {
                linkButton(
                    icon: "globe",
                    title: "Website",
                    subtitle: "daniellauding.se",
                    url: AppInfo.website
                )

                linkButton(
                    icon: "envelope",
                    title: "Contact",
                    subtitle: AppInfo.email,
                    url: "mailto:\(AppInfo.email)"
                )

                linkButton(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "GitHub",
                    subtitle: "Source code & issues",
                    url: AppInfo.github
                )

                linkButton(
                    icon: "ant",
                    title: "Report Bug / Feature Request",
                    subtitle: "Help improve Claude Manager",
                    url: "mailto:\(AppInfo.email)?subject=Claude%20Manager%20Feedback"
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func linkButton(icon: String, title: String, subtitle: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.cmSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(.cmText)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.cmTertiary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.cmBorder.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export/Import Actions

    private func exportLibrary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "claude-library-\(dateString()).cmlib"
        panel.title = "Export Library"
        panel.message = "Choose where to save your library backup"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if snippetManager.exportLibrary(to: url) {
                    exportMessage = "Exported \(snippetManager.snippets.count) items"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        exportMessage = nil
                    }
                }
            }
        }
    }

    private func importLibrary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Import Library"
        panel.message = "Select a .cmlib file to import"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let count = snippetManager.importLibrary(from: url)
                if count > 0 {
                    importMessage = "Imported \(count) new items"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        importMessage = nil
                    }
                } else {
                    importMessage = "No new items to import"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        importMessage = nil
                    }
                }
            }
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, description: String)] = [
        (
            "terminal.fill",
            "Welcome to Claude Manager",
            "Your menu bar companion for Claude Code. Monitor sessions, save prompts, and build your AI toolkit."
        ),
        (
            "square.stack.3d.up",
            "Monitor Claude Instances",
            "See all running Claude sessions at a glance. Click to focus, view details, or stop instances."
        ),
        (
            "books.vertical",
            "Build Your Library",
            "Save prompts, agents, workflows, and hooks. Organize with categories, tags, and favorites."
        ),
        (
            "sparkles",
            "Discover & Share",
            "Explore curated prompts and MCP configs. Export your library to share with others."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: pages[currentPage].icon)
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.cmText)
                    .frame(height: 60)

                // Text
                VStack(spacing: 12) {
                    Text(pages[currentPage].title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.cmText)

                    Text(pages[currentPage].description)
                        .font(.system(size: 13))
                        .foregroundColor(.cmSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.cmText : Color.cmBorder)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 20)

                // Navigation
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.cmSecondary)
                    }

                    Spacer()

                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                            isPresented = false
                        }
                    }) {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.cmBackground)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.cmText)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cmBackground)
    }
}

// MARK: - What's New View

struct WhatsNewView: View {
    @Binding var isPresented: Bool

    private let updates: [(version: String, date: String, items: [String])] = [
        (
            "1.1.0",
            "January 2025",
            [
                "New: Hooks category for Claude Code automation",
                "New: Workflows category for multi-step processes",
                "New: Category-specific empty state guides",
                "New: Export/Import library feature",
                "New: Onboarding for new users",
                "Changed: Renamed Snippets tab to Library",
                "Added: 4 hook examples and 6 workflow templates"
            ]
        ),
        (
            "1.0.0",
            "January 2025",
            [
                "Initial release",
                "Monitor Claude CLI instances",
                "Snippets library with categories",
                "Discover curated prompts and MCP configs",
                "Folder watching for auto-import",
                "GitHub search integration"
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11))
                        Text("Back")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("What's New")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Color.clear.frame(width: 50, height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.cmBackground)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(updates, id: \.version) { update in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("v\(update.version)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.cmText)

                                Spacer()

                                Text(update.date)
                                    .font(.system(size: 11))
                                    .foregroundColor(.cmTertiary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(update.items, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle()
                                            .fill(itemColor(for: item))
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 5)

                                        Text(item)
                                            .font(.system(size: 12))
                                            .foregroundColor(.cmSecondary)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.cmBorder.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cmBackground)
    }

    private func itemColor(for item: String) -> Color {
        if item.hasPrefix("New:") {
            return .cmText
        } else if item.hasPrefix("Changed:") || item.hasPrefix("Added:") {
            return .cmText
        } else if item.hasPrefix("Fixed:") {
            return .cmSecondary
        }
        return .cmTertiary
    }
}

// MARK: - API Keys Storage

struct APIKeys: Codable {
    var anthropic: String = ""
    var openai: String = ""
    var google: String = ""
    var ollamaURL: String = ""

    var hasAnyKey: Bool {
        !anthropic.isEmpty || !openai.isEmpty || !google.isEmpty || !ollamaURL.isEmpty
    }

    var preferredProvider: String? {
        if !anthropic.isEmpty { return "anthropic" }
        if !openai.isEmpty { return "openai" }
        if !google.isEmpty { return "google" }
        if !ollamaURL.isEmpty { return "ollama" }
        return nil
    }

    static func load() -> APIKeys {
        guard let data = UserDefaults.standard.data(forKey: "apiKeys"),
              let keys = try? JSONDecoder().decode(APIKeys.self, from: data) else {
            return APIKeys()
        }
        return keys
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "apiKeys")
        }
    }
}

// MARK: - AI Helper View

struct AIHelperView: View {
    @ObservedObject var snippetManager: SnippetManager
    @Binding var apiKeys: APIKeys
    @Binding var isPresented: Bool

    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedAction: AIAction = .improve
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    enum AIAction: String, CaseIterable {
        case improve = "Improve"
        case expand = "Expand"
        case simplify = "Simplify"
        case convertToAgent = "Convert to Agent"
        case addExamples = "Add Examples"

        var prompt: String {
            switch self {
            case .improve:
                return "Improve this prompt to be clearer, more specific, and more effective. Keep the same intent but make it better:"
            case .expand:
                return "Expand this prompt with more detail, context, and instructions while keeping the core intent:"
            case .simplify:
                return "Simplify this prompt to be more concise and direct while preserving the key requirements:"
            case .convertToAgent:
                return "Convert this into a well-structured agent prompt that defines a persona, expertise, and behavior patterns:"
            case .addExamples:
                return "Add 2-3 concrete examples to this prompt to better illustrate the expected output format:"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11))
                        Text("Back")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                    Text("AI Helper")
                        .font(.system(size: 13, weight: .medium))
                    Text("Beta")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.cmTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.cmBorder.opacity(0.3))
                        .cornerRadius(3)
                }

                Spacer()

                if let provider = apiKeys.preferredProvider {
                    Text("Using \(provider.capitalized)")
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Action selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AIAction.allCases, id: \.self) { action in
                        Button(action: { selectedAction = action }) {
                            Text(action.rawValue)
                                .font(.system(size: 11, weight: selectedAction == action ? .medium : .regular))
                                .foregroundColor(selectedAction == action ? .cmText : .cmSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedAction == action ? Color.cmBorder.opacity(0.3) : Color.clear)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            Divider()

            // Content area
            ScrollView {
                VStack(spacing: 16) {
                    // Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Prompt")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)

                        TextEditor(text: $inputText)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color.cmBorder.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Process button
                    Button(action: processPrompt) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                            }
                            Text(isLoading ? "Processing..." : selectedAction.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.cmBackground)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(inputText.isEmpty || isLoading ? Color.cmTertiary : Color.cmText)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty || isLoading)

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.cmSecondary)
                            .padding(12)
                            .background(Color.cmBorder.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Output
                    if !outputText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Result")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.cmSecondary)

                                Spacer()

                                // Copy button
                                Button(action: copyOutput) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 10))
                                        Text("Copy")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(.cmSecondary)
                                }
                                .buttonStyle(.plain)

                                // Save to library
                                Button(action: saveToLibrary) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 10))
                                        Text("Save to Library")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(.cmSecondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(outputText)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.cmBorder.opacity(0.15))
                                .cornerRadius(8)

                            // Saved message
                            if let saved = savedMessage {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                    Text(saved)
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.cmText)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 600)
        .background(Color.cmBackground)
    }

    // MARK: - Actions

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
    }

    private func saveToLibrary() {
        let snippet = Snippet(
            title: "AI Generated: \(selectedAction.rawValue)",
            content: outputText,
            category: selectedAction == .convertToAgent ? .agent : .prompt,
            tags: ["ai-generated"],
            project: nil,
            isFavorite: false
        )
        snippetManager.addSnippet(snippet)
        savedMessage = "Saved to Library"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            savedMessage = nil
        }
    }

    private func processPrompt() {
        guard !inputText.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        outputText = ""

        let fullPrompt = "\(selectedAction.prompt)\n\n\(inputText)"

        // Try providers in order of preference
        if !apiKeys.anthropic.isEmpty {
            callAnthropic(prompt: fullPrompt)
        } else if !apiKeys.openai.isEmpty {
            callOpenAI(prompt: fullPrompt)
        } else if !apiKeys.google.isEmpty {
            callGoogle(prompt: fullPrompt)
        } else if !apiKeys.ollamaURL.isEmpty {
            callOllama(prompt: fullPrompt)
        } else {
            isLoading = false
            errorMessage = "No API key configured"
        }
    }

    // MARK: - API Calls

    private func callAnthropic(prompt: String) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKeys.anthropic, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let content = json["content"] as? [[String: Any]],
                      let first = content.first,
                      let text = first["text"] as? String else {
                    errorMessage = "Failed to parse response"
                    return
                }
                outputText = text
            }
        }.resume()
    }

    private func callOpenAI(prompt: String) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKeys.openai)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let message = first["message"] as? [String: Any],
                      let text = message["content"] as? String else {
                    errorMessage = "Failed to parse response"
                    return
                }
                outputText = text
            }
        }.resume()
    }

    private func callGoogle(prompt: String) {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(apiKeys.google)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let first = candidates.first,
                      let content = first["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let firstPart = parts.first,
                      let text = firstPart["text"] as? String else {
                    errorMessage = "Failed to parse response"
                    return
                }
                outputText = text
            }
        }.resume()
    }

    private func callOllama(prompt: String) {
        guard let url = URL(string: "\(apiKeys.ollamaURL)/api/generate") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "llama3.2",
            "prompt": prompt,
            "stream": false
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let text = json["response"] as? String else {
                    errorMessage = "Failed to parse response. Make sure Ollama is running."
                    return
                }
                outputText = text
            }
        }.resume()
    }
}
