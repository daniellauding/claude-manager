import SwiftUI
import AppKit

// MARK: - Search Provider

struct SearchProvider: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let urlPattern: String  // {query} will be replaced

    func searchURL(query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = urlPattern.replacingOccurrences(of: "{query}", with: encoded)
        return URL(string: urlString)
    }

    static let allProviders: [SearchProvider] = [
        SearchProvider(id: "github", name: "GitHub", icon: "chevron.left.forwardslash.chevron.right", urlPattern: "https://github.com/search?q={query}"),
        SearchProvider(id: "stackoverflow", name: "Stack Overflow", icon: "text.bubble", urlPattern: "https://stackoverflow.com/search?q={query}"),
        SearchProvider(id: "npm", name: "npm", icon: "shippingbox", urlPattern: "https://www.npmjs.com/search?q={query}"),
        SearchProvider(id: "pypi", name: "PyPI", icon: "cube", urlPattern: "https://pypi.org/search/?q={query}"),
        SearchProvider(id: "crates", name: "Crates.io", icon: "cube.box", urlPattern: "https://crates.io/search?q={query}"),
        SearchProvider(id: "mdn", name: "MDN", icon: "book", urlPattern: "https://developer.mozilla.org/en-US/search?q={query}"),
        SearchProvider(id: "claude", name: "Claude Docs", icon: "sparkles", urlPattern: "https://docs.anthropic.com/en/docs?q={query}"),
        SearchProvider(id: "google", name: "Google", icon: "magnifyingglass", urlPattern: "https://www.google.com/search?q={query}")
    ]
}

// MARK: - Dashboard View

struct DashboardView: View {
    @ObservedObject var processManager: ClaudeProcessManager
    @ObservedObject var snippetManager: SnippetManager
    @ObservedObject var newsManager: NewsManager
    let onNavigate: (AppTab) -> Void

    // Search state
    @State private var searchQuery: String = ""
    @State private var selectedProvider: SearchProvider = SearchProvider.allProviders[0]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Quick Search
                quickSearchSection

                // Quick Stats
                statsSection

                // Quick Actions Grid
                quickActionsGrid

                // Recent Library Items
                recentLibrarySection

                // Latest News
                latestNewsSection

