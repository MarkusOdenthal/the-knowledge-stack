# Hetzner VPS Prerequisites

One-time setup guide for the hcloud CLI. Complete these steps before using the hetzner-vps skill.

## 1. Install hcloud CLI

### macOS (Homebrew)

```bash
brew install hcloud
```

### Linux (apt)

```bash
curl -fsSL https://packages.hetzner.com/hcloud/key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/hcloud.gpg
echo "deb [signed-by=/usr/share/keyrings/hcloud.gpg] https://packages.hetzner.com/hcloud/deb debian main" | sudo tee /etc/apt/sources.list.d/hcloud.list
sudo apt update && sudo apt install hcloud-cli
```

### Linux (Binary)

```bash
curl -sL https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz | tar xz
sudo mv hcloud /usr/local/bin/
```

## 2. Create API Token

1. Log in to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Select your project (or create one)
3. Go to **Security** > **API Tokens**
4. Click **Generate API Token** with **Read & Write** permissions
5. Copy the token immediately (shown only once)

## 3. Set Environment Variable

```bash
# Add to ~/.zshrc or ~/.bashrc
export HCLOUD_TOKEN="your-api-token-here"

# Reload
source ~/.zshrc
```

## 4. Register SSH Key

```bash
# Check existing keys
ls -la ~/.ssh/*.pub

# Create key if needed
ssh-keygen -t ed25519 -C "your-email@example.com"

# Register in Hetzner Cloud
hcloud ssh-key create --name my-laptop --public-key-from-file ~/.ssh/id_ed25519.pub
```

## 5. Verify Setup

```bash
hcloud version      # Should show version
hcloud server list  # Should work without error
hcloud ssh-key list # Should show your key
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `hcloud server list` | List all servers |
| `hcloud server-type list` | Available server types |
| `hcloud location list` | Available datacenters |
| `hcloud ssh-key list` | Registered SSH keys |

## Server Types

| Type | vCPU | RAM | ~Monthly |
|------|------|-----|----------|
| cx22 | 2 | 4 GB | $4 |
| cx33 | 4 | 8 GB | $8 |
| cx44 | 8 | 16 GB | $16 |

**Recommended:** cx33 for Claude Code (good balance of cost/performance)

## Locations

| Code | Location |
|------|----------|
| fsn1 | Falkenstein, Germany |
| nbg1 | Nuremberg, Germany |
| ash | Ashburn, VA (USA) |
| hil | Hillsboro, OR (USA) |
