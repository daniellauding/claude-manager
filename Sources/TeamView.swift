import SwiftUI
import AppKit

// MARK: - Team List View

struct TeamListView: View {
    @ObservedObject var teamManager: TeamManager
    @State private var showingCreateTeam = false
    @State private var showingJoinTeam = false
    @State private var selectedTeam: Team?
    @State private var searchText = ""
    @State private var pendingInviteToken: String?
    @State private var selectedSegment = 0  // 0 = My Teams, 1 = Invitations

    var filteredTeams: [Team] {
        if searchText.isEmpty {
            return teamManager.teams
        }
        return teamManager.teams.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Teams")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cmText)

                Spacer()

                Button(action: { showingJoinTeam = true }) {
                    Image(systemName: "link")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.cmSecondary)
                .help("Join team with invite link")

                Button(action: { showingCreateTeam = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.cmSecondary)
                .help("Create new team")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Segmented control
            Picker("", selection: $selectedSegment) {
                HStack {
                    Text("My Teams")
                    if !teamManager.teams.isEmpty {
                        Text("(\(teamManager.teams.count))")
                            .foregroundColor(.cmTertiary)
                    }
                }
                .tag(0)

                HStack {
                    Text("Invitations")
                    if !teamManager.receivedInvitations.isEmpty {
                        Text("(\(teamManager.receivedInvitations.count))")
                            .foregroundColor(.orange)
                    }
                }
                .tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Search (only for teams)
            if selectedSegment == 0 && !teamManager.teams.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.cmTertiary)
                    TextField("Search teams...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cmBorder.opacity(0.2))
                .cornerRadius(6)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            // Content
            if selectedSegment == 0 {
                // My Teams
                if teamManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTeams.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredTeams) { team in
                                TeamRowView(team: team, onSelect: { selectedTeam = team })
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                // Invitations
                InvitationsListView(teamManager: teamManager)
            }
        }
        .sheet(isPresented: $showingCreateTeam) {
            CreateTeamSheet(teamManager: teamManager, isPresented: $showingCreateTeam)
        }
        .sheet(isPresented: $showingJoinTeam) {
            JoinTeamSheet(teamManager: teamManager, isPresented: $showingJoinTeam, prefilledToken: pendingInviteToken)
        }
        .onChange(of: showingJoinTeam) { isShowing in
            if !isShowing {
                pendingInviteToken = nil  // Clear token when sheet is dismissed
            }
        }
        .sheet(item: $selectedTeam) { team in
            TeamDetailView(team: team, teamManager: teamManager, isPresented: Binding(
                get: { selectedTeam != nil },
                set: { if !$0 { selectedTeam = nil } }
            ))
        }
        .onAppear {
            // Check for pending invite from URL scheme
            if let token = AppDelegate.pendingInviteToken {
                pendingInviteToken = token
                showingJoinTeam = true
                AppDelegate.pendingInviteToken = nil
            }

            // Fetch pending invitations
            teamManager.fetchPendingInvitations()
        }
        .onReceive(NotificationCenter.default.publisher(for: .teamInviteReceived)) { notification in
            if let token = notification.userInfo?["token"] as? String {
                pendingInviteToken = token
                showingJoinTeam = true
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.cmTertiary)

            Text("No teams yet")
                .font(.system(size: 13))
                .foregroundColor(.cmSecondary)

            HStack(spacing: 12) {
                Button(action: { showingCreateTeam = true }) {
                    Text("Create Team")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmBackground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cmText)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: { showingJoinTeam = true }) {
                    Text("Join with Link")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cmText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cmBorder.opacity(0.3))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Team Row View

struct TeamRowView: View {
    let team: Team
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: team.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.cmText)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: team.color).opacity(0.2))
                    .cornerRadius(6)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(team.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.cmText)

                        if team.isPublic {
                            Image(systemName: "globe")
                                .font(.system(size: 9))
                                .foregroundColor(.cmTertiary)
                        }
                    }

                    HStack(spacing: 8) {
                        Label("\(team.memberCount)", systemImage: "person")
                        Label("\(team.projectIds.count)", systemImage: "folder")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
                }

                Spacer()

