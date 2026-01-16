# Homebrew Cask formula for Claude Manager
#
# To use this formula:
# 1. Create a new repo: github.com/daniellauding/homebrew-tap
# 2. Copy this file to Casks/claude-manager.rb in that repo
# 3. Users can then install with:
#    brew tap daniellauding/tap
#    brew install --cask claude-manager

cask "claude-manager" do
  version "1.1.0"
  sha256 "UPDATE_WITH_SHA256_FROM_RELEASE_SCRIPT"

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
