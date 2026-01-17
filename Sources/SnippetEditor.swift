import SwiftUI

struct SnippetEditor: View {
    @ObservedObject var manager: SnippetManager
    let snippet: Snippet?
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var category: SnippetCategory = .prompt
    @State private var tagsText: String = ""
    @State private var project: String = ""

    var isEditing: Bool { snippet != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Snippet" : "New Snippet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cmText)

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.cmSecondary)
                    .keyboardShortcut(.escape)

                Button(isEditing ? "Save" : "Add") {
                    saveSnippet()
                }
                .buttonStyle(.plain)
                .foregroundColor(title.isEmpty || content.isEmpty ? .cmTertiary : .cmText)
                .fontWeight(.medium)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(title.isEmpty || content.isEmpty)
            }
            .padding(16)

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
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color.cmBorder.opacity(0.15))
                            .cornerRadius(6)
                    }

                    // Category - use menu picker instead of segmented
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)

                        Menu {
                            ForEach(SnippetCategory.allCases) { cat in
                                Button(action: { category = cat }) {
                                    HStack {
                                        Image(systemName: cat.icon)
                                        Text(cat.displayName)
                                        if category == cat {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .font(.system(size: 11))
                                Text(category.displayName)
                                    .font(.system(size: 12))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.cmText)
                            .padding(8)
                            .background(Color.cmBorder.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .menuStyle(.borderlessButton)
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags (comma-separated)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cmSecondary)

                        TextField("frontend, api, tutorial...", text: $tagsText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color.cmBorder.opacity(0.15))
                            .cornerRadius(6)

                        // Quick tags
                        if !manager.allTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(manager.allTags.prefix(6), id: \.self) { tag in
                                        Button(action: { addTag(tag) }) {
                                            Text(tag)
                                                .font(.system(size: 9))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.cmBorder.opacity(0.2))
                                                .cornerRadius(4)
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

                        TextField("Project name...", text: $project)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color.cmBorder.opacity(0.15))
                            .cornerRadius(6)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Content")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cmSecondary)

                            Spacer()

                            Text("\(content.count) chars")
                                .font(.system(size: 9))
                                .foregroundColor(.cmTertiary)
                        }

                        TextEditor(text: $content)
                            .font(.system(size: 11, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.cmBorder.opacity(0.15))
                            .cornerRadius(6)
                            .frame(minHeight: 150, maxHeight: 200)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 380, height: 480)
        .background(Color.cmBackground)
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
            var updated = existing
            updated.title = title
            updated.content = content
            updated.category = category
            updated.tags = tags
            updated.project = project.isEmpty ? nil : project
            manager.updateSnippet(updated)
        } else {
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