                // Role badge
                if let role = team.role(for: DeviceIdentity.shared.deviceId) {
                    Text(role.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cmSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cmBorder.opacity(0.3))
                        .cornerRadius(4)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isHovering ? Color.cmBorder.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Create Team Sheet

struct CreateTeamSheet: View {
    @ObservedObject var teamManager: TeamManager
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = "person.3"
    @State private var selectedColor = ProjectColor.blue
    @State private var isPublic = false
    @State private var isCreating = false
    @State private var error: String?

    let icons = ["person.3", "person.2", "building.2", "house", "star", "heart", "flag", "bolt", "flame", "leaf"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Team")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Team Name")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)
                        TextField("My Team", text: $name)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.cmBorder.opacity(0.2))
                            .cornerRadius(6)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description (optional)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)
                        TextField("What's this team for?", text: $description)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.cmBorder.opacity(0.2))
                            .cornerRadius(6)
                    }

                    // Icon
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Icon")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                        .frame(width: 36, height: 36)
                                        .background(selectedIcon == icon ? Color(hex: selectedColor.hex).opacity(0.3) : Color.cmBorder.opacity(0.2))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Color")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)
                        HStack(spacing: 8) {
                            ForEach(ProjectColor.allCases, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(Color(hex: color.hex))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.cmText, lineWidth: selectedColor == color ? 2 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Public toggle
                    Toggle(isOn: $isPublic) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Public Team")
                                .font(.system(size: 12, weight: .medium))
                            Text("Allow others to discover this team")
                                .font(.system(size: 10))
                                .foregroundColor(.cmTertiary)
                        }
                    }
                    .toggleStyle(.switch)

                    // Error
                    if let error = error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
                .padding(16)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.cmSecondary)

                Spacer()

                Button(action: createTeam) {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Create Team")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || isCreating)
            }
            .padding(16)
        }
        .frame(width: 360, height: 480)
    }

    private func createTeam() {
        isCreating = true
        error = nil

        var team = Team.create(name: name, description: description.isEmpty ? nil : description)
        team.icon = selectedIcon
        team.color = selectedColor.hex
        team.isPublic = isPublic

        teamManager.createTeam(name: name, description: description.isEmpty ? nil : description, isPublic: isPublic) { result in
            isCreating = false
            switch result {
            case .success:
                isPresented = false
            case .failure(let err):
                error = err.localizedDescription
            }
        }
    }
}

// MARK: - Join Team Sheet

