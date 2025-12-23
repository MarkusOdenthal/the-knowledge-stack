# The Knowledge Stack

Weekly tactics for developers building an AI-powered second brain. Turn scattered notes into shipped products. Stop losing context, start sharing what you build. Most devs stay invisible—don't be most devs.

## What This Is

**For newsletter followers**: This is the repo behind [The Knowledge Stack](https://theknowledgestack.substack.com) newsletter.

**For template users**: Fork this repo to build your own knowledge stack with Claude Code. Start with the VPS infrastructure, then add capture, content creation, and more.

## Current State: Week 1

VPS infrastructure for running Claude Code in the cloud.

### Quick Start

1. Clone the repo:
   ```bash
   git clone https://github.com/MarkusOdenthal/the-knowledge-stack
   cd the-knowledge-stack
   ```

2. Set up Hetzner prerequisites (see `hetzner-vps/skills/provision/references/prerequisites.md`)

3. Tell Claude:
   ```
   Set up a Hetzner VPS for Claude Code
   ```

### What Happens

Claude runs a preflight check, then asks you a few questions:
- Server name
- Datacenter location
- Terminal setup (zsh/oh-my-zsh/p10k)
- Statusline setup

Then it provisions a Hetzner VPS with Claude Code pre-installed (~$8/month).

## Plugins

This repo includes a plugin marketplace you can install from.

### Install Plugins

Add the marketplace:
```
/plugin marketplace add https://github.com/MarkusOdenthal/the-knowledge-stack
```

Then install any plugin:
```
/plugin install hetzner-vps
```

### Available Plugins

| Plugin | Purpose | Status |
|--------|---------|--------|
| `hetzner-vps` | Provision Claude Code on Hetzner Cloud | Ready |

## Project Structure

```
the-knowledge-stack/
├── .claude/                      # Local Claude Code configuration
├── .claude-plugin/
│   └── marketplace.json          # Plugin marketplace manifest
└── hetzner-vps/                  # VPS provisioning plugin
    ├── .claude-plugin/
    ├── agents/
    ├── commands/
    ├── skills/
    ├── LICENSE
    └── README.md
```

## Vision

This project will grow into a full knowledge stack following Dan Koe's content ecosystem:

```
Daily Experiences & Learnings
         │
         ▼
┌─────────────────────┐
│  CAPTURE            │ ◀── Quick capture of insights
│  /capture "idea..." │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  KNOWLEDGE GRAPH    │ ◀── Connect ideas, surface patterns
│  /connect           │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  CONTENT CREATION   │ ◀── Newsletter → Short-form posts
│  /draft-newsletter  │
│  /create-posts      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  LIFE DIRECTION     │ ◀── Reviews and goal tracking
│  /review weekly     │
└─────────────────────┘
```

## Roadmap

| Week | Focus |
|------|-------|
| 1 | VPS Infrastructure (current) |
| 2 | n8n + SSH Connection |
| 3 | Telegram Thought Capture |
| 4 | Auto-tagging & Organization |
| 5 | Content Generation Pipeline |

## Newsletter

Following along? [The Knowledge Stack](https://theknowledgestack.substack.com) documents each week's progress.
