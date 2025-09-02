#!/bin/bash
#
# cleanup_deleted_logs.sh
# Finds processes holding deleted log files and kills them
# To be run daily by cron at midnight
# 0 0 * * * /usr/local/bin/cleanup_deleted_logs.sh
# sudo chmod +x /usr/local/bin/cleanup_deleted_logs.sh


LOGFILE="/var/log/cleanup_deleted_logs.log"
DATE=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$DATE] Starting cleanup of deleted log files..." >> "$LOGFILE"

# Use lsof to find deleted log files
# -nP avoids DNS lookups and port resolution (faster)
# grep 'deleted' filters only deleted files
# awk gets the PID (2nd column)
PIDS=$(lsof -nP | grep 'deleted' | grep '/var/log' | awk '{print $2}' | sort -u)

if [ -z "$PIDS" ]; then
    echo "[$DATE] No processes with deleted log files found." >> "$LOGFILE"
else
    echo "[$DATE] Processes with deleted log files: $PIDS" >> "$LOGFILE"
    for pid in $PIDS; do
        PROC_NAME=$(ps -p $pid -o comm=)
        echo "[$DATE] Killing PID $pid ($PROC_NAME)" >> "$LOGFILE"
        kill -9 "$pid"
    done
fi

echo "[$DATE] Cleanup finished." >> "$LOGFILE"
