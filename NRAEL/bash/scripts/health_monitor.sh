#!/bin/bash
# ============================================
# Script Name: health_monitor.sh
# Description: Full system health check with
#              alerting and detailed reporting
# Usage      : sudo ./health_monitor.sh
# Schedule   : */5 * * * * /path/to/health_monitor.sh
# ============================================
set -euo pipefail

# --- Config ---
LOGFILE="/var/log/health_monitor.log"
REPORT="/tmp/health_report_$(date +%Y%m%d_%H%M%S).txt"
DISK_THRESHOLD=85
MEM_THRESHOLD=90
CPU_THRESHOLD=80
SERVICES=("sshd" "cron" "rsyslog")
ALERT_EMAIL="admin@yourdomain.com"

# --- Logging ---
log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $1" | tee -a $LOGFILE; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $1" | tee -a $LOGFILE; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a $LOGFILE; }
log_crit()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRIT]  $1" | tee -a $LOGFILE; }

# --- Alert function ---
send_alert() {
    local SUBJECT=$1
    local MESSAGE=$2
    echo "$MESSAGE" | mail -s "$SUBJECT" "$ALERT_EMAIL" 2>/dev/null \
        && log_info "Alert sent to $ALERT_EMAIL" \
        || log_warn "Failed to send alert email"
}

# --- Check disk ---
check_disk() {
    log_info "--- Checking Disk Usage ---"
    while read -r USAGE FS MOUNT; do
        if [ "$USAGE" -ge "$DISK_THRESHOLD" ]; then
            log_crit "Disk CRITICAL: $MOUNT is at ${USAGE}% on $FS"
            send_alert "🚨 DISK CRITICAL: $MOUNT" \
                "Disk usage on $MOUNT ($FS) is at ${USAGE}% — above ${DISK_THRESHOLD}% threshold"
        elif [ "$USAGE" -ge 70 ]; then
            log_warn "Disk WARNING: $MOUNT is at ${USAGE}% on $FS"
        else
            log_info "Disk OK: $MOUNT is at ${USAGE}%"
        fi
    done < <(df -h | awk 'NR>1 {gsub(/%/,"",$5); print $5, $1, $6}')
}

# --- Check memory ---
check_memory() {
    log_info "--- Checking Memory Usage ---"
    local TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    local USED=$(free -m | awk '/Mem:/ {print $3}')
    local FREE=$(free -m | awk '/Mem:/ {print $4}')
    local PERCENT=$(( USED * 100 / TOTAL ))
    local SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')

    if [ "$PERCENT" -ge "$MEM_THRESHOLD" ]; then
        log_crit "Memory CRITICAL: ${PERCENT}% used (${USED}MB / ${TOTAL}MB)"
        send_alert "🚨 MEMORY CRITICAL" "Memory usage is at ${PERCENT}%"
    else
        log_info "Memory OK: ${PERCENT}% used | Free: ${FREE}MB | Swap used: ${SWAP_USED}MB"
    fi
}

# --- Check CPU ---
check_cpu() {
    log_info "--- Checking CPU Usage ---"
    local CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%')
    local CPU_USED=$(echo "100 - $CPU_IDLE" | bc 2>/dev/null || echo "N/A")
    local LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)

    if [ "$CPU_USED" != "N/A" ] && [ "${CPU_USED%.*}" -ge "$CPU_THRESHOLD" ]; then
        log_warn "CPU WARNING: ${CPU_USED}% used | Load: $LOAD"
    else
        log_info "CPU OK: ${CPU_USED}% used | Load average: $LOAD"
    fi
}

# --- Check services ---
check_services() {
    log_info "--- Checking Services ---"
    for SERVICE in "${SERVICES[@]}"; do
        STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null || echo "unknown")
        if [ "$STATUS" = "active" ]; then
            log_info "Service OK: $SERVICE is running"
        else
            log_crit "Service DOWN: $SERVICE is $STATUS — attempting restart"
            systemctl restart "$SERVICE" 2>/dev/null && \
                log_info "Service $SERVICE restarted successfully" || \
                log_error "Failed to restart $SERVICE"
        fi
    done
}

# --- Check zombie processes ---
check_zombies() {
    log_info "--- Checking Zombie Processes ---"
    local ZOMBIES=$(ps aux | awk '$8=="Z" {print $0}' | wc -l)
    if [ "$ZOMBIES" -gt 0 ]; then
        log_warn "Found $ZOMBIES zombie process(es)"
    else
        log_info "No zombie processes found"
    fi
}

# --- Generate summary report ---
generate_report() {
    echo "====== Health Report — $(date) ======" > $REPORT
    echo "" >> $REPORT
    echo "Hostname  : $(hostname)" >> $REPORT
    echo "Uptime    : $(uptime -p)" >> $REPORT
    echo "Kernel    : $(uname -r)" >> $REPORT
    echo "" >> $REPORT
    grep -E "\[WARN\]|\[CRIT\]|\[ERROR\]" $LOGFILE \
        | tail -20 >> $REPORT || true
    echo "" >> $REPORT
    echo "Full log: $LOGFILE" >> $REPORT
    log_info "Report saved to: $REPORT"
}

# --- Main ---
log_info "========== Health Monitor Started =========="
check_disk
check_memory
check_cpu
check_services
check_zombies
generate_report
log_info "========== Health Monitor Completed =========="
