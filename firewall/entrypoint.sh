#!/bin/sh
set -e

# -----------------------------------------------------------------------------
# BioLab Analytics - perimeter firewall (Description.md section 6.3 /
# Plan_Maquette.txt section 11)
#
# Real, inspectable iptables rules (run `iptables -t nat -L` / `iptables -L`
# inside this container to see them). Scope, deliberately minimal:
#
#   - This container owns the ONE host-published port that lets the outside
#     world (or the attacker/hospital containers on net_external, via the
#     host) reach the SFTP server: host 2222 -> DNAT -> sftp-server:22.
#   - Everything else is DROPped in FORWARD by default -- "minimal
#     filtering" (ANSSI Regle 25): one flow explicitly allowed, nothing
#     else considered.
#
# DOCUMENTED SCOPE LIMITATION (carried over from earlier sections): the
# admin workstation and the simulated hospital/former-contractor endpoints
# are, for now, pragmatically DUAL-HOMED directly onto net_dmz (see
# terraform/workstations.tf and terraform/external.tf) so they can reach
# sftp-server without this firewall existing yet. That direct L2 path is
# NOT filtered by this container -- Docker's flat bridge networking means a
# container already attached to net_dmz reaches other net_dmz containers
# directly, with no way to force that traffic through a third container
# without a much larger networking redesign (macvlan / per-container static
# routes) that is out of scope for this mockup. This firewall genuinely
# controls the ONE path that previously had NO control at all (the
# host-published port), which is real progress, not the full perimeter the
# plan originally envisioned. Worth carrying this gap into the risk
# analysis: segmentation remains weak for anything already inside net_dmz.
# -----------------------------------------------------------------------------

sysctl -w net.ipv4.ip_forward=1

SFTP_TARGET_IP=$(getent hosts biolab-sftp-server | awk '{print $1}')
if [ -z "$SFTP_TARGET_IP" ]; then
  echo "[firewall] could not resolve sftp-server, exiting" >&2
  exit 1
fi

echo "[firewall] forwarding host:2222 -> ${SFTP_TARGET_IP}:22 (sftp-server)"

# NAT: redirect anything arriving on this container's 2222 to sftp-server:22
iptables -t nat -A PREROUTING -p tcp --dport 2222 -j DNAT --to-destination "${SFTP_TARGET_IP}:22"
iptables -t nat -A POSTROUTING -j MASQUERADE

# FORWARD policy: allow only the SFTP flow + already-established traffic,
# drop everything else. This is the real "minimal filtering" rule set.
iptables -A FORWARD -p tcp -d "${SFTP_TARGET_IP}" --dport 22 -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -j DROP

echo "[firewall] rules in place:"
iptables -t nat -L -n
iptables -L FORWARD -n

exec tail -f /dev/null
