#!/bin/bash
# Block an IP that requests several vulnerability-scanner paths in one window.
# Search bots re-crawl removed pages and collect 404s. They do not request
# .git, .svn, .env, wp-config, editor backups or router exploit URLs.
# One such request is not enough. The IP is blocked only after several
# different probe paths. Same iptables DROP as subnet-monitor.sh, own comment.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export SHELL=/bin/bash
export LANG=en_US.UTF-8

shopt -s nullglob

DEFAULT_LOG_FILES="/var/log/nginx/access.log"
DEFAULT_THRESHOLD_PATHS=3
DEFAULT_LOG_WINDOW_SECONDS=600
DEFAULT_BAN_TIME=86400

CONFIG_FILE="/opt/killbot/f2b/scanner-probe.conf"
EXTRA_FILE="/opt/killbot/f2b/scanner-probe-extra.conf"
WHITELIST_FILE="/opt/killbot/f2b/subnet-monitor-whitelist.conf"

LOG_FILES="$DEFAULT_LOG_FILES"
THRESHOLD_PATHS="$DEFAULT_THRESHOLD_PATHS"
LOG_WINDOW_SECONDS="$DEFAULT_LOG_WINDOW_SECONDS"
BAN_TIME="$DEFAULT_BAN_TIME"

mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    cat > "$CONFIG_FILE" << EOF
# scanner-probe.sh
# Created: $(date)

# Access log (globs allowed). Same file subnet-monitor reads.
LOG_FILES="$DEFAULT_LOG_FILES"

# Block when one IP requested this many different probe paths in the window.
# Repeats of the same path do not count. 3 keeps a single /.env from banning.
THRESHOLD_PATHS=$DEFAULT_THRESHOLD_PATHS

# How far back from the last log line to count, in seconds.
LOG_WINDOW_SECONDS=$DEFAULT_LOG_WINDOW_SECONDS

# How long the iptables DROP stays, in seconds. 86400 = 24 hours.
BAN_TIME=$DEFAULT_BAN_TIME

# Extra path fragments, one per line. See scanner-probe-extra.conf.
EXTRA_FILE="$EXTRA_FILE"

# Exact IP or CIDR listed here is not blocked.
# Yandex and Googlebot networks are added by the script itself.
WHITELIST_FILE="$WHITELIST_FILE"
EOF
    echo "Configuration file created: $CONFIG_FILE"
fi

if [ ! -f "$EXTRA_FILE" ]; then
    cat > "$EXTRA_FILE" << 'EOF'
# Extra probe fragments for scanner-probe.sh
# One per line, matched inside the request path, case ignored.
# A line shorter than 4 characters is ignored. Empty and # lines are ignored.
# Built-in probes already cover .git .svn .env wp-config and the usual scanner files.
EOF
fi

[[ "${THRESHOLD_PATHS:-}" =~ ^[1-9][0-9]*$ ]] || THRESHOLD_PATHS=$DEFAULT_THRESHOLD_PATHS
[[ "${LOG_WINDOW_SECONDS:-}" =~ ^[1-9][0-9]*$ ]] || LOG_WINDOW_SECONDS=$DEFAULT_LOG_WINDOW_SECONDS
[[ "${BAN_TIME:-}" =~ ^[0-9]+$ ]] || BAN_TIME=$DEFAULT_BAN_TIME
[ -n "${WHITELIST_FILE:-}" ] || WHITELIST_FILE="/opt/killbot/f2b/subnet-monitor-whitelist.conf"
[ -n "${EXTRA_FILE:-}" ] || EXTRA_FILE="/opt/killbot/f2b/scanner-probe-extra.conf"

BAN_LOG="/var/log/killbot/scanner-probe-block.log"
UNBAN_LOG="/var/log/killbot/scanner-probe-unban.log"
BAN_FILE="/tmp/scanner_probe_bans"
IPTABLES_CHAIN="INPUT"
IPTABLES_COMMENT_TAG="scanner-probe"
PIDFILE="/tmp/scanner-probe.pid"

mkdir -p /var/log/killbot 2>/dev/null
[ -f "$BAN_LOG" ] || touch "$BAN_LOG"
[ -f "$UNBAN_LOG" ] || touch "$UNBAN_LOG"
[ -f "$BAN_FILE" ] || touch "$BAN_FILE"

declare -ga WL_ITEMS=()
declare -gA SELF_IPS=()

