#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
NFQWS="$BASE_DIR/nfq/nfqws"
STRATEGIES="$BASE_DIR/strategies.txt"
RESULT="$BASE_DIR/WORKING_STRATEGY.conf"

echo "[*] preparing system (kernel + nftables)"

modprobe nfnetlink_queue || true
modprobe nf_conntrack || true

sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=1
sysctl -w net.netfilter.nf_conntrack_checksum=0

nft list table inet zapret >/dev/null 2>&1 || \
nft add table inet zapret

nft list chain inet zapret output >/dev/null 2>&1 || \
nft add chain inet zapret output '{ type filter hook output priority 0; }'

nft list chain inet zapret output | grep -q "queue num 100" || \
nft add rule inet zapret output \
    meta mark and 0x40000000 == 0 \
    tcp dport { 80, 443 } \
    ct original packets 1-6 \
    queue num 100 bypass

echo "[*] starting autotest"

while IFS= read -r strategy; do
    [[ -z "$strategy" || "$strategy" =~ ^# ]] && continue

    echo "[*] testing: $strategy"

    timeout 12 sudo "$NFQWS" --qnum=100 $strategy &
    PID=$!

    sleep 2

    if curl -4 --tlsv1.2 -s --connect-timeout 5 https://rutracker.org >/dev/null; then
        echo "[+] WORKING strategy found"
        echo "$strategy" > "$RESULT"

        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
        fi

        exit 0
    fi

    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
    fi

    sleep 1
done < "$STRATEGIES"

echo "[-] no working strategy found"
exit 1
