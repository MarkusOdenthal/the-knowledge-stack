#!/bin/sh
# provision.sh - Create and configure a Hetzner VPS with Claude Code
# Part of hetzner-vps skill

set -e

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

# Defaults
DEFAULT_SERVER_TYPE="cx33"
DEFAULT_IMAGE="ubuntu-24.04"
DEFAULT_LOCATION=""

# User configuration
DEFAULT_CLAUDE_USER="claude"

# Parse arguments
SERVER_NAME=""
SSH_KEY=""
SERVER_TYPE="$DEFAULT_SERVER_TYPE"
IMAGE="$DEFAULT_IMAGE"
LOCATION="$DEFAULT_LOCATION"
CLAUDE_USER=""
COPY_TERMINAL_SETUP=""
STATUSLINE_SETUP=""

print_usage() {
    cat <<EOF
Usage: provision.sh --name <server-name> --ssh-key <key-name> [options]

Create a Hetzner VPS with Claude Code installed.

Required:
  --name <name>       Server name (must be unique)
  --ssh-key <key>     SSH key name from Hetzner Cloud

Options:
  --type <type>       Server type (default: cx33)
  --location <loc>    Datacenter location (default: prompt)
  --image <image>     OS image (default: ubuntu-24.04)
  --user <username>   Non-root user for Claude Code (default: claude)
  --terminal-setup    Copy local terminal config (zsh, oh-my-zsh, statusline)
  --statusline-setup  Install bun and copy statusLine settings (ccstatusline)
  --help              Show this help message

Exit codes:
  0  Success
  1  Invalid arguments
  2  Hetzner API error
  3  SSH key not found
  4  Server creation failed
  5  SSH connection timeout
  6  Dependency installation failed
  7  Claude Code installation failed

Examples:
  provision.sh --name dev-server --ssh-key my-laptop
  provision.sh --name prod --ssh-key work --type cx44 --location ash
EOF
}

# Select location interactively if not provided
select_location() {
    if [ -z "$LOCATION" ]; then
        echo "Available locations:" >&2
        hcloud location list -o columns=name,city,country >&2
        printf "Enter location (e.g., fsn1, ash): " >&2
        read -r LOCATION
        if [ -z "$LOCATION" ]; then
            echo "Error: Location is required" >&2
            exit $EXIT_INVALID_ARGS
        fi
    fi

    # Validate location
    if ! hcloud location describe "$LOCATION" >/dev/null 2>&1; then
        echo "Error: Invalid location '$LOCATION'" >&2
        exit $EXIT_INVALID_ARGS
    fi
}

# Install dependencies on remote server
install_dependencies() {
    local host="$1"

    ssh -o StrictHostKeyChecking=no "root@$host" "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq curl git jq unzip
    " 2>&1 | grep -v '^$' || true

    # Verify installation succeeded by checking for curl
    ssh -o StrictHostKeyChecking=no "root@$host" "which curl" >/dev/null 2>&1
}

# Create non-root user for Claude Code
create_claude_user() {
    local host="$1"
    local username="$2"

    ssh -o StrictHostKeyChecking=no "root@$host" "
        useradd -m -s /bin/bash '$username'
        usermod -aG sudo '$username'
        echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username
        chmod 440 /etc/sudoers.d/$username
    " >/dev/null 2>&1
}

# Copy SSH key to non-root user
setup_user_ssh() {
    local host="$1"
    local username="$2"

    ssh -o StrictHostKeyChecking=no "root@$host" "
        mkdir -p /home/$username/.ssh
        chmod 700 /home/$username/.ssh
        cp /root/.ssh/authorized_keys /home/$username/.ssh/
        chmod 600 /home/$username/.ssh/authorized_keys
        chown -R $username:$username /home/$username/.ssh
    " >/dev/null 2>&1
}

# Configure PATH for Claude Code in user's shell
configure_user_path() {
    local host="$1"
    local username="$2"

    ssh -o StrictHostKeyChecking=no "root@$host" "
        echo '' >> /home/$username/.bashrc
        echo '# Claude Code' >> /home/$username/.bashrc
        echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> /home/$username/.bashrc
        chown $username:$username /home/$username/.bashrc
    " >/dev/null 2>&1
}

