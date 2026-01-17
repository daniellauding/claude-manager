import SwiftUI

// MARK: - Admin Tab Enum

enum AdminTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case users = "Users"
    case teams = "Teams"
    case projects = "Projects"
    case invites = "Invites"
    case newsSources = "News Sources"

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar"
        case .users: return "person.2"
        case .teams: return "person.3"
        case .projects: return "folder"
        case .invites: return "envelope"
        case .newsSources: return "newspaper"
        }
    }
}

// MARK: - Admin View

struct AdminView: View {
    @ObservedObject var adminManager: AdminManager
    @State private var selectedTab: AdminTab = .dashboard
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            adminTabBar

            Divider()

            // Content
            ScrollView {
                switch selectedTab {
                case .dashboard:
                    dashboardContent
                case .users:
                    usersContent
                case .teams:
                    teamsContent
                case .projects:
                    projectsContent
                case .invites:
                    invitesContent
                case .newsSources:
                    newsSourcesContent
                }
            }
        }
        .onAppear {
            adminManager.fetchAllData()
        }
    }

    // MARK: - Tab Bar

    private var adminTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(AdminTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .cmText : .cmSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? Color.cmBorder.opacity(0.3) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        VStack(spacing: 20) {
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCard(title: "Total Users", value: "\(adminManager.stats.totalUsers)", icon: "person.2", color: .blue)
                statCard(title: "Total Teams", value: "\(adminManager.stats.totalTeams)", icon: "person.3", color: .purple)
                statCard(title: "Total Projects", value: "\(adminManager.stats.totalProjects)", icon: "folder", color: .orange)
                statCard(title: "Total Invites", value: "\(adminManager.stats.totalInvites)", icon: "envelope", color: .green)
                statCard(title: "Active Invites", value: "\(adminManager.stats.activeInvites)", icon: "envelope.badge", color: .teal)
                statCard(title: "News Sources", value: "\(adminManager.defaultNewsSources.count)", icon: "newspaper", color: .red)
            }

            // Quick Actions
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cmText)

                HStack(spacing: 12) {
                    quickActionButton(title: "Refresh Data", icon: "arrow.clockwise") {
                        adminManager.fetchAllData()
                    }

                    quickActionButton(title: "Update Stats", icon: "chart.bar") {
                        adminManager.updateStats()
                    }
                }
            }

            // Last Updated
            if adminManager.stats.lastUpdated > Date.distantPast {
                Text("Last updated: \(adminManager.stats.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
            }

            Spacer()
        }
        .padding(20)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Spacer()
            }

            HStack {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.cmText)
                Spacer()
            }

            HStack {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.cmSecondary)
                Spacer()
            }
        }
        .padding(12)
        .background(Color.cmBorder.opacity(0.1))
        .cornerRadius(10)
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.cmText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.cmBorder.opacity(0.2))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Users Content

    private var usersContent: some View {
        VStack(spacing: 16) {
            // Search bar
            searchBar(placeholder: "Search users...")

            // Users list
            if adminManager.isLoading {
                loadingView
            } else if adminManager.allUsers.isEmpty {
                emptyStateView(icon: "person.2", message: "No users found")
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(filteredUsers) { userInfo in
                        UserAdminRow(userInfo: userInfo) {
                            deleteUserWithConfirmation(userInfo.id)
                        }
                    }
                }
                .background(Color.cmBorder.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(20)
    }

    private var filteredUsers: [AdminUserInfo] {
        guard !searchText.isEmpty else { return adminManager.allUsers }
        let lowercased = searchText.lowercased()
        return adminManager.allUsers.filter {
            $0.email.lowercased().contains(lowercased) ||
            $0.displayName.lowercased().contains(lowercased)
        }
    }

    // MARK: - Teams Content

    private var teamsContent: some View {
        VStack(spacing: 16) {
            searchBar(placeholder: "Search teams...")

            if adminManager.isLoading {
                loadingView
            } else if adminManager.allTeams.isEmpty {
                emptyStateView(icon: "person.3", message: "No teams found")
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(filteredTeams) { team in
                        TeamAdminRow(team: team) {
                            deleteTeamWithConfirmation(team.id)
                        }
                    }
                }
                .background(Color.cmBorder.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(20)
    }

    private var filteredTeams: [Team] {
        guard !searchText.isEmpty else { return adminManager.allTeams }
        let lowercased = searchText.lowercased()
        return adminManager.allTeams.filter {
            $0.name.lowercased().contains(lowercased) ||
            ($0.description?.lowercased().contains(lowercased) ?? false)
        }
    }

    // MARK: - Projects Content

    private var projectsContent: some View {
        VStack(spacing: 16) {
            searchBar(placeholder: "Search projects...")

            if adminManager.isLoading {
                loadingView
            } else if adminManager.allProjects.isEmpty {
                emptyStateView(icon: "folder", message: "No projects found")
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(filteredProjects) { project in
                        ProjectAdminRow(project: project) {
                            deleteProjectWithConfirmation(project.id)
                        }
                    }
                }
                .background(Color.cmBorder.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(20)
    }

    private var filteredProjects: [Project] {
        guard !searchText.isEmpty else { return adminManager.allProjects }
        let lowercased = searchText.lowercased()
        return adminManager.allProjects.filter {
            $0.name.lowercased().contains(lowercased) ||
            ($0.description?.lowercased().contains(lowercased) ?? false)
        }
    }

    // MARK: - Invites Content

    private var invitesContent: some View {
        VStack(spacing: 16) {
            searchBar(placeholder: "Search invites...")

            if adminManager.isLoading {
                loadingView
            } else if adminManager.allInvites.isEmpty {
                emptyStateView(icon: "envelope", message: "No invites found")
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(filteredInvites) { invite in
                        InviteAdminRow(invite: invite, onRevoke: {
                            revokeInvite(invite.id)
                        }, onDelete: {
                            deleteInviteWithConfirmation(invite.id)
                        })
                    }
                }
                .background(Color.cmBorder.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(20)
    }

    private var filteredInvites: [TeamInvite] {
        guard !searchText.isEmpty else { return adminManager.allInvites }
        let lowercased = searchText.lowercased()
        return adminManager.allInvites.filter {
            $0.teamName.lowercased().contains(lowercased) ||
            $0.id.lowercased().contains(lowercased)
        }
    }

    // MARK: - News Sources Content

    @State private var showingAddNewsSource = false
    @State private var editingNewsSource: NewsSource?

    private var newsSourcesContent: some View {
        VStack(spacing: 16) {
            // Header with Add button
            HStack {
                Text("Default News Sources")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cmText)

                Spacer()

                Button(action: { showingAddNewsSource = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("Add Source")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.cmText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cmBorder.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Text("These sources will be shown to all new users by default.")
                .font(.system(size: 11))
                .foregroundColor(.cmSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if adminManager.isLoading {
                loadingView
            } else if adminManager.defaultNewsSources.isEmpty {
                emptyStateView(icon: "newspaper", message: "No default news sources")
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(adminManager.defaultNewsSources) { source in
                        NewsSourceAdminRow(source: source, onEdit: {
                            editingNewsSource = source
                        }, onDelete: {
                            deleteNewsSourceWithConfirmation(source.id)
                        })
                    }
                }
                .background(Color.cmBorder.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(20)
        .sheet(isPresented: $showingAddNewsSource) {
            NewsSourceEditorSheet(
                source: nil,
                onSave: { source in
                    adminManager.addDefaultNewsSource(source) { _ in }
                    showingAddNewsSource = false
                },
                onCancel: { showingAddNewsSource = false }
            )
        }
        .sheet(item: $editingNewsSource) { source in
            NewsSourceEditorSheet(
                source: source,
                onSave: { updatedSource in
                    adminManager.updateDefaultNewsSource(updatedSource) { _ in }
                    editingNewsSource = nil
                },
                onCancel: { editingNewsSource = nil }
            )
        }
    }

    // MARK: - Helper Views

    private func searchBar(placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.cmTertiary)

            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.cmTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cmBorder.opacity(0.1))
        .cornerRadius(8)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(.system(size: 12))
                .foregroundColor(.cmSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.cmTertiary)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.cmSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func deleteUserWithConfirmation(_ userId: String) {
        // In a real app, show a confirmation dialog
        adminManager.deleteUser(userId) { result in
            if case .failure(let error) = result {
                print("Failed to delete user: \(error)")
            }
        }
    }

    private func deleteTeamWithConfirmation(_ teamId: String) {
        adminManager.deleteTeam(teamId) { result in
            if case .failure(let error) = result {
                print("Failed to delete team: \(error)")
            }
        }
    }

    private func deleteProjectWithConfirmation(_ projectId: String) {
        adminManager.deleteProject(projectId) { result in
            if case .failure(let error) = result {
                print("Failed to delete project: \(error)")
            }
        }
    }

    private func revokeInvite(_ token: String) {
        adminManager.revokeInvite(token) { result in
            if case .failure(let error) = result {
                print("Failed to revoke invite: \(error)")
            }
        }
    }

    private func deleteInviteWithConfirmation(_ token: String) {
        adminManager.deleteInvite(token) { result in
            if case .failure(let error) = result {
                print("Failed to delete invite: \(error)")
            }
        }
    }

    private func deleteNewsSourceWithConfirmation(_ sourceId: UUID) {
        adminManager.deleteDefaultNewsSource(sourceId) { result in
            if case .failure(let error) = result {
                print("Failed to delete news source: \(error)")
            }
        }
    }
}

// MARK: - User Admin Row

struct UserAdminRow: View {
    let userInfo: AdminUserInfo
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.cmBorder.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(userInfo.displayName.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmSecondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(userInfo.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cmText)

                Text(userInfo.email)
                    .font(.system(size: 10))
                    .foregroundColor(.cmSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(userInfo.deviceCount) device(s)")
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)

                if let lastSeen = userInfo.lastSeen {
                    Text("Last seen: \(lastSeen.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 9))
                        .foregroundColor(.cmTertiary)
                }
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Team Admin Row

struct TeamAdminRow: View {
    let team: Team
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: team.icon)
                .font(.system(size: 14))
                .foregroundColor(.cmSecondary)
                .frame(width: 32, height: 32)
                .background(Color.cmBorder.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(team.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmText)

                    if team.isPublic {
                        Text("Public")
                            .font(.system(size: 9))
                            .foregroundColor(.cmSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cmBorder.opacity(0.3))
                            .cornerRadius(4)
                    }
                }

                Text("\(team.memberCount) members · \(team.projectIds.count) projects")
                    .font(.system(size: 10))
                    .foregroundColor(.cmSecondary)
            }

            Spacer()

            Text(team.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 10))
                .foregroundColor(.cmTertiary)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Project Admin Row

struct ProjectAdminRow: View {
    let project: Project
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: project.icon)
                .font(.system(size: 14))
                .foregroundColor(.cmSecondary)
                .frame(width: 32, height: 32)
                .background(Color.cmBorder.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmText)

                    Image(systemName: project.privacy.icon)
                        .font(.system(size: 9))
                        .foregroundColor(.cmTertiary)
                }

                Text("\(project.snippetCount) snippets")
                    .font(.system(size: 10))
                    .foregroundColor(.cmSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if project.isTeamProject {
                    Text("Team")
                        .font(.system(size: 9))
                        .foregroundColor(.purple)
                } else {
                    Text("Personal")
                        .font(.system(size: 9))
                        .foregroundColor(.cmTertiary)
                }

                Text(project.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 9))
                    .foregroundColor(.cmTertiary)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Invite Admin Row

struct InviteAdminRow: View {
    let invite: TeamInvite
    let onRevoke: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(invite.teamName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cmText)

                HStack(spacing: 8) {
                    Text("Role: \(invite.role.displayName)")
                        .font(.system(size: 10))
                        .foregroundColor(.cmSecondary)

                    Text("Used: \(invite.usageCount)")
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary)

                    if let limit = invite.usageLimit {
                        Text("/ \(limit)")
                            .font(.system(size: 10))
                            .foregroundColor(.cmTertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(statusColor)

                Text("Expires \(invite.expiresIn)")
                    .font(.system(size: 9))
                    .foregroundColor(.cmTertiary)
            }

            if invite.isActive && !invite.isExpired {
                Button(action: onRevoke) {
                    Text("Revoke")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var statusColor: Color {
        if !invite.isActive { return .gray }
        if invite.isExpired { return .red }
        if invite.isUsageLimitReached { return .orange }
        return .green
    }

    private var statusText: String {
        if !invite.isActive { return "Revoked" }
        if invite.isExpired { return "Expired" }
        if invite.isUsageLimitReached { return "Limit Reached" }
        return "Active"
    }
}

// MARK: - News Source Admin Row

struct NewsSourceAdminRow: View {
    let source: NewsSource
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.icon)
                .font(.system(size: 14))
                .foregroundColor(.cmSecondary)
                .frame(width: 32, height: 32)
                .background(Color.cmBorder.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(source.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmText)

                    if !source.isEnabled {
                        Text("Disabled")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                Text(source.feedURL)
                    .font(.system(size: 10))
                    .foregroundColor(.cmSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.cmSecondary)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - News Source Editor Sheet

struct NewsSourceEditorSheet: View {
    let source: NewsSource?
    let onSave: (NewsSource) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var feedURL: String = ""
    @State private var icon: String = "newspaper"
    @State private var isEnabled: Bool = true

    var body: some View {
        VStack(spacing: 20) {
            Text(source == nil ? "Add News Source" : "Edit News Source")
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmSecondary)
                    TextField("Source name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Feed URL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmSecondary)
                    TextField("https://example.com/feed.xml", text: $feedURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Icon (SF Symbol)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmSecondary)
                    TextField("newspaper", text: $icon)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                Toggle("Enabled", isOn: $isEnabled)
                    .font(.system(size: 12))
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.cmSecondary)

                Button("Save") {
                    let newSource = NewsSource(
                        id: source?.id ?? UUID(),
                        name: name,
                        feedURL: feedURL,
                        isEnabled: isEnabled,
                        icon: icon
                    )
                    onSave(newSource)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || feedURL.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            if let source = source {
                name = source.name
                feedURL = source.feedURL
                icon = source.icon
                isEnabled = source.isEnabled
            }
        }
    }
}
