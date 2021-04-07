#! /usr/bin/env bash
# shellcheck disable=SC2086,SC2155,SC2004,SC2046,SC2062

set -u
set -o pipefail

send_msg()
{
        local MESSAGE="$1"
        curl -s \
        https://api.telegram.org/bot$APITOKEN/sendMessage \
        -F text="$MESSAGE" \
        -F chat_id=$CHATID \
        -F parse_mode=HTML \
        -F disable_web_page_preview=true
}

get_block_height()
{
	local RESPONSE=$(curl --insecure --connect-timeout 6 -sf --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST $IPN)
	local BH=$(echo "$RESPONSE" | jq -r '.|select(.result)|.result')
	BH=$(($BH))
        echo $BH
}

is_already_active()
{
        if [ ! -f $ALERT_LIST ]; then
                echo "false"
                return 0
        fi
        local alarm_type=$3
        local pattern="-E $NAME.*$IPN.*$alarm_type"
        if [ $# -eq 4 ]; then
                pattern="-E $NAME.*$IPN.*$alarm_type.*$BLOCK"
        fi
        if [ "$(cat $ALERT_LIST | grep $pattern)" != "" ]; then
                echo "true"
        else
                echo "false"
        fi
}

check()
{
        NAME=$(echo $IP |awk -F ";" '{print $1}' | sed 's/NODE=//g')
        IPN=$(echo $IP | awk -F ";" '{print $2}')
        for (( ITERATION=1; ITERATION<=$RETRY; ITERATION++ )); do
                INITIAL=$(get_block_height $IPN)
                if [ -z $INITIAL ]; then
                        continue
                fi
		echo "Initial BH: $INITIAL"
                sleep 30
                BLOCK=$(get_block_height $IPN)
                if [ -z $BLOCK ]; then
                        continue
                else
			echo "Final BH: $BLOCK"
                        break
                fi
        done
        if [ -z $INITIAL ] || [ -z $BLOCK ]; then
                # node down
                if [ $(is_already_active $NAME $IPN "Down") = "false" ]; then
                        echo "*** ALERT *** Node is down -> $NAME $IPN"
                        echo "$(date +%s),$NAME,$IPN,Down," >> $ALERT_LIST
                        send_msg "&#9940 Node $NAME $IPN is down."
                        echo ""
                        return 0
                fi
                echo "Down alert for node $NAME $IPN is already active"
                return 0
        fi
        # node down resolved
        if [ $(is_already_active $NAME $IPN "Down") = "true" ]; then
                # remove down alert
                echo "Node down for $NAME $IPN has been resolved"
                send_msg "&#9989 Node $NAME $IPN is back up again."
                echo ""
                grep -v -E $NAME.*$IPN.*Down $ALERT_LIST > temp_alert ; rm $ALERT_LIST ; mv temp_alert $ALERT_LIST
        fi
        if [ "$INITIAL" -eq "$BLOCK" ]; then
                if [ $(is_already_active $NAME $IPN "Stopped" $BLOCK) = "true" ]; then
                        echo "Stucked alert already active. $NAME $IPN $BLOCK"
                        return 0
                fi
                if [ $(is_already_active $NAME $IPN "Stopped") = "true" ]; then
                        # remove old alert
                        grep -v -E $NAME.*$IPN.*Stopped $ALERT_LIST > temp_alert ; rm $ALERT_LIST ; mv temp_alert $ALERT_LIST
                        # add new alert
                        echo "Update. Node is stucked. $NAME $IPN $BLOCK"
                        echo "$(date +%s),$NAME,$IPN,Stopped,$BLOCK" >> $ALERT_LIST
                        send_msg "&#9203 Update. Node $NAME $IPN stucked at block <code>$BLOCK</code>."
                        echo ""
                        return 0
                fi
                echo "Node is stucked. $NAME $IPN $BLOCK"
                echo "$(date +%s),$NAME,$IPN,Stopped,$BLOCK" >> $ALERT_LIST
                send_msg "&#8987 Node $NAME $IPN stucked at block <code>$BLOCK</code>."
                echo ""
                return 0
        fi
        # node stucked resolved
        if [ $(is_already_active $NAME $IPN "Stopped") = "true" ]; then
                # remove stucked alert
                echo "Node stucked resolved. $NAME $IPN"
                send_msg "&#127939 Node $NAME $IPN is back to work."
                echo ""
                grep -v -E $NAME.*$IPN.*Stopped $ALERT_LIST > temp_alert ; rm $ALERT_LIST ; mv temp_alert $ALERT_LIST
        fi
}

# check for TMUX or SCREEN session
if ! [[ "$TERM" =~ "screen" ]]; then
	echo ""
        echo "No TMUX or SCREEN session detected. Proceed anyway?"
	read -rsp $'Press any key to continue or CTRL-C to exit ...\n' -n 1 key
fi

# check external requirements
if ! type "jq" > /dev/null; then
        echo "jq not found. Install it before use this script. Exit"
        exit 1
fi
if ! type "curl" > /dev/null; then
        echo "curl not found. Install it before use this script. Exit"
        exit 1
fi

# get working dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# check config file
if [ ! -f $__dir/config.ini ]; then
        echo "File $__dir/config.ini not found. Exit."
        exit 1
fi

# load config
CHATID=$(grep -v "#" < $__dir/config.ini | grep "CHATID" | awk -F "=" '{print $2}')
APITOKEN=$(grep -v "#" < $__dir/config.ini | grep "APITOKEN" | awk -F "=" '{print $2}')
RETRY=3
ALERT_LIST=$__dir/alerts.txt

while true; do
        NODEIP=$(grep -v "#" < $__dir/config.ini | grep "NODE")
        for IP in $NODEIP; do
                check $IP
        done
        sleep 10
done

