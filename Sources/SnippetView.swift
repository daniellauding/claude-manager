import SwiftUI
import AppKit

struct SnippetView: View {
    @ObservedObject var manager: SnippetManager
    @State private var expandedSnippets: Set<UUID> = []
    @State private var showingAddSheet = false
    @State private var showingFolderSettings = false
    @State private var showingDiscover = false
    @State private var snippetToEdit: Snippet?
    @State private var showingDeleteConfirmation = false
    @State private var snippetToDelete: Snippet?

    var body: some View {
        Group {
            if showingDiscover {
                // Discover view (inline, not sheet)
                DiscoverView(snippetManager: manager, isPresented: $showingDiscover)
            } else {
                // Main snippets view
                VStack(spacing: 0) {
                    // Search and actions bar
                    searchBar

                    Divider()

                    // Filter bar
                    filterBar

                    Divider()

                    // Content
                    if manager.filteredSnippets.isEmpty {
                        emptyStateView
                    } else {
                        snippetListView
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            SnippetEditor(manager: manager, snippet: nil)
        }
        .sheet(item: $snippetToEdit) { snippet in
            SnippetEditor(manager: manager, snippet: snippet)
        }
        .sheet(isPresented: $showingFolderSettings) {
            FolderSettingsView(manager: manager)
        }
        .alert("Delete Snippet?", isPresented: $showingDeleteConfirmation, presenting: snippetToDelete) { snippet in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                manager.deleteSnippet(snippet)
            }
        } message: { snippet in
            Text("Delete \"\(snippet.title)\"? This cannot be undone.")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.cmTertiary)

                TextField("Search...", text: $manager.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !manager.searchText.isEmpty {
                    Button(action: { manager.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.cmTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.cmBorder.opacity(0.2))
            .cornerRadius(8)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { showingDiscover = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("Discover")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.cmSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cmBorder.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Find prompts on GitHub")

                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.cmSecondary)
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .help("Create new")

                Button(action: { showingFolderSettings = true }) {
                    Image(systemName: "folder")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.cmSecondary)
                .help("Manage folders")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "All", isSelected: manager.currentFilter == .all) {
                    manager.currentFilter = .all
                }

                FilterChip(label: "Favorites", icon: "star", isSelected: manager.currentFilter == .favorites) {
                    manager.currentFilter = .favorites
                }

                FilterChip(label: "Recent", icon: "clock", isSelected: manager.currentFilter == .recent) {
                    manager.currentFilter = .recent
                }

                // Category filters - only show main ones
                ForEach([SnippetCategory.agent, .skill, .prompt, .template, .mcp], id: \.self) { category in
                    FilterChip(
                        label: category.displayName,
                        isSelected: manager.currentFilter == .category(category)
                    ) {
                        manager.currentFilter = .category(category)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Show category-specific icon and guide
            if case .category(let cat) = manager.currentFilter {
                categoryEmptyState(for: cat)
            } else if manager.snippets.isEmpty {
                genericEmptyState
            } else {
                noResultsState
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var genericEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.cmTertiary.opacity(0.6))

            VStack(spacing: 8) {
                Text("Your Library is Empty")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.cmSecondary)

                Text("Save prompts, agents, hooks, and workflows")
                    .font(.system(size: 12))
                    .foregroundColor(.cmTertiary)
            }

            VStack(spacing: 16) {
                Button(action: { showingAddSheet = true }) {
                    Text("Create New")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmBackground)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.cmText)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: { showingFolderSettings = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text("Import from folder")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.cmTertiary)
            }
            .padding(.top, 8)
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundColor(.cmTertiary.opacity(0.6))

            Text("No results")
                .font(.system(size: 14))
                .foregroundColor(.cmSecondary)

            Button(action: {
                manager.searchText = ""
                manager.currentFilter = .all
            }) {
                Text("Clear filters")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.cmTertiary)
        }
    }

    private func categoryEmptyState(for category: SnippetCategory) -> some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.cmTertiary.opacity(0.6))

            VStack(spacing: 8) {
                Text("No \(category.displayName)s yet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.cmSecondary)

                Text(categoryDescription(for: category))
                    .font(.system(size: 12))
                    .foregroundColor(.cmTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 12) {
                Text(categoryHowTo(for: category))
                    .font(.system(size: 11))
                    .foregroundColor(.cmTertiary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.cmBorder.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.top, 4)

            Button(action: { showingAddSheet = true }) {
                Text("Create \(category.displayName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cmBackground)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.cmText)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private func categoryDescription(for category: SnippetCategory) -> String {
        switch category {
        case .agent:
            return "Agents are specialized AI personas with specific expertise and behavior patterns."
        case .skill:
            return "Skills are focused capabilities like code review, documentation, or testing."
        case .prompt:
            return "Prompts are reusable questions or instructions for common tasks."
        case .template:
            return "Templates provide structured output formats for consistent results."
        case .instruction:
            return "Instructions are detailed guides for Claude on how to behave in specific contexts."
        case .mcp:
            return "MCP configs connect Claude to external tools like databases, APIs, and browsers."
        case .hook:
            return "Hooks are scripts that run automatically at specific moments in Claude sessions."
        case .workflow:
            return "Workflows are multi-step processes combining multiple tools and actions."
        case .other:
            return "General snippets that don't fit other categories."
        }
    }

    private func categoryHowTo(for category: SnippetCategory) -> String {
        switch category {
        case .agent:
            return "💡 Start with: \"You are an expert in...\"\nDefine personality, expertise, and response style."
        case .skill:
            return "💡 Define a specific capability:\n\"When asked to review code, analyze for...\""
        case .prompt:
            return "💡 Create reusable prompts:\n\"Explain [concept] as if I'm a beginner.\""
        case .template:
            return "💡 Structure your output:\n\"Format the response as:\\n- Summary\\n- Details\\n- Next steps\""
        case .instruction:
            return "💡 Add to CLAUDE.md in your project:\n\"Always use TypeScript. Follow the existing patterns.\""
        case .mcp:
            return "💡 Configure in ~/.claude/mcp.json\nRun: claude mcp add <name> <command>"
        case .hook:
            return "💡 Run /hooks in Claude Code\nChoose: SessionStart, PostToolUse, Stop, etc.\nAdd your script path."
        case .workflow:
            return "💡 Document multi-step processes:\n\"Step 1: ... Step 2: ... Step 3: ...\"\nGreat for onboarding and repeatable tasks."
        case .other:
            return "💡 Any content that helps you work with Claude."
        }
    }

    // MARK: - Snippet List

    private var snippetListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(manager.filteredSnippets) { snippet in
                    SnippetRow(
                        snippet: snippet,
                        isExpanded: expandedSnippets.contains(snippet.id),
                        onToggleExpand: {
                            if expandedSnippets.contains(snippet.id) {
                                expandedSnippets.remove(snippet.id)
                            } else {
                                expandedSnippets.insert(snippet.id)
                            }
                        },
                        onCopy: { manager.copyToClipboard(snippet) },
                        onEdit: { snippetToEdit = snippet },
                        onDelete: {
                            snippetToDelete = snippet
                            showingDeleteConfirmation = true
                        },
                        onToggleFavorite: { manager.toggleFavorite(snippet) }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.cmText.opacity(0.08) : Color.clear)
            .foregroundColor(isSelected ? .cmText : .cmTertiary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Snippet Row Component

struct SnippetRow: View {
    let snippet: Snippet
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovering = false
    @State private var showCopiedFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row - clean and minimal
            HStack(spacing: 12) {
                // Category indicator
                Text(snippet.category.displayName.prefix(1).uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.cmTertiary)
                    .frame(width: 20, height: 20)
                    .background(Color.cmBorder.opacity(0.3))
                    .cornerRadius(4)

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.cmText)
                        .lineLimit(1)

                    if !snippet.tags.isEmpty {
                        Text(snippet.tags.prefix(3).joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundColor(.cmTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Favorite indicator (subtle)
                if snippet.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow.opacity(0.7))
                }

                // Chevron
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.cmTertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggleExpand()
                }
            }
            .padding(.vertical, 12)

            // Expanded details
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .background(isHovering ? Color.cmBorder.opacity(0.1) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Content preview
            Text(snippet.content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.cmSecondary)
                .textSelection(.enabled)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.cmBorder.opacity(0.15))
                .cornerRadius(8)

            // Actions - simple row
            HStack(spacing: 20) {
                Button(action: {
                    onCopy()
                    showCopiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopiedFeedback = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        Text(showCopiedFeedback ? "Copied" : "Copy")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(showCopiedFeedback ? .green : .cmSecondary)
                }
                .buttonStyle(.plain)

                Button(action: onToggleFavorite) {
                    HStack(spacing: 5) {
                        Image(systemName: snippet.isFavorite ? "star.fill" : "star")
                        Text(snippet.isFavorite ? "Starred" : "Star")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(snippet.isFavorite ? .yellow : .cmSecondary)
                }
                .buttonStyle(.plain)

                if !snippet.isSynced {
                    Button(action: onEdit) {
                        HStack(spacing: 5) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.cmTertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()

                    Text("Synced")
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 4)
    }
}

// MARK: - Folder Settings View

struct FolderSettingsView: View {
    @ObservedObject var manager: SnippetManager
    @Environment(\.dismiss) var dismiss
    @State private var newFolderPath = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Watched Folders")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            // Folder list
            if manager.watchedFolders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.cmTertiary)
                    Text("No folders being watched")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                    Text("Add a folder to automatically import markdown files as snippets")
                        .font(.system(size: 11))
                        .foregroundColor(.cmTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(manager.watchedFolders, id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.cmSecondary)
                            Text(folder)
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Button(action: { manager.removeWatchedFolder(folder) }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Divider()

            // Add folder
            HStack(spacing: 8) {
                TextField("Folder path...", text: $newFolderPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))

                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false

                    if panel.runModal() == .OK, let url = panel.url {
                        newFolderPath = url.path
                    }
                }
                .font(.system(size: 11))

                Button("Add") {
                    if !newFolderPath.isEmpty {
                        manager.addWatchedFolder(newFolderPath)
                        newFolderPath = ""
                    }
                }
                .disabled(newFolderPath.isEmpty)
                .font(.system(size: 11))
            }
            .padding()
        }
        .frame(width: 500, height: 350)
    }
}
