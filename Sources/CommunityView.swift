import SwiftUI

// MARK: - Community View

struct CommunityView: View {
    @StateObject private var firebase = FirebaseManager.shared
    @ObservedObject var snippetManager: SnippetManager

    @State private var searchText = ""
    @State private var selectedCategory: SnippetCategory? = nil
    @State private var showingShareSheet = false
    @State private var snippetToShare: Snippet? = nil
    @State private var showingNicknamePrompt = false
    @State private var nickname = DeviceIdentity.shared.nickname ?? ""
    @State private var shareStatus: ShareStatus = .idle

    enum ShareStatus: Equatable {
        case idle, sharing, success, error(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Firebase config warning
            if !firebase.isConfigured {
                configWarning
            } else {
                // Search and filters
                filterBar

                Divider()

                // Content
                if firebase.isLoading {
                    loadingView
                } else if firebase.communitySnippets.isEmpty {
                    emptyState
                } else {
                    snippetList
                }
            }
        }
        .onAppear {
            if firebase.isConfigured {
                firebase.fetchCommunitySnippets()
                firebase.trackEvent(.categoryViewed, category: "community")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let snippet = snippetToShare {
                ShareSnippetSheet(
                    snippet: snippet,
                    nickname: $nickname,
                    shareStatus: $shareStatus,
                    onShare: { shareSnippet(snippet) },
                    onDismiss: { showingShareSheet = false }
                )
            }
        }
    }

    // MARK: - Config Warning

    private var configWarning: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.orange)

