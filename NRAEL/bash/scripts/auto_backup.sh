#!/bin/bash
# ============================================
# Script Name: auto_backup.sh
# Description: Automated backup with retention
#              policy and integrity verification
# Usage      : sudo ./auto_backup.sh <source>
# Schedule   : 0 2 * * * /path/to/auto_backup.sh /var/www
# ============================================
set -euo pipefail

BACKUP_ROOT="/backup"
LOGFILE="/var/log/auto_backup.log"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $1" | tee -a $LOGFILE; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a $LOGFILE; exit 1; }

cleanup() { [ -f "${TMPFILE:-}" ] && rm -f "$TMPFILE"; }
trap cleanup EXIT

# --- Validation ---
[ "$EUID" -ne 0 ]  && log_error "Must run as root"
[ -z "${1:-}" ]    && log_error "Usage: $0 <source_directory>"
[ ! -d "$1" ]      && log_error "Source not found: $1"

SOURCE=$1
SOURCE_NAME=$(basename "$SOURCE")
DEST_DIR="$BACKUP_ROOT/$SOURCE_NAME"
DEST_FILE="$DEST_DIR/${SOURCE_NAME}_${TIMESTAMP}.tar.gz"
TMPFILE="$DEST_DIR/.tmp_${TIMESTAMP}.tar.gz"
CHECKSUM_FILE="${DEST_FILE}.md5"

mkdir -p "$DEST_DIR"

# --- Disk space check ---
AVAILABLE=$(df "$BACKUP_ROOT" | awk 'NR==2 {print $4}')
SOURCE_SIZE=$(du -sk "$SOURCE" | cut -f1)
[ "$SOURCE_SIZE" -ge "$AVAILABLE" ] && \
    log_error "Insufficient disk space. Need: ${SOURCE_SIZE}K | Available: ${AVAILABLE}K"

# --- Run backup ---
log_info "Starting backup: $SOURCE → $DEST_FILE"
tar -czf "$TMPFILE" -C "$(dirname $SOURCE)" "$SOURCE_NAME" \
    || log_error "Backup failed during compression"

mv "$TMPFILE" "$DEST_FILE"

# --- Integrity check ---
md5sum "$DEST_FILE" > "$CHECKSUM_FILE"
md5sum -c "$CHECKSUM_FILE" &>/dev/null \
    && log_info "✔ Integrity check passed" \
    || log_error "❌ Integrity check FAILED — backup may be corrupt"

BACKUP_SIZE=$(du -sh "$DEST_FILE" | cut -f1)
log_info "✔ Backup complete | Size: $BACKUP_SIZE | File: $DEST_FILE"

# --- Retention policy ---
log_info "Applying retention policy: keeping last $RETENTION_DAYS days"
find "$DEST_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \; \
    && log_info "Old backups cleaned up successfully"

REMAINING=$(find "$DEST_DIR" -name "*.tar.gz" | wc -l)
log_info "Total backups retained: $REMAINING"