# Install Claude Code for specific user
install_claude_code_for_user() {
    local host="$1"
    local username="$2"

    ssh -o StrictHostKeyChecking=no "root@$host" "
        su - $username -c 'curl -fsSL https://claude.ai/install.sh | bash'
    " >/dev/null 2>&1
}

# ============================================================================
# Terminal Configuration Functions
# ============================================================================

# Check if local terminal config files exist and show status
check_local_terminal_files() {
    local files_found=0

    echo "" >&2
    echo "Checking local terminal configuration files..." >&2

    if [ -f "$HOME/.zshrc" ]; then
        echo "  [x] ~/.zshrc found" >&2
        files_found=$((files_found + 1))
    else
        echo "  [ ] ~/.zshrc not found (skipping)" >&2
    fi

    if [ -d "$HOME/.oh-my-zsh" ]; then
        local omz_size
        omz_size=$(du -sh "$HOME/.oh-my-zsh" 2>/dev/null | cut -f1)
        echo "  [x] ~/.oh-my-zsh found ($omz_size)" >&2
        files_found=$((files_found + 1))
    else
        echo "  [ ] ~/.oh-my-zsh not found (skipping)" >&2
    fi

    if [ -f "$HOME/.p10k.zsh" ]; then
        echo "  [x] ~/.p10k.zsh found" >&2
        files_found=$((files_found + 1))
    else
        echo "  [ ] ~/.p10k.zsh not found (skipping)" >&2
    fi

    if [ -d "$HOME/.config/ccstatusline" ]; then
        echo "  [x] ~/.config/ccstatusline found" >&2
        files_found=$((files_found + 1))
    else
        echo "  [ ] ~/.config/ccstatusline not found (skipping)" >&2
    fi

    if [ -f "$HOME/.claude/settings.json" ]; then
        if jq -e '.statusLine' "$HOME/.claude/settings.json" >/dev/null 2>&1; then
            echo "  [x] ~/.claude/settings.json statusLine found" >&2
            files_found=$((files_found + 1))
        else
            echo "  [ ] ~/.claude/settings.json (no statusLine config)" >&2
        fi
    else
        echo "  [ ] ~/.claude/settings.json not found" >&2
    fi

    echo "" >&2
    return $files_found
}