            Text("Firebase Not Configured")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.cmText)

            Text("To enable community features, update FirebaseConfig.swift with your Firebase project details.")
                .font(.system(size: 12))
                .foregroundColor(.cmSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Setup steps:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cmText)

                Text("1. Go to console.firebase.google.com")
                Text("2. Create project or use existing")
                Text("3. Enable Realtime Database")
                Text("4. Copy database URL and API key")
                Text("5. Update FirebaseConfig.swift")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.cmSecondary)
            .padding()
            .background(Color.cmBorder.opacity(0.3))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.cmTertiary)

                TextField("Search community...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cmTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.cmBorder.opacity(0.3))
            .cornerRadius(6)

            // Category filter
            Menu {
                Button("All Categories") { selectedCategory = nil }
                Divider()
                ForEach(SnippetCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                            if selectedCategory == category {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedCategory?.icon ?? "line.3.horizontal.decrease")
                        .font(.system(size: 10))
                    Text(selectedCategory?.displayName ?? "All")
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundColor(.cmText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cmBorder.opacity(0.3))
                .cornerRadius(6)
            }

            Spacer()

            // Share button
            Button(action: { showingShareSheet = true; snippetToShare = nil }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                    Text("Share")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.cmText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cmBorder.opacity(0.3))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Refresh
            Button(action: { firebase.fetchCommunitySnippets(category: selectedCategory) }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.cmSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading community snippets...")
                .font(.system(size: 12))
                .foregroundColor(.cmSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.cmTertiary)

            Text("No community snippets yet")
                .font(.system(size: 13))
                .foregroundColor(.cmSecondary)

            Text("Be the first to share!")
                .font(.system(size: 11))
                .foregroundColor(.cmTertiary)

            Button(action: { showingShareSheet = true }) {
                Text("Share a Snippet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cmBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cmText)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Snippet List

    private var snippetList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredSnippets) { snippet in
                    CommunitySnippetRow(
                        snippet: snippet,
                        onDownload: { downloadSnippet(snippet) },
                        onLike: { firebase.likeSnippet(snippet.id) },
                        onReport: { firebase.reportSnippet(snippet.id, reason: "inappropriate") }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var filteredSnippets: [SharedSnippet] {
        var snippets = firebase.communitySnippets

        if let category = selectedCategory {
            snippets = snippets.filter { $0.category == category.rawValue }
        }

        if !searchText.isEmpty {
            snippets = firebase.filterCommunity(by: searchText)
        }

        return snippets
    }

    // MARK: - Actions

    private func shareSnippet(_ snippet: Snippet) {
        shareStatus = .sharing

        // Save nickname
        if !nickname.isEmpty {
            DeviceIdentity.shared.nickname = nickname
        }

        firebase.shareSnippet(snippet) { result in
            switch result {
            case .success:
                shareStatus = .success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showingShareSheet = false
                    shareStatus = .idle
                    firebase.fetchCommunitySnippets()
                }
            case .failure(let error):
                shareStatus = .error(error.localizedDescription)
            }
        }
    }

    private func downloadSnippet(_ shared: SharedSnippet) {
        let localSnippet = firebase.downloadSnippet(shared)
        snippetManager.addSnippet(localSnippet)
    }
}

// MARK: - Community Snippet Row

struct CommunitySnippetRow: View {
    let snippet: SharedSnippet
    let onDownload: () -> Void
    let onLike: () -> Void
    let onReport: () -> Void

    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var justDownloaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 10) {
                // Category icon
                Image(systemName: snippet.categoryEnum.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.cmSecondary)
                    .frame(width: 20)

                // Title
                Text(snippet.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cmText)
                    .lineLimit(1)

                // Tags
                if !snippet.tags.isEmpty {
                    Text(snippet.tags.prefix(2).joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Author
                Text(snippet.displayAuthor)
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)

                // Stats
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "heart")
                            .font(.system(size: 9))
                        Text("\(snippet.likes)")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(.cmTertiary)

                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 9))
                        Text("\(snippet.downloads)")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(.cmTertiary)
                }

                // Expand button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    // Content preview
                    Text(snippet.content)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.cmSecondary)
                        .lineLimit(10)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cmBorder.opacity(0.2))
                        .cornerRadius(4)

                    // Actions
                    HStack(spacing: 12) {
                        Button(action: {
                            onDownload()
                            justDownloaded = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                justDownloaded = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: justDownloaded ? "checkmark" : "arrow.down.to.line")
                                    .font(.system(size: 10))
                                Text(justDownloaded ? "Added!" : "Add to Library")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(justDownloaded ? .green : .cmText)
                        }
                        .buttonStyle(.plain)
                        .disabled(justDownloaded)

                        Button(action: onLike) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart")
                                    .font(.system(size: 10))
                                Text("Like")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.cmSecondary)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(snippet.content, forType: .string)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                Text("Copy")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.cmSecondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(action: onReport) {
                            Image(systemName: "flag")
                                .font(.system(size: 10))
                                .foregroundColor(.cmTertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Report inappropriate content")
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .padding(.horizontal, 16)
        .background(isHovering ? Color.cmBorder.opacity(0.2) : Color.clear)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Share Snippet Sheet

struct ShareSnippetSheet: View {
    let snippet: Snippet?
    @Binding var nickname: String
    @Binding var shareStatus: CommunityView.ShareStatus
    let onShare: () -> Void
    let onDismiss: () -> Void

    @ObservedObject var snippetManager = SnippetManager()
    @State private var selectedSnippet: Snippet?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Share to Community")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.cmTertiary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Nickname
            VStack(alignment: .leading, spacing: 4) {
                Text("Your nickname (optional)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cmSecondary)

                TextField("Anonymous", text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            // Snippet selector if none provided
            if snippet == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select snippet to share")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmSecondary)

                    Picker("", selection: $selectedSnippet) {
                        Text("Choose...").tag(nil as Snippet?)
                        ForEach(snippetManager.snippets) { s in
                            Text(s.title).tag(s as Snippet?)
                        }
                    }
                    .labelsHidden()
                }
            }

            // Preview
            if let s = snippet ?? selectedSnippet {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: s.category.icon)
                            Text(s.title)
                                .font(.system(size: 12, weight: .medium))
                        }
                        Text(s.contentPreview)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.cmSecondary)
                            .lineLimit(5)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cmBorder.opacity(0.2))
                    .cornerRadius(4)
                }
            }

            Spacer()

            // Status
            switch shareStatus {
            case .idle:
                EmptyView()
            case .sharing:
                ProgressView()
                    .scaleEffect(0.8)
            case .success:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Shared successfully!")
                        .font(.system(size: 12))
                }
            case .error(let message):
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.cmSecondary)
                }
            }

            // Actions
            HStack {
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Share") {
                    if let s = snippet ?? selectedSnippet {
                        // temporarily store for sharing
                        onShare()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled((snippet ?? selectedSnippet) == nil || shareStatus == .sharing)
            }
        }
        .padding(20)
        .frame(width: 400, height: 450)
    }
}

#Preview {
    CommunityView(snippetManager: SnippetManager())
}