struct JoinTeamSheet: View {
    @ObservedObject var teamManager: TeamManager
    @Binding var isPresented: Bool
    var prefilledToken: String?

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var result: InviteAcceptanceResult?
    @State private var hasAttemptedAutoJoin = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Join Team")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            VStack(spacing: 16) {
                Image(systemName: "link")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.cmTertiary)

                Text("Enter the invite code or paste the link")
                    .font(.system(size: 12))
                    .foregroundColor(.cmSecondary)

                TextField("Invite code or link", text: $inviteCode)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.cmBorder.opacity(0.2))
                    .cornerRadius(6)
                    .font(.system(size: 13, design: .monospaced))

                if let result = result {
                    HStack {
                        Image(systemName: result.isSuccess ? "checkmark.circle" : "exclamationmark.circle")
                        Text(result.message)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(result.isSuccess ? .green : .red)
                    .padding(10)
                    .background((result.isSuccess ? Color.green : Color.red).opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(16)

            Spacer()

            Divider()

            // Actions
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.cmSecondary)

                Spacer()

                Button(action: joinTeam) {
                    if isJoining {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Join Team")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inviteCode.isEmpty || isJoining)
            }
            .padding(16)
        }
        .frame(width: 320, height: 320)
        .onAppear {
            // Pre-fill with token from URL scheme if available
            if let token = prefilledToken, !token.isEmpty {
                inviteCode = token
                // Auto-join if token was provided via URL
                if !hasAttemptedAutoJoin {
                    hasAttemptedAutoJoin = true
                    joinTeam()
                }
            }
        }
    }

    private func joinTeam() {
        isJoining = true
        result = nil

        // Extract token from link or use as-is
        let token = extractToken(from: inviteCode)

        teamManager.acceptInvite(token: token) { acceptResult in
            isJoining = false
            result = acceptResult

            if acceptResult.isSuccess {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isPresented = false
                }
            }
        }
    }

    private func extractToken(from input: String) -> String {
        // Handle full URLs
        if input.contains("invite?token=") {
            return input.components(separatedBy: "invite?token=").last ?? input
        }
        if input.contains("invite/") {
            return input.components(separatedBy: "invite/").last ?? input
        }
        return input.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Team Detail View

struct TeamDetailView: View {
    let team: Team
    @ObservedObject var teamManager: TeamManager
    @Binding var isPresented: Bool

    @State private var showingInviteSheet = false
    @State private var showingSettings = false
    @State private var showingLeaveConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var selectedTab = 0
    @State private var isLeaving = false
    @State private var leaveError: String?

    var currentUserRole: TeamRole? {
        team.role(for: DeviceIdentity.shared.deviceId)
    }

    var isOwner: Bool {
        currentUserRole == .owner
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: team.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.cmText)
                    .frame(width: 36, height: 36)
                    .background(Color(hex: team.color).opacity(0.2))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(.system(size: 14, weight: .semibold))
                    if let desc = team.description {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(.cmSecondary)
                    }
                }

                Spacer()

                if currentUserRole?.canInviteMembers == true {
                    Button(action: { showingInviteSheet = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .help("Invite members")
                }

                // Team menu
                Menu {
                    if currentUserRole?.canInviteMembers == true {
                        Button(action: { showingInviteSheet = true }) {
                            Label("Invite Members", systemImage: "person.badge.plus")
                        }
                        Divider()
                    }

                    if isOwner {
                        Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                            Label("Delete Team", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive, action: { showingLeaveConfirm = true }) {
                            Label("Leave Team", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.cmSecondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "Members", isSelected: selectedTab == 0) { selectedTab = 0 }
                TabButton(title: "Projects", isSelected: selectedTab == 1) { selectedTab = 1 }
                TabButton(title: "Snippets", isSelected: selectedTab == 2) { selectedTab = 2 }
            }
            .padding(.horizontal, 16)

            Divider()

            // Content
            switch selectedTab {
            case 0:
                TeamMembersView(team: team, teamManager: teamManager)
            case 1:
                TeamProjectsView(team: team, teamManager: teamManager)
            default:
                TeamSnippetsListView(team: team, teamManager: teamManager)
            }
        }
        .frame(width: 420, height: 500)
        .sheet(isPresented: $showingInviteSheet) {
            CreateInviteSheet(team: team, teamManager: teamManager, isPresented: $showingInviteSheet)
        }
        .alert("Leave Team?", isPresented: $showingLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                leaveTeam()
            }
        } message: {
            Text("Are you sure you want to leave \"\(team.name)\"? You'll lose access to team snippets and projects.")
        }
        .alert("Delete Team?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTeam()
            }
        } message: {
            Text("Are you sure you want to delete \"\(team.name)\"? This will remove all team members and cannot be undone.")
        }
        .alert("Error", isPresented: .constant(leaveError != nil)) {
            Button("OK") { leaveError = nil }
        } message: {
            Text(leaveError ?? "")
        }
    }

    private func leaveTeam() {
        isLeaving = true
        teamManager.leaveTeam(team.id) { result in
            isLeaving = false
            switch result {
            case .success:
                isPresented = false
            case .failure(let error):
                leaveError = error.localizedDescription
            }
        }
    }

    private func deleteTeam() {
        teamManager.deleteTeam(team.id) { result in
            switch result {
            case .success:
                isPresented = false
            case .failure(let error):
                leaveError = error.localizedDescription
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .cmText : .cmSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.cmBorder.opacity(0.2) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Team Members View

struct TeamMembersView: View {
    let team: Team
    @ObservedObject var teamManager: TeamManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(team.membersList) { member in
                    MemberRowView(member: member, team: team, teamManager: teamManager)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct MemberRowView: View {
    let member: TeamMember
    let team: Team
    @ObservedObject var teamManager: TeamManager

    @State private var isHovering = false

    var canManage: Bool {
        team.canManage(DeviceIdentity.shared.deviceId) && member.role != .owner
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Image(systemName: "person.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.cmTertiary)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.displayName)
                        .font(.system(size: 12, weight: .medium))
                    if member.id == DeviceIdentity.shared.deviceId {
                        Text("(you)")
                            .font(.system(size: 10))
                            .foregroundColor(.cmTertiary)
                    }
                }

                Text("Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
            }

            Spacer()

            // Role
            HStack(spacing: 4) {
                Image(systemName: member.role.icon)
                    .font(.system(size: 10))
                Text(member.role.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.cmSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.cmBorder.opacity(0.3))
            .cornerRadius(4)

            // Actions (if can manage)
            if canManage && isHovering {
                Menu {
                    ForEach(TeamRole.allCases, id: \.self) { role in
                        if role != .owner {
                            Button(role.displayName) {
                                updateRole(to: role)
                            }
                        }
                    }
                    Divider()
                    Button("Remove", role: .destructive) {
                        removeMember()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovering ? Color.cmBorder.opacity(0.1) : Color.clear)
        .onHover { isHovering = $0 }
    }

    private func updateRole(to role: TeamRole) {
        teamManager.updateMemberRole(member.id, in: team.id, to: role) { _ in }
    }

    private func removeMember() {
        teamManager.removeMember(member.id, from: team.id) { _ in }
    }
}

// MARK: - Team Projects View

struct TeamProjectsView: View {
    let team: Team
    @ObservedObject var teamManager: TeamManager

    @State private var showingCreateProject = false

    var teamProjects: [Project] {
        teamManager.projects.filter { $0.teamId == team.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if teamProjects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundColor(.cmTertiary)
                    Text("No projects yet")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                    Button("Create Project") { showingCreateProject = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(teamProjects) { project in
                            ProjectRowView(project: project)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectSheet(teamManager: teamManager, teamId: team.id, isPresented: $showingCreateProject)
        }
    }
}

struct ProjectRowView: View {
    let project: Project

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: project.icon)
                .font(.system(size: 14))
                .foregroundColor(.cmText)
                .frame(width: 28, height: 28)
                .background(Color(hex: project.color).opacity(0.2))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 12, weight: .medium))
                Text("\(project.snippetCount) snippets")
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
            }

            Spacer()

            Image(systemName: project.privacy.icon)
                .font(.system(size: 10))
                .foregroundColor(.cmTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovering ? Color.cmBorder.opacity(0.1) : Color.clear)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Team Snippets List View

struct TeamSnippetsListView: View {
    let team: Team
    @ObservedObject var teamManager: TeamManager

    var teamSnippets: [TeamSnippet] {
        teamManager.teamSnippets.filter { $0.teamId == team.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if teamSnippets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundColor(.cmTertiary)
                    Text("No team snippets yet")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                    Text("Share snippets with your team")
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(teamSnippets) { snippet in
                            TeamSnippetRowView(snippet: snippet)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            teamManager.fetchTeamSnippets(for: team.id)
        }
    }
}

struct TeamSnippetRowView: View {
    let snippet: TeamSnippet

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: snippet.categoryEnum.icon)
                .font(.system(size: 12))
                .foregroundColor(.cmSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(snippet.displayAuthor)
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
            }

            Spacer()

            Image(systemName: snippet.privacy.icon)
                .font(.system(size: 10))
                .foregroundColor(.cmTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovering ? Color.cmBorder.opacity(0.1) : Color.clear)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Create Invite Sheet

struct CreateInviteSheet: View {
    let team: Team
    @ObservedObject var teamManager: TeamManager
    @Binding var isPresented: Bool

    @State private var selectedRole: TeamRole = .member
    @State private var selectedExpiration: InviteExpiration = .oneWeek
    @State private var selectedUsageLimit: InviteUsageLimit = .unlimited
    @State private var isCreating = false
    @State private var createdInvite: TeamInvite?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(createdInvite == nil ? "Create Invite" : "Invite Link")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            if let invite = createdInvite {
                // Show created invite
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)

                    Text("Invite link created!")
                        .font(.system(size: 13, weight: .medium))

                    // Link display
                    VStack(spacing: 8) {
                        Text(invite.webLink)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.cmSecondary)
                            .padding(10)
                            .background(Color.cmBorder.opacity(0.2))
                            .cornerRadius(6)
                            .textSelection(.enabled)

                        HStack(spacing: 12) {
                            Button(action: { copyLink(invite) }) {
                                Label("Copy Link", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: { shareLink(invite) }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Role: \(invite.role.displayName)")
                        Text("Expires: \(invite.expiresIn)")
                        if let remaining = invite.remainingUses {
                            Text("Uses: \(remaining) remaining")
                        } else {
                            Text("Uses: Unlimited")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
                }
                .padding(16)
            } else {
                // Create form
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Role picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Role for new members")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cmSecondary)
                            Picker("Role", selection: $selectedRole) {
                                ForEach(TeamRole.allCases.filter { $0 != .owner }, id: \.self) { role in
                                    Text(role.displayName).tag(role)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Expiration picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Link expires after")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cmSecondary)
                            Picker("Expiration", selection: $selectedExpiration) {
                                ForEach(InviteExpiration.allCases, id: \.self) { exp in
                                    Text(exp.displayName).tag(exp)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Usage limit picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Number of uses")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cmSecondary)
                            Picker("Usage", selection: $selectedUsageLimit) {
                                ForEach(InviteUsageLimit.allCases, id: \.self) { limit in
                                    Text(limit.displayName).tag(limit)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(16)
                }
            }

            Spacer()

            Divider()

            // Actions
            HStack {
                Button(createdInvite == nil ? "Cancel" : "Done") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.cmSecondary)

                Spacer()

                if createdInvite == nil {
                    Button(action: createInvite) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Create Link")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreating)
                }
            }
            .padding(16)
        }
        .frame(width: 360, height: 400)
    }

    private func createInvite() {
        isCreating = true

        teamManager.createInvite(for: team, role: selectedRole, expiration: selectedExpiration, usageLimit: selectedUsageLimit) { result in
            isCreating = false
            if case .success(let invite) = result {
                createdInvite = invite
            }
        }
    }

    private func copyLink(_ invite: TeamInvite) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(invite.webLink, forType: .string)
    }

    private func shareLink(_ invite: TeamInvite) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(invite.shareText, forType: .string)
    }
}

// MARK: - Create Project Sheet

struct CreateProjectSheet: View {
    @ObservedObject var teamManager: TeamManager
    let teamId: String
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = "folder"
    @State private var selectedColor = ProjectColor.blue
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Project")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Project Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmSecondary)
                    TextField("My Project", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.cmBorder.opacity(0.2))
                        .cornerRadius(6)
                }

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (optional)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmSecondary)
                    TextField("What's this project for?", text: $description)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.cmBorder.opacity(0.2))
                        .cornerRadius(6)
                }

                // Color
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cmSecondary)
                    HStack(spacing: 8) {
                        ForEach(ProjectColor.allCases, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(Color(hex: color.hex))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.cmText, lineWidth: selectedColor == color ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)

            Spacer()

            Divider()

            // Actions
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.cmSecondary)

                Spacer()

                Button(action: createProject) {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Create Project")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || isCreating)
            }
            .padding(16)
        }
        .frame(width: 320, height: 340)
    }

    private func createProject() {
        isCreating = true

        teamManager.createProject(name: name, teamId: teamId, description: description.isEmpty ? nil : description) { result in
            isCreating = false
            if case .success = result {
                isPresented = false
            }
        }
    }
}

// MARK: - Invitations List View

struct InvitationsListView: View {
    @ObservedObject var teamManager: TeamManager
    @State private var acceptingInvite: String?
    @State private var result: InviteAcceptanceResult?

    var body: some View {
        VStack(spacing: 0) {
            if teamManager.receivedInvitations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 28))
                        .foregroundColor(.cmTertiary)
                    Text("No pending invitations")
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                    Text("Invitations from teams will appear here")
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary)

                    Button(action: { teamManager.fetchPendingInvitations() }) {
                        Text("Refresh")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(teamManager.receivedInvitations) { received in
                            InvitationRowView(
                                received: received,
                                isAccepting: acceptingInvite == received.id,
                                onAccept: { acceptInvite(received) },
                                onDecline: { declineInvite(received) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Result message
            if let result = result {
                HStack {
                    Image(systemName: result.isSuccess ? "checkmark.circle" : "exclamationmark.circle")
                    Text(result.message)
                }
                .font(.system(size: 11))
                .foregroundColor(result.isSuccess ? .green : .red)
                .padding(10)
                .background((result.isSuccess ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(6)
                .padding()
            }
        }
        .onAppear {
            teamManager.fetchPendingInvitations()
        }
    }

    private func acceptInvite(_ received: ReceivedInvitation) {
        acceptingInvite = received.id
        result = nil

        teamManager.acceptInvite(token: received.invite.id) { acceptResult in
            acceptingInvite = nil
            result = acceptResult

            if acceptResult.isSuccess {
                // Remove from list
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    teamManager.fetchPendingInvitations()
                    result = nil
                }
            }
        }
    }

    private func declineInvite(_ received: ReceivedInvitation) {
        // Just remove from local list (don't mark as used)
        teamManager.receivedInvitations.removeAll { $0.id == received.id }
    }
}

struct InvitationRowView: View {
    let received: ReceivedInvitation
    let isAccepting: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Team icon
                Image(systemName: received.team.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.cmText)
                    .frame(width: 36, height: 36)
                    .background(Color(hex: received.team.color).opacity(0.2))
                    .cornerRadius(8)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(received.team.name)
                        .font(.system(size: 13, weight: .medium))

                    Text("\(received.inviterName) invited you as \(received.role.displayName)")
                        .font(.system(size: 10))
                        .foregroundColor(.cmSecondary)

                    HStack(spacing: 8) {
                        Label("\(received.team.memberCount) members", systemImage: "person")
                        Text("·")
                        Text("Expires \(received.invite.expiresIn)")
                    }
                    .font(.system(size: 9))
                    .foregroundColor(.cmTertiary)
                }

                Spacer()
            }

            // Actions
            HStack(spacing: 8) {
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundColor(.cmSecondary)
                .background(Color.cmBorder.opacity(0.3))
                .cornerRadius(6)

                Button(action: onAccept) {
                    if isAccepting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 60)
                    } else {
                        Text("Accept")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAccepting)
            }
        }
        .padding(12)
        .background(isHovering ? Color.cmBorder.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .padding(.horizontal, 8)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
