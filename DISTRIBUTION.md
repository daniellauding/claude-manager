# Distribution Guide

How to release Claude Manager for others to install.

## Quick Release

```bash
# 1. Build and package
./scripts/release.sh 1.2.0

# 2. Create GitHub release
git tag v1.2.0
git push origin v1.2.0

# 3. Upload ClaudeManager-v1.2.0.zip to the release

# 4. Update Homebrew formula with SHA256
```

## Step-by-Step

### 1. Build the Release

```bash
cd ~/Work/instinctly/internal/claude-manager
./scripts/release.sh 1.2.0
```

This creates:
- `ClaudeManager.app` - The app bundle
- `ClaudeManager-v1.2.0.zip` - Distributable archive
- Prints SHA256 hash for Homebrew

### 2. Create GitHub Release

```bash
# Tag the release
git add .
git commit -m "Release v1.2.0"
git tag v1.2.0
git push origin main
git push origin v1.2.0
```

Then on GitHub:
1. Go to https://github.com/daniellauding/claude-manager/releases
2. Click "Draft a new release"
3. Select tag `v1.2.0`
4. Title: `v1.2.0`
5. Description: List changes
6. Upload `ClaudeManager-v1.2.0.zip`
7. Publish release

### 3. Set Up Homebrew Tap (One-time)

Create a new repo for your Homebrew tap:

```bash
# Create repo: github.com/daniellauding/homebrew-tap
mkdir homebrew-tap
cd homebrew-tap
mkdir Casks
```

Copy the formula:
```bash
cp ~/Work/instinctly/internal/claude-manager/homebrew/claude-manager.rb Casks/
```

Edit `Casks/claude-manager.rb`:
```ruby
cask "claude-manager" do
  version "1.2.0"
  sha256 "PASTE_SHA256_FROM_RELEASE_SCRIPT"

  url "https://github.com/daniellauding/claude-manager/releases/download/v#{version}/ClaudeManager-v#{version}.zip"
  name "Claude Manager"
  desc "Menu bar app for managing Claude CLI instances"
  homepage "https://github.com/daniellauding/claude-manager"

  depends_on macos: ">= :ventura"

  app "ClaudeManager.app"

  zap trash: [
    "~/.claude/snippets.json",
  ]
end
```

Push to GitHub:
```bash
git init
git add .
git commit -m "Add claude-manager cask"
git remote add origin https://github.com/daniellauding/homebrew-tap.git
git push -u origin main
```

### 4. Update Homebrew for New Releases

After each release:

1. Run `./scripts/release.sh X.X.X` to get new SHA256
2. Update `Casks/claude-manager.rb` in homebrew-tap repo:
   - Change `version "X.X.X"`
   - Change `sha256 "NEW_HASH"`
3. Commit and push

### 5. Users Install

Once set up, users can install with:

```bash
# First time
brew tap daniellauding/tap
brew install --cask claude-manager

# Updates
brew upgrade --cask claude-manager
```

## File Checklist

Before releasing, ensure these files are ready:

- [ ] `README.md` - Updated with current features
- [ ] `CLAUDE.md` - Development notes
- [ ] `scripts/release.sh` - Build script (executable)
- [ ] `homebrew/claude-manager.rb` - Formula template
- [ ] `docs/index.html` - GitHub Pages landing page

## GitHub Pages (Optional)

Enable a landing page:

1. Go to repo Settings → Pages
2. Source: Deploy from branch `main` / `docs` folder
3. Your page: https://daniellauding.github.io/claude-manager

## Version Numbering

Follow semantic versioning:
- `1.0.0` → `1.0.1` - Bug fixes
- `1.0.0` → `1.1.0` - New features
- `1.0.0` → `2.0.0` - Breaking changes

## Troubleshooting

### "App is damaged" error
Users on first launch may see this. Fix:
```bash
xattr -cr /Applications/ClaudeManager.app
```

Or right-click → Open → Open anyway.

### Homebrew install fails
Check:
- SHA256 matches the uploaded zip
- URL is correct and accessible
- Version number matches tag

### Build fails
Ensure Xcode Command Line Tools:
```bash
xcode-select --install
```
