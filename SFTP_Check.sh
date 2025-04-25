#!/bin/bash

# List of client servers
SERVERS=("client1" "client2" "client3" "client4" "client5" "client6" "client7" "client8")

# Report file
REPORT="/tmp/ftp_check_report_$(date +%F_%T).txt"
EMAIL_TO="you@example.com"
SUBJECT="FTP Check Report - $(date)"

# Header for the table
echo -e "Server\tSFTP_Subsystem\tSFTP_Config\tSymlink_OK\tFTPHOME_Mounted\tFTPHOME_in_FSTAB\tftpadmin_Login_OK\tftpaccess.sh_Exists" > "$REPORT"

# Loop through each server
for SERVER in "${SERVERS[@]}"; do
    echo "Checking $SERVER..."

    # Commands to run on the remote server
    ssh "$SERVER" bash << 'EOF' > /tmp/ftp_tmp_check.$$ 2>/dev/null
SFTP_SUBSYSTEM=$(grep -E "^Subsystem\s+sftp\s+/usr/bin/mysecureshell" /etc/ssh/sshd_config &>/dev/null && echo OK || echo FAIL)
SFTP_CONFIG=$(test -f /etc/ssh/sftp_config && echo OK || echo MISSING)
SYMLINK=$(test -L /sbin/nologin && [ "$(readlink -f /sbin/nologin)" == "/usr/bin/mysecureshell" ] && echo OK || echo FAIL)
FTPHOME_MOUNTED=$(mountpoint -q /ftphome && echo YES || echo NO)
FTPHOME_IN_FSTAB=$(grep -q '/ftphome' /etc/fstab && echo YES || echo NO)
FTPADMIN_LOGIN=$(id ftpadmin &>/dev/null && grep -q "/bash" <(getent passwd ftpadmin) && echo OK || echo FAIL)
FTPACCESS=$(test -f /ftpaccess.sh && echo YES || echo NO)
echo -e "$HOSTNAME\t$SFTP_SUBSYSTEM\t$SFTP_CONFIG\t$SYMLINK\t$FTPHOME_MOUNTED\t$FTPHOME_IN_FSTAB\t$FTPADMIN_LOGIN\t$FTPACCESS"
EOF

    # Append the result to the report
    cat /tmp/ftp_tmp_check.$$ >> "$REPORT"
    rm -f /tmp/ftp_tmp_check.$$
done

# Email the report (using mail or mailx)
if command -v mailx &>/dev/null; then
    mailx -s "$SUBJECT" "$EMAIL_TO" < "$REPORT"
elif command -v mail &>/dev/null; then
    mail -s "$SUBJECT" "$EMAIL_TO" < "$REPORT"
else
    echo "Mail command not found. Report saved at $REPORT"
fi
