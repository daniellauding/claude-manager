import Foundation
import Combine
import AppKit

class SnippetManager: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var watchedFolders: [String] = []
    @Published var recentProjects: [String] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var currentFilter: SnippetFilter = .all
    @Published var currentSort: SnippetSort = .recent

    private let storageURL: URL
    private var folderWatchers: [String: DispatchSourceFileSystemObject] = [:]
    private var syncTimer: Timer?

    init() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")

        // Create .claude directory if needed
        try? FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        storageURL = claudeDir.appendingPathComponent("snippets.json")
        loadFromDisk()
        startFolderSync()
    }

    deinit {
        stopFolderSync()
    }

    // MARK: - Filtered & Sorted Results

    var filteredSnippets: [Snippet] {
        var result = snippets

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { snippet in
                snippet.title.lowercased().contains(query) ||
                snippet.content.lowercased().contains(query) ||
                snippet.tags.contains { $0.lowercased().contains(query) } ||
                (snippet.project?.lowercased().contains(query) ?? false)
            }
        }

        // Apply category/status filter
        switch currentFilter {
        case .all:
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .recent:
            result = result.filter { $0.lastUsedAt != nil }
                .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            return Array(result.prefix(20))
        case .category(let cat):
            result = result.filter { $0.category == cat }
        case .tag(let tag):
            result = result.filter { $0.tags.contains(tag) }
        case .project(let proj):
            result = result.filter { $0.project == proj }
        }

        // Apply sorting
        switch currentSort {
        case .title:
            result.sort { $0.title.lowercased() < $1.title.lowercased() }
        case .recent:
            result.sort { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        case .mostUsed:
            result.sort { $0.useCount > $1.useCount }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        }

        return result
    }

    var allTags: [String] {
        Array(Set(snippets.flatMap { $0.tags })).sorted()
    }

    var allProjects: [String] {
        Array(Set(snippets.compactMap { $0.project })).sorted()
    }

    // MARK: - CRUD Operations

    func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        if let project = snippet.project, !recentProjects.contains(project) {
            recentProjects.insert(project, at: 0)
            if recentProjects.count > 10 {
                recentProjects = Array(recentProjects.prefix(10))
            }
        }
        saveToDisk()
    }

    func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            saveToDisk()
        }
    }

    func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveToDisk()
    }

    func toggleFavorite(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index].toggleFavorite()
            saveToDisk()
        }
    }

    func markUsed(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index].markUsed()
            saveToDisk()
        }
    }

    func copyToClipboard(_ snippet: Snippet) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet.content, forType: .string)
        markUsed(snippet)
    }

    // MARK: - Folder Watching

    func addWatchedFolder(_ path: String) {
        guard !watchedFolders.contains(path) else { return }
        watchedFolders.append(path)
        importFromFolder(path)
        startWatching(folder: path)
        saveToDisk()
    }

    func removeWatchedFolder(_ path: String) {
        watchedFolders.removeAll { $0 == path }
        stopWatching(folder: path)
        // Remove synced snippets from this folder
        snippets.removeAll { $0.sourceFile?.hasPrefix(path) ?? false }
        saveToDisk()
    }

    func refreshWatchedFolders() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            for folder in self.watchedFolders {
                self.importFromFolder(folder)
            }
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }

    private func startFolderSync() {
        // Sync every 30 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshWatchedFolders()
        }

        // Start watching existing folders
        for folder in watchedFolders {
            startWatching(folder: folder)
        }
    }

    private func stopFolderSync() {
        syncTimer?.invalidate()
        for (_, watcher) in folderWatchers {
            watcher.cancel()
        }
        folderWatchers.removeAll()
    }

    private func startWatching(folder: String) {
        let fd = open(folder, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .global()
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.importFromFolder(folder)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        folderWatchers[folder] = source
    }

    private func stopWatching(folder: String) {
        folderWatchers[folder]?.cancel()
        folderWatchers.removeValue(forKey: folder)
    }

    private func importFromFolder(_ folder: String) {
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folder)

        guard let files = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let markdownFiles = files.filter { $0.pathExtension == "md" }

        for file in markdownFiles {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }

            let filename = file.deletingPathExtension().lastPathComponent
            let title = extractTitle(from: content, filename: filename)
            let category = SnippetCategory.infer(from: content, filename: filename)
            let tags = extractTags(from: content)
            let project = extractProject(from: folder)

            // Check if snippet already exists (by source file)
            if let existingIndex = snippets.firstIndex(where: { $0.sourceFile == file.path }) {
                // Update existing snippet
                var updated = snippets[existingIndex]
                updated.title = title
                updated.content = content
                updated.category = category
                updated.tags = tags
                DispatchQueue.main.async {
                    self.snippets[existingIndex] = updated
                }
            } else {
                // Add new snippet
                let snippet = Snippet(
                    title: title,
                    content: content,
                    category: category,
                    tags: tags,
                    project: project,
                    sourceFile: file.path
                )
                DispatchQueue.main.async {
                    self.snippets.append(snippet)
                }
            }
        }

        DispatchQueue.main.async {
            self.saveToDisk()
        }
    }

    // MARK: - Content Parsing Helpers

    private func extractTitle(from content: String, filename: String) -> String {
        // Try to find H1 header
        let lines = content.components(separatedBy: .newlines)
        for line in lines.prefix(10) {
            if line.hasPrefix("# ") {
                return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }

        // Try to find Agent Name or title in metadata
        if let match = content.range(of: "Agent Name:\\s*(.+)", options: .regularExpression) {
            let line = String(content[match])
            if let colonIndex = line.firstIndex(of: ":") {
                return String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Fallback to filename
        return filename.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private func extractTags(from content: String) -> [String] {
        var tags: [String] = []

        // Look for explicit tags
        if let match = content.range(of: "tags?:\\s*\\[?([^\\]\\n]+)", options: [.regularExpression, .caseInsensitive]) {
            let tagString = String(content[match])
            if let colonIndex = tagString.firstIndex(of: ":") {
                let tagsText = String(tagString[tagString.index(after: colonIndex)...])
                tags = tagsText
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .components(separatedBy: CharacterSet(charactersIn: ",;"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }

        // Auto-detect common keywords
        let keywords = ["frontend", "backend", "ux", "ui", "figma", "api", "testing", "tutorial", "agent", "mcp"]
        for keyword in keywords {
            if content.lowercased().contains(keyword) && !tags.contains(keyword) {
                tags.append(keyword)
            }
        }

        return Array(Set(tags)).sorted()
    }

    private func extractProject(from folderPath: String) -> String? {
        // Extract project name from folder path
        let components = folderPath.components(separatedBy: "/")
        if let index = components.firstIndex(of: "internal"), index + 1 < components.count {
            return components[index + 1]
        }
        return components.last
    }

    // MARK: - Export / Import

    func exportLibrary(to url: URL) -> Bool {
        let exportData = LibraryExport(
            version: "1.1.0",
            exportDate: Date(),
            snippets: snippets,
            watchedFolders: watchedFolders
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(exportData) else { return false }

        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func importLibrary(from url: URL) -> Int {
        guard let data = try? Data(contentsOf: url) else { return 0 }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try new format first
        if let importData = try? decoder.decode(LibraryExport.self, from: data) {
            return mergeImport(importData.snippets)
        }

        // Try legacy format (just snippets array)
        if let legacySnippets = try? decoder.decode([Snippet].self, from: data) {
            return mergeImport(legacySnippets)
        }

        // Try SnippetStorage format
        if let storage = try? decoder.decode(SnippetStorage.self, from: data) {
            return mergeImport(storage.snippets)
        }

        return 0
    }

    private func mergeImport(_ importedSnippets: [Snippet]) -> Int {
        var addedCount = 0
        let existingTitles = Set(snippets.map { $0.title.lowercased() })

        for snippet in importedSnippets {
            // Skip duplicates by title
            if existingTitles.contains(snippet.title.lowercased()) {
                continue
            }

            // Create new snippet with fresh ID
            let newSnippet = Snippet(
                id: UUID(),
                title: snippet.title,
                content: snippet.content,
                category: snippet.category,
                tags: snippet.tags,
                project: snippet.project,
                isFavorite: snippet.isFavorite,
                sourceFile: nil,  // Clear source file on import
                createdAt: Date(),
                lastUsedAt: nil,
                useCount: 0
            )

            snippets.append(newSnippet)
            addedCount += 1
        }

        if addedCount > 0 {
            saveToDisk()
        }

        return addedCount
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let storage = try? JSONDecoder().decode(SnippetStorage.self, from: data) else {
            return
        }

        snippets = storage.snippets
        watchedFolders = storage.watchedFolders
        recentProjects = storage.recentProjects
    }

    private func saveToDisk() {
        let storage = SnippetStorage(
            snippets: snippets,
            watchedFolders: watchedFolders,
            recentProjects: recentProjects
        )

        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

// MARK: - Library Export Format

struct LibraryExport: Codable {
    let version: String
    let exportDate: Date
    let snippets: [Snippet]
    let watchedFolders: [String]
}
