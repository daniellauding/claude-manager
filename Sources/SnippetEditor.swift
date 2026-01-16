import SwiftUI

struct SnippetEditor: View {
    @ObservedObject var manager: SnippetManager
    let snippet: Snippet?
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var category: SnippetCategory = .other
    @State private var tagsText: String = ""
    @State private var project: String = ""

    var isEditing: Bool { snippet != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit" : "New")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button(isEditing ? "Save" : "Add") {
                    saveSnippet()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(title.isEmpty || content.isEmpty)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)

                        TextField("Snippet title...", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }

                    // Category
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)

                        Picker("", selection: $category) {
                            ForEach(SnippetCategory.allCases) { cat in
                                HStack {
                                    Image(systemName: cat.icon)
                                    Text(cat.displayName)
                                }
                                .tag(cat)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags (comma-separated)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)

                        TextField("frontend, tutorial, api...", text: $tagsText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))

                        // Tag suggestions
                        if !manager.allTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    Text("Existing:")
                                        .font(.system(size: 10))
                                        .foregroundColor(.cmTertiary)

                                    ForEach(manager.allTags.prefix(8), id: \.self) { tag in
                                        Button(action: { addTag(tag) }) {
                                            Text(tag)
                                                .font(.system(size: 10))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.cmBorder.opacity(0.3))
                                                .cornerRadius(3)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(.cmSecondary)
                                    }
                                }
                            }
                        }
                    }

                    // Project
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Project (optional)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)

                        HStack {
                            TextField("Project name...", text: $project)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))

                            if !manager.recentProjects.isEmpty {
                                Picker("", selection: $project) {
                                    Text("Select...").tag("")
                                    ForEach(manager.recentProjects, id: \.self) { proj in
                                        Text(proj).tag(proj)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }
                        }
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Content")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cmSecondary)

                            Spacer()

                            Text("\(content.count) characters")
                                .font(.system(size: 10))
                                .foregroundColor(.cmTertiary)
                        }

                        TextEditor(text: $content)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(minHeight: 200)
                            .padding(4)
                            .background(Color.cmBorder.opacity(0.2))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.cmBorder, lineWidth: 1)
                            )
                    }
                }
                .padding()
            }
        }
        .frame(width: 550, height: 550)
        .onAppear {
            if let snippet = snippet {
                title = snippet.title
                content = snippet.content
                category = snippet.category
                tagsText = snippet.tags.joined(separator: ", ")
                project = snippet.project ?? ""
            }
        }
    }

    private func addTag(_ tag: String) {
        let currentTags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if !currentTags.contains(tag) {
            if tagsText.isEmpty {
                tagsText = tag
            } else {
                tagsText += ", \(tag)"
            }
        }
    }

    private func saveSnippet() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let existing = snippet {
            // Update existing
            var updated = existing
            updated.title = title
            updated.content = content
            updated.category = category
            updated.tags = tags
            updated.project = project.isEmpty ? nil : project
            manager.updateSnippet(updated)
        } else {
            // Create new
            let newSnippet = Snippet(
                title: title,
                content: content,
                category: category,
                tags: tags,
                project: project.isEmpty ? nil : project
            )
            manager.addSnippet(newSnippet)
        }

        dismiss()
    }
}

#Preview {
    SnippetEditor(manager: SnippetManager(), snippet: nil)
}
