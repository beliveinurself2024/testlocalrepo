#!/bin/bash

# Stephane Korning # CGI Inc. # 2004
# Last Update: Stephane.Korning 2017-09-08, Inode Consultants, stefuss@yahoo.com
# mssh: multi-host wrapper for ssh.

Usage () {
    name=$(basename $0)
    echo "Usage: $name [options] [command]"
    echo "Options:"
    echo "  -h, --host HOSTS        Specify hosts (comma-separated)"
    echo "  -f, --file FILE         Specify a file with hosts"
    echo "  -I, --info              Get system info from hosts"
    echo "  -u, --user USER         Specify user to connect as"
    echo "  -r, --root              Use sudo for remote commands"
    echo "  -P, --sshpass           Use sshpass"
    echo "  -q, --quiet             Quiet mode, less output"
    echo "  --help                  Show this help message"
}

[ -x /usr/local/bin/ssh ] && ssh=/usr/local/bin/ssh || ssh=ssh

ssh="$ssh -XCqt -o StrictHostKeyChecking=no"

sudo=""
scp="scp "
PORT=22
SSHRPORT=22
HOSTS=""
rcommand=""
userid=""
quiet="no"

Get_Args () {
    while [ $# -ne 0 ]; do
        case $1 in
            -h|--host)
                shift
                val=$1
                shift
                NEWHOSTS=$(echo "$val" | sed -e 's/,/ /g')
                HOSTS="$HOSTS $NEWHOSTS"
                ;;
            -f|--file)
                shift
                val=$1
                shift
                if [ ! -r "$val" ]; then
                    echo "ERROR: Invalid hostfile for -f argument"
                    exit 1
                else
                    NEWHOSTS=$(cat "$val" | grep -v "^#" | sed -e 's/\s*#.*$//' | awk '{print $1}')
                    HOSTS="$HOSTS $NEWHOSTS"
                fi
                ;;
            -I|--info)
                rcommand+=" echo \$(cat /etc/system-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null || head -1 /etc/redhat-release 2>/dev/null) : \$(uname -a); "
                ;;
            -u|--user)
                shift
                val=$1
                shift
                userid="$val@"
                ;;
            -r|--root)
                shift
                sudo="sudo"
                PORT="$SSHRPORT"
                ;;
            -P|--sshpass|--pseudo)
                shift
                sudo="sshpass"
                PORT="$SSHRPORT"
                ;;
            -q|--quiet)
                shift
                quiet="yes"
                ;;
            --help)
                Usage
                exit 0
                ;;
            *)
                rcommand+="$@"
                break
                ;;
        esac
    done
}

Get_IPHosts () {
    for iphost in $HOSTS; do
        TEST=''
        IPHOST=$(echo "$iphost" | sed -e 's/[i,I][p,P]-/gtsadmin@/g' | sed -E 's/\.[a-z,A-Z]*\..*cloud\.socgen.*//g' | sed -e 's/\.cloud\.socgen.*//g')
        TEST=$(echo "$IPHOST" | grep "^gtsadmin@" 2>/dev/null)
        if [ ! -z "$TEST" ]; then
            IPHOST=$(echo $IPHOST | sed -e 's/-/\./g')
        fi
        IPHOSTS="$IPHOSTS $IPHOST"
    done
}

Exec_remote () {
    for i in $IPHOSTS; do
        PLT=""
        PLT=$(echo "$i" | grep "^gtsadmin@" 2>/dev/null)
        if [ ! -z "$PLT" ] && [ ! -z "$SSHPASS" ]; then
            sshpass="sshpass -e"
        else
            sshpass=""
        fi
        ip=''
        ip=$(echo $i | sed -e 's/gtsadmin@//g')
        STATUS="0"
        nc -w2 "$ip" $PORT </dev/null 2>&1 && echo "" && STATUS="$?"
        if [ "$STATUS" = "0" ]; then
            if [ "$quiet" != "yes" ]; then
                echo "#$i:"
            fi
            $sudo $sshpass $ssh ${userid}$i $rcommand
        else
            if [ "$quiet" != "yes" ]; then
                echo "#$i: is unreachable"
            fi
        fi
        if [ "$quiet" != "yes" ]; then
            echo ""
        fi
    done
}

case "$#" in
    0)
        Usage
        ;;
    *)
        Get_Args $@
        Get_IPHosts
        Exec_remote
        ;;
esac
