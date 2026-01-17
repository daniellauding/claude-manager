# Homebrew Cask formula for Claude Manager
#
# To use this formula:
# 1. Create a new repo: github.com/daniellauding/homebrew-tap
# 2. Copy this file to Casks/claude-manager.rb in that repo
# 3. Users can then install with:
#    brew tap daniellauding/tap
#    brew install --cask claude-manager

cask "claude-manager" do
  version "1.3.0"
  sha256 "826f7d5b7337a42a5da01ef0579c26e2c3b23d8c73b7e90e8a58354db6d58975"

  url "https://github.com/daniellauding/claude-manager/releases/download/v#{version}/ClaudeManager-v#{version}.zip"
  name "Claude Manager"
  desc "Menu bar app for managing Claude CLI instances"
  homepage "https://github.com/daniellauding/claude-manager"

  depends_on macos: ">= :ventura"

  app "ClaudeManager.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/ClaudeManager.app"],
                   sudo: false
  end

  zap trash: [
    "~/.claude/snippets.json",
  ]
end
