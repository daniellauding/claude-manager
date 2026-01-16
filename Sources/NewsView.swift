import SwiftUI
import AppKit

// MARK: - News View

struct NewsView: View {
    @ObservedObject var manager: NewsManager
    @State private var showingSourceEditor = false
    @State private var editingSource: NewsSource?
    @State private var expandedItems: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Sticky header with sources button
            headerBar

            Divider()

            // Scrollable filter chips
            filterBar

            Divider()

            // Content
            if manager.isLoading && manager.items.isEmpty {
                loadingView
            } else if manager.filteredItems.isEmpty {
                emptyStateView
            } else {
                newsListView
            }
        }
        .onAppear {
            if manager.items.isEmpty {
                manager.refresh()
            }
        }
        .sheet(isPresented: $showingSourceEditor) {
            SourceEditorSheet(
                manager: manager,
                editingSource: $editingSource,
                isPresented: $showingSourceEditor
            )
        }
    }

    // MARK: - Header Bar (Sticky)

    private var headerBar: some View {
        HStack(spacing: 12) {
            Text("News")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.cmText)

            Spacer()

            // Refresh button
            Button(action: { manager.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .rotationEffect(.degrees(manager.isLoading ? 360 : 0))
                    .animation(manager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isLoading)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.cmSecondary)
            .help("Refresh feeds")

            // Sources button (sticky/always visible)
            Button(action: { showingSourceEditor = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                    Text("Sources")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.cmSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.cmBorder.opacity(0.2))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Manage news sources")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Filter chips
                filterChip(for: .all, count: manager.items.count)
                filterChip(for: .starred, count: manager.starredItems.count)
                filterChip(for: .unread, count: manager.items.filter { !$0.isRead }.count)

                if !manager.sources.filter({ $0.isEnabled }).isEmpty {
                    Divider()
                        .frame(height: 16)

                    // Source filters
                    ForEach(manager.sources.filter { $0.isEnabled }) { source in
                        filterChip(for: .source(source.name), count: manager.items.filter { $0.source == source.name }.count)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(for filter: NewsFilter, count: Int) -> some View {
        Button(action: { manager.selectedFilter = filter }) {
            HStack(spacing: 4) {
                Text(filter.displayName)
                    .font(.system(size: 11, weight: manager.selectedFilter == filter ? .semibold : .regular))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(manager.selectedFilter == filter ? Color.cmText : Color.cmBorder)
                        .foregroundColor(manager.selectedFilter == filter ? .cmBackground : .cmTertiary)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(manager.selectedFilter == filter ? Color.cmBorder.opacity(0.3) : Color.clear)
            .foregroundColor(manager.selectedFilter == filter ? .cmText : .cmSecondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - News List

    private var newsListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(manager.filteredItems) { item in
                    NewsRow(
                        item: item,
                        isExpanded: expandedItems.contains(item.id),
                        onTap: {
                            if expandedItems.contains(item.id) {
                                expandedItems.remove(item.id)
                            } else {
                                expandedItems.insert(item.id)
                            }
                        },
                        onOpen: { manager.openInBrowser(item) },
                        onStar: { manager.toggleStar(item) }
                    )
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Loading news feeds...")
                .font(.system(size: 13))
                .foregroundColor(.cmSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: manager.selectedFilter == .starred ? "star" : "newspaper")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.cmTertiary)

            if manager.selectedFilter == .starred {
                Text("No starred articles")
                    .font(.system(size: 14))
                    .foregroundColor(.cmSecondary)

                Text("Star articles to save them for later")
                    .font(.system(size: 12))
                    .foregroundColor(.cmTertiary)
            } else if manager.sources.filter({ $0.isEnabled }).isEmpty {
                Text("No news sources enabled")
                    .font(.system(size: 14))
                    .foregroundColor(.cmSecondary)

                Button(action: { showingSourceEditor = true }) {
                    Text("Manage Sources")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmBackground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.cmText)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                Text("No news articles")
                    .font(.system(size: 14))
                    .foregroundColor(.cmSecondary)

                Button(action: { manager.refresh() }) {
                    Text("Refresh")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmBackground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.cmText)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - News Row

struct NewsRow: View {
    let item: NewsItem
    let isExpanded: Bool
    let onTap: () -> Void
    let onOpen: () -> Void
    let onStar: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 12) {
                    // Star button
                    Button(action: onStar) {
                        Image(systemName: item.isStarred ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(item.isStarred ? .cmText : .cmTertiary)
                    }
                    .buttonStyle(.plain)

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 13, weight: item.isRead ? .regular : .medium))
                            .foregroundColor(item.isRead ? .cmSecondary : .cmText)
                            .lineLimit(isExpanded ? nil : 2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            Text(item.source)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.cmTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cmBorder.opacity(0.3))
                                .cornerRadius(4)

                            if !item.pubDateFormatted.isEmpty {
                                Text(item.pubDateFormatted)
                                    .font(.system(size: 10))
                                    .foregroundColor(.cmTertiary)
                            }
                        }
                    }

                    Spacer()

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isHovering ? Color.cmBorder.opacity(0.1) : Color.clear)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.system(size: 12))
                            .foregroundColor(.cmSecondary)
                            .lineLimit(6)
                    }

                    Button(action: onOpen) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                            Text("Read Article")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.cmText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 44)
                .padding(.bottom, 12)
            }

            Divider()
                .padding(.leading, 44)
        }
    }
}

