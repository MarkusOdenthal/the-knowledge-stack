# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Knowledge Stack is a Claude Code plugin marketplace and development framework for building an AI-powered knowledge system. The main deliverable is the `hetzner-vps` plugin for provisioning VPS instances with Claude Code pre-installed.

## Architecture

```
the-knowledge-stack/
├── .claude/                    # Claude Code configuration
│   ├── commands/               # SpecKit slash commands (/speckit.*)
│   └── settings.local.json     # Permissions whitelist
├── .specify/                   # Feature specification framework
│   ├── memory/constitution.md  # Project principles (Plugin-Dev First)
│   └── templates/              # Spec, plan, tasks templates
├── .claude-plugin/             # Plugin marketplace manifest
│   └── marketplace.json
└── hetzner-vps/                # Main plugin
    ├── plugin.json             # Plugin manifest
    ├── agents/                 # Agent definitions (preflight-check)
    ├── skills/provision/       # VPS provisioning skill
    │   ├── SKILL.md            # Skill definition with workflow
    │   ├── scripts/            # Shell scripts (provision.sh, status.sh)
    │   └── references/         # Prerequisites, troubleshooting docs
    └── commands/               # Plugin slash commands
```

## Plugin Architecture

**Skills** trigger on specific phrases (defined in SKILL.md frontmatter) and orchestrate multi-step workflows.

**Agents** are autonomous actors invoked by skills to handle complex tasks (e.g., preflight verification).

**Scripts** are stateless shell utilities called by agents/skills. Located in `scripts/` with shared code in `lib/common.sh`.

## Key Workflows

### Hetzner VPS Provisioning

Triggered by: "provision a VPS", "create a Hetzner server", "set up a cloud server for Claude Code"

1. `hetzner-preflight-check` agent verifies hcloud CLI, token, lists available options
2. AskUserQuestion gathers: server name, SSH key, location, server type, terminal/statusline setup
3. `provision.sh` creates server, installs Claude Code, configures SSH access

```bash
# Check server health
hetzner-vps/skills/provision/scripts/status.sh <server-name>

# Execute remote command
hetzner-vps/skills/provision/scripts/ssh-command.sh <server-name> "command"
```

### SpecKit Feature Development

```
/speckit.specify  → Creates spec.md from feature description
/speckit.plan     → Creates plan.md with technical approach
/speckit.tasks    → Creates tasks.md with actionable items
/speckit.implement → Executes tasks from tasks.md
/speckit.analyze  → Validates consistency across artifacts
```

## Constitution Principle: Plugin-Dev First

When building plugins or skills for Claude Code, always use the official `plugin-dev` plugin:

- New plugins: Start with `/plugin-dev:create-plugin`
- Skills: Use `plugin-dev:skill-development` skill
- Commands: Use `plugin-dev:command-development` skill
- Agents: Use `plugin-dev:agent-development` skill
- Validation: Run `plugin-validator` and `skill-reviewer` agents before completion

All plugins must use `${CLAUDE_PLUGIN_ROOT}` for portable paths.

## Hetzner CLI Commands

Requires `HCLOUD_TOKEN` environment variable.

```bash
hcloud server list              # List servers
hcloud server create ...        # Create server
hcloud server delete <name>     # Delete server
hcloud location list            # Available datacenters
hcloud server-type list         # Available server types
hcloud ssh-key list             # Registered SSH keys
```

## Active Technologies
- POSIX Shell (sh), Bash, Zsh + hcloud CLI, SSH, rsync (001-fix-claude-path)
- N/A (file-based shell configuration) (001-fix-claude-path)
- POSIX Shell (sh), compatible with bash/zsh + hcloud CLI, SSH, rsync (001-fix-claude-path)
- N/A (shell configuration files) (001-fix-claude-path)

## Recent Changes
- 001-fix-claude-path: Added POSIX Shell (sh), Bash, Zsh + hcloud CLI, SSH, rsync
