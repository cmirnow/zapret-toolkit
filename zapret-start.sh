#!/usr/bin/env bash
set -e

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: must be run as root"
    exit 1
fi

if pgrep -x nfqws >/dev/null; then
    echo "ERROR: nfqws is already running"
    exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
STRATEGY_FILE="$BASE_DIR/WORKING_STRATEGY.conf"

echo "[*] loading kernel modules"
modprobe nfnetlink_queue || true
modprobe nf_conntrack || true

echo "[*] applying sysctl settings"
sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=1
sysctl -w net.netfilter.nf_conntrack_checksum=0

echo "[*] configuring nftables"

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

if [[ ! -f "$STRATEGY_FILE" ]]; then
    echo "ERROR: no working strategy found"
    echo "Run zapret-autotest.sh first"
    exit 1
fi

read -r STRATEGY < "$STRATEGY_FILE"

echo "[*] starting nfqws with strategy:"
echo "    $STRATEGY"

exec "$BASE_DIR/nfq/nfqws" \
    --qnum=100 \
    $STRATEGY
