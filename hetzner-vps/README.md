# Hetzner VPS Plugin for Claude Code

Provision Hetzner Cloud VPS instances with Claude Code pre-installed.

## Features

- Automated VPS provisioning with Ubuntu 24.04
- Claude Code pre-installed and ready to use
- Non-root `claude` user with proper SSH access
- Optional terminal setup (zsh, oh-my-zsh, p10k)
- Optional statusline setup (ccstatusline)
- Server health monitoring
- Secure secret injection

## Prerequisites

Before using this plugin, you need:

1. **hcloud CLI** - Hetzner's command-line tool
   ```bash
   # macOS
   brew install hcloud

   # Linux (Debian/Ubuntu)
   curl -fsSL https://packages.hetzner.cloud/hcloud/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/hcloud.gpg
   echo "deb [signed-by=/usr/share/keyrings/hcloud.gpg] https://packages.hetzner.cloud/hcloud/deb stable main" | sudo tee /etc/apt/sources.list.d/hcloud.list
   sudo apt update && sudo apt install hcloud-cli
   ```

2. **Hetzner Cloud API Token** - Get from [Hetzner Cloud Console](https://console.hetzner.cloud/) with Read & Write permissions

3. **HCLOUD_TOKEN environment variable** - Add to your shell config:
   ```bash
   export HCLOUD_TOKEN="your-token-here"
   ```

4. **SSH Key registered with Hetzner**:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   hcloud ssh-key create --name my-laptop --public-key-from-file ~/.ssh/id_ed25519.pub
   ```

## Installation

### Via Git URL (simplest)

```
/plugin install https://github.com/YOUR_USERNAME/hetzner-vps-plugin
```

### Local Development

```bash
claude --plugin-dir /path/to/hetzner-vps
```

## Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/hetzner-vps:provision` | Provision a new VPS with Claude Code |
| `/hetzner-vps:status` | Check status of your Hetzner VPS servers |

### Natural Language

The plugin also responds to natural language requests:
- "Provision a new VPS"
- "Create a Hetzner server"
- "Set up a cloud server for Claude Code"

### Server Types

| Type | vCPU | RAM | Price |
|------|------|-----|-------|
| cx22 | 2 | 4GB | ~$4/month |
| cx33 | 4 | 8GB | ~$8/month (recommended) |
| cx44 | 8 | 16GB | ~$16/month |

### Datacenter Locations

| Code | Location |
|------|----------|
| fsn1 | Falkenstein, Germany |
| nbg1 | Nuremberg, Germany |
| hel1 | Helsinki, Finland |
| ash | Ashburn, USA |
| hil | Hillsboro, USA |

## What Gets Installed

When you provision a VPS, the script:

1. Creates a new Hetzner VPS with Ubuntu 24.04
2. Installs system dependencies (curl, git, jq, unzip)
3. Creates a non-root `claude` user with sudo access
4. Configures SSH key access
5. Installs Claude Code CLI
6. (Optional) Copies your terminal config (zsh, oh-my-zsh, p10k)
7. (Optional) Sets up ccstatusline for status display

## Connecting to Your VPS

After provisioning:

```bash
ssh claude@YOUR_SERVER_IP
```

Then authenticate Claude Code:

```bash
claude login
```

## Security

- Claude Code uses browser-based OAuth (no API keys stored on server)
- Secrets stored in `~/.secrets/` with chmod 600
- Non-root user for isolation
- SSH key authentication only

## License

MIT
