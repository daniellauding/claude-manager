# Product Hunt Launch Guide

## Quick Checklist

- [ ] App icon (240x240 PNG)
- [ ] Gallery images (1270x760 each, 3-5 images)
- [ ] Tagline (60 chars max)
- [ ] Description (260 chars max)
- [ ] First comment (maker's comment)
- [ ] Landing page live
- [ ] GitHub release ready
- [ ] Homebrew tap set up

---

## Product Hunt Listing

### Name
**Claude Manager**

### Tagline (60 chars max)
```
Menu bar app for Claude prompts, MCPs, and instance management
```

Alternative taglines:
- `Your Claude prompt library, right in the menu bar`
- `Manage Claude sessions and prompts from your menu bar`
- `The missing menu bar companion for Claude Code`

### Description (260 chars max)
```
A macOS menu bar app to manage your Claude CLI instances and build a library of prompts, agents, skills, and MCP configurations. Discover 50+ curated prompts, search GitHub for more, and organize everything with tags, favorites, and folders.
```

### Topics/Tags
- Developer Tools
- Productivity
- Artificial Intelligence
- macOS
- Open Source

### Links
- **Website**: https://daniellauding.github.io/claude-manager
- **GitHub**: https://github.com/daniellauding/claude-manager

---

## Maker's First Comment

Post this immediately after launch:

```
Hey Product Hunt! 👋

I built Claude Manager because I was drowning in Claude CLI sessions and kept losing track of useful prompts.

**The problem:**
- Multiple Claude instances running, no idea which is which
- Great prompts scattered across files, notes, and browser tabs
- MCP server configs hard to remember

**The solution:**
A simple menu bar app that shows all your Claude sessions AND lets you build a prompt library.

**Key features:**
✨ See all running Claude instances with context
📚 Save and organize prompts, agents, skills, templates
🔌 15+ MCP server setup guides included
🔍 Search GitHub for community prompts
📁 Auto-sync prompts from your folders

**It's free and open source.** Built with SwiftUI, runs natively on macOS.

I'd love your feedback - what prompts or MCP configs would you want to see included?
```

---

## Gallery Images (1270x760 px)

### Image 1: Hero Shot
**Filename**: `hero.png`
**Content**: App icon + menu bar dropdown showing instances
**Caption**: "Monitor all your Claude sessions from the menu bar"

### Image 2: Snippets Library
**Filename**: `snippets.png`
**Content**: Snippets tab with several prompts visible
**Caption**: "Organize prompts, agents, skills, and templates"

### Image 3: Discover
**Filename**: `discover.png`
**Content**: Discover view with featured prompts
**Caption**: "50+ curated prompts and MCP configs included"

### Image 4: MCP Configs
**Filename**: `mcp.png`
**Content**: MCP category showing GitHub, Slack, PostgreSQL configs
**Caption**: "Easy setup guides for popular MCP servers"

### Image 5: Detail View
**Filename**: `detail.png`
**Content**: Expanded prompt with full content visible
**Caption**: "Preview and save prompts with one click"

---

## How to Take Screenshots

```bash
# 1. Open the app
open /Applications/ClaudeManager

# 2. Click menu bar icon to show dropdown

# 3. Take screenshot
# Press Cmd+Shift+4, then Space, then click the window

# 4. Screenshots save to Desktop by default
```

**Tips:**
- Use a clean desktop background
- Close other menu bar icons if possible
- Show real content, not placeholder text
- Make sure some prompts are saved for the library view

---

## App Icon

Need a 240x240 PNG icon. Current options:

1. **Use SF Symbol**: The app uses system icons currently
2. **Create custom**: Simple design ideas:
   - Terminal icon with Claude "C"
   - Menu bar icon with sparkles
   - Minimalist "CM" monogram

For quick icon creation:
- [Figma](https://figma.com) - Free, make a 240x240 frame
- [IconKitchen](https://icon.kitchen) - Generate from emoji/text
- [Haikei](https://haikei.app) - Background patterns

---

## Landing Page

Update `docs/index.html` with:

```html
<!-- Add these meta tags for social sharing -->
<meta property="og:title" content="Claude Manager">
<meta property="og:description" content="Menu bar app for Claude prompts and instance management">
<meta property="og:image" content="https://daniellauding.github.io/claude-manager/og-image.png">
<meta property="og:url" content="https://daniellauding.github.io/claude-manager">
<meta name="twitter:card" content="summary_large_image">
```

---

## Launch Day Timeline

### Before Launch (1-2 days)
- [ ] Final build and test
- [ ] Create GitHub release
- [ ] Set up Homebrew tap
- [ ] Prepare all images
- [ ] Write maker comment
- [ ] Test download links

### Launch Day
- [ ] Submit to Product Hunt (12:01 AM PT is best)
- [ ] Post maker comment immediately
- [ ] Share on Twitter/X
- [ ] Share on LinkedIn
- [ ] Post in relevant Discord/Slack communities
- [ ] Reply to all comments within hours

### Communities to Share
- Twitter/X with #buildinpublic #indiehackers
- r/macapps subreddit
- r/ClaudeAI subreddit
- Indie Hackers
- Hacker News (Show HN)
- Dev.to article
- Claude Discord (if exists)

---

## Social Post Templates

### Twitter/X
```
🚀 Just launched Claude Manager on Product Hunt!

A free menu bar app for macOS that helps you:
✨ Monitor Claude CLI sessions
📚 Build a prompt library
🔌 Set up MCP servers easily

Built with SwiftUI, open source.

👉 [Product Hunt link]

#buildinpublic #claude #ai #macos
```

### LinkedIn
```
Excited to share my new open source project: Claude Manager 🎉

If you use Claude Code/CLI, you know the struggle of:
- Losing track of multiple sessions
- Forgetting great prompts
- Setting up MCP servers

Claude Manager solves all of this from your menu bar.

Features:
• Monitor all Claude instances
• Save and organize prompts
• 50+ curated prompts included
• MCP setup guides for GitHub, Slack, Postgres, and more

It's free and open source. Would love your feedback!

[Product Hunt link]
```

---

## Metrics to Track

After launch:
- Product Hunt upvotes
- GitHub stars
- Downloads (via GitHub release stats)
- Homebrew install count (hard to track)

---

## Post-Launch

1. **Thank voters** - Reply to Product Hunt comments
2. **Collect feedback** - Note feature requests
3. **Fix bugs** - Quick patch releases if needed
4. **Write blog post** - "How I built Claude Manager"
5. **Update roadmap** - Based on feedback
