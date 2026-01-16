import SwiftUI
import AppKit

// MARK: - Dashboard View

struct DashboardView: View {
    @ObservedObject var processManager: ClaudeProcessManager
    @ObservedObject var snippetManager: SnippetManager
    @ObservedObject var newsManager: NewsManager
    let onNavigate: (AppTab) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Quick Stats
                statsSection

                // Quick Actions Grid
                quickActionsGrid

                // News Preview
                newsPreviewSection

                // Recent Library Items
                recentLibrarySection

                // Footer with links
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

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "terminal",
                value: "\(processManager.instances.count)",
                label: "Instances",
                color: processManager.instances.isEmpty ? .cmTertiary : .green,
                action: { onNavigate(.instances) }
            )

            statCard(
                icon: "books.vertical",
                value: "\(snippetManager.snippets.count)",
                label: "Library Items",
                color: .blue,
                action: { onNavigate(.snippets) }
            )

            statCard(
                icon: "star.fill",
                value: "\(newsManager.starredItems.count)",
                label: "Saved Articles",
                color: .yellow,
                action: { onNavigate(.news) }
            )
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)

                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.cmText)
                }

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.cmBorder.opacity(0.1))
            .cornerRadius(12)
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
                quickActionButton(icon: "plus.circle", label: "New Claude", color: .green) {
                    launchClaude()
                }

                quickActionButton(icon: "doc.badge.plus", label: "New Snippet", color: .blue) {
                    onNavigate(.snippets)
                }

                quickActionButton(icon: "arrow.clockwise", label: "Refresh", color: .orange) {
                    processManager.refresh()
                    newsManager.refresh()
                }

                quickActionButton(icon: "newspaper", label: "Read News", color: .purple) {
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

    // MARK: - News Preview

    private var newsPreviewSection: some View {
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
                        Text("Loading news...")
                            .font(.system(size: 11))
                            .foregroundColor(.cmTertiary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color.cmBorder.opacity(0.05))
                .cornerRadius(10)
                .onAppear {
                    if newsManager.items.isEmpty {
                        newsManager.refresh()
                    }
                }
            } else {
                VStack(spacing: 1) {
                    ForEach(newsManager.items.prefix(4)) { item in
                        newsPreviewRow(item)
                    }
                }
                .background(Color.cmBorder.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }

    private func newsPreviewRow(_ item: NewsItem) -> some View {
        Button(action: { newsManager.openInBrowser(item) }) {
            HStack(spacing: 10) {
                // Star indicator
                if item.isStarred {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                } else {
                    Circle()
                        .fill(item.isRead ? Color.clear : Color.blue)
                        .frame(width: 6, height: 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 12, weight: item.isRead ? .regular : .medium))
                        .foregroundColor(item.isRead ? .cmSecondary : .cmText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(item.source)
                            .font(.system(size: 9))
                            .foregroundColor(.cmTertiary)

                        if !item.pubDateFormatted.isEmpty {
                            Text("·")
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
                                .foregroundColor(.blue)
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
                                .foregroundColor(.yellow)
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

    // MARK: - Footer Links

    private var footerLinksSection: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 16) {
                footerLink(icon: "book", label: "Docs", url: "https://docs.anthropic.com")
                footerLink(icon: "bubble.left.and.bubble.right", label: "Discord", url: "https://discord.gg/anthropic")
                footerLink(icon: "chevron.left.forwardslash.chevron.right", label: "GitHub", url: "https://github.com/anthropics")
                footerLink(icon: "graduationcap", label: "Learn", url: "https://www.anthropic.com/claude")
            }

            Text("Claude Manager v\(AppInfo.version) · by \(AppInfo.author)")
                .font(.system(size: 10))
                .foregroundColor(.cmTertiary.opacity(0.6))
        }
    }

    private func footerLink(icon: String, label: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.cmTertiary)

                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.cmTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func launchClaude() {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "open -a Terminal && sleep 0.5 && osascript -e 'tell application \"Terminal\" to do script \"claude\"'"]
        try? task.run()
    }
}