# Search-crawler networks. Always applied, and written into the whitelist file.
# Yandex: https://killbot.ru/ips/yandex.json
# Googlebot ipv4: https://developers.google.com/static/search/apis/ipranges/googlebot.json (2026-11-13)
DEFAULT_SEARCH_BOT_CIDRS=(
    5.45.192.0/18
    5.255.192.0/18
    37.9.64.0/18
    37.140.128.0/18
    77.88.0.0/18
    84.252.160.0/19
    87.250.224.0/19
    90.156.176.0/20
    92.255.112.0/20
    93.158.128.0/18
    95.108.128.0/17
    141.8.128.0/18
    178.154.128.0/18
    185.32.187.0/24
    213.180.192.0/19
    192.178.4.0/27
    192.178.4.32/27
    192.178.4.64/27
    192.178.4.96/27
    192.178.4.128/27
    192.178.4.160/27
    192.178.4.192/27
    192.178.4.224/27
    192.178.5.0/27
    192.178.6.0/27
    192.178.6.32/27
    192.178.6.64/27
    192.178.6.96/27
    192.178.6.128/27
    192.178.6.160/27
    192.178.6.192/27
    192.178.6.224/27
    192.178.7.0/27
    192.178.7.32/27
    192.178.7.64/27
    192.178.7.96/27
    192.178.7.128/27
    192.178.7.160/27
    192.178.7.192/27
    192.178.7.224/27
    34.22.85.0/27
    34.64.82.64/28
    34.65.242.112/28
    34.80.50.80/28
    34.88.194.0/28
    34.89.10.80/28
    34.89.198.80/28
    34.96.162.48/28
    34.100.182.96/28
    34.101.50.144/28
    34.118.66.0/28
    34.118.254.0/28
    34.126.178.96/28
    34.146.150.144/28
    34.147.110.144/28
    34.151.74.144/28
    34.152.50.64/28
    34.154.114.144/28
    34.155.98.32/28
    34.165.18.176/28
    34.175.160.64/28
    34.176.130.16/28
    35.247.243.240/28
    66.249.64.0/27
    66.249.64.32/27
    66.249.64.64/27
    66.249.64.96/27
    66.249.64.128/27
    66.249.64.160/27
    66.249.64.192/27
    66.249.64.224/27
    66.249.65.0/27
    66.249.65.32/27
    66.249.65.64/27
    66.249.65.96/27
    66.249.65.128/27
    66.249.65.160/27
    66.249.65.192/27
    66.249.65.224/27
    66.249.66.0/27
    66.249.66.32/27
    66.249.66.64/27
    66.249.66.96/27
    66.249.66.128/27
    66.249.66.160/27
    66.249.66.192/27
    66.249.66.224/27
    66.249.67.0/27
    66.249.67.32/27
    66.249.67.64/27
    66.249.68.0/27
    66.249.68.32/27
    66.249.68.64/27
    66.249.68.96/27
    66.249.68.128/27
    66.249.68.160/27
    66.249.68.192/27
    66.249.68.224/27
    66.249.69.0/27
    66.249.69.32/27
    66.249.69.64/27
    66.249.69.96/27
    66.249.69.128/27
    66.249.69.160/27
    66.249.69.192/27
    66.249.69.224/27
    66.249.70.0/27
    66.249.70.32/27
    66.249.70.64/27
    66.249.70.96/27
    66.249.70.128/27
    66.249.70.160/27
    66.249.70.192/27
    66.249.70.224/27
    66.249.71.0/27
    66.249.71.32/27
    66.249.71.64/27
    66.249.71.96/27
    66.249.71.128/27
    66.249.71.160/27
    66.249.71.192/27
    66.249.71.224/27
    66.249.72.0/27
    66.249.72.32/27
    66.249.72.64/27
    66.249.72.96/27
    66.249.72.128/27
    66.249.72.160/27
    66.249.72.192/27
    66.249.72.224/27
    66.249.73.0/27
    66.249.73.32/27
    66.249.73.64/27
    66.249.73.96/27
    66.249.73.128/27
    66.249.73.160/27
    66.249.73.192/27
    66.249.73.224/27
    66.249.74.0/27
    66.249.74.32/27
    66.249.74.64/27
    66.249.74.96/27
    66.249.74.128/27
    66.249.74.160/27
    66.249.74.192/27
    66.249.74.224/27
    66.249.75.0/27
    66.249.75.32/27
    66.249.75.64/27
    66.249.75.96/27
    66.249.75.128/27
    66.249.75.160/27
    66.249.75.192/27
    66.249.75.224/27
    66.249.76.0/27
    66.249.76.32/27
    66.249.76.64/27
    66.249.76.96/27
    66.249.76.128/27
    66.249.76.160/27
    66.249.76.192/27
    66.249.76.224/27
    66.249.77.0/27
    66.249.77.32/27
    66.249.77.64/27
    66.249.77.96/27
    66.249.77.128/27
    66.249.77.160/27
    66.249.77.192/27
    66.249.77.224/27
    66.249.78.0/27
    66.249.78.32/27
    66.249.78.64/27
    66.249.78.96/27
    66.249.78.128/27
    66.249.78.160/27
    66.249.78.192/27
    66.249.78.224/27
    66.249.79.0/27
    66.249.79.32/27
    66.249.79.64/27
    66.249.79.128/27
    66.249.79.160/27
    66.249.79.192/27
    66.249.79.224/27
)
SELF_IPS_LOADED=0

