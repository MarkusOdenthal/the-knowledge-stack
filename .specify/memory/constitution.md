<!--
  Sync Impact Report
  ==================
  Version change: 0.0.0 → 1.0.0 (Initial constitution)

  Added Principles:
    - I. Plugin-Dev First (NEW)

  Added Sections:
    - Plugin Development Standards
    - Development Workflow
    - Governance

  Templates requiring updates:
    - .specify/templates/plan-template.md: ✅ No changes needed (Constitution Check section is generic)
    - .specify/templates/spec-template.md: ✅ No changes needed (technology-agnostic)
    - .specify/templates/tasks-template.md: ✅ No changes needed (generic structure)
    - .specify/templates/checklist-template.md: ✅ No changes needed (generic structure)
    - .specify/templates/agent-file-template.md: ✅ No changes needed (generic structure)

  Follow-up TODOs: None
-->

# The Knowledge Stack Constitution

## Core Principles

### I. Plugin-Dev First

When building plugins or skills for Claude Code, you MUST use the official **plugin-dev** plugin
as the primary development tool and reference.

**Non-negotiable rules:**

- All plugin creation MUST begin with `/plugin-dev:create-plugin` command for guided end-to-end setup
- When creating individual components (skills, commands, agents, hooks, MCP integrations),
  you MUST invoke the corresponding plugin-dev skill before implementation:
  - Skills: Use `plugin-dev:skill-development` skill
  - Commands: Use `plugin-dev:command-development` skill
  - Agents: Use `plugin-dev:agent-development` skill
  - Hooks: Use `plugin-dev:hook-development` skill
  - MCP: Use `plugin-dev:mcp-integration` skill
  - Structure: Use `plugin-dev:plugin-structure` skill
  - Settings: Use `plugin-dev:plugin-settings` skill
- Plugin-dev's validation agents MUST be run before any plugin is considered complete:
  - `plugin-validator` for structure validation
  - `skill-reviewer` for skill quality review
- All plugins MUST use `${CLAUDE_PLUGIN_ROOT}` for portable path references

**Rationale:** The plugin-dev plugin encapsulates Anthropic's official best practices, security
patterns, and quality standards. Using it ensures consistent, portable, and well-structured
plugins that follow the latest Claude Code conventions.

## Plugin Development Standards

**Directory Structure:**

All plugins MUST follow the standard plugin-dev directory layout:

```text
plugin-name/
├── plugin.json           # Manifest (required)
├── README.md             # Documentation
├── skills/               # SKILL.md files with YAML frontmatter
├── commands/             # Slash command .md files
├── agents/               # Agent definition files
├── hooks/                # Hook implementations
├── scripts/              # Supporting shell scripts
└── .mcp.json             # MCP server configuration (if needed)
```

**Quality Gates:**

- Every skill MUST have clear trigger phrases in its description
- Every command MUST include YAML frontmatter with description
- Every agent MUST have a comprehensive system prompt (500-3,000 words)
- Every hook MUST specify its event type and matcher pattern
- All external connections MUST use HTTPS/WSS protocols

**Portability Requirements:**

- Use `${CLAUDE_PLUGIN_ROOT}` instead of absolute paths
- Store secrets in environment variables, never hardcode
- Support installation from plugin marketplace

## Development Workflow

**For New Plugins:**

1. Run `/plugin-dev:create-plugin [description]` to start the 8-phase guided workflow
2. Complete Discovery, Component Planning, and Detailed Design phases
3. Implement components using plugin-dev skills for each type
4. Run validation agents before finalizing
5. Test plugin in Claude Code environment
6. Document in README.md

**For Individual Components:**

1. Identify the component type (skill, command, agent, hook, MCP)
2. Invoke the corresponding plugin-dev skill
3. Follow the skill's guidance for structure and best practices
4. Validate the component before integration

## Governance

**Constitutional Authority:**

This constitution supersedes all other development practices for plugin and skill development
in The Knowledge Stack project. All contributors MUST verify compliance with these principles
before creating or modifying plugins.

**Amendment Process:**

1. Amendments MUST be documented with clear rationale
2. Version number MUST be updated following semantic versioning:
   - MAJOR: Breaking changes to principles or removal of requirements
   - MINOR: New principles added or material expansions
   - PATCH: Clarifications and wording improvements
3. All dependent templates MUST be reviewed for alignment after amendments

**Compliance Review:**

- Plugin PRs MUST demonstrate plugin-dev usage in commit history
- Code reviews MUST verify plugin-dev validation was performed
- Non-compliant plugins MUST NOT be merged until corrected

**Version**: 1.0.0 | **Ratified**: 2025-12-25 | **Last Amended**: 2025-12-25
