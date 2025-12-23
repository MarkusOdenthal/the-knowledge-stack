#!/bin/sh
# status.sh - Check health status of Hetzner VPS
# Part of hetzner-vps skill

set -e

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

# Parse arguments
SERVER_NAME=""
SHOW_ALL=false

print_usage() {
    cat <<EOF
Usage: status.sh [--name <server-name>] [--all]

Check health status of Hetzner VPS instances.

Options:
  --name <name>       Check specific server
  --all               Show all servers (no prompting)
  --help              Show this help message

Exit codes:
  0  Success
  1  Invalid arguments
  2  Hetzner API error
  3  No servers found
  4  SSH connection failed

Examples:
  status.sh                    # Interactive server selection
  status.sh --name dev-server  # Check specific server
  status.sh --all              # Show all servers
EOF
}

# Get server list as JSON
get_servers() {
    hcloud server list -o json
}

# Count servers
count_servers() {
    local servers="$1"
    printf '%s' "$servers" | jq 'length'
}

# Get server info by name
get_server_by_name() {
    local name="$1"
    hcloud server describe "$name" -o json 2>/dev/null
}

# Get SSH health info from server
get_ssh_health() {
    local ip="$1"
    local result

    # Try claude user first (new default), then fall back to root
    # Use full path since PATH may not be loaded in non-interactive shells
    result=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "claude@$ip" "
        uptime -p 2>/dev/null || echo 'unknown'
        ~/.local/bin/claude --version 2>/dev/null || echo 'not installed'
    " 2>/dev/null) || {
        # Fallback to root for legacy servers
        result=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "root@$ip" "
            uptime -p 2>/dev/null || echo 'unknown'
            ~/.local/bin/claude --version 2>/dev/null || /usr/local/bin/claude --version 2>/dev/null || echo 'not installed'
        " 2>/dev/null) || result="unreachable"
    }

    printf '%s' "$result"
}

# Print single server status (detailed)
print_single_status() {
    local name="$1"
    local server_json

    server_json=$(get_server_by_name "$name")
    if [ -z "$server_json" ]; then
        echo "Error: Server '$name' not found" >&2
        exit $EXIT_NO_SERVERS
    fi

    local ip status
    ip=$(printf '%s' "$server_json" | jq -r '.public_net.ipv4.ip // "none"')
    status=$(printf '%s' "$server_json" | jq -r '.status')

    echo "Server: $name ($ip)"
    echo "Status: $status"

    if [ "$status" = "running" ] && [ "$ip" != "none" ]; then
        local health_info uptime_str claude_ver

        health_info=$(get_ssh_health "$ip")

        if [ "$health_info" = "unreachable" ]; then
            echo "Uptime: (SSH unreachable)"
            echo "Claude Code: (SSH unreachable)"
        else
            uptime_str=$(printf '%s' "$health_info" | head -n 1)
            claude_ver=$(printf '%s' "$health_info" | tail -n 1)

            echo "Uptime: $uptime_str"
            echo "Claude Code: $claude_ver"
        fi
    fi
}

# Print all servers in table format
print_all_status() {
    local servers="$1"
    local count

    count=$(count_servers "$servers")
    if [ "$count" = "0" ]; then
        echo "No Hetzner servers found" >&2
        exit $EXIT_NO_SERVERS
    fi

    # Print header
    printf "%-15s %-16s %-10s %-15s\n" "Name" "IP" "Status" "Claude Code"
    printf "%-15s %-16s %-10s %-15s\n" "---------------" "----------------" "----------" "---------------"

    # Print each server
    printf '%s' "$servers" | jq -r '.[] | "\(.name)\t\(.public_net.ipv4.ip // "none")\t\(.status)"' | while IFS='	' read -r name ip status; do
        local claude_ver="-"

        if [ "$status" = "running" ] && [ "$ip" != "none" ]; then
            # Try claude user first, fallback to root (use full path since PATH may not be loaded)
            claude_ver=$(ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes "claude@$ip" "~/.local/bin/claude --version 2>/dev/null || echo '-'" 2>/dev/null) || \
            claude_ver=$(ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes "root@$ip" "~/.local/bin/claude --version 2>/dev/null || echo '-'" 2>/dev/null) || claude_ver="-"
        fi

        printf "%-15s %-16s %-10s %-15s\n" "$name" "$ip" "$status" "$claude_ver"
    done
}

# Interactive server selection
select_server() {
    local servers="$1"
    local count names

    count=$(count_servers "$servers")

    if [ "$count" = "0" ]; then
        echo "No Hetzner servers found" >&2
        exit $EXIT_NO_SERVERS
    fi

    if [ "$count" = "1" ]; then
        # Single server, use it directly
        printf '%s' "$servers" | jq -r '.[0].name'
        return
    fi

    # Multiple servers, show menu
    echo "Available servers:" >&2
    printf '%s' "$servers" | jq -r '.[] | "  \(.name) (\(.public_net.ipv4.ip // "no IP")) - \(.status)"' >&2

    printf "Enter server name: " >&2
    read -r selected_name

    # Validate selection
    if ! printf '%s' "$servers" | jq -e --arg name "$selected_name" '.[] | select(.name == $name)' >/dev/null 2>&1; then
        echo "Error: Server '$selected_name' not found" >&2
        exit $EXIT_NO_SERVERS
    fi

    printf '%s' "$selected_name"
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --name)
            SERVER_NAME="$2"
            shift 2
            ;;
        --all)
            SHOW_ALL=true
            shift
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

# Main execution
check_hcloud_token || exit $?

servers=$(get_servers)

if [ "$SHOW_ALL" = true ]; then
    print_all_status "$servers"
elif [ -n "$SERVER_NAME" ]; then
    print_single_status "$SERVER_NAME"
else
    # Interactive mode
    selected=$(select_server "$servers")
    print_single_status "$selected"
fi

exit $EXIT_SUCCESS