# Check if local Claude settings.json has statusLine configured
check_local_statusline_config() {
    if [ ! -f "$HOME/.claude/settings.json" ]; then
        return 1
    fi
    if jq -e '.statusLine' "$HOME/.claude/settings.json" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Install zsh on remote server
install_zsh() {
    local host="$1"

    ssh -o StrictHostKeyChecking=no "root@$host" "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq zsh
    " >/dev/null 2>&1
}

# Install bun for the user (required for ccstatusline)
install_bun() {
    local host="$1"
    local username="$2"

    ssh -o StrictHostKeyChecking=no "root@$host" "
        su - $username -c 'curl -fsSL https://bun.sh/install | bash'
    " >/dev/null 2>&1
}

# Add bun to PATH in .zshrc
configure_bun_path() {
    local host="$1"
    local username="$2"

    ssh -o StrictHostKeyChecking=no "root@$host" "
        if ! grep -q 'BUN_INSTALL' /home/$username/.zshrc 2>/dev/null; then
            echo '' >> /home/$username/.zshrc
            echo '# Bun' >> /home/$username/.zshrc
            echo 'export BUN_INSTALL=\"\$HOME/.bun\"' >> /home/$username/.zshrc
            echo 'export PATH=\"\$BUN_INSTALL/bin:\$PATH\"' >> /home/$username/.zshrc
        fi
        chown $username:$username /home/$username/.zshrc
    " >/dev/null 2>&1
}

# Set zsh as default shell for user
set_default_shell_zsh() {
    local host="$1"
    local username="$2"

    ssh -o StrictHostKeyChecking=no "root@$host" "
        chsh -s /bin/zsh '$username'
    " >/dev/null 2>&1
}

# Copy terminal configuration to remote server
copy_terminal_config() {
    local host="$1"
    local username="$2"
    local home_dir="/home/$username"

    # Copy .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        print_status "Copying .zshrc"
        if rsync -az "$HOME/.zshrc" "root@$host:$home_dir/.zshrc" 2>/dev/null; then
            print_ok
        else
            print_fail
            echo "Warning: Failed to copy .zshrc" >&2
        fi
    fi

    # Copy oh-my-zsh directory
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_status "Copying oh-my-zsh (~21MB, this may take a moment)"
        # Use rsync with compression for large directory
        if rsync -az --delete "$HOME/.oh-my-zsh/" "root@$host:$home_dir/.oh-my-zsh/" 2>/dev/null; then
            print_ok
        else
            print_fail
            echo "Warning: Failed to copy oh-my-zsh" >&2
        fi
    fi

    # Copy p10k config
    if [ -f "$HOME/.p10k.zsh" ]; then
        print_status "Copying p10k.zsh"
        if rsync -az "$HOME/.p10k.zsh" "root@$host:$home_dir/.p10k.zsh" 2>/dev/null; then
            print_ok
        else
            print_fail
            echo "Warning: Failed to copy p10k.zsh" >&2
        fi
    fi

    # Copy ccstatusline config
    if [ -d "$HOME/.config/ccstatusline" ]; then
        print_status "Copying ccstatusline config"
        # Create .config directory if it doesn't exist
        ssh -o StrictHostKeyChecking=no "root@$host" "mkdir -p '$home_dir/.config'" >/dev/null 2>&1
        if rsync -az --delete "$HOME/.config/ccstatusline/" "root@$host:$home_dir/.config/ccstatusline/" 2>/dev/null; then
            print_ok
        else
            print_fail
            echo "Warning: Failed to copy ccstatusline config" >&2
        fi
    fi

    # Fix ownership
    print_status "Setting file ownership"
    if ssh -o StrictHostKeyChecking=no "root@$host" "chown -R '$username:$username' '$home_dir'" >/dev/null 2>&1; then
        print_ok
    else
        print_fail
        echo "Warning: Failed to set file ownership" >&2
    fi
}

# Copy statusLine settings from local Claude settings.json (excludes plugins)
# Updates bunx command to use full path for non-interactive shell compatibility
copy_statusline_settings() {
    local host="$1"
    local username="$2"
    local home_dir="/home/$username"

    if ! check_local_statusline_config; then
        return 1
    fi

    # Extract only statusLine from local settings.json
    # Replace 'bunx' with full path for non-interactive shell compatibility
    local statusline_json
    statusline_json=$(jq '{statusLine: .statusLine}' "$HOME/.claude/settings.json" | \
        sed "s|\"bunx |\"$home_dir/.bun/bin/bunx |g")

    print_status "Creating Claude settings.json with statusLine"

    # Create .claude directory on remote
    ssh -o StrictHostKeyChecking=no "root@$host" "
        mkdir -p '$home_dir/.claude'
        chown '$username:$username' '$home_dir/.claude'
        chmod 700 '$home_dir/.claude'
    " >/dev/null 2>&1

    # Transfer settings.json using pipe (avoids heredoc escaping issues)
    if echo "$statusline_json" | ssh -o StrictHostKeyChecking=no "root@$host" "
        cat > '$home_dir/.claude/settings.json'
        chown '$username:$username' '$home_dir/.claude/settings.json'
        chmod 600 '$home_dir/.claude/settings.json'
    " 2>/dev/null; then
        print_ok
        return 0
    else
        print_fail
        return 1
    fi
}

# Configure PATH for Claude Code in zsh
configure_zsh_path() {
    local host="$1"
    local username="$2"

    # Add PATH to .zshrc if not already present
    ssh -o StrictHostKeyChecking=no "root@$host" "
        if ! grep -q 'PATH=\"\$HOME/.local/bin:\$PATH\"' /home/$username/.zshrc 2>/dev/null; then
            echo '' >> /home/$username/.zshrc
            echo '# Claude Code PATH' >> /home/$username/.zshrc
            echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> /home/$username/.zshrc
        fi
        chown $username:$username /home/$username/.zshrc
    " >/dev/null 2>&1
}

# Full terminal setup orchestration
setup_terminal_config() {
    local host="$1"
    local username="$2"

    # Check local files
    check_local_terminal_files
    local files_found=$?

    if [ "$files_found" -eq 0 ]; then
        echo "No terminal configuration files found to copy" >&2
        return 1
    fi

    # Install zsh
    print_status "Installing zsh on server"
    if install_zsh "$host"; then
        print_ok
    else
        print_fail
        echo "Warning: Failed to install zsh, continuing with bash" >&2
        return 1
    fi

    # Copy configuration files
    copy_terminal_config "$host" "$username"

    # ccstatusline setup (only if user requested it)
    if [ "$STATUSLINE_SETUP" = "yes" ]; then
        # Install bun (required for ccstatusline)
        print_status "Installing bun runtime"
        if install_bun "$host" "$username"; then
            print_ok
            # Add bun to PATH in .zshrc
            print_status "Configuring bun PATH"
            if configure_bun_path "$host" "$username"; then
                print_ok
            else
                print_fail
                echo "Warning: Failed to configure bun PATH" >&2
            fi
        else
            print_fail
            echo "Warning: Failed to install bun, ccstatusline will not work" >&2
        fi

        # Copy statusLine settings to Claude settings.json (uses full path to bunx)
        copy_statusline_settings "$host" "$username"
    fi

    # Configure PATH for Claude Code in zsh
    print_status "Configuring PATH in .zshrc"
    if configure_zsh_path "$host" "$username"; then
        print_ok
    else
        print_fail
    fi

    # Set zsh as default shell
    print_status "Setting zsh as default shell"
    if set_default_shell_zsh "$host" "$username"; then
        print_ok
    else
        print_fail
        echo "Warning: Failed to set default shell to zsh" >&2
    fi

    # Note about Nerd Fonts
    echo "" >&2
    echo "Note: Powerline/Nerd Font characters require a compatible font" >&2
    echo "      in your terminal to display correctly." >&2

    return 0
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --name)
            SERVER_NAME="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        --type)
            SERVER_TYPE="$2"
            shift 2
            ;;
        --location)
            LOCATION="$2"
            shift 2
            ;;
        --image)
            IMAGE="$2"
            shift 2
            ;;
        --user)
            CLAUDE_USER="$2"
            shift 2
            ;;
        --terminal-setup)
            COPY_TERMINAL_SETUP="yes"
            shift
            ;;
        --statusline-setup)
            STATUSLINE_SETUP="yes"
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

