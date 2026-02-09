#!/usr/bin/env bash
set -e

echo "[*] stopping nfqws"
pkill -TERM nfqws 2>/dev/null || true

# даём корректно выйти
sleep 1

# на случай зависшего процесса
pkill -KILL nfqws 2>/dev/null || true

echo "[*] removing nftables rules"
nft delete table inet zapret 2>/dev/null || true

echo "[*] done"
