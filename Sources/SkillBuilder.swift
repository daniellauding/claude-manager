import SwiftUI
import AppKit

// MARK: - Skill Builder View

struct SkillBuilderView: View {
    @ObservedObject var snippetManager: SnippetManager
    @Binding var isPresented: Bool

    @State private var currentStep: BuilderStep = .selectType
    @State private var selectedType: SnippetCategory = .prompt
    @State private var answers: [String: String] = [:]
    @State private var generatedContent: String = ""
    @State private var customTitle: String = ""
    @State private var isGenerating = false
    @State private var savedMessage: String?
    @State private var useAI = true
    @State private var apiKeys = APIKeys.load()

    enum BuilderStep: Int, CaseIterable {
        case selectType
        case questions
        case customize
        case result

        var title: String {
            switch self {
            case .selectType: return "What do you want to create?"
            case .questions: return "Tell me more"
            case .customize: return "Customize"
            case .result: return "Your creation"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Progress indicator
            progressBar

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    switch currentStep {
                    case .selectType:
                        typeSelectionView
                    case .questions:
                        questionsView
                    case .customize:
                        customizeView
                    case .result:
                        resultView
                    }
                }
                .padding(20)
            }

            Divider()

            // Navigation buttons
            navigationButtons
        }
        .frame(width: 480, height: 560)
        .background(Color.cmBackground)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.cmTertiary)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12))
                Text("Skill Builder")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.cmText)

            Spacer()

            // Placeholder for balance
            Color.clear.frame(width: 20, height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(BuilderStep.allCases, id: \.self) { step in
                    Rectangle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.cmText : Color.cmBorder.opacity(0.3))
                        .frame(height: 3)
                        .cornerRadius(1.5)
                }
            }
            .padding(.horizontal, 20)

            Text(currentStep.title)
                .font(.system(size: 11))
                .foregroundColor(.cmTertiary)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Type Selection

    private var typeSelectionView: some View {
        VStack(spacing: 20) {
            Text("I want to create a...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.cmText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                typeOption(.agent, description: "AI persona with expertise")
                typeOption(.skill, description: "Specific capability")
                typeOption(.prompt, description: "Reusable instruction")
                typeOption(.template, description: "Output format")
                typeOption(.workflow, description: "Multi-step process")
                typeOption(.hook, description: "Automation script")
            }

            // Quick start examples
            VStack(alignment: .leading, spacing: 10) {
                Text("Or start from an example:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cmTertiary)

                FlowLayout(spacing: 6) {
                    ForEach(examplesForType(selectedType), id: \.title) { example in
                        exampleChip(example)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func exampleChip(_ example: QuickExample) -> some View {
        Button(action: {
            // Pre-fill answers from example
            for (key, value) in example.prefill {
                answers[key] = value
            }
            customTitle = example.title
            // Skip to questions step
            withAnimation { currentStep = .questions }
        }) {
            Text(example.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.cmSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cmBorder.opacity(0.15))
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }

    private func typeOption(_ type: SnippetCategory, description: String) -> some View {
        Button(action: { selectedType = type }) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(selectedType == type ? .cmText : .cmSecondary)

                Text(type.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selectedType == type ? .cmText : .cmSecondary)

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.cmTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedType == type ? Color.cmBorder.opacity(0.2) : Color.cmBorder.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedType == type ? Color.cmText.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Questions View

    private var questionsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(questionsForType(selectedType), id: \.id) { question in
                questionCard(question)
            }
        }
    }

    private func questionCard(_ question: BuilderQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.question)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.cmText)

            if let hint = question.hint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(.cmTertiary)
            }

            if question.options.isEmpty {
                // Text input
                TextField(question.placeholder, text: answerBinding(for: question.id))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            } else {
                // Options
                FlowLayout(spacing: 8) {
                    ForEach(question.options, id: \.self) { option in
                        optionChip(option, questionId: question.id, multiSelect: question.multiSelect)
                    }
                }

                // Custom input if allowed
                if question.allowCustom {
                    HStack {
                        TextField("Or type your own...", text: customAnswerBinding(for: question.id))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.cmBorder.opacity(0.08))
        .cornerRadius(10)
    }

    private func optionChip(_ option: String, questionId: String, multiSelect: Bool) -> some View {
        let isSelected = answers[questionId]?.contains(option) ?? false

        return Button(action: {
            if multiSelect {
                var current = answers[questionId] ?? ""
                if current.contains(option) {
                    current = current.replacingOccurrences(of: option, with: "").replacingOccurrences(of: ", , ", with: ", ").trimmingCharacters(in: CharacterSet(charactersIn: ", "))
                } else {
                    current = current.isEmpty ? option : "\(current), \(option)"
                }
                answers[questionId] = current
            } else {
                answers[questionId] = option
            }
        }) {
            Text(option)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .cmBackground : .cmSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.cmText : Color.cmBorder.opacity(0.2))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func answerBinding(for id: String) -> Binding<String> {
        Binding(
            get: { answers[id] ?? "" },
            set: { answers[id] = $0 }
        )
    }

    private func customAnswerBinding(for id: String) -> Binding<String> {
        Binding(
            get: { answers["\(id)_custom"] ?? "" },
            set: { newValue in
                answers["\(id)_custom"] = newValue
                if !newValue.isEmpty {
                    let existing = answers[id] ?? ""
                    if !existing.contains(newValue) {
                        answers[id] = existing.isEmpty ? newValue : "\(existing), \(newValue)"
                    }
                }
            }
        )
    }

    // MARK: - Customize View

    private var customizeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Almost done! Give it a name and review.")
                .font(.system(size: 13))
                .foregroundColor(.cmSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cmSecondary)

                TextField("My \(selectedType.displayName)", text: $customTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cmSecondary)

                Text(generatePreview())
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.cmSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.cmBorder.opacity(0.1))
                    .cornerRadius(8)
            }

            // Additional options
            VStack(alignment: .leading, spacing: 12) {
                Text("Add more details (optional)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cmSecondary)

                TextEditor(text: answerBinding(for: "additional"))
                    .font(.system(size: 12))
                    .frame(height: 80)
                    .padding(8)
                    .background(Color.cmBorder.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Generating...")
                        .font(.system(size: 12))
                        .foregroundColor(.cmTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customTitle.isEmpty ? "My \(selectedType.displayName)" : customTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.cmText)

                        Text(selectedType.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.cmTertiary)
                    }

                    Spacer()

                    // Copy button
                    Button(action: copyResult) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(.cmSecondary)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    Text(generatedContent)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 250)
                .padding(12)
                .background(Color.cmBorder.opacity(0.1))
                .cornerRadius(8)

                if let msg = savedMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text(msg)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.cmText)
                }
            }
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if currentStep != .selectType {
                Button(action: goBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10))
                        Text("Back")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if currentStep == .result {
                Button(action: saveToLibrary) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Save to Library")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.cmBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cmText)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: goNext) {
                    HStack(spacing: 4) {
                        Text(currentStep == .customize ? "Generate" : "Next")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.cmBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(canProceed ? Color.cmText : Color.cmTertiary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!canProceed)
            }
        }
        .padding(16)
    }

    private var canProceed: Bool {
        switch currentStep {
        case .selectType:
            return true
        case .questions:
            let required = questionsForType(selectedType).filter { !$0.optional }
            return required.allSatisfy { !(answers[$0.id] ?? "").isEmpty }
        case .customize:
            return true
        case .result:
            return true
        }
    }

    private func goBack() {
        if let prev = BuilderStep(rawValue: currentStep.rawValue - 1) {
            withAnimation { currentStep = prev }
        }
    }

    private func goNext() {
        if currentStep == .customize {
            generateContent()
        }
        if let next = BuilderStep(rawValue: currentStep.rawValue + 1) {
            withAnimation { currentStep = next }
        }
    }

    // MARK: - Generation

    private func generatePreview() -> String {
        let lines = questionsForType(selectedType).compactMap { q -> String? in
            guard let answer = answers[q.id], !answer.isEmpty else { return nil }
            return "• \(q.shortLabel): \(answer)"
        }
        return lines.joined(separator: "\n")
    }

    private func generateContent() {
        isGenerating = true

        // Generate based on type and answers
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generatedContent = buildContent()
            isGenerating = false
        }
    }

    private func buildContent() -> String {
        switch selectedType {
        case .agent:
            return buildAgentContent()
        case .skill:
            return buildSkillContent()
        case .prompt:
            return buildPromptContent()
        case .template:
            return buildTemplateContent()
        case .workflow:
            return buildWorkflowContent()
        case .hook:
            return buildHookContent()
        default:
            return buildGenericContent()
        }
    }

    private func buildAgentContent() -> String {
        let role = answers["role"] ?? "assistant"
        let expertise = answers["expertise"] ?? "general tasks"
        let personality = answers["personality"] ?? "helpful and professional"
        let rules = answers["rules"] ?? ""
        let additional = answers["additional"] ?? ""

        var content = """
        You are an expert \(role) specialized in \(expertise).

        ## Personality
        Your communication style is \(personality).

        ## Expertise Areas
        \(expertise.split(separator: ",").map { "- \($0.trimmingCharacters(in: .whitespaces))" }.joined(separator: "\n"))
        """

        if !rules.isEmpty {
            content += "\n\n## Guidelines\n\(rules.split(separator: ",").map { "- \($0.trimmingCharacters(in: .whitespaces))" }.joined(separator: "\n"))"
        }

        if !additional.isEmpty {
            content += "\n\n## Additional Instructions\n\(additional)"
        }

        return content
    }

    private func buildSkillContent() -> String {
        let action = answers["action"] ?? "help with"
        let domain = answers["domain"] ?? "tasks"
        let approach = answers["approach"] ?? ""
        let output = answers["output"] ?? ""
        let additional = answers["additional"] ?? ""

        var content = """
        When asked to \(action) related to \(domain):

        ## Approach
        """

        if !approach.isEmpty {
            content += "\n\(approach.split(separator: ",").map { "- \($0.trimmingCharacters(in: .whitespaces))" }.joined(separator: "\n"))"
        } else {
            content += "\n- Analyze the request carefully\n- Break down into steps\n- Provide clear explanations"
        }

        if !output.isEmpty {
            content += "\n\n## Output Format\n\(output)"
        }

        if !additional.isEmpty {
            content += "\n\n## Notes\n\(additional)"
        }

        return content
    }

    private func buildPromptContent() -> String {
        let goal = answers["goal"] ?? "accomplish a task"
        let context = answers["context"] ?? ""
        let format = answers["format"] ?? ""
        let additional = answers["additional"] ?? ""

        var content = goal

        if !context.isEmpty {
            content += "\n\nContext: \(context)"
        }

        if !format.isEmpty {
            content += "\n\nFormat the response as: \(format)"
        }

        if !additional.isEmpty {
            content += "\n\n\(additional)"
        }

        return content
    }

    private func buildTemplateContent() -> String {
        let purpose = answers["purpose"] ?? "structured output"
        let sections = answers["sections"] ?? "Summary, Details, Conclusion"
        let style = answers["style"] ?? "professional"
        let additional = answers["additional"] ?? ""

        var content = """
        Format your response for \(purpose) using this structure:

        """

        let sectionList = sections.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for section in sectionList {
            content += "## \(section)\n[Your \(section.lowercased()) here]\n\n"
        }

        content += "Style: \(style)"

        if !additional.isEmpty {
            content += "\n\nAdditional requirements:\n\(additional)"
        }

        return content
    }

    private func buildWorkflowContent() -> String {
        let goal = answers["goal"] ?? "complete a task"
        let steps = answers["steps"] ?? "Plan, Execute, Review"
        let tools = answers["tools"] ?? ""
        let additional = answers["additional"] ?? ""

        var content = """
        # Workflow: \(customTitle.isEmpty ? goal : customTitle)

        ## Goal
        \(goal)

        ## Steps
        """

        let stepList = steps.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for (index, step) in stepList.enumerated() {
            content += "\n\(index + 1). **\(step)**\n   - [Details for this step]"
        }

        if !tools.isEmpty {
            content += "\n\n## Tools Required\n\(tools.split(separator: ",").map { "- \($0.trimmingCharacters(in: .whitespaces))" }.joined(separator: "\n"))"
        }

        if !additional.isEmpty {
            content += "\n\n## Notes\n\(additional)"
        }

        return content
    }

    private func buildHookContent() -> String {
        let trigger = answers["trigger"] ?? "SessionStart"
        let action = answers["action"] ?? "run a script"
        let script = answers["script"] ?? "echo 'Hook triggered'"
        let additional = answers["additional"] ?? ""

        var content = """
        # Hook: \(trigger)

        ## Trigger
        This hook runs on: \(trigger)

        ## Action
        \(action)

        ## Script
        ```bash
        \(script)
        ```

        ## Setup
        Run `/hooks` in Claude Code and add this hook for the \(trigger) event.
        """

        if !additional.isEmpty {
            content += "\n\n## Notes\n\(additional)"
        }

        return content
    }

    private func buildGenericContent() -> String {
        var content = ""
        for question in questionsForType(selectedType) {
            if let answer = answers[question.id], !answer.isEmpty {
                content += "\(question.shortLabel): \(answer)\n"
            }
        }
        if let additional = answers["additional"], !additional.isEmpty {
            content += "\n\(additional)"
        }
        return content
    }

    // MARK: - Actions

    private func copyResult() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedContent, forType: .string)
    }

    private func saveToLibrary() {
        let snippet = Snippet(
            title: customTitle.isEmpty ? "My \(selectedType.displayName)" : customTitle,
            content: generatedContent,
            category: selectedType,
            tags: ["generated"],
            project: nil,
            isFavorite: false
        )
        snippetManager.addSnippet(snippet)
        savedMessage = "Saved to Library!"

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isPresented = false
        }
    }
}