// MARK: - Source Editor Sheet

struct SourceEditorSheet: View {
    @ObservedObject var manager: NewsManager
    @Binding var editingSource: NewsSource?
    @Binding var isPresented: Bool

    @State private var showingAddSource = false
    @State private var newSourceName = ""
    @State private var newSourceURL = ""
    @State private var sourceToEdit: NewsSource?
    @State private var editName = ""
    @State private var editURL = ""
    @State private var showingDeleteConfirm = false
    @State private var sourceToDelete: NewsSource?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("News Sources")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.cmTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Source list
            if manager.sources.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.cmTertiary)
                    Text("No news sources")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                    Text("Add RSS feeds to see news")
                        .font(.system(size: 11))
                        .foregroundColor(.cmTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(manager.sources) { source in
                            sourceRow(source)
                        }
                    }
                }
            }

            Divider()

            // Edit source section
            if let source = sourceToEdit {
                VStack(spacing: 12) {
                    Text("Edit Source")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmSecondary)

                    TextField("Name", text: $editName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    TextField("RSS Feed URL", text: $editURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    HStack {
                        Button("Cancel") {
                            sourceToEdit = nil
                            editName = ""
                            editURL = ""
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.cmSecondary)

                        Spacer()

                        Button("Save") {
                            var updated = source
                            updated.name = editName
                            updated.feedURL = editURL
                            manager.updateSource(updated)
                            sourceToEdit = nil
                            editName = ""
                            editURL = ""
                            manager.refresh()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(editName.isEmpty || editURL.isEmpty)
                    }
                }
                .padding()
            }
            // Add source section
            else if showingAddSource {
                VStack(spacing: 12) {
                    Text("Add Source")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmSecondary)

                    TextField("Name", text: $newSourceName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    TextField("RSS Feed URL", text: $newSourceURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    HStack {
                        Button("Cancel") {
                            showingAddSource = false
                            newSourceName = ""
                            newSourceURL = ""
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.cmSecondary)

                        Spacer()

                        Button("Add") {
                            if !newSourceName.isEmpty && !newSourceURL.isEmpty {
                                let source = NewsSource(name: newSourceName, feedURL: newSourceURL)
                                manager.addSource(source)
                                showingAddSource = false
                                newSourceName = ""
                                newSourceURL = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newSourceName.isEmpty || newSourceURL.isEmpty)
                    }
                }
                .padding()
            } else {
                HStack {
                    Button(action: { showingAddSource = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Source")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    if !manager.sources.isEmpty {
                        Button(action: {
                            showingDeleteConfirm = true
                            sourceToDelete = nil // nil means delete all
                        }) {
                            Text("Clear All")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.cmTertiary)
                    }

                    Button(action: { manager.resetToDefaults() }) {
                        Text("Reset to Defaults")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.cmTertiary)
                }
                .padding()
            }
        }
        .frame(width: 400, height: 450)
        .background(Color.cmBackground)
        .alert("Delete Source?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let source = sourceToDelete {
                    manager.deleteSource(source)
                } else {
                    // Clear all sources
                    for source in manager.sources {
                        manager.deleteSource(source)
                    }
                }
            }
        } message: {
            if sourceToDelete != nil {
                Text("Remove this news source?")
            } else {
                Text("Remove all news sources?")
            }
        }
    }

    private func sourceRow(_ source: NewsSource) -> some View {
        HStack(spacing: 12) {
            // Toggle
            Button(action: { manager.toggleSourceEnabled(source) }) {
                Image(systemName: source.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(source.isEnabled ? .cmText : .cmTertiary)
            }
            .buttonStyle(.plain)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(source.isEnabled ? .cmText : .cmTertiary)

                Text(source.feedURL)
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Edit
            Button(action: {
                sourceToEdit = source
                editName = source.name
                editURL = source.feedURL
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.cmTertiary)
            }
            .buttonStyle(.plain)

            // Delete
            Button(action: {
                sourceToDelete = source
                showingDeleteConfirm = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.cmTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cmBorder.opacity(0.05))
    }
}
