#!/bin/bash
# ============================================
# Script Name: user_manager.sh
# Description: Create, delete, and list users
#              with full validation and logging
# Usage      : sudo ./user_manager.sh {create|delete|list} [username]
# sudo ./user_manager.sh create john
# sudo ./user_manager.sh delete john
# sudo ./user_manager.sh list

# ============================================
set -euo pipefail

LOGFILE="/var/log/user_manager.log"
DEFAULT_SHELL="/bin/bash"
DEFAULT_GROUP="users"

# --- Logging ---
log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $1" | tee -a $LOGFILE; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $1" | tee -a $LOGFILE; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a $LOGFILE; exit 1; }

# --- Root check ---
[ "$EUID" -ne 0 ] && log_error "Must run as root. Use sudo."

# --- Validate username ---
validate_username() {
    local USERNAME=$1
    [ -z "$USERNAME" ] && log_error "Username cannot be empty"
    [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]] && \
        log_error "Invalid username: only letters, numbers, _ and - allowed"
}

# --- Create user ---
create_user() {
    local USERNAME=$1
    validate_username "$USERNAME"

    if id "$USERNAME" &>/dev/null; then
        log_warn "User $USERNAME already exists — skipping"
        return
    fi

    # Create user with home directory and default shell
    useradd -m -s "$DEFAULT_SHELL" -g "$DEFAULT_GROUP" "$USERNAME" \
        || log_error "Failed to create user: $USERNAME"

    # Set password expiry — force change on first login
    chage -d 0 "$USERNAME"

    # Set a temporary password
    echo "$USERNAME:TempPass@123" | chpasswd \
        || log_error "Failed to set password for: $USERNAME"

    log_info "✔ User created: $USERNAME | Home: /home/$USERNAME | Shell: $DEFAULT_SHELL"
    log_warn "Temporary password set. User must change on first login."
}

# --- Delete user ---
delete_user() {
    local USERNAME=$1
    validate_username "$USERNAME"

    if ! id "$USERNAME" &>/dev/null; then
        log_warn "User $USERNAME does not exist — skipping"
        return
    fi

    # Archive home directory before deletion
    ARCHIVE="/backup/${USERNAME}_home_$(date +%Y%m%d).tar.gz"
    mkdir -p /backup
    tar -czf "$ARCHIVE" "/home/$USERNAME" 2>/dev/null \
        && log_info "Home directory archived to: $ARCHIVE"

    userdel -r "$USERNAME" || log_error "Failed to delete user: $USERNAME"
    log_info "✔ User deleted: $USERNAME | Archive: $ARCHIVE"
}

# --- List users ---
list_users() {
    echo ""
    echo "====== System Users with Bash Shell ======"
    printf "%-15s %-25s %-10s\n" "USERNAME" "HOME" "LAST LOGIN"
    echo "---------------------------------------------------"
    while IFS=: read -r USER _ _ _ _ HOME SHELL; do
        if [ "$SHELL" = "/bin/bash" ]; then
            LAST=$(lastlog -u "$USER" 2>/dev/null | awk 'NR==2 {print $4,$5,$9}')
            printf "%-15s %-25s %-10s\n" "$USER" "$HOME" "$LAST"
        fi
    done < /etc/passwd
    echo ""
}

# --- Main ---
ACTION=${1:-}
USERNAME=${2:-}

case "$ACTION" in
    create) create_user "$USERNAME" ;;
    delete) delete_user "$USERNAME" ;;
    list)   list_users ;;
    *)
        echo "Usage: $0 {create|delete|list} [username]"
        exit 1
        ;;
esac