# Addresses configured on this machine. A health check to the public IP is
# logged with that address as the client, and a DROP of it cuts the server
# off from itself.
load_self_ips() {
    [ "$SELF_IPS_LOADED" -eq 1 ] && return 0
    SELF_IPS_LOADED=1
    SELF_IPS=()
    local addr
    SELF_IPS["127.0.0.1"]=1
    while read -r addr; do
        [[ "$addr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
        SELF_IPS["$addr"]=1
    done < <(ip -4 -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
}

# True when ip is the exact address or lies inside a CIDR of any prefix length.
ip_in_cidr() {
    local ip="$1" cidr="$2" net mask
    local ia ib ic id na nb nc nd bits ipo neto shift i
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    if [[ "$cidr" != */* ]]; then
        [[ "$cidr" == "$ip" ]] && return 0
        return 1
    fi
    IFS=/ read -r net mask <<< "$cidr"
    [[ "$mask" =~ ^([0-9]|[12][0-9]|3[0-2])$ ]] || return 1
    [[ "$net" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    IFS=. read -r ia ib ic id <<< "$ip"
    IFS=. read -r na nb nc nd <<< "$net"
    bits=$mask
    for i in 1 2 3 4; do
        case $i in
            1) ipo=$ia; neto=$na ;;
            2) ipo=$ib; neto=$nb ;;
            3) ipo=$ic; neto=$nc ;;
            4) ipo=$id; neto=$nd ;;
        esac
        if (( bits >= 8 )); then
            (( ipo == neto )) || return 1
            bits=$((bits - 8))
        elif (( bits > 0 )); then
            shift=$((8 - bits))
            (( (ipo >> shift) == (neto >> shift) )) || return 1
            return 0
        else
            return 0
        fi
    done
    return 0
}

ensure_search_bot_whitelist() {
    local dir
    dir=$(dirname "$WHITELIST_FILE")
    mkdir -p "$dir" 2>/dev/null || true
    [ -e "$WHITELIST_FILE" ] || touch "$WHITELIST_FILE" 2>/dev/null || return 0
    if grep -q 'killbot-search-bots' "$WHITELIST_FILE" 2>/dev/null; then
        return 0
    fi
    {
        echo ""
        echo "# killbot-search-bots Yandex and Googlebot. Do not remove."
        printf '%s\n' "${DEFAULT_SEARCH_BOT_CIDRS[@]}"
    } >> "$WHITELIST_FILE" 2>/dev/null || true
}

load_whitelist() {
    WL_ITEMS=()
    local line cidr
    ensure_search_bot_whitelist
    if [ -f "$WHITELIST_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%%#*}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [ -z "$line" ] && continue
            if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
                WL_ITEMS+=("$line")
            fi
        done < "$WHITELIST_FILE"
    fi
    for cidr in "${DEFAULT_SEARCH_BOT_CIDRS[@]}"; do
        WL_ITEMS+=("$cidr")
    done
}

ip_whitelisted() {
    local ip="$1" item
    load_self_ips
    [[ -n "${SELF_IPS[$ip]:-}" ]] && return 0
    for item in "${WL_ITEMS[@]}"; do
        ip_in_cidr "$ip" "$item" && return 0
    done
    return 1
}

if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "$(date): scanner-probe already running (PID: $OLD_PID), exiting"
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

# Print "count ip sample-paths" for distinct probe paths in the window.
count_probes() {
    local window="${LOG_WINDOW_SECONDS}" now_ts last_ts limit_ts log_file
    now_ts=$(date +%s)
    for log_file in $LOG_FILES; do
        [ -f "$log_file" ] || continue
        [ -s "$log_file" ] || continue
        last_ts=$(get_last_log_timestamp "$log_file")
        [ "${last_ts:-0}" -gt 0 ] || last_ts="$now_ts"
        limit_ts=$((last_ts - window))
        tail -n 200000 "$log_file" | awk -v limit_ts="$limit_ts" -v last_ts="$last_ts" -v extrafile="$EXTRA_FILE" '
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
            function extra_hit(uri, i) {
                for (i = 1; i <= nextra; i++) if (index(uri, extra[i])) return 1
                return 0
            }
            function probe_hit(uri) {
                if (uri == "" || uri == "/") return 0
                if (index(uri, "..") || index(uri, "%2e%2e") || index(uri, "%252e")) return 1
                if (index(uri, "/etc/passwd") || index(uri, "/etc/shadow")) return 1
                if (index(uri, "/.git") || index(uri, "/.svn") || index(uri, "/.hg") || index(uri, "/.bzr")) return 1
                if (index(uri, "/.env") || index(uri, "/.aws/") || index(uri, "/.ssh/") || index(uri, "/.kube/")) return 1
                if (index(uri, "id_rsa") || index(uri, "id_dsa") || index(uri, "id_ed25519")) return 1
                if (index(uri, "/.htpasswd") || index(uri, "/.htaccess") || index(uri, "/.ds_store") || index(uri, "/.npmrc")) return 1
                if (index(uri, "/.bash_history") || index(uri, "/.mysql_history") || index(uri, "/.idea/") || index(uri, "/.vscode/")) return 1
                if (index(uri, "/wp-config")) return 1
                if (index(uri, "/xmlrpc.php") || index(uri, "wlwmanifest.xml")) return 1
                if (index(uri, "/phpinfo") || uri ~ /\/info\.php$/) return 1
                if (index(uri, "/server-status") || index(uri, "/server-info")) return 1
                if (index(uri, "/_profiler") || index(uri, "/actuator/") || index(uri, "/vendor/phpunit") || index(uri, "eval-stdin.php")) return 1
                if (index(uri, "/hnap1") || index(uri, "/boaform") || index(uri, "/gponform")) return 1
                if (index(uri, "/jmx-console") || index(uri, "/web-console") || index(uri, "jmxinvokerservlet")) return 1
                if (index(uri, "/solr/admin") || index(uri, "/containers/json") || index(uri, "/owa/auth")) return 1
                if (index(uri, "/web.config") || index(uri, "/appsettings.json") || index(uri, "/application.yml") || index(uri, "/docker-compose.yml")) return 1
                if (index(uri, "/composer.json") || index(uri, "/composer.lock") || index(uri, "/package.json") || index(uri, "/package-lock.json")) return 1
                if (uri ~ /\.(bak|old|orig|swp|save|sql|sql\.gz)$/ || uri ~ /~$/) return 1
                return extra_hit(uri)
            }
            BEGIN {
                while ((getline line < extrafile) > 0) {
                    sub(/#.*/, "", line)
                    gsub(/^[ \t]+|[ \t]+$/, "", line)
                    line = tolower(line)
                    if (length(line) >= 4) extra[++nextra] = line
                }
                close(extrafile)
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
                if (match($0, /"[A-Z]+ ([^" ?]+)/, mm) == 0) next
                uri = tolower(mm[1])
                if (!probe_hit(uri)) next
                key = $1 SUBSEP uri
                if (key in seen) next
                seen[key] = 1
                uniq[$1]++
                n = split(sample[$1], tmp, " ")
                if (sample[$1] == "" || n < 5) sample[$1] = (sample[$1] == "" ? uri : sample[$1] " " uri)
            }
            END {
                for (ip in uniq) print uniq[ip], ip, sample[ip]
            }'
    done
}

