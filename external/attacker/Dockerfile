# -----------------------------------------------------------------------------
# Generic attacker node (Description.md section 6 / Plan_Maquette.txt
# section 15). Deliberately minimal: this is a narrative anchor for the
# EBIOS-RM risk analysis ("a threat actor on the internet"), not a
# pre-loaded exploitation toolkit. It ships only common, legitimate network
# diagnostic tools (nmap, curl, netcat, an SSH client) -- exactly what any
# admin or attacker alike might already have.
#
# By design (see terraform/external.tf), this container is attached ONLY to
# net_external, not to net_dmz: unlike the hospital / admin workstation,
# which are pragmatically dual-homed onto the DMZ for now (documented
# elsewhere as a placeholder pending firewall.tf), the attacker is meant to
# be stopped at the perimeter -- so that a later firewall section has
# something meaningful to demonstrate blocking (or failing to block).
# -----------------------------------------------------------------------------

FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nmap \
        curl \
        netcat-traditional \
        openssh-client \
        dnsutils \
        iputils-ping && \
    rm -rf /var/lib/apt/lists/*

CMD ["tail", "-f", "/dev/null"]
