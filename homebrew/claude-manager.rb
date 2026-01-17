# Homebrew Cask formula for Claude Manager
#
# To use this formula:
# 1. Create a new repo: github.com/daniellauding/homebrew-tap
# 2. Copy this file to Casks/claude-manager.rb in that repo
# 3. Users can then install with:
#    brew tap daniellauding/tap
#    brew install --cask claude-manager

cask "claude-manager" do
  version "1.3.1"
  sha256 "f5fa9435fd2b27eb27cf766d7f945605d91a6d982669b402a872b2961edb9b9f"

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
