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

                // Recent Library Items
                recentLibrarySection

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