// MARK: - Quick Examples

struct QuickExample {
    let title: String
    let prefill: [String: String]
}

func examplesForType(_ type: SnippetCategory) -> [QuickExample] {
    switch type {
    case .agent:
        return [
            QuickExample(title: "Code Reviewer", prefill: ["role": "Code Reviewer", "expertise": "Code quality, Best practices, Security", "personality": "Thorough, Constructive"]),
            QuickExample(title: "Technical Writer", prefill: ["role": "Technical Writer", "expertise": "Documentation, API docs, Tutorials", "personality": "Clear, Detailed"]),
            QuickExample(title: "Debugging Expert", prefill: ["role": "Debugger", "expertise": "Bug hunting, Stack traces, Performance", "personality": "Analytical, Patient"]),
            QuickExample(title: "Architect", prefill: ["role": "Software Architect", "expertise": "System design, Patterns, Scalability", "personality": "Strategic, Thorough"]),
        ]
    case .skill:
        return [
            QuickExample(title: "Write Unit Tests", prefill: ["action": "Write tests", "domain": "Testing, Code coverage", "approach": "Analyze code first, Cover edge cases"]),
            QuickExample(title: "Refactor Code", prefill: ["action": "Refactor", "domain": "Code quality", "approach": "Identify smells, Preserve behavior"]),
            QuickExample(title: "API Documentation", prefill: ["action": "Document", "domain": "API, Endpoints", "output": "Markdown with examples"]),
            QuickExample(title: "Security Audit", prefill: ["action": "Audit for security", "domain": "Security, OWASP", "approach": "Check vulnerabilities"]),
        ]
    case .prompt:
        return [
            QuickExample(title: "Explain [concept]", prefill: ["goal": "Explain [concept] in simple terms", "format": "Bullet points"]),
            QuickExample(title: "Compare [A] vs [B]", prefill: ["goal": "Compare [A] and [B]", "format": "Comparison table"]),
            QuickExample(title: "Debug this error", prefill: ["goal": "Help me debug: [error message]", "context": "I'm getting this error..."]),
            QuickExample(title: "Improve this code", prefill: ["goal": "Review and improve: [paste code]", "format": "Code with comments"]),
        ]
    case .template:
        return [
            QuickExample(title: "PR Description", prefill: ["purpose": "PR description", "sections": "Summary, Changes, Testing, Notes"]),
            QuickExample(title: "Bug Report", prefill: ["purpose": "Bug report", "sections": "Description, Steps to Reproduce, Expected, Actual"]),
            QuickExample(title: "Meeting Notes", prefill: ["purpose": "Meeting notes", "sections": "Attendees, Discussion, Decisions, Action Items"]),
            QuickExample(title: "Code Review", prefill: ["purpose": "Code review", "sections": "Overview, Issues, Suggestions, Verdict"]),
        ]
    case .workflow:
        return [
            QuickExample(title: "Feature Development", prefill: ["goal": "Develop a new feature end-to-end", "steps": "Plan, Branch, Implement, Test, PR, Review, Merge", "tools": "Git, Editor, Terminal"]),
            QuickExample(title: "Bug Fix", prefill: ["goal": "Fix a bug systematically", "steps": "Reproduce, Investigate, Fix, Test, Document", "tools": "Git, Debugger"]),
            QuickExample(title: "Code Review", prefill: ["goal": "Review a PR thoroughly", "steps": "Read description, Check code, Run tests, Leave feedback", "tools": "Git, Browser"]),
            QuickExample(title: "Deploy Release", prefill: ["goal": "Deploy to production", "steps": "Version bump, Build, Test, Deploy, Verify, Monitor", "tools": "Git, CI/CD, Terminal"]),
        ]
    case .hook:
        return [
            QuickExample(title: "Add Date Context", prefill: ["trigger": "SessionStart", "action": "Add current date", "script": "echo \"Today is $(date '+%A, %B %d, %Y')\""]),
            QuickExample(title: "Git Branch Info", prefill: ["trigger": "SessionStart", "action": "Show git status", "script": "git branch --show-current && git status -s"]),
            QuickExample(title: "Notify on Complete", prefill: ["trigger": "Stop", "action": "Send notification", "script": "osascript -e 'display notification \"Claude finished\" with title \"Claude Code\"'"]),
            QuickExample(title: "Auto-format Code", prefill: ["trigger": "PostToolUse", "action": "Format on save", "script": "if [[ $TOOL == 'write' ]]; then prettier --write \"$FILE\"; fi"]),
        ]
    default:
        return []
    }
}

