# Security Best Practices

Guidelines for secure VPS management and authentication.

## Claude Code Authentication

Claude Code uses account-based authentication via `claude login`. This is more secure than API keys:

- **No secrets to manage**: Authentication tokens are handled automatically
- **Browser-based flow**: Credentials never touch the command line
- **Session management**: Log out anytime with `claude logout`

### Login Process

```bash
claude login
```

1. A URL is displayed
2. Open it in your browser (can be on any device)
3. Log in with your Claude account
4. Authorize the connection
5. Return to terminal - you're authenticated

### Session Security

- Sessions persist across reboots
- Use `claude logout` when decommissioning a server
- Each server has its own session

## Other Secrets (Optional)

For non-Claude secrets (database passwords, other API keys), use `inject-secret.sh`:

Secrets are stored at `~/.secrets/` with restricted permissions (chmod 600).

**Secure Transfer:**
1. Silent input (stty -echo hides typing)
2. stdin transfer (secret via pipe, never as argument)
3. Encrypted channel (SSH transport encryption)
4. Restrictive permissions (umask 177 + chmod 600)

## Hetzner Token Security

### Storage

```bash
# Environment variable (add to ~/.zshrc)
export HCLOUD_TOKEN="your-token"

# Or secure file
echo "your-token" > ~/.hcloud_token
chmod 600 ~/.hcloud_token
export HCLOUD_TOKEN=$(cat ~/.hcloud_token)
```

### Token Permissions

- Create tokens with minimal required permissions
- Use **Read & Write** only for provisioning
- Consider separate tokens for read-only monitoring
- Rotate tokens periodically

## Incident Response

### If Claude Session is Compromised

1. Log out: `ssh claude@<ip> "claude logout"`
2. Review Claude usage in your account dashboard
3. Re-authenticate if needed: `claude login`

### If Hetzner Token is Compromised

1. Delete token in Hetzner Cloud Console
2. Create new token
3. Update HCLOUD_TOKEN environment variable
4. Review server list for unauthorized instances

### If VPS is Compromised

1. Log out Claude: `ssh claude@<ip> "claude logout"` (if accessible)
2. Delete server: `hcloud server delete <name>`
3. Provision fresh server
4. Re-authenticate: `claude login`

## Audit Checklist

Periodic security review:

- [ ] SSH keys are Ed25519 or RSA 4096+
- [ ] Hetzner token has minimal permissions
- [ ] Claude sessions active only on needed servers
- [ ] Unused servers deleted
- [ ] Tokens rotated within last 90 days
