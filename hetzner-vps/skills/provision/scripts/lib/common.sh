#!/bin/sh
# common.sh - Shared utilities for hetzner-vps scripts
# Part of hetzner-vps skill
#
# Usage: Source this file from other scripts
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   . "$SCRIPT_DIR/lib/common.sh"

# ============================================================================
# Exit Codes (standardized across all scripts)
# ============================================================================

EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_API_ERROR=2
EXIT_SSH_FAILED=3
EXIT_TRANSFER_FAILED=4
EXIT_SERVER_CREATE_FAILED=5
EXIT_SSH_TIMEOUT=6
EXIT_DEPENDENCY_FAILED=7
EXIT_CLAUDE_INSTALL_FAILED=8
EXIT_NO_SERVERS=9
EXIT_SSH_KEY_NOT_FOUND=10

# ============================================================================
# Status Printing Functions
# ============================================================================

# Print status message without newline (for progress indication)
# Usage: print_status "Installing dependencies"
print_status() {
    printf "%s... " "$1"
}

# Print success indicator
print_ok() {
    printf "[OK]\n"
}

# Print failure indicator
print_fail() {
    printf "[FAIL]\n"
}

# ============================================================================
# SSH Utilities
# ============================================================================

# Default SSH options for non-interactive commands
SSH_OPTS="-o StrictHostKeyChecking=no -o BatchMode=yes"

# Execute SSH command with timeout
# Usage: ssh_exec "user@host" "command" [timeout_seconds]
ssh_exec() {
    local target="$1"
    local command="$2"
    local timeout="${3:-10}"

    ssh -o ConnectTimeout="$timeout" $SSH_OPTS "$target" "$command"
}

# Try claude user first, fall back to root
# Usage: ssh_with_fallback "host" "command" [timeout_seconds]
# Returns: command output or "unreachable" on failure
ssh_with_fallback() {
    local host="$1"
    local command="$2"
    local timeout="${3:-5}"
    local result

    # Try claude user first
    result=$(ssh -o ConnectTimeout="$timeout" $SSH_OPTS "claude@$host" "$command" 2>/dev/null) && {
        printf '%s' "$result"
        return 0
    }

    # Fall back to root for legacy servers
    result=$(ssh -o ConnectTimeout="$timeout" $SSH_OPTS "root@$host" "$command" 2>/dev/null) && {
        printf '%s' "$result"
        return 0
    }

    # Both failed
    printf 'unreachable'
    return 1
}

# Wait for SSH to become available on a host
# Usage: wait_for_ssh "host" [max_attempts] [sleep_seconds]
# Returns: 0 on success, 1 on timeout
wait_for_ssh() {
    local host="$1"
    local max_attempts="${2:-30}"
    local sleep_seconds="${3:-5}"
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if ssh -o ConnectTimeout=5 $SSH_OPTS "root@$host" "exit 0" 2>/dev/null; then
            return 0
        fi
        sleep "$sleep_seconds"
        attempt=$((attempt + 1))
    done

    return 1
}

# ============================================================================
# Hetzner API Utilities
# ============================================================================

# Validate HCLOUD_TOKEN is set and working
# Usage: check_hcloud_token
# Exits with EXIT_API_ERROR if token is invalid
check_hcloud_token() {
    if [ -z "$HCLOUD_TOKEN" ]; then
        echo "Error: HCLOUD_TOKEN environment variable is not set" >&2
        echo "" >&2
        echo "To set up:" >&2
        echo "  1. Go to https://console.hetzner.cloud/" >&2
        echo "  2. Navigate to: Security > API Tokens" >&2
        echo "  3. Generate a new API token with Read & Write permissions" >&2
        echo "  4. Add to your shell config (~/.zshrc or ~/.bashrc):" >&2
        echo "     export HCLOUD_TOKEN=\"your-token-here\"" >&2
        echo "  5. Reload: source ~/.zshrc" >&2
        return $EXIT_API_ERROR
    fi

    # Verify token works with retry for rate limits
    local attempts=0
    local max_attempts=3

    while [ $attempts -lt $max_attempts ]; do
        if hcloud server list >/dev/null 2>&1; then
            return 0
        fi

        attempts=$((attempts + 1))
        if [ $attempts -lt $max_attempts ]; then
            echo "API request failed, retrying in 5 seconds..." >&2
            sleep 5
        fi
    done

    echo "Error: Invalid HCLOUD_TOKEN or API error (after $max_attempts attempts)" >&2
    return $EXIT_API_ERROR
}

# Validate SSH key exists in Hetzner Cloud
# Usage: check_ssh_key "key-name"
# Exits with EXIT_SSH_KEY_NOT_FOUND if key doesn't exist
check_ssh_key() {
    local key_name="$1"

    if ! hcloud ssh-key describe "$key_name" >/dev/null 2>&1; then
        echo "Error: SSH key '$key_name' not found in Hetzner Cloud" >&2
        echo "Available keys:" >&2
        hcloud ssh-key list >&2
        return $EXIT_SSH_KEY_NOT_FOUND
    fi

    return 0
}
