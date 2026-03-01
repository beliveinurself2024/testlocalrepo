#!/bin/bash
# ============================================
# Script Name: log_cleanup.sh
# Description: Rotates, compresses and cleans
#              up old logs automatically
# Usage      : sudo ./log_cleanup.sh
# Schedule   : 0 0 * * 0 /path/to/log_cleanup.sh
# ============================================
set -euo pipefail

LOG_DIR="/var/log"
ARCHIVE_DIR="/var/log/archive"
LOGFILE="/var/log/log_cleanup.log"
COMPRESS_DAYS=3
DELETE_DAYS=30
MAX_SIZE_MB=100

log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $1" | tee -a $LOGFILE; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $1" | tee -a $LOGFILE; }

[ "$EUID" -ne 0 ] && { echo "Must run as root"; exit 1; }

mkdir -p "$ARCHIVE_DIR"

log_info "===== Log Cleanup Started ====="

# --- Compress logs older than N days ---
log_info "Compressing logs older than $COMPRESS_DAYS days..."
find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" \
    -mtime +$COMPRESS_DAYS ! -name "*.gz" \
    | while read -r LOGF; do
        gzip -f "$LOGF" && log_info "Compressed: $LOGF"
    done

# --- Move compressed logs to archive ---
log_info "Moving compressed logs to archive..."
find "$LOG_DIR" -maxdepth 1 -name "*.gz" \
    | while read -r GZFILE; do
        mv "$GZFILE" "$ARCHIVE_DIR/" \
            && log_info "Archived: $(basename $GZFILE)"
    done

# --- Delete archive logs older than retention period ---
log_info "Deleting archives older than $DELETE_DAYS days..."
find "$ARCHIVE_DIR" -name "*.gz" -mtime +$DELETE_DAYS \
    | while read -r OLD; do
        rm -f "$OLD" && log_info "Deleted: $(basename $OLD)"
    done

# --- Truncate oversized active logs ---
log_info "Checking for oversized active logs..."
find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" \
    | while read -r LOGF; do
        SIZE_MB=$(du -m "$LOGF" | cut -f1)
        if [ "$SIZE_MB" -ge "$MAX_SIZE_MB" ]; then
            log_warn "$LOGF is ${SIZE_MB}MB — truncating"
            cp "$LOGF" "${LOGF}.bak"
            : > "$LOGF"
            log_info "Truncated: $LOGF | Backup: ${LOGF}.bak"
        fi
    done

# --- Summary ---
ARCHIVE_SIZE=$(du -sh "$ARCHIVE_DIR" | cut -f1)
ARCHIVE_COUNT=$(find "$ARCHIVE_DIR" -name "*.gz" | wc -l)
log_info "Archive size: $ARCHIVE_SIZE | Files: $ARCHIVE_COUNT"
log_info "===== Log Cleanup Completed ====="