// MARK: - Questions Data

struct BuilderQuestion: Identifiable {
    let id: String
    let question: String
    let shortLabel: String
    let hint: String?
    let placeholder: String
    let options: [String]
    let multiSelect: Bool
    let allowCustom: Bool
    let optional: Bool

    init(id: String, question: String, shortLabel: String, hint: String? = nil, placeholder: String = "", options: [String] = [], multiSelect: Bool = false, allowCustom: Bool = false, optional: Bool = false) {
        self.id = id
        self.question = question
        self.shortLabel = shortLabel
        self.hint = hint
        self.placeholder = placeholder
        self.options = options
        self.multiSelect = multiSelect
        self.allowCustom = allowCustom
        self.optional = optional
    }
}

func questionsForType(_ type: SnippetCategory) -> [BuilderQuestion] {
    switch type {
    case .agent:
        return [
            BuilderQuestion(
                id: "role",
                question: "What role should the agent play?",
                shortLabel: "Role",
                hint: "The agent's primary function",
                options: ["Developer", "Reviewer", "Writer", "Analyst", "Teacher", "Designer"],
                allowCustom: true
            ),
            BuilderQuestion(
                id: "expertise",
                question: "What areas of expertise?",
                shortLabel: "Expertise",
                hint: "Select multiple or add your own",
                options: ["Swift", "Python", "JavaScript", "React", "Backend", "DevOps", "Data", "Security"],
                multiSelect: true,
                allowCustom: true
            ),
            BuilderQuestion(
                id: "personality",
                question: "What communication style?",
                shortLabel: "Style",
                options: ["Professional", "Friendly", "Concise", "Detailed", "Encouraging", "Direct"],
                multiSelect: true
            ),
            BuilderQuestion(
                id: "rules",
                question: "Any specific rules or constraints?",
                shortLabel: "Rules",
                hint: "Things the agent should always or never do",
                placeholder: "e.g., Always explain reasoning, Never use deprecated APIs",
                optional: true
            )
        ]
    case .skill:
        return [
            BuilderQuestion(
                id: "action",
                question: "What action should this skill perform?",
                shortLabel: "Action",
                options: ["Review code", "Write tests", "Debug issues", "Refactor", "Document", "Optimize"],
                allowCustom: true
            ),
            BuilderQuestion(
                id: "domain",
                question: "In what domain or context?",
                shortLabel: "Domain",
                options: ["Frontend", "Backend", "Database", "API", "Mobile", "Infrastructure"],
                multiSelect: true,
                allowCustom: true
            ),
            BuilderQuestion(
                id: "approach",
                question: "How should it approach the task?",
                shortLabel: "Approach",
                options: ["Step-by-step", "Quick scan first", "Ask clarifying questions", "Show examples"],
                multiSelect: true,
                optional: true
            ),
            BuilderQuestion(
                id: "output",
                question: "What format for the output?",
                shortLabel: "Output",
                options: ["Bullet points", "Code blocks", "Markdown", "Numbered steps", "Table"],
                optional: true
            )
        ]
    case .prompt:
        return [
            BuilderQuestion(
                id: "goal",
                question: "What do you want to accomplish?",
                shortLabel: "Goal",
                placeholder: "e.g., Explain a concept, Generate code, Analyze data"
            ),
            BuilderQuestion(
                id: "context",
                question: "Any context to include?",
                shortLabel: "Context",
                placeholder: "e.g., I'm working on a React app...",
                optional: true
            ),
            BuilderQuestion(
                id: "format",
                question: "Preferred response format?",
                shortLabel: "Format",
                options: ["Paragraph", "Bullet points", "Code", "Step-by-step", "Comparison table"],
                optional: true
            )
        ]
    case .template:
        return [
            BuilderQuestion(
                id: "purpose",
                question: "What is this template for?",
                shortLabel: "Purpose",
                options: ["Code review", "Documentation", "Report", "Meeting notes", "PR description", "Bug report"],
                allowCustom: true
            ),
            BuilderQuestion(
                id: "sections",
                question: "What sections should it include?",
                shortLabel: "Sections",
                hint: "Separate with commas",
                placeholder: "e.g., Summary, Changes, Testing, Notes"
            ),
            BuilderQuestion(
                id: "style",
                question: "What style?",
                shortLabel: "Style",
                options: ["Professional", "Technical", "Casual", "Detailed", "Brief"],
                optional: true
            )
        ]
    case .workflow:
        return [
            BuilderQuestion(
                id: "goal",
                question: "What's the end goal of this workflow?",
                shortLabel: "Goal",
                placeholder: "e.g., Deploy a feature, Review a PR, Set up a project"
            ),
            BuilderQuestion(
                id: "steps",
                question: "What are the main steps?",
                shortLabel: "Steps",
                hint: "Separate with commas",
                placeholder: "e.g., Plan, Implement, Test, Review, Deploy"
            ),
            BuilderQuestion(
                id: "tools",
                question: "What tools are involved?",
                shortLabel: "Tools",
                options: ["Git", "Terminal", "Browser", "Editor", "Docker", "Database"],
                multiSelect: true,
                allowCustom: true,
                optional: true
            )
        ]
    case .hook:
        return [
            BuilderQuestion(
                id: "trigger",
                question: "When should this hook run?",
                shortLabel: "Trigger",
                hint: "Claude Code hook events",
                options: ["SessionStart", "Stop", "PostToolUse", "PreToolUse", "Notification"]
            ),
            BuilderQuestion(
                id: "action",
                question: "What should it do?",
                shortLabel: "Action",
                options: ["Add context", "Run checks", "Send notification", "Log activity", "Validate input"],
                allowCustom: true
            ),
            BuilderQuestion(
                id: "script",
                question: "What command or script?",
                shortLabel: "Script",
                hint: "Bash command to run",
                placeholder: "e.g., echo \"Today is $(date)\""
            )
        ]
    default:
        return [
            BuilderQuestion(
                id: "content",
                question: "What content do you want to save?",
                shortLabel: "Content",
                placeholder: "Enter your content here..."
            )
        ]
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + lineHeight
        }
    }
}
