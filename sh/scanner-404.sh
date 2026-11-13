#!/bin/bash
# Block an IP that received too many HTTP 404 responses.
# Same iptables DROP as subnet-monitor.sh, separate ban file and comment
# so the two scripts do not remove each other's rules.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export SHELL=/bin/bash
export LANG=en_US.UTF-8

shopt -s nullglob

DEFAULT_LOG_FILES="/var/log/nginx/access.log"
DEFAULT_THRESHOLD_404=10
DEFAULT_LOG_WINDOW_SECONDS=60
DEFAULT_BAN_TIME=86400

CONFIG_FILE="/opt/killbot/f2b/scanner-404.conf"
WHITELIST_FILE="/opt/killbot/f2b/subnet-monitor-whitelist.conf"

LOG_FILES="$DEFAULT_LOG_FILES"
THRESHOLD_404="$DEFAULT_THRESHOLD_404"
LOG_WINDOW_SECONDS="$DEFAULT_LOG_WINDOW_SECONDS"
BAN_TIME="$DEFAULT_BAN_TIME"

mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    cat > "$CONFIG_FILE" << EOF
# scanner-404.sh
# Created: $(date)

# Access log (globs allowed). Same file subnet-monitor reads.
LOG_FILES="$DEFAULT_LOG_FILES"

# Block when an IP got this many 404 responses in the window.
THRESHOLD_404=$DEFAULT_THRESHOLD_404

# How far back from the last log line to count, in seconds.
LOG_WINDOW_SECONDS=$DEFAULT_LOG_WINDOW_SECONDS

# How long the iptables DROP stays, in seconds. 86400 = 24 hours.
BAN_TIME=$DEFAULT_BAN_TIME

# Exact IP, or its /24 or /16, listed here is not blocked.
WHITELIST_FILE="$WHITELIST_FILE"
EOF
    echo "Configuration file created: $CONFIG_FILE"
fi

[[ "${THRESHOLD_404:-}" =~ ^[0-9]+$ ]] || THRESHOLD_404=$DEFAULT_THRESHOLD_404
[[ "${LOG_WINDOW_SECONDS:-}" =~ ^[0-9]+$ ]] || LOG_WINDOW_SECONDS=$DEFAULT_LOG_WINDOW_SECONDS
[[ "${BAN_TIME:-}" =~ ^[0-9]+$ ]] || BAN_TIME=$DEFAULT_BAN_TIME
[ -n "${WHITELIST_FILE:-}" ] || WHITELIST_FILE="/opt/killbot/f2b/subnet-monitor-whitelist.conf"

BAN_LOG="/var/log/killbot/scanner-404-block.log"
UNBAN_LOG="/var/log/killbot/scanner-404-unban.log"
BAN_FILE="/tmp/scanner_404_bans"
IPTABLES_CHAIN="INPUT"
IPTABLES_COMMENT_TAG="scanner-404"
PIDFILE="/tmp/scanner-404.pid"

mkdir -p /var/log/killbot 2>/dev/null
[ -f "$BAN_LOG" ] || touch "$BAN_LOG"
[ -f "$UNBAN_LOG" ] || touch "$UNBAN_LOG"
[ -f "$BAN_FILE" ] || touch "$BAN_FILE"

declare -ga WL_ITEMS=()

