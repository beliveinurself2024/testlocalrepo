#!/bin/bash
# ============================================
# Script Name: server_inventory.sh
# Description: Generates a full server
#              inventory and hardware report
# Usage      : sudo ./server_inventory.sh
# ============================================
set -euo pipefail

REPORT="/tmp/inventory_$(hostname)_$(date +%Y%m%d).txt"

# --- Helper ---
section() { echo "" | tee -a $REPORT; echo "===== $1 =====" | tee -a $REPORT; }
info()    { printf "%-20s: %s\n" "$1" "$2" | tee -a $REPORT; }

echo "====== Server Inventory Report ======" | tee $REPORT
echo "Generated: $(date)" | tee -a $REPORT

# --- System Info ---
section "System Information"
info "Hostname"       "$(hostname -f)"
info "OS"             "$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
info "Kernel"         "$(uname -r)"
info "Architecture"   "$(uname -m)"
info "Uptime"         "$(uptime -p)"
info "Last Boot"      "$(who -b | awk '{print $3, $4}')"

# --- CPU Info ---
section "CPU Information"
info "Model"          "$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
info "CPU Cores"      "$(nproc)"
info "CPU Sockets"    "$(grep 'physical id' /proc/cpuinfo | sort -u | wc -l)"
info "Load Average"   "$(uptime | awk -F'load average:' '{print $2}' | xargs)"

# --- Memory Info ---
section "Memory Information"
info "Total RAM"      "$(free -h | awk '/Mem:/ {print $2}')"
info "Used RAM"       "$(free -h | awk '/Mem:/ {print $3}')"
info "Free RAM"       "$(free -h | awk '/Mem:/ {print $4}')"
info "Total Swap"     "$(free -h | awk '/Swap:/ {print $2}')"
info "Used Swap"      "$(free -h | awk '/Swap:/ {print $3}')"

# --- Disk Info ---
section "Disk Information"
df -h | awk 'NR>1 {printf "%-20s %-8s %-8s %-8s %s\n", $1, $2, $3, $4, $5}' | tee -a $REPORT

# --- Network Info ---
section "Network Information"
ip -br addr show | tee -a $REPORT
echo "" | tee -a $REPORT
info "Default Gateway" "$(ip route | awk '/default/ {print $3}')"
info "DNS Servers"     "$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')"

# --- Running Services ---
section "Active Services"
systemctl list-units --type=service --state=active \
    | awk 'NR>1 && /running/ {print $1}' \
    | head -20 | tee -a $REPORT

# --- Logged in Users ---
section "Currently Logged In Users"
who | tee -a $REPORT

# --- Last 5 Logins ---
section "Last 5 Logins"
last | head -5 | tee -a $REPORT

echo "" | tee -a $REPORT
echo "====== Report saved to: $REPORT ======" | tee -a $REPORT
