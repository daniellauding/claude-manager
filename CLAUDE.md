# Claude Manager - Development Notes

## What We Built

A macOS menu bar app to manage multiple Claude CLI instances and a snippets library for agent prompts. When you have many Claude sessions running in different terminals, this helps you:

1. **See all instances at a glance** - PID, runtime, CPU/memory usage
2. **Identify which session is which** - Shows working directory, first prompt, session title
3. **Focus on a specific terminal** - Click to bring that terminal window to front
4. **Stop instances** - Graceful (SIGTERM) or force (SIGKILL)
5. **Manage snippets** - Store agent prompts, skills, and templates with tags and favorites
6. **Sync with folders** - Watch directories to auto-import markdown files as snippets

## Architecture

### macOS App (SwiftUI)

Located in `/Users/daniellauding/Work/instinctly/internal/claude-manager/`

**Source Files:**
- `Sources/ClaudeManagerApp.swift` - Menu bar app entry point with NSStatusItem
- `Sources/ClaudeInstance.swift` - Instance model + ClaudeProcessManager
- `Sources/ContentView.swift` - Main UI with tab bar (Instances/Snippets)
- `Sources/Snippet.swift` - Snippet data model and categories
- `Sources/SnippetManager.swift` - Snippet CRUD, persistence, folder watching
- `Sources/SnippetView.swift` - Snippets list UI with filtering
- `Sources/SnippetEditor.swift` - Add/Edit snippet sheet

**How Instance Detection Works:**
1. `ClaudeProcessManager.fetchInstances()` runs shell commands to get process list
2. For each PID, extracts: start time, CPU%, memory, TTY, parent chain
3. `findSessionInfo()` uses `lsof -p <pid>` to directly find open session files (more accurate)
4. Falls back to time-proximity matching if lsof doesn't find files
5. `extractSessionDetails()` parses JSONL for: cwd, gitBranch, first prompt, session title

**How Snippets Work:**
1. Snippets stored in `~/.claude/snippets.json`
2. Can manually add snippets via the editor
3. Can watch folders - markdown files auto-imported as snippets
4. Uses `DispatchSource.makeFileSystemObjectSource` for efficient file watching
5. Categories inferred from content (agent, skill, prompt, template, instruction)

## Features

### Instance Management
- Tab bar to switch between Instances and Snippets views
- Menu bar badge shows instance count
- Auto-refresh every 5 seconds when PIDs change
- Expandable rows with full session details
- Copy launch command, focus terminal, stop/force kill

### Snippets Library
- Add/edit/delete snippets
- Organize with categories, tags, projects
- Mark favorites for quick access
- Track recently used and use count
- Filter by category, tag, project, favorites, recent
- Search across title and content
- Watch folders to auto-import markdown files
- Double-click to copy snippet content

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+1 | Switch to Instances tab |
| Cmd+2 | Switch to Snippets tab |
| Cmd+N | New Claude session (instances) |
| Cmd+Shift+N | New snippet (snippets) |
| Cmd+R | Refresh |

## Instance Types

| Type | Detection | Description |
|------|-----------|-------------|
| **Happy** | `happy-coder` in parent chain | Spawned by Happy app (Warp terminal) |
| **Terminal** | Parent is `zsh`/`bash` | Started from Terminal.app |
| **Node.js** | Parent is `node` | Spawned by MCP server |

## Session File Format

JSONL files in `~/.claude/projects/-<path-with-dashes>/`

```json
{"type":"user","cwd":"/path","gitBranch":"main","message":{"content":"prompt text"}}
{"type":"assistant","message":{"content":[...]}}
```

## Build & Install

```bash
cd ~/Work/instinctly/internal/claude-manager
swift build -c release
rm -f /Applications/ClaudeManager && cp .build/release/ClaudeManager /Applications/
open /Applications/ClaudeManager
```

## Release

```bash
./scripts/release.sh 1.2.0
# Creates ClaudeManager.app bundle and zip
# Outputs SHA256 for Homebrew formula
```

## Distribution

### Homebrew
```bash
brew tap daniellauding/tap
brew install --cask claude-manager
```

### GitHub
- Releases: https://github.com/daniellauding/claude-manager/releases
- Landing page: https://daniellauding.github.io/claude-manager

## Data Storage

- Instance data: In-memory, refreshed from system processes
- Snippets: `~/.claude/snippets.json`
- Watched folders: Stored in snippets.json

## Shell Aliases (Optional)

Add to `~/.zshrc` for terminal access:

```bash
alias cls='ps -xc -o pid,command | grep -E "^\s*[0-9]+\s+claude$" | while read pid cmd; do echo "$pid"; done'
alias ck='kill'  # claude-kill
alias cn='claude'  # claude-new
```

## GitHub

https://github.com/daniellauding/claude-manager