load_whitelist() {
    WL_ITEMS=()
    local line
    [ -f "$WHITELIST_FILE" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue
        if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
            WL_ITEMS+=("$line")
        fi
    done < "$WHITELIST_FILE"
}

ip_whitelisted() {
    local ip="$1" item a b c d
    [[ "$ip" == "127.0.0.1" ]] && return 0
    IFS=. read -r a b c d <<< "$ip"
    for item in "${WL_ITEMS[@]}"; do
        [[ "$item" == "$ip" ]] && return 0
        [[ "$item" == "$a.$b.$c.0/24" ]] && return 0
        [[ "$item" == "$a.$b.0.0/16" ]] && return 0
    done
    return 1
}

if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "$(date): scanner-404 already running (PID: $OLD_PID), exiting"
        exit 1
    fi
    rm -f "$PIDFILE"
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

get_last_log_timestamp() {
    local log_file="$1" last_line last_date ts
    [ -s "$log_file" ] || { echo 0; return; }
    last_line=$(tail -n 20000 "$log_file" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -n 1) || last_line=""
    [ -n "$last_line" ] || { echo 0; return; }
    last_date=$(echo "$last_line" | awk '{print $4}' | sed 's/^\[//') || last_date=""
    [ -n "$last_date" ] || { echo 0; return; }
    ts=$(date -d "${last_date}" +%s 2>/dev/null || echo 0)
    echo "${ts:-0}"
}

# Print "count ip" for 404s in the window. Status is the code after the quoted request.
count_404() {
    local window="${LOG_WINDOW_SECONDS}" now_ts last_ts limit_ts log_file
    now_ts=$(date +%s)
    for log_file in $LOG_FILES; do
        [ -f "$log_file" ] || continue
        [ -s "$log_file" ] || continue
        last_ts=$(get_last_log_timestamp "$log_file")
        [ "${last_ts:-0}" -gt 0 ] || last_ts="$now_ts"
        limit_ts=$((last_ts - window))
        tail -n 200000 "$log_file" | awk -v limit_ts="$limit_ts" -v last_ts="$last_ts" '
            function mon2n(m) {
                m = tolower(m)
                if (m=="jan") return 1
                if (m=="feb") return 2
                if (m=="mar") return 3
                if (m=="apr") return 4
                if (m=="may") return 5
                if (m=="jun") return 6
                if (m=="jul") return 7
                if (m=="aug") return 8
                if (m=="sep") return 9
                if (m=="oct") return 10
                if (m=="nov") return 11
                if (m=="dec") return 12
                return 0
            }
            /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {
                t = $4
                gsub(/^\[/, "", t)
                split(t, a, /[:\/]/)
                if (length(a[1]) == 0) next
                mon = mon2n(a[2])
                if (mon == 0) next
                log_ts = mktime(sprintf("%04d %02d %02d %02d %02d %02d", a[3]+0, mon, a[1]+0, a[4]+0, a[5]+0, a[6]+0))
                if (log_ts < limit_ts || log_ts > last_ts) next
                if (match($0, /"[^"]*"[[:space:]]+([0-9]{3})[[:space:]]/, mm) == 0) next
                if (mm[1] != "404") next
                ipC[$1]++
            }
            END {
                for (ip in ipC) print ipC[ip], ip
            }'
    done
}

our_rule_number() {
    local ip="$1"
    sudo iptables -L "$IPTABLES_CHAIN" --line-numbers -n -v 2>/dev/null | awk -v ip="$ip" -v tag="$IPTABLES_COMMENT_TAG" '
        $4 == "DROP" && $9 == ip && index($0, tag) { print $1; exit }'
}

ban_ip() {
    local ip="$1" count="$2" timestamp
    if ip_whitelisted "$ip"; then
        echo "$(date): SKIP (whitelist): $ip - $count 404/${LOG_WINDOW_SECONDS}s" | tee -a "$BAN_LOG"
        return 0
    fi
    if [ -n "$(our_rule_number "$ip")" ]; then
        return 0
    fi
    timestamp=$(date +%s)
    echo "$(date): Blocking IP $ip - $count 404 in ${LOG_WINDOW_SECONDS}s" | tee -a "$BAN_LOG"
    sudo iptables -A "$IPTABLES_CHAIN" -s "$ip" -m comment --comment "$IPTABLES_COMMENT_TAG" -j DROP
    echo "$timestamp $ip" >> "$BAN_FILE"
}

unban_expired() {
    local current_time now_line ban_time ip time_passed rule_num temp_file
    [ -s "$BAN_FILE" ] || return 0
    current_time=$(date +%s)
    temp_file=$(mktemp)
    while IFS= read -r now_line; do
        [ -z "$now_line" ] && continue
        ban_time=$(echo "$now_line" | awk '{print $1}')
        ip=$(echo "$now_line" | awk '{print $2}')
        if [[ ! "$ban_time" =~ ^[0-9]+$ ]] || [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi
        time_passed=$((current_time - ban_time))
        if [ "$time_passed" -ge "$BAN_TIME" ]; then
            echo "$(date): Unbanning $ip (elapsed ${time_passed}s)" >> "$UNBAN_LOG"
            while true; do
                rule_num=$(our_rule_number "$ip")
                [ -z "$rule_num" ] && break
                sudo iptables -D "$IPTABLES_CHAIN" "$rule_num" 2>/dev/null || break
            done
        else
            echo "$now_line" >> "$temp_file"
        fi
    done < "$BAN_FILE"
    mv "$temp_file" "$BAN_FILE"
}

run_scan() {
    local count ip
    declare -A totals=()
    load_whitelist
    while read -r count ip; do
        [[ "$count" =~ ^[0-9]+$ ]] || continue
        [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
        totals["$ip"]=$(( ${totals["$ip"]:-0} + count ))
    done < <(count_404)

    for ip in "${!totals[@]}"; do
        count="${totals[$ip]}"
        if [ "$count" -ge "$THRESHOLD_404" ]; then
            ban_ip "$ip" "$count"
        fi
    done
    unban_expired
}

show_bans() {
    local line ban_time ip left current_time
    echo "=== scanner-404 ==="
    echo "threshold: $THRESHOLD_404 404 in ${LOG_WINDOW_SECONDS}s, ban ${BAN_TIME}s"
    echo "ban file: $BAN_FILE"
    current_time=$(date +%s)
    if [ -s "$BAN_FILE" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            ban_time=$(echo "$line" | awk '{print $1}')
            ip=$(echo "$line" | awk '{print $2}')
            [[ "$ban_time" =~ ^[0-9]+$ ]] || continue
            left=$((BAN_TIME - (current_time - ban_time)))
            if [ "$left" -gt 0 ]; then
                printf "  %-16s unban in %ss\n" "$ip" "$left"
            else
                printf "  %-16s expired\n" "$ip"
            fi
        done < "$BAN_FILE"
    else
        echo "  (none)"
    fi
    echo "iptables:"
    sudo iptables -L "$IPTABLES_CHAIN" --line-numbers -n -v 2>/dev/null | grep -F "$IPTABLES_COMMENT_TAG" || echo "  (none)"
}

clear_bans() {
    local rules rule_num ip deleted=0
    echo "Clearing scanner-404 bans..."
    rules=$(
        sudo iptables -L "$IPTABLES_CHAIN" --line-numbers -n -v 2>/dev/null | awk -v tag="$IPTABLES_COMMENT_TAG" '
            $4 == "DROP" && index($0, tag) { print }
        ' | tac
    )
    while read -r line; do
        [ -z "$line" ] && continue
        rule_num=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $9}')
        echo "  Removing rule #$rule_num for $ip"
        if sudo iptables -D "$IPTABLES_CHAIN" "$rule_num" 2>/dev/null; then
            deleted=$((deleted + 1))
        fi
    done <<< "$rules"
    > "$BAN_FILE"
    echo "  iptables rules removed: $deleted"
}

test_scan() {
    local count ip
    echo "$(date): 404 counts in the last ${LOG_WINDOW_SECONDS}s, block at ${THRESHOLD_404}"
    count_404 | sort -nr | while read -r count ip; do
        [ -n "$count" ] || continue
        if [ "$count" -ge "$THRESHOLD_404" ]; then
            echo "  BLOCK $count $ip"
        else
            echo "  $count $ip"
        fi
    done
}

case "$1" in
    run)
        run_scan
        ;;
    show)
        unban_expired
        show_bans
        ;;
    clear)
        clear_bans
        ;;
    test)
        test_scan
        ;;
    *)
        echo "Usage: $0 {run|test|show|clear}"
        exit 1
        ;;
esac
