#!/bin/bash
# Configuration
ADDR="adguard.lan"          # AdGuard host:port
USER="rooter"               # username
PASS="topsecret"            # password

INITIAL=100  # request and display this many initial log entries
LIMIT=40     # how many entries to request per second--increase if entries are being lost

declare -A STATS_LISTS
declare -A STATS_CUSTOM
LAST_C_TIME=0

echo -n "Building Filter Lookup Table..."
FILTER_MAP=$(curl -s -u "$USER:$PASS" "$ADDR/control/filtering/status" | jq -c '.filters | map({(.id|tostring): .name}) | add')
echo " Done"

trap 'handle_control_c' SIGINT

handle_control_c() {
    CURRENT_TIME=$(date +%s)
    DIFF=$((CURRENT_TIME - LAST_C_TIME))

    if [ "$DIFF" -le 1 ]; then
        echo -e "\n\e[1;31m[!] Exiting...\e[0m"
        exit 0
    fi

    LAST_C_TIME=$CURRENT_TIME

    echo -e "\n\n\e[1;34m=== ADGUARD BLOCK STATISTICS ===\e[0m"
    
    echo -e "\e[1;33m[ Blocks by List ]\e[0m"
    for list in "${!STATS_LISTS[@]}"; do
        echo "${STATS_LISTS[$list]}#$list"
    done | sort -rn | while IFS="#" read -r count label; do
        printf "  %-45s : %s\n" "$label" "$count"
    done

    echo -e "\n\e[1;33m[ Blocks by Custom Rule ]\e[0m"
    for rule in "${!STATS_CUSTOM[@]}"; do
        echo "${STATS_CUSTOM[$rule]}#$rule"
    done | sort -rn | while IFS="#" read -r count label; do
        printf "  %-45s : %s\n" "$label" "$count"
    done
    
    echo -e "\n\e[1;30m(Press Ctrl+C again within 1s to exit)\e[0m\n"
}

SEARCH_FILTER="$1"
SEARCH_PARAM=""
[[ ! -z "$SEARCH_FILTER" ]] && SEARCH_PARAM="&search=$SEARCH_FILTER"

LAST_TS="0"
CURRENT_LIMIT=$INITIAL

while true; do
    RESPONSE=$(curl -s -u "$USER:$PASS" "$ADDR/control/querylog?limit=$CURRENT_LIMIT$SEARCH_PARAM")
    
    # Updated cleaning logic to remove the "||" and trailing spaces AdGuard likes to append
	RAW_STATS=$(echo "$RESPONSE" | jq -r --arg last "$LAST_TS" --argjson fmap "$FILTER_MAP" '
        .data[] | 
        select(.time > $last and (.reason | startswith("Filtered")) and .reason != "FilteredAllowList" and .reason != "NotFilteredWhiteList" and .question.type != "HTTPS") |
        ((.rules[0].filter_list_id // .rules[0].filter_id) | tostring) as $fid |
        (($fmap[$fid] // "Custom") | gsub("[| ]+$"; "")) + "#" + (.rules[0].text // "n/a")
    ')

    while read -r line; do
        [[ -z "$line" ]] && continue
        LNAME="${line%#*}"
        RTEXT="${line#*#}"

        ((STATS_LISTS["$LNAME"]++))
        if [[ "$LNAME" == "Custom" && "$RTEXT" != "n/a" ]]; then
            ((STATS_CUSTOM["$RTEXT"]++))
        fi
    done <<< "$RAW_STATS"

    MAX_LEN=$(echo "$RESPONSE" | jq -r '[.data[] | (.client_info.name // .client | length)] | max // 4')
    [[ "$MAX_LEN" -lt 5 ]] && MAX_LEN=5

	NEW_QUERIES=$(echo "$RESPONSE" | jq -r --arg last "$LAST_TS" --argjson pad "$MAX_LEN" --argjson fmap "$FILTER_MAP" '
		.data | reverse | .[] | 
		
		# 1. Filter out HTTPS (Type 65) queries
		select(.time > $last and .question.type != "HTTPS") |
		
		# 2. COLOR LOGIC: Green for all "Pass" types, Red for Blocks
		(if .reason == "NotFilteredNotFound" or 
			.reason == "RewriteEtcHosts" or 
			.reason == "Rewrite" or 
			.reason == "NotFilteredWhiteList" or 
			.reason == "FilteredAllowList" 
		 then "\u001b[32m" else "\u001b[31m" end) as $color |
		
		# 3. Client Name Logic
		(.client_info.name // .client) as $raw_name |
		(if $raw_name == "" then .client else $raw_name end) as $display_name |
		
		# 4. Rule & List ID Logic
		(if .rules and (.rules | length > 0) then 
			((.rules[0].filter_list_id // .rules[0].filter_id) | tostring) as $fid |
			(($fmap[$fid] // "Custom") | gsub("[| ]+$"; "")) as $list_label |
			" (" + .rules[0].text + " [" + $list_label + "])"
		 elif .reason != "NotFilteredNotFound" then 
			" (" + .reason + ")" 
		 else "" end) as $info |
		
		# 5. Final Output Construction
		"[\(.time[11:19])] " + 
		($display_name + (" " * ($pad - ($display_name | length))) + " ") + 
		"\($color)\(.question.type | . + " " | .[0:1])\u001b[0m " + 
		"\(.question.name)\($info)"
	  ')

    if [[ ! -z "$NEW_QUERIES" ]]; then
        echo -e "$NEW_QUERIES"
        LAST_TS=$(echo "$RESPONSE" | jq -r '.data[0].time')
    fi

    CURRENT_LIMIT=$LIMIT
    sleep 1
done
