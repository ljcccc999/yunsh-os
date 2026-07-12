#!/bin/bash
# YUNSH OS v1.0.1 - Firewall Rules (iptables)
# Applies and persists security-hardened iptables rules for Raspberry Pi 5
# Idempotent: safe to run multiple times

IPTABLES_SAVE="/etc/iptables/rules.v4"
IP6TABLES_SAVE="/etc/iptables/rules.v6"

# Flush existing rules and custom chains
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F 2>/dev/null || true
iptables -t raw -X 2>/dev/null || true

# Default policies: deny incoming/forwarded, allow outgoing
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ── Loopback ──────────────────────────────────
iptables -A INPUT -i lo -j ACCEPT

# ── Established / Related connections ─────────
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ── ICMP (ping) from LAN only ─────────────────
iptables -A INPUT -p icmp --icmp-type echo-request -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -s 172.16.0.0/12 -j ACCEPT

# ── DHCP (client) ─────────────────────────────
iptables -A INPUT -p udp --sport 67 --dport 68 -j ACCEPT

# ── DNS ───────────────────────────────────────
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT

# ── SSH (port 22) from private LAN ranges ─────
iptables -A INPUT -p tcp --dport 22 -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8     -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 172.16.0.0/12  -j ACCEPT

# ── HTTP / HTTPS outbound (OUTPUT is ACCEPT, explicit rules for logging) ──
# NOTE: Outbound is already allowed by default policy.
# These rules are explicit for policy visibility.
iptables -A OUTPUT -p tcp --dport 80  -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# ── Log dropped packets (rate-limited) ────────
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "YUNSH-IPT-DROP: " --log-level 4

# ── Persist rules ─────────────────────────────
mkdir -p /etc/iptables
iptables-save > "$IPTABLES_SAVE"
ip6tables-save > "$IP6TABLES_SAVE" 2>/dev/null || true

echo "[YUNSH] Firewall rules applied and saved to $IPTABLES_SAVE"
