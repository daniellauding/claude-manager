# Claude Manager

A minimalist menu bar app to monitor and manage Claude CLI instances on macOS and Windows.

Similar to [port-killer](https://github.com/productdevbook/port-killer) but for Claude processes.

## Features

- **View all running Claude instances** - PID, runtime, type, CPU%, memory usage
- **Session context** - Working folder, first prompt, session info
- **Instance types** - Detect Happy daemon, terminal, or Node.js spawned instances
- **SSH detection** - Shows if instance is running over SSH
- **Quick actions** - Focus window, stop (graceful), force stop, kill all
- **One-click focus** - Click any instance to bring its terminal to front
- **New session shortcut** - Launch new Claude session from the app
- **Auto-refresh** - Updates every 30 seconds

## Screenshots

```
┌─────────────────────────────────────────────────┐
│  ⬛  Claude Manager           1 · 12% · 256M  + ↻│
├─────────────────────────────────────────────────┤
│  1  46300  [happy]                    36:13     │
│     ├─ Jan 14, 10:30 · ttys001                  │
│     ├─ /Users/you/project                       │
│     └─ "help me build a feature..."             │
│     [Focus] [Copy]              [Stop] [Force]  │
├─────────────────────────────────────────────────┤
│  Stop All                              Quit     │
└─────────────────────────────────────────────────┘
```

## Installation

### macOS (Swift)

**Option 1: Build from source**
```bash
git clone https://github.com/daniellauding/claude-manager.git
cd claude-manager
swift build -c release
```

**Option 2: Run directly**
```bash
swift run
```

**Option 3: Install to Applications**
```bash
swift build -c release
cp -r .build/release/ClaudeManager.app /Applications/
```

### Windows (PowerShell)

```powershell
# Clone the repo
git clone https://github.com/daniellauding/claude-manager.git
cd claude-manager/windows

# Run directly
powershell -ExecutionPolicy Bypass -File claude-manager.ps1

# Or use the batch file
run-claude-manager.bat
```

**Add to startup (optional):**
Copy `run-claude-manager.bat` to `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`

## Shell Aliases (Alternative)

For command-line users, add these to your `~/.zshrc` or `~/.bashrc`:

```bash
# List all Claude instances
alias cls='claude-list'

# Kill instance by index or PID
alias ck='claude-kill'

# Kill all instances
alias cka='claude-kill all'

# Quick status
alias cst='claude-status'

# Live monitoring
alias cw='claude-watch'

# Start new session
alias cn='claude-new'

# Focus on instance
alias cf='claude-focus'
```

See the full shell functions in the [wiki](https://github.com/daniellauding/claude-manager/wiki).

## Instance Types

| Type | Description | How Detected |
|------|-------------|--------------|
| **happy** | Spawned by Happy daemon | Process ancestry includes `happy-coder` |
| **terminal** | Started from terminal | Parent is `zsh` or `bash` |
| **node** | Spawned by Node.js | Parent is `node` |
| **unknown** | Other spawn method | Default fallback |

## Requirements

### macOS
- macOS 13.0 (Ventura) or later
- Swift 5.9+
- Claude CLI installed

### Windows
- Windows 10/11
- PowerShell 5.1+
- Claude CLI installed

## Development

### macOS
```bash
# Debug build
swift build

# Release build
swift build -c release

# Run
swift run

# Run tests (when available)
swift test
```

### Windows
The Windows version is a single PowerShell script with no dependencies.

## Roadmap

- [ ] Linux support (GTK/Qt)
- [ ] Auto-start on login option
- [ ] Keyboard shortcuts
- [ ] Instance grouping by project
- [ ] Resource usage graphs
- [ ] Notification when instance ends
- [ ] Dark/light mode sync
- [ ] Custom refresh interval
- [ ] Export session logs

## Author

**Daniel Lauding**
[@daniellauding](https://github.com/daniellauding)

## Contributing

Contributions welcome! Please open an issue or PR.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [port-killer](https://github.com/productdevbook/port-killer)
- Built for use with [Claude CLI](https://claude.ai)
- Uses macOS system colors for native appearance