# Validate required arguments
if [ -z "$SERVER_NAME" ]; then
    echo "Error: --name is required" >&2
    print_usage >&2
    exit $EXIT_INVALID_ARGS
fi

if [ -z "$SSH_KEY" ]; then
    echo "Error: --ssh-key is required" >&2
    print_usage >&2
    exit $EXIT_INVALID_ARGS
fi

# Set default claude user if not specified
if [ -z "$CLAUDE_USER" ]; then
    CLAUDE_USER="$DEFAULT_CLAUDE_USER"
fi

# Main execution
check_hcloud_token || exit $?
check_ssh_key "$SSH_KEY" || exit $?
select_location

# Create server with retry for transient failures
print_status "Creating VPS '$SERVER_NAME'"

create_attempts=0
max_create_attempts=3
create_error=""

while [ $create_attempts -lt $max_create_attempts ]; do
    create_error=$(hcloud server create \
        --name "$SERVER_NAME" \
        --type "$SERVER_TYPE" \
        --image "$IMAGE" \
        --ssh-key "$SSH_KEY" \
        --location "$LOCATION" 2>&1) && break

    create_attempts=$((create_attempts + 1))

    # Check for permanent errors (don't retry)
    case "$create_error" in
        *"uniqueness_error"*|*"already in use"*)
            print_fail
            echo "Error: Server name '$SERVER_NAME' already exists" >&2
            exit $EXIT_SERVER_CREATE_FAILED
            ;;
        *"quota"*|*"limit"*)
            print_fail
            echo "Error: Account quota exceeded. Delete unused servers or upgrade." >&2
            exit $EXIT_SERVER_CREATE_FAILED
            ;;
    esac

    if [ $create_attempts -lt $max_create_attempts ]; then
        sleep 5
    fi
