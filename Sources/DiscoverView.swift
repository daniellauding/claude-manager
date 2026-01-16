import SwiftUI
import AppKit

// MARK: - Discover View (replaces sheet - now inline)

struct DiscoverView: View {
    @ObservedObject var snippetManager: SnippetManager
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var isLoading = false
    @State private var results: [DiscoverItem] = []
    @State private var selectedItem: DiscoverItem?
    @State private var previewContent: String?
    @State private var savedIds: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    if selectedItem != nil {
                        // Go back to Discover list
                        selectedItem = nil
                        previewContent = nil
                    } else {
                        // Exit Discover entirely
                        isPresented = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11))
                        Text(selectedItem != nil ? "Discover" : "Back")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.cmSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(selectedItem?.title ?? "Discover")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                // Spacer for balance
                Text("Discover")
                    .font(.system(size: 12))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            if let item = selectedItem {
                // Detail view
                detailView(item: item)
            } else {
                // List view
                listView
            }
        }
        .onAppear { loadFeatured() }
    }

    @State private var isSearching = false

    // MARK: - List View

    private var listView: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.cmTertiary)

                    TextField("Search GitHub for prompts...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit { search(); isSearching = true }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            isSearching = false
                            loadFeatured()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.cmTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.cmBorder.opacity(0.2))
                .cornerRadius(8)

                if !searchText.isEmpty {
                    Button(action: { search(); isSearching = true }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.cmText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // Quick search suggestions
            if !isSearching && searchText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Text("Try:")
                            .font(.system(size: 11))
                            .foregroundColor(.cmTertiary)

                        ForEach(["awesome prompts", "mcp server", "chatgpt", "coding agent"], id: \.self) { suggestion in
                            Button(action: {
                                searchText = suggestion
                                search()
                                isSearching = true
                            }) {
                                Text(suggestion)
                                    .font(.system(size: 11))
                                    .foregroundColor(.cmSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.cmBorder.opacity(0.2))
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 10)
            }

            Divider()

            // Content
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Section header
                    if !isLoading && errorMessage == nil {
                        HStack {
                            Text(isSearching ? "GitHub Results" : "Featured")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cmTertiary)

                            Spacer()

                            Text("\(results.count) items")
                                .font(.system(size: 10))
                                .foregroundColor(.cmTertiary.opacity(0.7))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching GitHub...")
                                .font(.system(size: 12))
                                .foregroundColor(.cmTertiary)
                            Spacer()
                        }
                        .padding(.vertical, 60)
                    } else if let error = errorMessage {
                        VStack(spacing: 8) {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.cmTertiary)
                            Button("Show featured") {
                                isSearching = false
                                searchText = ""
                                loadFeatured()
                            }
                                .font(.system(size: 12))
                                .foregroundColor(.cmSecondary)
                        }
                        .padding(.vertical, 60)
                    } else {
                        ForEach(results) { item in
                            DiscoverRow(
                                item: item,
                                isSaved: savedIds.contains(item.id),
                                onTap: { selectedItem = item; loadPreview(item) }
                            )
                            Divider().padding(.leading, 20)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Detail View

    private func detailView(item: DiscoverItem) -> some View {
        VStack(spacing: 0) {
            // Back + Title
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.category.displayName.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cmTertiary)

                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.cmText)

                    Text(item.description)
                        .font(.system(size: 12))
                        .foregroundColor(.cmSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Content preview
            ScrollView {
                if let content = previewContent {
                    Text(content)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cmSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.system(size: 12))
                            .foregroundColor(.cmTertiary)
                        Spacer()
                    }
                    .padding(.vertical, 40)
                }
            }
            .background(Color.cmBorder.opacity(0.1))

            Divider()

            // Actions
            HStack(spacing: 16) {
                Button(action: { openInBrowser(item.url) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "safari")
                        Text("View Source")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.cmSecondary)

                Spacer()

                Button(action: { saveItem(item) }) {
                    HStack(spacing: 4) {
                        Image(systemName: savedIds.contains(item.id) ? "checkmark" : "plus")
                        Text(savedIds.contains(item.id) ? "Saved!" : "Save to Library")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(savedIds.contains(item.id) ? .green : .cmBackground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(savedIds.contains(item.id) ? Color.green.opacity(0.15) : Color.cmText)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(savedIds.contains(item.id))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Data Loading

    private func loadFeatured() {
        isLoading = true
        errorMessage = nil

        // Load from curated sources
        results = [
            // AGENTS
            DiscoverItem(
                id: "code-review",
                title: "Code Review Agent",
                description: "Reviews code for bugs, security issues, and suggests improvements",
                category: .agent,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                # Code Review Agent

                You are an expert code reviewer. Analyze the provided code and:

                1. **Identify bugs** - Look for logic errors, null pointer issues, race conditions
                2. **Security review** - Check for SQL injection, XSS, auth issues
                3. **Performance** - Identify N+1 queries, unnecessary loops, memory leaks
                4. **Best practices** - Suggest cleaner patterns, better naming, documentation

                Format your response as:
                - 🐛 **Bugs**: List of issues
                - 🔒 **Security**: Vulnerabilities found
                - ⚡ **Performance**: Optimization suggestions
                - ✨ **Improvements**: Code quality suggestions

                Be specific with line numbers and provide fixed code examples.
                """
            ),
            DiscoverItem(
                id: "refactor",
                title: "Refactoring Assistant",
                description: "Helps refactor code while maintaining behavior",
                category: .agent,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                # Refactoring Assistant

                Help refactor code while preserving existing behavior.

                ## Approach
                1. First, understand what the code currently does
                2. Identify code smells and improvement opportunities
                3. Suggest refactoring in small, safe steps
                4. Each step should be independently testable

                ## Common Refactorings
                - Extract method/function
                - Rename for clarity
                - Remove duplication
                - Simplify conditionals
                - Replace magic numbers with constants

                ## Output Format
                For each suggestion:
                - What to change
                - Why it improves the code
                - Before/after code snippets
                - How to verify behavior is unchanged

                Never change behavior - only improve structure.
                """
            ),
            DiscoverItem(
                id: "debug-agent",
                title: "Debugging Agent",
                description: "Systematically diagnoses and fixes bugs",
                category: .agent,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                # Debugging Agent

                You are an expert debugger. When given a bug report or error:

                ## Process
                1. **Reproduce** - Understand the exact steps to trigger the bug
                2. **Isolate** - Narrow down to the specific component/function
                3. **Diagnose** - Identify the root cause (not just symptoms)
                4. **Fix** - Propose minimal change that fixes the issue
                5. **Verify** - Explain how to confirm the fix works

                ## Output Format
                - **Bug Summary**: One sentence description
                - **Root Cause**: Why this happens
                - **Fix**: Code changes needed
                - **Prevention**: How to avoid similar bugs

                Ask clarifying questions if the bug report is unclear.
                """
            ),
            DiscoverItem(
                id: "api-designer",
                title: "API Design Agent",
                description: "Designs RESTful APIs with best practices",
                category: .agent,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                # API Design Agent

                Design RESTful APIs following industry best practices.

                ## Principles
                - Use nouns for resources, verbs come from HTTP methods
                - Consistent naming (plural nouns, kebab-case)
                - Proper status codes (200, 201, 400, 401, 404, 500)
                - Version your API (/v1/, /v2/)
                - HATEOAS where appropriate

                ## For each endpoint, provide:
                - Method and path
                - Request body (with example)
                - Response body (with example)
                - Error responses
                - Authentication requirements

                ## Example
                ```
                POST /v1/users
                Request: { "email": "...", "name": "..." }
                Response: 201 { "id": "...", "email": "...", "name": "..." }
                Errors: 400 (validation), 409 (email exists)
                ```
                """
            ),
            DiscoverItem(
                id: "migration-agent",
                title: "Migration Agent",
                description: "Helps migrate code between frameworks or versions",
                category: .agent,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Community",
                content: """
                # Migration Agent

                Help migrate codebases between frameworks, libraries, or major versions.

                ## Process
                1. **Analyze** - Understand current implementation and dependencies
                2. **Plan** - Create step-by-step migration path
                3. **Transform** - Convert code patterns to new equivalents
                4. **Verify** - Identify what needs manual testing

                ## For each change:
                - Show before/after code
                - Explain breaking changes
                - Note behavioral differences
                - Flag deprecation warnings

                ## Common migrations:
                - React class → functional components
                - JavaScript → TypeScript
                - REST → GraphQL
                - Framework version upgrades

                Prioritize backwards compatibility when possible.
                """
            ),

            // SKILLS
            DiscoverItem(
                id: "doc-writer",
                title: "Documentation Writer",
                description: "Generates clear, comprehensive documentation from code",
                category: .skill,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                # Documentation Writer

                Generate documentation for the provided code. Include:

                ## Overview
                Brief description of what this code does and why it exists.

                ## Usage
                ```
                // Example code showing how to use this
                ```

                ## API Reference
                For each public function/method:
                - **Name**: function name
                - **Parameters**: list with types and descriptions
                - **Returns**: return type and description
                - **Throws**: possible exceptions
                - **Example**: usage example

                ## Notes
                Any important caveats, performance considerations, or gotchas.

                Write for developers who will use this code but haven't seen it before.
                """
            ),
            DiscoverItem(
                id: "commit-message",
                title: "Commit Message Writer",
                description: "Writes clear, conventional commit messages",
                category: .skill,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Community",
                content: """
                # Commit Message Writer

                Write commit messages following Conventional Commits format.

                ## Format
                ```
                <type>(<scope>): <description>

                [optional body]

                [optional footer]
                ```

                ## Types
                - feat: New feature
                - fix: Bug fix
                - docs: Documentation
                - style: Formatting (no code change)
                - refactor: Code restructuring
                - test: Adding tests
                - chore: Maintenance

                ## Rules
                - Subject line max 50 chars
                - Use imperative mood ("add" not "added")
                - Body explains what and why, not how
                - Reference issues: "Fixes #123"

                ## Example
                ```
                feat(auth): add OAuth2 login support

                - Add Google and GitHub providers
                - Store tokens securely in keychain
                - Add refresh token rotation

                Closes #456
                ```
                """
            ),
            DiscoverItem(
                id: "pr-reviewer",
                title: "PR Review Helper",
                description: "Helps write thorough pull request reviews",
                category: .skill,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                # PR Review Helper

                Review pull requests thoroughly and constructively.

                ## Review Checklist
                - [ ] Code correctness
                - [ ] Test coverage
                - [ ] Performance implications
                - [ ] Security considerations
                - [ ] Documentation updates
                - [ ] Breaking changes noted

                ## Comment Types
                - **must**: Blocking issue, must fix
                - **should**: Important suggestion
                - **nit**: Minor style/preference
                - **question**: Seeking clarification

                ## Format
                ```
                [must] This SQL query is vulnerable to injection
                → Use parameterized queries instead

                [nit] Consider renaming `x` to `userCount` for clarity
                ```

                Be constructive. Explain *why*, not just what.
                """
            ),
            DiscoverItem(
                id: "error-messages",
                title: "Error Message Writer",
                description: "Writes helpful, user-friendly error messages",
                category: .skill,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Community",
                content: """
                # Error Message Writer

                Write error messages that help users recover.

                ## Good error messages:
                1. **Say what happened** - Clear, specific description
                2. **Say why** - What caused this error
                3. **Say how to fix** - Actionable next steps

                ## Examples

                ❌ Bad: "Error: Invalid input"
                ✅ Good: "Email address is invalid. Please enter a valid email like name@example.com"

                ❌ Bad: "Error 500"
                ✅ Good: "We couldn't save your changes. Please try again, or contact support if this continues."

                ❌ Bad: "Permission denied"
                ✅ Good: "You don't have permission to delete this file. Ask the owner to grant you access."

                ## Tone
                - Don't blame the user
                - Be specific, not vague
                - Avoid technical jargon
                - Provide a clear path forward
                """
            ),

            // PROMPTS
            DiscoverItem(
                id: "test-gen",
                title: "Test Generator",
                description: "Creates comprehensive unit tests with edge cases",
                category: .prompt,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                # Test Generator

                Generate unit tests for the provided code. Follow these principles:

                1. **Happy path** - Test normal expected behavior
                2. **Edge cases** - Empty inputs, null values, boundaries
                3. **Error cases** - Invalid inputs, exceptions
                4. **Integration** - How components work together

                Use this format:
                ```
                describe('FunctionName', () => {
                  it('should handle normal input', () => {
                    // Arrange
                    // Act
                    // Assert
                  });

                  it('should handle edge case: empty input', () => {
                    // ...
                  });
                });
                ```

                Aim for 80%+ code coverage. Name tests descriptively.
                """
            ),
            DiscoverItem(
                id: "explain",
                title: "Code Explainer",
                description: "Explains complex code in simple terms",
                category: .prompt,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                # Code Explainer

                Explain this code clearly for someone learning to program.

                ## Structure your explanation:

                1. **One-sentence summary** - What does this code do overall?

                2. **Step by step** - Walk through the code line by line or block by block

                3. **Key concepts** - Explain any programming concepts used (loops, recursion, etc.)

                4. **Why it works** - The logic/algorithm behind it

                5. **Real-world analogy** - Compare to something familiar

                Use simple language. Avoid jargon or explain it when necessary.
                """
            ),
            DiscoverItem(
                id: "typescript-convert",
                title: "TypeScript Converter",
                description: "Converts JavaScript to TypeScript with proper types",
                category: .prompt,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Community",
                content: """
                # TypeScript Converter

                Convert JavaScript code to TypeScript with proper type annotations.

                ## Guidelines
                1. Infer types from usage when possible
                2. Use specific types over `any`
                3. Create interfaces for object shapes
                4. Add generics where appropriate
                5. Use union types for multiple possibilities

                ## Output format
                - Show the converted TypeScript code
                - List any new interfaces/types created
                - Note any places where types couldn't be inferred

                ## Example
                ```typescript
                // Before (JS)
                function greet(user) {
                  return `Hello, ${user.name}!`;
                }

                // After (TS)
                interface User {
                  name: string;
                }

                function greet(user: User): string {
                  return `Hello, ${user.name}!`;
                }
                ```
                """
            ),
            DiscoverItem(
                id: "regex-helper",
                title: "Regex Helper",
                description: "Creates and explains regular expressions",
                category: .prompt,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Community",
                content: """
                # Regex Helper

                Help create and understand regular expressions.

                ## When creating regex:
                1. Ask what strings should match/not match
                2. Build pattern step by step
                3. Explain each part
                4. Provide test cases

                ## Explanation format:
                ```
                /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$/

                ^                    - Start of string
                [a-zA-Z0-9._%+-]+    - One or more valid email chars
                @                    - Literal @ symbol
                [a-zA-Z0-9.-]+       - Domain name
                \\.                  - Literal dot
                [a-zA-Z]{2,}         - TLD (2+ letters)
                $                    - End of string
                ```

                ## Always include:
                - Regex pattern
                - Step-by-step explanation
                - Example matches and non-matches
                - Common edge cases to consider
                """
            ),
            DiscoverItem(
                id: "sql-optimizer",
                title: "SQL Query Optimizer",
                description: "Analyzes and optimizes SQL queries",
                category: .prompt,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Community",
                content: """
                # SQL Query Optimizer

                Analyze SQL queries and suggest optimizations.

                ## Check for:
                1. **Missing indexes** - Columns in WHERE, JOIN, ORDER BY
                2. **N+1 queries** - Loops that should be JOINs
                3. **SELECT *** - Only select needed columns
                4. **Subquery vs JOIN** - Often JOINs are faster
                5. **LIKE '%...'** - Leading wildcards prevent index use

                ## Output format:
                - Original query
                - Issues found
                - Optimized query
                - Suggested indexes

                ## Example optimization:
                ```sql
                -- Before
                SELECT * FROM orders WHERE customer_id = 5;

                -- After
                SELECT id, total, created_at
                FROM orders
                WHERE customer_id = 5;

                -- Add index
                CREATE INDEX idx_orders_customer ON orders(customer_id);
                ```
                """
            ),

            // TEMPLATES
            DiscoverItem(
                id: "readme-template",
                title: "README Template",
                description: "Standard README structure for projects",
                category: .template,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                # Project Name

                Brief description of what this project does.

                ## Features

                - Feature 1
                - Feature 2
                - Feature 3

                ## Installation

                ```bash
                npm install project-name
                ```

                ## Quick Start

                ```javascript
                import { thing } from 'project-name';

                const result = thing.doSomething();
                ```

                ## Configuration

                | Option | Type | Default | Description |
                |--------|------|---------|-------------|
                | `option1` | string | `"default"` | Description |

                ## API Reference

                ### `functionName(param)`

                Description of what it does.

                **Parameters:**
                - `param` (type): Description

                **Returns:** type - Description

                ## Contributing

                See [CONTRIBUTING.md](CONTRIBUTING.md)

                ## License

                MIT
                """
            ),
            DiscoverItem(
                id: "pr-template",
                title: "Pull Request Template",
                description: "Standard PR description template",
                category: .template,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Anthropic",
                content: """
                ## Summary

                Brief description of what this PR does.

                ## Changes

                - Change 1
                - Change 2
                - Change 3

                ## Type of Change

                - [ ] Bug fix (non-breaking change that fixes an issue)
                - [ ] New feature (non-breaking change that adds functionality)
                - [ ] Breaking change (fix or feature that breaks existing functionality)
                - [ ] Documentation update

                ## Testing

                - [ ] Unit tests added/updated
                - [ ] Integration tests added/updated
                - [ ] Manual testing done

                ## Screenshots (if applicable)

                ## Checklist

                - [ ] My code follows the project's style guidelines
                - [ ] I have performed a self-review
                - [ ] I have commented hard-to-understand areas
                - [ ] I have updated documentation
                - [ ] My changes generate no new warnings
                - [ ] New and existing tests pass

                ## Related Issues

                Closes #
                """
            ),
            DiscoverItem(
                id: "bug-template",
                title: "Bug Report Template",
                description: "Standard bug report structure",
                category: .template,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Community",
                content: """
                ## Bug Description

                A clear description of what the bug is.

                ## Steps to Reproduce

                1. Go to '...'
                2. Click on '...'
                3. Scroll down to '...'
                4. See error

                ## Expected Behavior

                What you expected to happen.

                ## Actual Behavior

                What actually happened.

                ## Screenshots

                If applicable, add screenshots.

                ## Environment

                - OS: [e.g., macOS 14.0]
                - Browser: [e.g., Chrome 120]
                - Version: [e.g., 1.2.3]

                ## Additional Context

                Any other context about the problem.

                ## Possible Solution

                If you have ideas on how to fix this.
                """
            ),
            DiscoverItem(
                id: "adr-template",
                title: "Architecture Decision Record",
                description: "Template for documenting technical decisions",
                category: .template,
                url: "https://github.com/anthropics/anthropic-cookbook",
                source: "Community",
                content: """
                # ADR-001: Title of Decision

                ## Status

                Proposed | Accepted | Deprecated | Superseded

                ## Context

                What is the issue that we're seeing that is motivating this decision?

                ## Decision

                What is the change that we're proposing and/or doing?

                ## Consequences

                ### Positive
                - Benefit 1
                - Benefit 2

                ### Negative
                - Tradeoff 1
                - Tradeoff 2

                ### Neutral
                - Note 1

                ## Alternatives Considered

                ### Alternative 1
                Description and why we didn't choose it.

                ### Alternative 2
                Description and why we didn't choose it.

                ## References

                - Link to relevant discussion
                - Link to related ADRs
                """
            ),

            // ANTHROPIC PROMPT LIBRARY
            DiscoverItem(
                id: "excel-formula",
                title: "Excel Formula Expert",
                description: "Creates complex Excel formulas from natural language",
                category: .skill,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Excel Formula Expert

                You are an Excel formula expert. Convert natural language descriptions into Excel formulas.

                ## Process
                1. Understand what the user wants to calculate
                2. Identify the appropriate Excel functions
                3. Build the formula step by step
                4. Explain how it works

                ## Output Format
                ```
                Formula: =FORMULA_HERE

                Explanation:
                - What each part does
                - Any assumptions made
                - Example with sample data
                ```

                ## Common Functions to Consider
                - VLOOKUP/XLOOKUP for lookups
                - SUMIFS/COUNTIFS for conditional aggregation
                - INDEX/MATCH for flexible lookups
                - IF/IFS for conditionals
                - TEXT for formatting
                - ARRAYFORMULA for array operations

                Always provide the simplest formula that solves the problem.
                """
            ),
            DiscoverItem(
                id: "python-bug-buster",
                title: "Python Bug Buster",
                description: "Identifies and fixes Python bugs with explanations",
                category: .agent,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Python Bug Buster

                You are an expert Python debugger. When given Python code with bugs:

                ## Analysis Steps
                1. Read the code carefully
                2. Identify syntax errors, logic errors, and runtime issues
                3. Check for common Python pitfalls:
                   - Mutable default arguments
                   - Variable scope issues
                   - Off-by-one errors
                   - Type mismatches
                   - Import issues

                ## Output Format
                ```
                🐛 Bug Found: [Description]
                📍 Location: Line X
                ❌ Problem: [What's wrong]
                ✅ Fix: [Corrected code]
                💡 Explanation: [Why this fixes it]
                ```

                ## Also Check
                - Is error handling appropriate?
                - Are there potential edge cases?
                - Could this cause issues at scale?

                Provide the complete fixed code at the end.
                """
            ),
            DiscoverItem(
                id: "sql-sorcerer",
                title: "SQL Sorcerer",
                description: "Translates natural language to SQL queries",
                category: .skill,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # SQL Sorcerer

                Transform natural language into SQL queries.

                ## Given a database schema and a question, generate SQL that:
                - Uses proper JOIN syntax
                - Handles NULL values correctly
                - Uses appropriate aggregations
                - Is optimized for performance

                ## Output Format
                ```sql
                -- Query description
                SELECT ...
                FROM ...
                WHERE ...
                ```

                ## Explanation
                - What each part of the query does
                - Why certain JOINs were chosen
                - Index recommendations if applicable

                ## Best Practices Applied
                - Use table aliases for readability
                - Avoid SELECT * in production
                - Use explicit column names
                - Consider query execution plan
                """
            ),
            DiscoverItem(
                id: "website-wizard",
                title: "Website Wizard",
                description: "Generates HTML/CSS/JS for web components",
                category: .skill,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Website Wizard

                Create beautiful, responsive web components.

                ## When given a component description, provide:

                ### HTML
                - Semantic, accessible markup
                - Proper ARIA attributes
                - Clean structure

                ### CSS
                - Modern CSS (flexbox, grid)
                - Responsive design (mobile-first)
                - CSS custom properties for theming
                - Smooth transitions

                ### JavaScript (if needed)
                - Vanilla JS or framework-specific
                - Event handling
                - State management

                ## Output Format
                ```html
                <!-- HTML -->
                ```

                ```css
                /* CSS */
                ```

                ```javascript
                // JavaScript
                ```

                ## Always Include
                - Dark mode support
                - Keyboard accessibility
                - Touch-friendly interactions
                - Loading states
                """
            ),
            DiscoverItem(
                id: "git-gud",
                title: "Git Gud",
                description: "Helps with complex Git operations and recovery",
                category: .skill,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Git Gud

                Expert help with Git operations, especially recovery scenarios.

                ## I can help with:

                ### Recovery
                - Undo commits (soft, mixed, hard reset)
                - Recover deleted branches
                - Fix merge conflicts
                - Rescue lost commits (reflog)

                ### Complex Operations
                - Interactive rebase
                - Cherry-picking
                - Bisect for finding bugs
                - Submodules and subtrees

                ### Best Practices
                - Branching strategies
                - Commit message conventions
                - .gitignore patterns

                ## When you describe your situation, I'll provide:
                1. **What happened** - Explanation of the state
                2. **Solution** - Step-by-step commands
                3. **Prevention** - How to avoid this next time

                ⚠️ Always recommend `git stash` or backup before destructive operations.
                """
            ),
            DiscoverItem(
                id: "mood-colorizer",
                title: "Mood Colorizer",
                description: "Generates color palettes based on moods or concepts",
                category: .skill,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Mood Colorizer

                Generate harmonious color palettes based on moods, concepts, or themes.

                ## Given a mood or concept, provide:

                ### Primary Palette (5 colors)
                ```
                Primary:    #HEXCODE - Role/Usage
                Secondary:  #HEXCODE - Role/Usage
                Accent:     #HEXCODE - Role/Usage
                Background: #HEXCODE - Role/Usage
                Text:       #HEXCODE - Role/Usage
                ```

                ### Extended Palette
                - Lighter/darker variants
                - Complementary accents
                - Semantic colors (success, warning, error)

                ### Usage Guidelines
                - Which colors for headers, body, CTAs
                - Accessibility notes (contrast ratios)
                - CSS custom properties ready to use

                ### Mood Explanation
                - Why these colors evoke the mood
                - Color psychology behind choices
                - Cultural considerations
                """
            ),

            // XML-STRUCTURED PROMPTS
            DiscoverItem(
                id: "xml-code-review",
                title: "Structured Code Review (XML)",
                description: "Code review using Anthropic's XML format for best results",
                category: .agent,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Structured Code Review

                Use XML tags for structured analysis:

                ```xml
                <task>Review this code and provide detailed feedback</task>

                <code>
                {{PASTE_YOUR_CODE_HERE}}
                </code>

                <review_criteria>
                  <security>Check for vulnerabilities, injection risks, unsafe patterns</security>
                  <performance>Identify bottlenecks, inefficient algorithms, memory issues</performance>
                  <maintainability>Assess readability, naming conventions, documentation</maintainability>
                  <best_practices>Verify adherence to language-specific conventions</best_practices>
                </review_criteria>

                <output_format>
                  For each issue found:
                  1. Location (file/line if applicable)
                  2. Severity (Critical/High/Medium/Low)
                  3. Description of the issue
                  4. Suggested fix with code example
                </output_format>
                ```

                This XML structure helps Claude provide more organized, thorough reviews.
                """
            ),
            DiscoverItem(
                id: "function-generator",
                title: "Function Generator with Thinking",
                description: "Uses Claude's thinking for complex function design",
                category: .prompt,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Function Generator with Thinking

                ```xml
                <task>Create a well-designed function</task>

                <requirements>
                  <function_name>{{FUNCTION_NAME}}</function_name>
                  <language>{{LANGUAGE: TypeScript, Python, etc.}}</language>
                  <purpose>{{DESCRIBE_WHAT_IT_SHOULD_DO}}</purpose>
                  <inputs>{{EXPECTED_INPUTS}}</inputs>
                  <outputs>{{EXPECTED_OUTPUTS}}</outputs>
                </requirements>

                <thinking>
                Before writing the code, think through:
                - Edge cases that need handling
                - Error conditions and how to handle them
                - Performance considerations
                - Type safety (if applicable)
                </thinking>

                <output>
                Provide:
                1. The complete function with type annotations
                2. JSDoc/docstring documentation
                3. Unit test examples
                4. Usage example
                </output>
                ```

                The <thinking> tag encourages step-by-step reasoning.
                """
            ),
            DiscoverItem(
                id: "research-analysis",
                title: "Research Analysis Framework",
                description: "Comprehensive research synthesis with structured output",
                category: .prompt,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Research Analysis Framework

                ```xml
                <task>Conduct comprehensive research analysis</task>

                <topic>{{YOUR_RESEARCH_TOPIC}}</topic>

                <research_parameters>
                  <scope>Broad overview / Deep dive / Comparative analysis</scope>
                  <perspective>Academic / Business / Technical / Consumer</perspective>
                  <time_frame>Last 6 months / Last year / All time</time_frame>
                </research_parameters>

                <analysis_framework>
                  <current_state>What is the current landscape?</current_state>
                  <key_players>Who are the major stakeholders?</key_players>
                  <trends>What patterns are emerging?</trends>
                  <challenges>What obstacles exist?</challenges>
                  <opportunities>What gaps can be exploited?</opportunities>
                  <predictions>Where is this heading?</predictions>
                </analysis_framework>

                <output_requirements>
                  <format>Structured report with sections</format>
                  <length>2000-3000 words</length>
                  <citations>Include sources where possible</citations>
                </output_requirements>
                ```
                """
            ),
            DiscoverItem(
                id: "document-summarizer",
                title: "Document Summarizer",
                description: "Extract key insights from long documents",
                category: .skill,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Document Summarizer

                ```xml
                <task>Summarize and extract key insights</task>

                <document>
                {{PASTE_DOCUMENT_CONTENT}}
                </document>

                <extraction_goals>
                  <main_thesis>What is the central argument or purpose?</main_thesis>
                  <key_points>List 5-7 most important points</key_points>
                  <evidence>What data or examples support the claims?</evidence>
                  <implications>What are the practical takeaways?</implications>
                  <questions>What questions remain unanswered?</questions>
                </extraction_goals>

                <output_format>
                  <executive_summary>2-3 sentences</executive_summary>
                  <detailed_breakdown>Bullet points by section</detailed_breakdown>
                  <action_items>Concrete next steps if applicable</action_items>
                </output_format>
                ```

                Works great with Claude's 200K token context for long documents.
                """
            ),
            DiscoverItem(
                id: "email-sequence",
                title: "Email Sequence Generator",
                description: "Creates multi-email nurture campaigns",
                category: .template,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Community",
                content: """
                # Email Sequence Generator

                ```xml
                <task>Create an email nurture sequence</task>

                <campaign_context>
                  <product>{{YOUR_PRODUCT_OR_SERVICE}}</product>
                  <goal>Lead nurturing / Onboarding / Re-engagement</goal>
                  <audience>{{Describe your audience}}</audience>
                  <sequence_length>{{NUMBER}} emails over {{TIMEFRAME}}</sequence_length>
                </campaign_context>

                <email_requirements>
                  For each email provide:
                  <subject_line>Compelling, under 50 chars</subject_line>
                  <preview_text>Supporting hook, under 90 chars</preview_text>
                  <body>
                    - Personal opening
                    - Value proposition
                    - Single clear CTA
                    - P.S. line if appropriate
                  </body>
                  <send_timing>Day and suggested time</send_timing>
                </email_requirements>

                <brand_voice>
                  <tone>Friendly / Professional / Urgent</tone>
                  <personality>{{Describe brand personality}}</personality>
                </brand_voice>
                ```
                """
            ),
            DiscoverItem(
                id: "api-documentation",
                title: "API Documentation Generator",
                description: "Generates OpenAPI/Swagger docs from code",
                category: .skill,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Community",
                content: """
                # API Documentation Generator

                Generate OpenAPI/Swagger documentation from API code.

                ## Given API endpoints, generate:

                ### OpenAPI 3.0 Spec
                ```yaml
                openapi: 3.0.0
                info:
                  title: API Name
                  version: 1.0.0
                paths:
                  /endpoint:
                    get:
                      summary: Description
                      parameters: [...]
                      responses:
                        200:
                          description: Success
                          content:
                            application/json:
                              schema: {...}
                ```

                ### For Each Endpoint Include
                - HTTP method and path
                - Summary and description
                - Request parameters (path, query, header)
                - Request body schema
                - Response schemas for all status codes
                - Example requests and responses
                - Authentication requirements

                ### Best Practices
                - Use consistent naming
                - Include error responses
                - Add examples for complex objects
                - Document rate limits
                """
            ),
            DiscoverItem(
                id: "data-analyst",
                title: "Data Analysis Assistant",
                description: "Analyzes data and suggests visualizations",
                category: .agent,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Data Analysis Assistant

                Help analyze datasets and derive insights.

                ## When given data, I will:

                ### 1. Understand the Data
                - Identify column types and meanings
                - Check for missing values
                - Detect outliers
                - Understand relationships

                ### 2. Provide Analysis
                - Summary statistics
                - Distribution analysis
                - Correlation findings
                - Trend identification

                ### 3. Suggest Visualizations
                - Bar charts for comparisons
                - Line charts for trends
                - Scatter plots for correlations
                - Histograms for distributions

                ### 4. Generate Code
                ```python
                import pandas as pd
                import matplotlib.pyplot as plt

                # Analysis code here
                ```

                ### 5. Actionable Insights
                - Key findings in plain language
                - Recommendations based on data
                - Questions for further investigation
                """
            ),
            DiscoverItem(
                id: "meeting-notes",
                title: "Meeting Notes Summarizer",
                description: "Converts meeting transcripts to structured notes",
                category: .skill,
                url: "https://docs.anthropic.com/en/prompt-library",
                source: "Anthropic",
                content: """
                # Meeting Notes Summarizer

                Transform meeting transcripts into actionable notes.

                ## Output Format

                ### Meeting Summary
                **Date:** [Date]
                **Attendees:** [List]
                **Duration:** [Time]

                ### Key Discussion Points
                1. [Topic 1]
                   - Main points discussed
                   - Decisions made

                2. [Topic 2]
                   - Main points discussed
                   - Decisions made

                ### Action Items
                | Task | Owner | Due Date |
                |------|-------|----------|
                | Task description | Name | Date |

                ### Decisions Made
                - [Decision 1]
                - [Decision 2]

                ### Open Questions
                - [Question needing follow-up]

                ### Next Steps
                - Next meeting date/time
                - Preparation needed
                """
            ),

            // MCP (Model Context Protocol)
            DiscoverItem(
                id: "figma-mcp",
                title: "Figma MCP Instructions",
                description: "Use Claude with Figma via browser MCP for design automation",
                category: .mcp,
                url: "https://cianfrani.dev/posts/a-better-figma-mcp/",
                source: "Community",
                content: """
                # Figma MCP Instructions

                Use browser access to interact with Figma's plugin API directly.

                ## Setup
                ```bash
                claude mcp add chrome-devtools npx chrome-devtools-mcp@latest
                ```

                ## Instructions for Claude

                1. **Navigate to Figma** - Open the Figma file in browser
                2. **Verify access** - Check for `figma` global object
                3. **Execute queries** - Use JavaScript with Figma's plugin API

                ## Operating Principles
                - Explain in plain English before executing code
                - Use API interaction, not UI automation
                - If permission issues, suggest creating file branches

                ## Example Commands
                ```javascript
                // Get current selection
                figma.currentPage.selection

                // Get all components
                figma.currentPage.findAll(n => n.type === "COMPONENT")

                // Get text nodes
                figma.currentPage.findAll(n => n.type === "TEXT")
                ```

                ## Use Cases
                - Component creation and modification
                - Design audits across files
                - Documentation organization
                - Code-to-design comparisons

                ⚠️ **Security**: Review tool calls before approval - browser access is powerful.
                """
            ),
            DiscoverItem(
                id: "filesystem-mcp",
                title: "Filesystem MCP Setup",
                description: "Give Claude access to read/write files on your system",
                category: .mcp,
                url: "https://github.com/anthropics/claude-code",
                source: "Anthropic",
                content: """
                # Filesystem MCP

                Allow Claude to read and write files on your local system.

                ## Installation
                ```bash
                claude mcp add filesystem npx @anthropic/mcp-server-filesystem /path/to/allowed/directory
                ```

                ## Configuration
                Specify which directories Claude can access:
                ```json
                {
                  "mcpServers": {
                    "filesystem": {
                      "command": "npx",
                      "args": [
                        "@anthropic/mcp-server-filesystem",
                        "/Users/you/projects",
                        "/Users/you/documents"
                      ]
                    }
                  }
                }
                ```

                ## Available Tools
                - `read_file` - Read file contents
                - `write_file` - Write/create files
                - `list_directory` - List directory contents
                - `create_directory` - Create new directories
                - `move_file` - Move/rename files
                - `search_files` - Search for files by pattern

                ## Security
                - Only specified directories are accessible
                - Claude cannot access parent directories
                - Review file operations before approving
                """
            ),
            DiscoverItem(
                id: "github-mcp",
                title: "GitHub MCP Setup",
                description: "Let Claude interact with GitHub repos, issues, and PRs",
                category: .mcp,
                url: "https://github.com/anthropics/claude-code",
                source: "Anthropic",
                content: """
                # GitHub MCP

                Enable Claude to interact with GitHub repositories.

                ## Installation
                ```bash
                claude mcp add github npx @anthropic/mcp-server-github
                ```

                ## Environment Setup
                ```bash
                export GITHUB_TOKEN=ghp_your_token_here
                ```

                ## Available Tools
                - `list_repos` - List your repositories
                - `get_repo` - Get repository details
                - `list_issues` - List issues in a repo
                - `create_issue` - Create new issues
                - `list_prs` - List pull requests
                - `get_pr` - Get PR details and diff
                - `create_pr` - Create pull requests
                - `search_code` - Search code across repos

                ## Example Usage
                "List open issues in my-org/my-repo"
                "Create a PR from feature-branch to main"
                "Search for usages of 'deprecated_function'"

                ## Permissions
                Token needs: `repo`, `read:org` scopes
                For private repos: `repo` (full control)
                """
            ),
            DiscoverItem(
                id: "postgres-mcp",
                title: "PostgreSQL MCP Setup",
                description: "Query and manage PostgreSQL databases with Claude",
                category: .mcp,
                url: "https://github.com/anthropics/claude-code",
                source: "Anthropic",
                content: """
                # PostgreSQL MCP

                Connect Claude to PostgreSQL databases.

                ## Installation
                ```bash
                claude mcp add postgres npx @anthropic/mcp-server-postgres "postgresql://user:pass@localhost/db"
                ```

                ## Configuration
                ```json
                {
                  "mcpServers": {
                    "postgres": {
                      "command": "npx",
                      "args": [
                        "@anthropic/mcp-server-postgres",
                        "postgresql://user:password@localhost:5432/mydb"
                      ]
                    }
                  }
                }
                ```

                ## Available Tools
                - `query` - Execute SELECT queries
                - `execute` - Execute INSERT/UPDATE/DELETE
                - `list_tables` - Show all tables
                - `describe_table` - Show table schema
                - `list_databases` - Show available databases

                ## Example Prompts
                "Show me all users created this week"
                "What's the average order value by month?"
                "Find duplicate email addresses"

                ## Security Best Practices
                - Use read-only credentials when possible
                - Limit to specific databases/schemas
                - Review queries before execution
                """
            ),
            DiscoverItem(
                id: "slack-mcp",
                title: "Slack MCP Setup",
                description: "Let Claude read and send Slack messages",
                category: .mcp,
                url: "https://github.com/anthropics/claude-code",
                source: "Community",
                content: """
                # Slack MCP

                Connect Claude to your Slack workspace.

                ## Installation
                ```bash
                claude mcp add slack npx @anthropic/mcp-server-slack
                ```

                ## Environment Setup
                ```bash
                export SLACK_BOT_TOKEN=xoxb-your-token
                export SLACK_USER_TOKEN=xoxp-your-token  # Optional
                ```

                ## Available Tools
                - `list_channels` - List accessible channels
                - `read_messages` - Read channel messages
                - `send_message` - Post to channels
                - `search_messages` - Search message history
                - `list_users` - List workspace members
                - `get_thread` - Get thread replies

                ## Example Usage
                "Summarize today's messages in #engineering"
                "Search for discussions about the API redesign"
                "Post a standup update to #team-updates"

                ## Required Scopes
                - channels:read, channels:history
                - chat:write
                - users:read
                - search:read (for search)
                """
            ),
            DiscoverItem(
                id: "browser-mcp",
                title: "Browser/Playwright MCP",
                description: "Automate browser actions and web scraping",
                category: .mcp,
                url: "https://github.com/anthropics/claude-code",
                source: "Anthropic",
                content: """
                # Browser MCP (Playwright)

                Give Claude browser automation capabilities.

                ## Installation
                ```bash
                claude mcp add playwright npx @anthropic/mcp-server-playwright
                ```

                ## Available Tools
                - `navigate` - Go to URL
                - `click` - Click elements
                - `type` - Type into inputs
                - `screenshot` - Capture page
                - `get_text` - Extract text content
                - `wait_for` - Wait for elements
                - `evaluate` - Run JavaScript

                ## Example Usage
                "Go to example.com and screenshot the homepage"
                "Fill out the login form with test credentials"
                "Extract all product prices from this page"

                ## Configuration Options
                ```json
                {
                  "mcpServers": {
                    "playwright": {
                      "command": "npx",
                      "args": ["@anthropic/mcp-server-playwright"],
                      "env": {
                        "HEADLESS": "true",
                        "BROWSER": "chromium"
                      }
                    }
                  }
                }
                ```

                ## Best Practices
                - Use headless mode for automation
                - Add delays between actions
                - Handle dynamic content with waits
                """
            ),
            DiscoverItem(
                id: "mcp-setup-guide",
                title: "MCP Setup Guide",
                description: "How to install and configure MCP servers for Claude",
                category: .mcp,
                url: "https://docs.anthropic.com/en/docs/claude-code/mcp",
                source: "Anthropic",
                content: """
                # MCP (Model Context Protocol) Setup Guide

                MCP lets you extend Claude's capabilities with external tools.

                ## Quick Start

                ### 1. Add an MCP Server
                ```bash
                claude mcp add <name> <command> [args...]
                ```

                ### 2. List Installed Servers
                ```bash
                claude mcp list
                ```

                ### 3. Remove a Server
                ```bash
                claude mcp remove <name>
                ```

                ## Configuration File
                Located at `~/.claude/mcp.json`:
                ```json
                {
                  "mcpServers": {
                    "filesystem": {
                      "command": "npx",
                      "args": ["@anthropic/mcp-server-filesystem", "/path"]
                    },
                    "github": {
                      "command": "npx",
                      "args": ["@anthropic/mcp-server-github"],
                      "env": {
                        "GITHUB_TOKEN": "your-token"
                      }
                    }
                  }
                }
                ```

                ## Popular MCP Servers
                - **filesystem** - File read/write access
                - **github** - GitHub API integration
                - **postgres** - Database queries
                - **slack** - Slack messaging
                - **playwright** - Browser automation
                - **chrome-devtools** - Chrome DevTools access

                ## Troubleshooting
                - Check server is installed: `npx <package> --help`
                - Verify environment variables are set
                - Check Claude Code logs for errors
                """
            ),

            // MORE POPULAR MCP SERVERS
            DiscoverItem(
                id: "notion-mcp",
                title: "Notion MCP",
                description: "Read and write Notion pages, databases, and blocks",
                category: .mcp,
                url: "https://github.com/modelcontextprotocol/servers",
                source: "Community",
                content: """
                # Notion MCP

                Connect Claude to your Notion workspace.

                ## Installation
                ```bash
                claude mcp add notion npx @anthropic/mcp-server-notion
                ```

                ## Environment
                ```bash
                export NOTION_API_KEY=secret_xxx
                ```

                ## Capabilities
                - Read pages and databases
                - Create new pages
                - Update existing content
                - Search across workspace
                - Query database entries

                ## Example Usage
                "Find all tasks due this week in my Projects database"
                "Create a meeting notes page for today"
                "Update the status of task X to Complete"
                """
            ),
            DiscoverItem(
                id: "linear-mcp",
                title: "Linear MCP",
                description: "Manage Linear issues, projects, and cycles",
                category: .mcp,
                url: "https://github.com/modelcontextprotocol/servers",
                source: "Community",
                content: """
                # Linear MCP

                Integrate Claude with Linear for issue tracking.

                ## Installation
                ```bash
                claude mcp add linear npx @anthropic/mcp-server-linear
                ```

                ## Environment
                ```bash
                export LINEAR_API_KEY=lin_api_xxx
                ```

                ## Capabilities
                - List and search issues
                - Create new issues
                - Update issue status/assignee
                - View project roadmaps
                - Access cycle information

                ## Example Usage
                "Show all my assigned bugs"
                "Create a feature request for dark mode"
                "Move issue LIN-123 to In Progress"
                """
            ),
            DiscoverItem(
                id: "mongodb-mcp",
                title: "MongoDB MCP",
                description: "Query and manage MongoDB databases",
                category: .mcp,
                url: "https://github.com/mongodb-js/mongodb-mcp-server",
                source: "MongoDB",
                content: """
                # MongoDB MCP

                Connect Claude to MongoDB and Atlas.

                ## Installation
                ```bash
                claude mcp add mongodb npx mongodb-mcp-server
                ```

                ## Environment
                ```bash
                export MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net
                ```

                ## Capabilities
                - Query collections
                - Insert/update documents
                - Aggregation pipelines
                - Index management
                - Atlas cluster info

                ## Example Usage
                "Find all users who signed up this month"
                "Show the aggregation for sales by region"
                "Create an index on the email field"
                """
            ),
            DiscoverItem(
                id: "sentry-mcp",
                title: "Sentry MCP",
                description: "Access error tracking and performance data",
                category: .mcp,
                url: "https://github.com/getsentry/sentry-mcp",
                source: "Sentry",
                content: """
                # Sentry MCP

                Connect Claude to Sentry error tracking.

                ## Installation
                ```bash
                claude mcp add sentry npx @sentry/mcp-server
                ```

                ## Environment
                ```bash
                export SENTRY_AUTH_TOKEN=sntrys_xxx
                export SENTRY_ORG=your-org
                ```

                ## Capabilities
                - View recent errors
                - Analyze error trends
                - Get stack traces
                - Check release health
                - Query performance metrics

                ## Example Usage
                "What are the top errors this week?"
                "Show me the stack trace for issue PROJ-123"
                "How is the latest release performing?"
                """
            ),
            DiscoverItem(
                id: "aws-mcp",
                title: "AWS MCP",
                description: "Access AWS docs, billing, and service info",
                category: .mcp,
                url: "https://github.com/awslabs/mcp",
                source: "AWS",
                content: """
                # AWS MCP

                Connect Claude to AWS resources and documentation.

                ## Installation
                ```bash
                claude mcp add aws npx @aws/mcp-server
                ```

                ## Environment
                ```bash
                export AWS_ACCESS_KEY_ID=xxx
                export AWS_SECRET_ACCESS_KEY=xxx
                export AWS_REGION=us-east-1
                ```

                ## Capabilities
                - Query AWS documentation
                - View billing information
                - List resources (EC2, S3, etc.)
                - Get service quotas
                - Check CloudWatch metrics

                ## Example Usage
                "What's my current AWS bill?"
                "List all S3 buckets"
                "How do I set up a VPC?"
                """
            ),
            DiscoverItem(
                id: "google-drive-mcp",
                title: "Google Drive MCP",
                description: "Read and search Google Drive files",
                category: .mcp,
                url: "https://github.com/modelcontextprotocol/servers",
                source: "Community",
                content: """
                # Google Drive MCP

                Connect Claude to Google Drive.

                ## Installation
                ```bash
                claude mcp add gdrive npx @anthropic/mcp-server-gdrive
                ```

                ## Setup
                1. Create OAuth credentials in Google Cloud Console
                2. Download credentials.json
                3. Run first auth flow

                ## Capabilities
                - Search files and folders
                - Read document contents
                - List recent files
                - Access shared drives
                - Read Google Docs/Sheets

                ## Example Usage
                "Find the Q4 budget spreadsheet"
                "What's in the project proposal doc?"
                "List files modified this week"
                """
            ),

            // CLAUDE CODE RESOURCES
            DiscoverItem(
                id: "claude-md-template",
                title: "CLAUDE.md Template",
                description: "Project instructions template for Claude Code",
                category: .instruction,
                url: "https://docs.anthropic.com/en/docs/claude-code",
                source: "Anthropic",
                content: """
                # Project Name

                Brief description of what this project does.

                ## Architecture

                Describe the codebase structure:
                - `src/` - Main source code
                - `tests/` - Test files
                - `docs/` - Documentation

                ## Development

                ### Setup
                ```bash
                npm install
                npm run dev
                ```

                ### Testing
                ```bash
                npm test
                ```

                ## Code Style

                - Use TypeScript strict mode
                - Follow ESLint configuration
                - Write tests for new features

                ## Important Files

                - `src/index.ts` - Entry point
                - `src/config.ts` - Configuration
                - `.env.example` - Environment template

                ## Common Tasks

                ### Adding a new feature
                1. Create feature branch
                2. Implement in `src/features/`
                3. Add tests
                4. Update documentation

                ### Debugging
                - Check logs in `./logs/`
                - Use `DEBUG=* npm run dev` for verbose output
                """
            ),
            DiscoverItem(
                id: "claude-hooks",
                title: "Claude Code Hooks Examples",
                description: "Pre/post command hooks for Claude Code automation",
                category: .instruction,
                url: "https://docs.anthropic.com/en/docs/claude-code",
                source: "Anthropic",
                content: """
                # Claude Code Hooks

                Automate actions before/after Claude commands.

                ## Configuration
                Add to `~/.claude/settings.json`:
                ```json
                {
                  "hooks": {
                    "preCommand": ["echo 'Starting...'"],
                    "postCommand": ["notify-send 'Done'"],
                    "onError": ["say 'Error occurred'"]
                  }
                }
                ```

                ## Common Hooks

                ### Auto-format on save
                ```json
                {
                  "hooks": {
                    "postWrite": ["prettier --write $FILE"]
                  }
                }
                ```

                ### Run tests after changes
                ```json
                {
                  "hooks": {
                    "postEdit": ["npm test -- --findRelatedTests $FILE"]
                  }
                }
                ```

                ### Git auto-stage
                ```json
                {
                  "hooks": {
                    "postWrite": ["git add $FILE"]
                  }
                }
                ```

                ### Notify on completion
                ```json
                {
                  "hooks": {
                    "postCommand": [
                      "osascript -e 'display notification \\\"Task complete\\\" with title \\\"Claude\\\"'"
                    ]
                  }
                }
                ```

                ## Variables
                - `$FILE` - Current file path
                - `$DIR` - Current directory
                - `$PROJECT` - Project root
                """
            ),
            DiscoverItem(
                id: "system-prompt-tips",
                title: "System Prompt Best Practices",
                description: "Tips for writing effective Claude system prompts",
                category: .instruction,
                url: "https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering",
                source: "Anthropic",
                content: """
                # System Prompt Best Practices

                ## Structure

                ### 1. Role Definition
                Start with who Claude should be:
                ```
                You are an expert Python developer specializing in data pipelines.
                ```

                ### 2. Context
                Provide relevant background:
                ```
                You're working on a fintech application that processes transactions.
                The codebase uses FastAPI, PostgreSQL, and Redis.
                ```

                ### 3. Instructions
                Be specific about behavior:
                ```
                - Always use type hints
                - Prefer async/await patterns
                - Include error handling
                - Write docstrings for public functions
                ```

                ### 4. Constraints
                Set boundaries:
                ```
                - Never use `eval()` or `exec()`
                - Don't store secrets in code
                - Keep functions under 50 lines
                ```

                ### 5. Output Format
                Specify how to respond:
                ```
                Format code responses as:
                1. Brief explanation
                2. Code block
                3. Usage example
                ```

                ## Tips

                - Use XML tags for structure: `<rules>`, `<context>`, `<examples>`
                - Give examples of good/bad outputs
                - Be explicit about edge cases
                - Update prompts based on failures
                """
            ),
            DiscoverItem(
                id: "awesome-mcp-list",
                title: "Awesome MCP Servers Directory",
                description: "Curated list of 1000+ MCP servers by category",
                category: .mcp,
                url: "https://github.com/punkpeye/awesome-mcp-servers",
                source: "Community",
                content: """
                # Awesome MCP Servers

                A curated directory of MCP servers. Browse the full list at:
                https://github.com/punkpeye/awesome-mcp-servers

                ## Popular Categories

                ### Databases
                - PostgreSQL, MySQL, MongoDB
                - Redis, ClickHouse, Chroma
                - Supabase, PlanetScale

                ### Development
                - GitHub, GitLab, Bitbucket
                - Jira, Linear, Asana
                - Sentry, Datadog

                ### Cloud
                - AWS, GCP, Azure
                - Cloudflare, Vercel
                - Terraform, Pulumi

                ### Productivity
                - Slack, Discord, Teams
                - Notion, Obsidian
                - Google Drive, Dropbox

                ### AI/ML
                - Hugging Face, Replicate
                - Qdrant, Pinecone (vector DBs)
                - LangChain tools

                ### Browsers
                - Playwright, Puppeteer
                - Chrome DevTools
                - Web scraping tools

                ## Finding Servers
                - GitHub: search "mcp-server"
                - npm: search "@mcp/"
                - mcpservers.org - Web directory
                - mcp-awesome.com - 1200+ servers
                """
            ),

            // HOOKS
            DiscoverItem(
                id: "hook-session-start-dates",
                title: "Session Start: Date Context",
                description: "Inject current date/week info when starting a session",
                category: .hook,
                url: "https://code.claude.com/docs/en/hooks",
                source: "Claude Code",
                content: """
                # SessionStart Hook: Date Context

                Automatically provides date context when you start a Claude session.

                ## Setup

                Run `/hooks` in Claude Code, select "SessionStart", then add:

                ```bash
                #!/bin/bash
                # Save as: ~/.claude/hooks/date-context.sh
                # Make executable: chmod +x ~/.claude/hooks/date-context.sh

                TODAY=$(date +"%Y-%m-%d")
                TOMORROW=$(date -v+1d +"%Y-%m-%d")
                WEEK_START=$(date -v-$(date +%u)d +"%Y-%m-%d")
                WEEK_END=$(date -v-$(date +%u)d -v+6d +"%Y-%m-%d")

                echo "📅 Date Context"
                echo "Today: $TODAY"
                echo "Tomorrow: $TOMORROW"
                echo "This week: $WEEK_START to $WEEK_END"
                ```

                ## Hook Types
                - **SessionStart** - Runs when entering a project
                - **SessionEnd** - Runs when leaving
                - **PreToolUse** - Before any tool call
                - **PostToolUse** - After any tool call
                - **UserPromptSubmit** - When you submit a prompt
                """
            ),
            DiscoverItem(
                id: "hook-git-context",
                title: "Session Start: Git Context",
                description: "Show branch, recent commits, and status on session start",
                category: .hook,
                url: "https://code.claude.com/docs/en/hooks",
                source: "Claude Code",
                content: """
                # SessionStart Hook: Git Context

                Automatically shows git status when starting a session.

                ## Setup

                ```bash
                #!/bin/bash
                # Save as: ~/.claude/hooks/git-context.sh

                if git rev-parse --git-dir > /dev/null 2>&1; then
                    echo "🔀 Git Context"
                    echo "Branch: $(git branch --show-current)"
                    echo ""
                    echo "Recent commits:"
                    git log --oneline -5
                    echo ""
                    echo "Changed files:"
                    git status --short
                fi
                ```

                ## Configure in Claude Code

                1. Run `/hooks`
                2. Select "SessionStart"
                3. Add the script path
                """
            ),
            DiscoverItem(
                id: "hook-post-tool-format",
                title: "PostToolUse: Auto-Format",
                description: "Run prettier/linting after file edits",
                category: .hook,
                url: "https://code.claude.com/docs/en/hooks",
                source: "Community",
                content: """
                # PostToolUse Hook: Auto-Format

                Automatically format files after Claude edits them.

                ## Setup

                ```bash
                #!/bin/bash
                # Save as: ~/.claude/hooks/auto-format.sh

                # Only run after Write or Edit tools
                if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
                    FILE="$TOOL_INPUT_FILE_PATH"

                    case "$FILE" in
                        *.js|*.ts|*.jsx|*.tsx|*.json)
                            npx prettier --write "$FILE" 2>/dev/null
                            ;;
                        *.py)
                            black "$FILE" 2>/dev/null
                            ;;
                        *.go)
                            gofmt -w "$FILE" 2>/dev/null
                            ;;
                        *.swift)
                            swift-format -i "$FILE" 2>/dev/null
                            ;;
                    esac
                fi
                ```

                ## Environment Variables Available
                - `TOOL_NAME` - Name of the tool that ran
                - `TOOL_INPUT_*` - Input parameters
                - `TOOL_OUTPUT` - Tool output
                """
            ),
            DiscoverItem(
                id: "hook-notify-complete",
                title: "Stop Hook: Notification",
                description: "macOS notification when Claude finishes a task",
                category: .hook,
                url: "https://code.claude.com/docs/en/hooks",
                source: "Community",
                content: """
                # Stop Hook: macOS Notification

                Get notified when Claude completes a task.

                ## Setup

                ```bash
                #!/bin/bash
                # Save as: ~/.claude/hooks/notify-complete.sh

                osascript -e 'display notification "Task completed" with title "Claude Code" sound name "Glass"'
                ```

                ## Configure
                1. Run `/hooks` in Claude Code
                2. Select "Stop"
                3. Add the script path

                ## Variations

                ### With task summary
                ```bash
                osascript -e "display notification \\"$CLAUDE_LAST_MESSAGE\\" with title \\"Claude Done\\""
                ```

                ### Slack notification
                ```bash
                curl -X POST -H 'Content-type: application/json' \\
                    --data '{"text":"Claude task completed"}' \\
                    YOUR_SLACK_WEBHOOK_URL
                ```
                """
            ),

            // WORKFLOWS
            DiscoverItem(
                id: "workflow-chrome-testing",
                title: "Chrome Browser Testing",
                description: "Test web apps with Claude + Chrome integration",
                category: .workflow,
                url: "https://code.claude.com/docs/en/chrome",
                source: "Claude Code",
                content: """
                # Chrome Browser Testing Workflow

                Use Claude Code with Chrome to test web applications.

                ## Prerequisites
                - Claude Code v2.0.73+
                - Claude in Chrome extension v1.0.36+
                - Paid Claude plan

                ## Setup
                ```bash
                # Update Claude Code
                claude update

                # Start with Chrome enabled
                claude --chrome

                # Or enable permanently
                /chrome
                # Select "Enabled by default"
                ```

                ## Step 1: Test Local App
                ```
                Open localhost:3000, try submitting the login form with
                invalid data, and check if error messages appear correctly.
                ```

                ## Step 2: Debug Console Errors
                ```
                Open the dashboard page and check the console for any
                errors when the page loads. Fix any issues you find.
                ```

                ## Step 3: Record Demo
                ```
                Record a GIF showing the checkout flow from adding
                an item to the cart through confirmation.
                ```

                ## Tips
                - Claude opens new tabs (won't take over existing ones)
                - Dismiss modal dialogs manually
                - Works with logged-in sites (Gmail, Notion, etc.)
                """
            ),
            DiscoverItem(
                id: "workflow-figma-implementation",
                title: "Figma Design Implementation",
                description: "Build UI from Figma designs with browser automation",
                category: .workflow,
                url: "https://cianfrani.dev/posts/a-better-figma-mcp/",
                source: "Community",
                content: """
                # Figma Design Implementation Workflow

                Implement UI from Figma designs using Chrome DevTools MCP.

                ## Setup

                ```bash
                # Add Chrome DevTools MCP
                claude mcp add chrome-devtools npx chrome-devtools-mcp@latest

                # Or use the Figma plugin
                /plugin marketplace add markacianfrani/claude-code-figma
                /plugin install figma-friend
                ```

                ## Step 1: Open Figma File
                ```
                Navigate to my Figma file at [URL] and open the
                "Dashboard" frame.
                ```

                ## Step 2: Extract Design Tokens
                ```
                Use evaluate_script to access the figma object and
                extract colors, typography, and spacing from this design.
                ```

                ## Step 3: Implement Component
                ```
                Based on the Figma design, create a React component
                that matches the layout, colors, and spacing exactly.
                ```

                ## Step 4: Visual Comparison
                ```
                Open my local implementation at localhost:3000/dashboard
                and compare it to the Figma design. List any differences.
                ```

                ## Tips
                - Figma object available via browser console
                - May need to open a plugin first to initialize
                - Works best with edit access to the file
                """
            ),
            DiscoverItem(
                id: "workflow-git-commit",
                title: "Git Commit Workflow",
                description: "Stage, commit, and push with Claude assistance",
                category: .workflow,
                url: "https://code.claude.com/docs",
                source: "Claude Code",
                content: """
                # Git Commit Workflow

                Let Claude help with your git workflow.

                ## Quick Commit
                ```
                Review my changes, write a commit message, and commit them.
                ```

                ## Detailed Workflow

                ### Step 1: Review Changes
                ```
                Show me what files changed and summarize the modifications.
                ```

                ### Step 2: Stage Selectively
                ```
                Stage only the files related to the auth feature,
                not the config changes.
                ```

                ### Step 3: Write Commit Message
                ```
                Write a conventional commit message for these changes.
                Follow the pattern: type(scope): description
                ```

                ### Step 4: Create PR
                ```
                Push this branch and create a PR with a summary of changes.
                ```

                ## Useful Commands
                - `/commit` - Quick commit with Claude
                - `git status` - See changes
                - `git diff --staged` - Review staged changes

                ## Tips
                - Claude won't push without asking
                - Commit messages follow conventional commits
                - PR descriptions auto-generated from commits
                """
            ),
            DiscoverItem(
                id: "workflow-feature-development",
                title: "Full Feature Development",
                description: "Plan, implement, test, and deploy a feature",
                category: .workflow,
                url: "https://code.claude.com/docs",
                source: "Claude Code",
                content: """
                # Full Feature Development Workflow

                End-to-end workflow for building a new feature.

                ## Step 1: Plan
                ```
                I want to add user authentication. Help me plan:
                - What files need to change
                - Database schema updates
                - API endpoints needed
                - Frontend components
                ```

                ## Step 2: Database
                ```
                Create the migration for the users table with email,
                password hash, and timestamps.
                ```

                ## Step 3: Backend
                ```
                Implement the auth endpoints:
                - POST /auth/register
                - POST /auth/login
                - POST /auth/logout
                - GET /auth/me
                ```

                ## Step 4: Frontend
                ```
                Create login and register forms that call these
                endpoints and store the session.
                ```

                ## Step 5: Test
                ```
                Write tests for the auth flow covering:
                - Successful registration
                - Duplicate email handling
                - Login with wrong password
                - Protected route access
                ```

                ## Step 6: Review & Deploy
                ```
                Review all changes, run tests, and create a PR
                with a summary of the auth implementation.
                ```
                """
            ),
            DiscoverItem(
                id: "workflow-agent-subagent",
                title: "Multi-Agent Workflow",
                description: "Use subagents for parallel tasks",
                category: .workflow,
                url: "https://code.claude.com/docs",
                source: "Claude Code",
                content: """
                # Multi-Agent Workflow

                Run parallel tasks using Claude's subagent system.

                ## When to Use Subagents
                - Independent tasks that can run in parallel
                - Research while implementing
                - Testing while developing

                ## Example: Parallel Research
                ```
                I need to choose between Redis and Memcached for caching.

                In parallel:
                1. Research Redis pros/cons for our use case
                2. Research Memcached pros/cons
                3. Check our current infrastructure compatibility

                Then summarize recommendations.
                ```

                ## Example: Build + Test
                ```
                While I implement the new API endpoint, run the
                existing test suite in the background and alert me
                if anything fails.
                ```

                ## Example: Multi-File Refactor
                ```
                Refactor these 5 service files to use the new
                error handling pattern. Work on them in parallel
                since they're independent.
                ```

                ## Tips
                - Claude automatically uses subagents when beneficial
                - Background tasks report completion
                - Use for truly independent work
                """
            ),
            DiscoverItem(
                id: "workflow-mcp-setup",
                title: "MCP Server Setup Workflow",
                description: "Configure and test MCP servers step by step",
                category: .workflow,
                url: "https://code.claude.com/docs",
                source: "Claude Code",
                content: """
                # MCP Server Setup Workflow

                Step-by-step guide to add and configure MCP servers.

                ## Step 1: Choose Server
                ```
                I want to connect Claude to my PostgreSQL database.
                What MCP server should I use?
                ```

                ## Step 2: Install
                ```bash
                # Most MCP servers install via npm
                claude mcp add postgres npx @mcp/postgres

                # Or with specific config
                claude mcp add postgres npx @mcp/postgres --connection-string "..."
                ```

                ## Step 3: Configure
                Edit `~/.claude/mcp.json`:
                ```json
                {
                  "mcpServers": {
                    "postgres": {
                      "command": "npx",
                      "args": ["@mcp/postgres"],
                      "env": {
                        "DATABASE_URL": "postgresql://..."
                      }
                    }
                  }
                }
                ```

                ## Step 4: Test
                ```
                List the tables in my database and show the schema
                for the users table.
                ```

                ## Step 5: Use
                ```
                Query the database for all users created in the
                last 7 days and show their activity.
                ```

                ## Popular MCP Servers
                - `@mcp/postgres` - PostgreSQL
                - `@anthropic/mcp-github` - GitHub
                - `@mcp/slack` - Slack
                - `@mcp/filesystem` - Local files
                """
            ),
        ]

        isLoading = false
    }

    private func search() {
        guard !searchText.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        // GitHub search - search for the term in repos related to prompts/agents/AI
        let query = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.github.com/search/repositories?q=\(query)+in:name,description+topic:prompt+OR+topic:chatgpt+OR+topic:llm+OR+topic:ai-prompts&sort=stars&per_page=15"

        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = json["items"] as? [[String: Any]] else {
                    errorMessage = "No results found"
                    return
                }

                results = items.compactMap { item -> DiscoverItem? in
                    guard let name = item["name"] as? String,
                          let htmlUrl = item["html_url"] as? String,
                          let owner = item["owner"] as? [String: Any],
                          let ownerName = owner["login"] as? String else {
                        return nil
                    }

                    let description = item["description"] as? String ?? "No description"

                    return DiscoverItem(
                        id: htmlUrl,
                        title: name.replacingOccurrences(of: "-", with: " ").capitalized,
                        description: description,
                        category: inferCategory(name + description),
                        url: htmlUrl,
                        source: ownerName,
                        content: nil // Will load on tap
                    )
                }

                if results.isEmpty {
                    errorMessage = "No results for '\(searchText)'"
                }
            }
        }.resume()
    }

    private func loadPreview(_ item: DiscoverItem) {
        // If we have cached content, use it
        if let content = item.content {
            previewContent = content
            return
        }

        // Try to fetch README from GitHub
        previewContent = nil

        let readmeUrl = item.url
            .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
            .appending("/main/README.md")

        guard let url = URL(string: readmeUrl) else {
            previewContent = "# \(item.title)\n\n\(item.description)\n\nSource: \(item.url)"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data, let content = String(data: data, encoding: .utf8) {
                    previewContent = content
                } else {
                    previewContent = "# \(item.title)\n\n\(item.description)\n\nVisit \(item.url) for full content."
                }
            }
        }.resume()
    }

    private func inferCategory(_ text: String) -> SnippetCategory {
        let lower = text.lowercased()
        if lower.contains("mcp") || lower.contains("model context protocol") || lower.contains("server") { return .mcp }
        if lower.contains("agent") { return .agent }
        if lower.contains("skill") { return .skill }
        if lower.contains("template") { return .template }
        return .prompt
    }

    private func saveItem(_ item: DiscoverItem) {
        let content = previewContent ?? item.content ?? "# \(item.title)\n\n\(item.description)"

        let snippet = Snippet(
            title: item.title,
            content: content,
            category: item.category,
            tags: ["imported", item.source.lowercased()],
            project: nil
        )
        snippetManager.addSnippet(snippet)
        savedIds.insert(item.id)
    }

    private func openInBrowser(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Models

struct DiscoverItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let category: SnippetCategory
    let url: String
    let source: String
    var content: String?
}

// MARK: - Row Component

struct DiscoverRow: View {
    let item: DiscoverItem
    let isSaved: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Category
                Text(item.category.displayName.prefix(1).uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.cmTertiary)
                    .frame(width: 24, height: 24)
                    .background(Color.cmBorder.opacity(0.3))
                    .cornerRadius(4)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.cmText)

                        if isSaved {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                    }

                    Text(item.description)
                        .font(.system(size: 11))
                        .foregroundColor(.cmTertiary)
                        .lineLimit(1)

                    Text(item.source)
                        .font(.system(size: 10))
                        .foregroundColor(.cmTertiary.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.cmTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isHovering ? Color.cmBorder.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
