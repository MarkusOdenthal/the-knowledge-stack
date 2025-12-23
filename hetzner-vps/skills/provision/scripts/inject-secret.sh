#!/bin/sh
# inject-secret.sh - Securely inject a secret into remote server
# Part of hetzner-vps skill
#
# Note: For Claude Code authentication, use `claude login` instead.
# This script is for other secrets (database credentials, API keys for other services, etc.)

set -e

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

# Defaults
DEFAULT_USER="claude"
DEFAULT_SECRET_NAME="secret"
SECRET_DIR=".secrets"

# Parse arguments
HOST=""
USER="$DEFAULT_USER"
SECRET_NAME="$DEFAULT_SECRET_NAME"

print_usage() {
    cat <<EOF
Usage: inject-secret.sh --host <ip-or-hostname> --name <secret-name> [options]

Securely inject a secret into a remote server.

Note: For Claude Code authentication, use 'claude login' on the server instead.
This script is for other secrets (database credentials, API keys, etc.)

Required:
  --host <host>       Server IP or hostname
  --name <name>       Name for the secret file

Options:
  --user <user>       SSH username (default: claude)
  --help              Show this help message

Exit codes:
  0  Success
  1  Invalid arguments
  2  SSH connection failed
  3  Secret transfer failed

Security:
  - Secret is read with hidden input (no terminal echo)
  - Secret is transferred via SSH stdin (never as argument)
  - Remote file created with chmod 600
  - Parent directory created with chmod 700

Examples:
  inject-secret.sh --host <server-ip> --name database_password
  inject-secret.sh --host my-server.example.com --name openai_api_key
  inject-secret.sh --host <server-ip> --user admin --name github_token
EOF
}

# Read secret with hidden input (POSIX-compatible)
read_secret() {
    printf "Enter API key: " >&2
    stty -echo
    IFS= read -r SECRET
    stty echo
    printf "\n" >&2

    if [ -z "$SECRET" ]; then
        echo "Error: API key cannot be empty" >&2
        exit $EXIT_INVALID_ARGS
    fi
}

# Test SSH connection
test_ssh() {
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$USER@$HOST" "exit 0" 2>/dev/null
}

# Transfer secret securely
transfer_secret() {
    # Create directory, set permissions, write file via stdin
    printf '%s' "$SECRET" | ssh -o StrictHostKeyChecking=no "$USER@$HOST" "
        mkdir -p ~/$SECRET_DIR
        chmod 700 ~/$SECRET_DIR
        umask 177
        cat > ~/$SECRET_DIR/$SECRET_NAME
        chmod 600 ~/$SECRET_DIR/$SECRET_NAME
    " 2>/dev/null
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --host)
            HOST="$2"
            shift 2
            ;;
        --user)
            USER="$2"
            shift 2
            ;;
        --name)
            SECRET_NAME="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit $EXIT_SUCCESS
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            print_usage >&2
            exit $EXIT_INVALID_ARGS
            ;;
    esac
done

# Validate required arguments
if [ -z "$HOST" ]; then
    echo "Error: --host is required" >&2
    print_usage >&2
    exit $EXIT_INVALID_ARGS
fi

if [ "$SECRET_NAME" = "$DEFAULT_SECRET_NAME" ]; then
    echo "Error: --name is required" >&2
    print_usage >&2
    exit $EXIT_INVALID_ARGS
fi

# Main execution

# Test SSH connection
print_status "Connecting to $HOST"
if ! test_ssh; then
    print_fail
    echo "Error: Cannot connect to $USER@$HOST via SSH" >&2
    echo "Check that:" >&2
    echo "  - The server is running" >&2
    echo "  - Your SSH key is authorized" >&2
    echo "  - The hostname/IP is correct" >&2
    exit $EXIT_SSH_FAILED
fi
print_ok

# Read secret with hidden input
read_secret

# Transfer secret
print_status "Injecting secret '$SECRET_NAME'"
if ! transfer_secret; then
    print_fail
    echo "Error: Failed to transfer secret to server" >&2
    exit $EXIT_TRANSFER_FAILED
fi
print_ok

# Verify permissions
print_status "Permissions set to 600"
print_ok

# Success
echo ""
echo "Secret stored at: ~/$SECRET_DIR/$SECRET_NAME"

exit $EXIT_SUCCESS