                // Footer
                footerLinksSection
            }
            .padding(20)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.cmText)

                    Text(dateText)
                        .font(.system(size: 12))
                        .foregroundColor(.cmTertiary)
                }

                Spacer()

                // App icon
                Image(systemName: "terminal.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.cmText.opacity(0.2))
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Quick Search Section

    private var quickSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Search")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.cmText)

            HStack(spacing: 8) {
                // Provider picker
                Menu {
                    ForEach(SearchProvider.allProviders) { provider in
                        Button(action: { selectedProvider = provider }) {
                            HStack {
                                Image(systemName: provider.icon)
                                Text(provider.name)
                                if provider.id == selectedProvider.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedProvider.icon)
                            .font(.system(size: 11))
                        Text(selectedProvider.name)
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.cmText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.cmBorder.opacity(0.15))
                    .cornerRadius(8)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.cmTertiary)

                    TextField("Search \(selectedProvider.name)...", text: $searchQuery, onCommit: {
                        performSearch()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.cmTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.cmBorder.opacity(0.08))
                .cornerRadius(8)

                // Search button
                Button(action: { performSearch() }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmBackground)
                        .padding(8)
                        .background(searchQuery.isEmpty ? Color.cmTertiary : Color.cmText)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(searchQuery.isEmpty)
            }

            // Quick provider buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SearchProvider.allProviders) { provider in
                        Button(action: {
                            selectedProvider = provider
                            if !searchQuery.isEmpty {
                                performSearch()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: provider.icon)
                                    .font(.system(size: 10))
                                Text(provider.name)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(selectedProvider.id == provider.id ? .cmText : .cmSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selectedProvider.id == provider.id ? Color.cmBorder.opacity(0.25) : Color.cmBorder.opacity(0.08))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func performSearch() {
        guard !searchQuery.isEmpty,
              let url = selectedProvider.searchURL(query: searchQuery) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "terminal",
                value: "\(processManager.instances.count)",
                label: "Instances",
                action: { onNavigate(.instances) }
            )

            statCard(
                icon: "books.vertical",
                value: "\(snippetManager.snippets.count)",
                label: "Library",
                action: { onNavigate(.snippets) }
            )

            statCard(
                icon: "newspaper",
                value: "\(newsManager.items.count)",
                label: "News",
                action: { onNavigate(.news) }
            )
        }
    }

    private func statCard(icon: String, value: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)

                    Text(value)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.cmText)
                }

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cmBorder.opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions Grid

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.cmText)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                quickActionButton(icon: "plus.circle", label: "New Claude", color: .cmText) {
                    launchClaude()
                }

                quickActionButton(icon: "doc.badge.plus", label: "New Snippet", color: .cmText) {
                    onNavigate(.snippets)
                }

                quickActionButton(icon: "arrow.clockwise", label: "Refresh", color: .cmText) {
                    processManager.refresh()
                    newsManager.refresh()
                }

                quickActionButton(icon: "newspaper", label: "Read News", color: .cmText) {
                    onNavigate(.news)
                }
            }
        }
    }

    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.cmSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cmBorder.opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Library

    private var recentLibrarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Library")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cmText)

                Spacer()

                Button(action: { onNavigate(.snippets) }) {
                    Text("See All")
                        .font(.system(size: 11))
                        .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)
            }

            if snippetManager.snippets.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.cmTertiary)
                        Text("No items yet")
                            .font(.system(size: 11))
                            .foregroundColor(.cmTertiary)
                        Button(action: { onNavigate(.snippets) }) {
                            Text("Add First Item")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.cmText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color.cmBorder.opacity(0.05))
                .cornerRadius(10)
            } else {
                let recentItems = snippetManager.snippets
                    .sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
                    .prefix(4)

                VStack(spacing: 1) {
                    ForEach(Array(recentItems)) { snippet in
                        libraryPreviewRow(snippet)
                    }
                }
                .background(Color.cmBorder.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }

    private func libraryPreviewRow(_ snippet: Snippet) -> some View {
        Button(action: {
            snippetManager.copyToClipboard(snippet)
        }) {
            HStack(spacing: 10) {
                Image(systemName: snippet.category.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.cmSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(snippet.category.displayName)
                            .font(.system(size: 9))
                            .foregroundColor(.cmTertiary)

                        if snippet.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.cmText)
                        }
                    }
                }

                Spacer()

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundColor(.cmTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Latest News

    private var latestNewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest News")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cmText)

                Spacer()

                Button(action: { onNavigate(.news) }) {
                    Text("See All")
                        .font(.system(size: 11))
                        .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)
            }

            if newsManager.items.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.cmTertiary)

                        if newsManager.isLoading {
                            Text("Loading news...")
                                .font(.system(size: 11))
                                .foregroundColor(.cmTertiary)
                        } else if newsManager.sources.filter({ $0.isEnabled }).isEmpty {
                            Text("No feeds configured")
                                .font(.system(size: 11))
                                .foregroundColor(.cmTertiary)
                            Button(action: { onNavigate(.news) }) {
                                Text("Add News Sources")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.cmText)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("No news yet")
                                .font(.system(size: 11))
                                .foregroundColor(.cmTertiary)
                            Button(action: { newsManager.refresh() }) {
                                Text("Refresh")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.cmText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color.cmBorder.opacity(0.05))
                .cornerRadius(10)
            } else {
                let recentNews = newsManager.items
                    .sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
                    .prefix(3)

                VStack(spacing: 1) {
                    ForEach(Array(recentNews)) { item in
                        newsPreviewRow(item)
                    }
                }
                .background(Color.cmBorder.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }

    private func newsPreviewRow(_ item: NewsItem) -> some View {
        Button(action: {
            newsManager.openInBrowser(item)
        }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(item.source)
                            .font(.system(size: 9))
                            .foregroundColor(.cmTertiary)

                        if !item.pubDateFormatted.isEmpty {
                            Text("·")
                                .font(.system(size: 9))
                                .foregroundColor(.cmTertiary)
                            Text(item.pubDateFormatted)
                                .font(.system(size: 9))
                                .foregroundColor(.cmTertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundColor(.cmTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footerLinksSection: some View {
        VStack(spacing: 8) {
            Divider()

            Text("v\(AppInfo.version) · \(AppInfo.author)")
                .font(.system(size: 10))
                .foregroundColor(.cmTertiary.opacity(0.5))
        }
    }

    // MARK: - Actions

    private func launchClaude() {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "open -a Terminal && sleep 0.5 && osascript -e 'tell application \"Terminal\" to do script \"claude\"'"]
        try? task.run()
    }
}
