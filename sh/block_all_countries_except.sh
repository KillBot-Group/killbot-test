#!/bin/bash
set -e

CONFIG="/opt/killbot/f2b/block_all_countries_except.config"
IPSET_NAME="country-whitelist"
CACHE_ROOT="/var/cache/killbot/ipdeny"
TODAY="$(date +%Y-%m-%d)"
TODAY_DIR="$CACHE_ROOT/$TODAY"

mkdir -p "$TODAY_DIR"

source "$CONFIG"

echo "[*] Countries: $COUNTRIES"
echo "[*] Ports: $PORTS"

apt install -y ipset iptables wget >/dev/null

ipset destroy "$IPSET_NAME" 2>/dev/null || true
ipset create "$IPSET_NAME" hash:net

IFS=',' read -ra COUNTRY_LIST <<< "$COUNTRIES"

for COUNTRY in "${COUNTRY_LIST[@]}"; do
    COUNTRY="$(echo "$COUNTRY" | tr '[:upper:]' '[:lower:]' | xargs)"
    ZONE_FILE="$TODAY_DIR/$COUNTRY.zone"

    if [ -s "$ZONE_FILE" ]; then
        echo "[*] Use cached $COUNTRY ($TODAY)"
    else
        echo "[*] Download $COUNTRY"
        TMP_ZONE="$(mktemp)"
        wget -q -O "$TMP_ZONE" "http://www.ipdeny.com/ipblocks/data/countries/$COUNTRY.zone"
        mv "$TMP_ZONE" "$ZONE_FILE"
    fi

    while read -r NET; do
        [ -n "$NET" ] && ipset add "$IPSET_NAME" "$NET" 2>/dev/null || true
    done < "$ZONE_FILE"
done

echo "[*] Total networks loaded:"
ipset list "$IPSET_NAME" | grep "Number of entries"

# ---- IPTABLES ----

# Remove old rules
iptables -D INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p tcp -m multiport --dports "$PORTS" -m set --match-set "$IPSET_NAME" src -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p tcp -m multiport --dports "$PORTS" -j DROP 2>/dev/null || true

# Add in the correct order
iptables -I INPUT 1 -p tcp -m multiport --dports "$PORTS" -j DROP
iptables -I INPUT 1 -p tcp -m multiport --dports "$PORTS" -m set --match-set "$IPSET_NAME" src -j ACCEPT
iptables -I INPUT 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "[OK] Firewall rules applied"
iptables -L INPUT -n -v --line-numbers | head -n 20