our_rule_number() {
    local ip="$1"
    sudo iptables -L "$IPTABLES_CHAIN" --line-numbers -n 2>/dev/null | awk -v ip="$ip" -v tag="$IPTABLES_COMMENT_TAG" '
        index($0, tag) {
            for (i = 1; i <= NF; i++) if ($i == ip) { print $1; exit }
        }'
}

ip_in_ban_file() {
    local ip="$1"
    [ -f "$BAN_FILE" ] || return 1
    awk -v ip="$ip" '$2 == ip { found = 1 } END { exit found ? 0 : 1 }' "$BAN_FILE"
}

ban_ip() {
    local ip="$1" count="$2" sample="$3" timestamp
    if ip_whitelisted "$ip"; then
        echo "$(date): SKIP (whitelist): $ip - $count probe paths/${LOG_WINDOW_SECONDS}s $sample" | tee -a "$BAN_LOG"
        return 0
    fi
    if [ -z "$(our_rule_number "$ip")" ]; then
        if ! sudo iptables -A "$IPTABLES_CHAIN" -s "$ip" -m comment --comment "$IPTABLES_COMMENT_TAG" -j DROP; then
            echo "$(date): Failed to block $ip - $count probe paths/${LOG_WINDOW_SECONDS}s $sample" | tee -a "$BAN_LOG"
            return 1
        fi
        echo "$(date): Blocking IP $ip - $count probe paths in ${LOG_WINDOW_SECONDS}s $sample" | tee -a "$BAN_LOG"
    fi
    if ! ip_in_ban_file "$ip"; then
        timestamp=$(date +%s)
        echo "$timestamp $ip" >> "$BAN_FILE"
    fi
}

