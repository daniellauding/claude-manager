# Claude Manager

A macOS menu bar app to monitor Claude CLI instances and manage your prompts library.

## Features

### Instance Management
- **View all running Claude instances** - PID, runtime, CPU%, memory usage
- **Session context** - Working folder, git branch, first prompt
- **Quick actions** - Focus window, stop, force kill
- **Auto-refresh** - Updates every 30 seconds

### Snippets Library
- **Organize prompts** - Agents, Skills, Prompts, Templates, MCPs
- **Tags & Projects** - Categorize and filter your collection
- **Favorites & Recent** - Quick access to frequently used items
- **Folder Sync** - Auto-import markdown files from watched folders

### Discover
- **50+ Curated Prompts** - Code review, testing, documentation, and more
- **15+ MCP Configs** - GitHub, Slack, PostgreSQL, Figma, etc.
- **GitHub Search** - Find community prompts and MCP servers
- **One-click Save** - Add to your library instantly

## Installation

### Option 1: Homebrew (Recommended)

```bash
# Add the tap
brew tap daniellauding/tap

# Install
brew install --cask claude-manager
```

### Option 2: Direct Download

1. Go to [Releases](https://github.com/daniellauding/claude-manager/releases/latest)
2. Download `ClaudeManager-vX.X.X.zip`
3. Unzip and drag `ClaudeManager.app` to `/Applications`
4. Open from Applications (right-click → Open on first launch)

### Option 3: Build from Source

```bash
git clone https://github.com/daniellauding/claude-manager.git
cd claude-manager
swift build -c release
./scripts/release.sh 1.2.0
open ClaudeManager.app
```

## Quick Start

1. **Launch** - Click the menu bar icon (appears top-right)
2. **Instances** - See all running Claude sessions
3. **Snippets** - Switch to the Snippets tab (Cmd+2)
4. **Discover** - Click "Discover" to browse curated prompts
5. **Save** - Click any prompt → "Save to Library"

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+1` | Switch to Instances |
| `Cmd+2` | Switch to Snippets |
| `Cmd+N` | Create new snippet |
| `Cmd+R` | Refresh instances |

## Categories

| Category | Icon | Description |
|----------|------|-------------|
| Agent | 👤 | Autonomous task executors |
| Skill | ⭐ | Specific capabilities |
| Prompt | 💬 | Reusable prompts |
| Template | 📄 | Document templates |
| MCP | 🔌 | Model Context Protocol servers |
| Instruction | 📋 | Project instructions (CLAUDE.md) |

## Featured MCP Servers

The Discover section includes setup guides for popular MCPs:

- **GitHub** - Issues, PRs, code search
- **PostgreSQL** - Database queries
- **Slack** - Read and send messages
- **Notion** - Pages and databases
- **Figma** - Design automation
- **Playwright** - Browser automation
- **AWS** - Docs and billing
- **Sentry** - Error tracking

## Folder Sync

Auto-import markdown files as snippets:

1. Go to Snippets → Click folder icon
2. Add a folder path (e.g., `~/prompts/`)
3. All `.md` files become snippets
4. Changes sync automatically

## Requirements

- macOS 13.0 (Ventura) or later
- Claude CLI installed (optional, for instance management)

## Creating a Release

```bash
# Build and package
./scripts/release.sh 1.2.0

# Output:
# - ClaudeManager.app (the app bundle)
# - ClaudeManager-v1.2.0.zip (for distribution)
# - SHA256 hash (for Homebrew formula)
```

## Setting Up Homebrew Tap

1. Create repo: `github.com/YOUR_USERNAME/homebrew-tap`
2. Copy `homebrew/claude-manager.rb` to `Casks/claude-manager.rb`
3. Update version and SHA256 from release script output
4. Users install with:
   ```bash
   brew tap YOUR_USERNAME/tap
   brew install --cask claude-manager
   ```

## Development

```bash
# Build
swift build

# Run
swift run

# Release build
swift build -c release

# Test (build + install + run)
swift build -c release && pkill -f ClaudeManager; cp .build/release/ClaudeManager /Applications/ && open /Applications/ClaudeManager
```

## Author

**Daniel Lauding** - [@daniellauding](https://github.com/daniellauding)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Links

- [GitHub](https://github.com/daniellauding/claude-manager)
- [Issues](https://github.com/daniellauding/claude-manager/issues)
- [Claude Code](https://claude.ai/claude-code)
- [MCP Servers](https://github.com/punkpeye/awesome-mcp-servers)