done

if [ $create_attempts -eq $max_create_attempts ]; then
    print_fail
    echo "Error: Failed to create server after $max_create_attempts attempts" >&2
    echo "Details: $create_error" >&2
    exit $EXIT_SERVER_CREATE_FAILED
fi
print_ok

echo "Server type: $SERVER_TYPE"
echo "Location: $LOCATION"

# Get server IP
SERVER_IP=$(hcloud server ip "$SERVER_NAME")
if [ -z "$SERVER_IP" ]; then
    echo "Error: Could not retrieve server IP" >&2
    exit $EXIT_SERVER_CREATE_FAILED
fi

# Wait for SSH
print_status "Waiting for server to start"
if ! wait_for_ssh "$SERVER_IP"; then
    print_fail
    echo "Error: SSH connection timeout after 150 seconds" >&2
    exit $EXIT_SSH_TIMEOUT
fi
print_ok

echo "IPv4: $SERVER_IP"

# Install dependencies
print_status "Installing dependencies"
if ! install_dependencies "$SERVER_IP"; then
    print_fail
    echo "Error: Failed to install dependencies" >&2
    exit $EXIT_DEPENDENCY_FAILED
fi
print_ok

# Create non-root user for Claude Code
print_status "Creating user '$CLAUDE_USER'"
if ! create_claude_user "$SERVER_IP" "$CLAUDE_USER"; then
    print_fail
    echo "Error: Failed to create user '$CLAUDE_USER'" >&2
    exit $EXIT_DEPENDENCY_FAILED
fi
print_ok

# Setup SSH access for new user
print_status "Configuring SSH for '$CLAUDE_USER'"
if ! setup_user_ssh "$SERVER_IP" "$CLAUDE_USER"; then
    print_fail
    echo "Error: Failed to configure SSH for '$CLAUDE_USER'" >&2
    exit $EXIT_DEPENDENCY_FAILED
fi
print_ok

# Terminal configuration (only if --terminal-setup flag provided)
TERMINAL_SETUP_DONE=false
if [ "$COPY_TERMINAL_SETUP" = "yes" ]; then
    if setup_terminal_config "$SERVER_IP" "$CLAUDE_USER"; then
        TERMINAL_SETUP_DONE=true
    fi
fi

# Configure PATH for Claude Code (only if terminal setup didn't do it)
if [ "$TERMINAL_SETUP_DONE" != "true" ]; then
    print_status "Configuring PATH"
    if ! configure_user_path "$SERVER_IP" "$CLAUDE_USER"; then
        print_fail
        echo "Error: Failed to configure PATH" >&2
        exit $EXIT_DEPENDENCY_FAILED
    fi
    print_ok
fi

# Install Claude Code for the non-root user
print_status "Installing Claude Code for '$CLAUDE_USER'"
if ! install_claude_code_for_user "$SERVER_IP" "$CLAUDE_USER"; then
    print_fail
    echo "Error: Failed to install Claude Code" >&2
    exit $EXIT_CLAUDE_INSTALL_FAILED
fi
print_ok

# Success
echo ""
echo "Server ready!"
echo ""
echo "SSH access:"
echo "  Root (admin):    ssh root@$SERVER_IP"
echo "  Claude Code:     ssh $CLAUDE_USER@$SERVER_IP"
echo ""
echo "Next steps:"
echo "  1. ssh $CLAUDE_USER@$SERVER_IP"
echo "  2. claude"
echo "  3. Follow the browser authentication flow"

exit $EXIT_SUCCESS
