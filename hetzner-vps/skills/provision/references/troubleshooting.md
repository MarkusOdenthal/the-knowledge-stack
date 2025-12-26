# Troubleshooting Guide

Common issues and solutions for post-provisioning problems.

For initial setup issues (hcloud CLI, API token, SSH key registration), see `PREREQUISITES.md`.

## SSH Connection Issues

### Connection Refused

```
ssh: connect to host <server-ip> port 22: Connection refused
```

**Causes:** Server still initializing (wait 30-60 seconds), SSH service not running

**Solution:**
```bash
hcloud server describe <name>  # Check status is "running"
# Wait and retry
```

### Permission Denied (publickey)

```
Permission denied (publickey).
```

**Causes:** Wrong SSH key, key not in ssh-agent, wrong user

**Solution:**
```bash
# Check which key was used
hcloud server describe <name> | grep ssh_key

# Verify key is loaded
ssh-add -l

# Add key if needed
ssh-add ~/.ssh/id_ed25519

# Try with explicit key
ssh -i ~/.ssh/id_ed25519 claude@<ip>
```

### Permission Denied for claude User

SSH key not copied to claude user during provisioning.

```bash
# Connect as root
ssh root@<ip>

# Copy SSH key to claude user
mkdir -p /home/claude/.ssh
cp /root/.ssh/authorized_keys /home/claude/.ssh/
chown -R claude:claude /home/claude/.ssh
chmod 700 /home/claude/.ssh
chmod 600 /home/claude/.ssh/authorized_keys
```

## Claude Code Issues

### Claude Code Not Found (Non-Interactive SSH)

```
ssh claude@<ip> "claude --version"
# zsh:1: command not found: claude
```

**Cause:** Non-interactive SSH commands don't source shell profiles (`.bashrc`, `.zshrc`), so PATH is not set.

**Solution:** Use the full path for non-interactive SSH commands:
```bash
# Correct - use full path
ssh claude@<ip> "~/.local/bin/claude --version"

# For interactive sessions, PATH works normally
ssh claude@<ip>
claude --version  # Works
```

**Why this happens:** When you run `ssh user@host "command"`, bash/zsh creates a non-interactive, non-login shell that skips all profile files. This is standard shell behavior, not a bug.

### Claude Code Not Found (Interactive Session)

```
claude: command not found
```

**Solution:**
```bash
# Verify you're the claude user
whoami  # Should show 'claude'

# Check if installed
ls -la ~/.local/bin/claude

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Installation Failed

```
Installing Claude Code... [FAIL]
```

**Solution:**
```bash
ssh claude@<ip>
curl -fsSL https://claude.ai/install.sh | bash
which claude
claude --version
```

### Cannot Use --dangerously-skip-permissions as Root

```
--dangerously-skip-permissions cannot be used with root/sudo privileges
```

**Solution:** Use the `claude` user, not root:
```bash
# Wrong
ssh root@<ip>
claude --dangerously-skip-permissions  # Fails

# Correct
ssh claude@<ip>
claude --dangerously-skip-permissions  # Works
```

### Login Issues

**URL Not Opening:** Copy the URL shown in terminal and paste into any browser.

**Authentication Failed:** Try `claude logout` then `claude login` again.

## Terminal Setup Issues

### Powerline Characters Not Displaying

Prompt shows boxes or garbled characters instead of icons.

**Solution:**
1. Download a Nerd Font from https://www.nerdfonts.com/
2. Install on your local machine
3. Configure terminal to use the Nerd Font
4. Restart terminal

Popular fonts: FiraCode, JetBrainsMono, Hack (Nerd Font variants)

### Zsh Not Default Shell

```bash
ssh root@<ip>
chsh -s /bin/zsh claude
exit
ssh claude@<ip>
echo $SHELL  # Should show /bin/zsh
```

## ccstatusline Issues

### Statusline Not Appearing

**Causes:** bun not installed, bun not in PATH, settings.json incorrect

**Solution:**
```bash
# Check bun
ssh claude@<ip> "~/.bun/bin/bun --version"

# Check settings.json
ssh claude@<ip> "cat ~/.claude/settings.json"

# Fix settings.json (MUST use full path to bunx)
ssh claude@<ip> 'cat > ~/.claude/settings.json << EOF
{
  "statusLine": {
    "type": "command",
    "command": "/home/claude/.bun/bin/bunx -y ccstatusline@latest",
    "padding": 0
  }
}
EOF'
```

### Bun Not Found

```bash
# Install if missing
ssh claude@<ip> "curl -fsSL https://bun.sh/install | bash"

# Add to PATH
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
```

## General Debugging

### Enable Verbose Output

```bash
# SSH issues
ssh -v claude@<ip>

# hcloud issues
hcloud --debug server list
```

### Check Server Logs

```bash
ssh root@<ip> "cat /var/log/cloud-init-output.log"
ssh root@<ip> "journalctl -xe"
```

### Reset and Start Fresh

```bash
hcloud server delete <name>
${CLAUDE_PLUGIN_ROOT}/skills/provision/scripts/provision.sh --name <name> --ssh-key <key> --location fsn1
```

## Script Issues

### "Location is required" Error

Always pass `--location` flag when running programmatically:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/provision/scripts/provision.sh --name my-server --ssh-key my-key --location fsn1
```

### Script Hangs

Script is waiting for interactive input. Pass all required flags:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/provision/scripts/provision.sh \
  --name my-server \
  --ssh-key my-key \
  --location fsn1 \
  --type cx33
```
