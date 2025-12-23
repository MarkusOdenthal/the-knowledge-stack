#!/bin/sh
# ssh-command.sh - Execute command on remote VPS
# Part of hetzner-vps skill

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

# Defaults
DEFAULT_USER="claude"

# Parse arguments
HOST=""
COMMAND=""
USER="$DEFAULT_USER"

print_usage() {
    cat <<EOF
Usage: ssh-command.sh --host <ip-or-hostname> --command <command> [options]

Execute a command on a remote VPS.

Required:
  --host <host>       Server IP or hostname
  --command <cmd>     Command to execute

Options:
  --user <user>       SSH username (default: claude)
  --help              Show this help message

Exit codes:
  0  Success
  1  Invalid arguments
  2  SSH connection failed
  N  Remote command exit code (passed through)

Examples:
  ssh-command.sh --host <server-ip> --command "whoami"
  ssh-command.sh --host my-server --command "apt update && apt upgrade -y"
  ssh-command.sh --host <server-ip> --user admin --command "docker ps"
EOF
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --host)
            HOST="$2"
            shift 2
            ;;
        --command)
            COMMAND="$2"
            shift 2
            ;;
        --user)
            USER="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
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

if [ -z "$COMMAND" ]; then
    echo "Error: --command is required" >&2
    print_usage >&2
    exit $EXIT_INVALID_ARGS
fi

# Execute command via SSH
# - StrictHostKeyChecking=no: Accept new host keys
# - RequestTTY=no: Don't request a TTY for non-interactive commands
# - Output streams directly to stdout/stderr
# - Exit code is passed through from remote command

ssh -o StrictHostKeyChecking=no -o RequestTTY=no "$USER@$HOST" "$COMMAND"
exit_code=$?

if [ $exit_code -eq 255 ]; then
    # SSH connection failure
    echo "Error: SSH connection to $USER@$HOST failed" >&2
    exit $EXIT_SSH_FAILED
fi

# Pass through remote command exit code
exit $exit_code