# The ban file is the list of addresses that must stay dropped until they expire.
# A missing iptables rule is put back. The file line is not written if iptables refused it.
ensure_ban_rules() {
    local now_line ban_time ip current_time time_passed
    declare -A want=()
    [ -s "$BAN_FILE" ] || return 0
    current_time=$(date +%s)
    while IFS= read -r now_line; do
        [ -z "$now_line" ] && continue
        ban_time=$(echo "$now_line" | awk '{print $1}')
        ip=$(echo "$now_line" | awk '{print $2}')
        [[ "$ban_time" =~ ^[0-9]+$ ]] || continue
        [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
        time_passed=$((current_time - ban_time))
        [ "$time_passed" -ge "$BAN_TIME" ] && continue
        if ip_whitelisted "$ip"; then
            continue
        fi
        want["$ip"]=1
    done < "$BAN_FILE"
    for ip in "${!want[@]}"; do
        [ -n "$(our_rule_number "$ip")" ] && continue
        if sudo iptables -A "$IPTABLES_CHAIN" -s "$ip" -m comment --comment "$IPTABLES_COMMENT_TAG" -j DROP; then
            echo "$(date): Restored missing DROP for $ip" >> "$BAN_LOG"
        else
            echo "$(date): Failed to restore DROP for $ip" >> "$BAN_LOG"
        fi
    done
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

unban_own_addresses() {
    local ip rule_num now_line temp_file
    load_self_ips
    for ip in "${!SELF_IPS[@]}"; do
        while true; do
            rule_num=$(our_rule_number "$ip")
            [ -z "$rule_num" ] && break
            echo "$(date): Removing ban of this server's address $ip" >> "$UNBAN_LOG"
            sudo iptables -D "$IPTABLES_CHAIN" "$rule_num" 2>/dev/null || break
        done
    done
    [ -s "$BAN_FILE" ] || return 0
    temp_file=$(mktemp)
    while IFS= read -r now_line; do
        [ -z "$now_line" ] && continue
        ip=$(echo "$now_line" | awk '{print $2}')
        [[ -n "${SELF_IPS[$ip]:-}" ]] && continue
        echo "$now_line" >> "$temp_file"
    done < "$BAN_FILE"
    mv "$temp_file" "$BAN_FILE"
}

run_scan() {
    local count ip sample
    declare -A totals=()
    declare -A samples=()
    load_whitelist
    unban_own_addresses
    while read -r count ip sample; do
        [[ "$count" =~ ^[0-9]+$ ]] || continue
        [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
        totals["$ip"]=$(( ${totals["$ip"]:-0} + count ))
        if [ -n "$sample" ]; then
            samples["$ip"]="${samples[$ip]} $sample"
        fi
    done < <(count_probes)

    for ip in "${!totals[@]}"; do
        count="${totals[$ip]}"
        if [ "$count" -ge "$THRESHOLD_PATHS" ]; then
            ban_ip "$ip" "$count" "${samples[$ip]}"
        fi
    done
    unban_expired
    ensure_ban_rules
}

show_bans() {
    local line ban_time ip left current_time
    echo "=== scanner-probe ==="
    echo "threshold: $THRESHOLD_PATHS different probe paths in ${LOG_WINDOW_SECONDS}s, ban ${BAN_TIME}s"
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
    echo "Clearing scanner-probe bans..."
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
    local count ip sample
    echo "$(date): probe paths in the last ${LOG_WINDOW_SECONDS}s, block at ${THRESHOLD_PATHS} different paths"
    count_probes | sort -nr | while read -r count ip sample; do
        [ -n "$count" ] || continue
        if [ "$count" -ge "$THRESHOLD_PATHS" ]; then
            echo "  BLOCK $count $ip $sample"
        else
            echo "  $count $ip $sample"
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
