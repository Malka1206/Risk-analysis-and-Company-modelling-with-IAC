# -----------------------------------------------------------------------------
# BioLab Analytics - bastion + central log server, combined
# (Description.md sections 6.2 and 6.6 / Plan_Maquette.txt sections 10 and 14)
#
# DESIGN ADJUSTMENT (documented, like similar scope decisions in earlier
# sections): the plan originally described the bastion and the log server
# as two separate boxes. In this mockup they are the SAME container --
# IT staff land here over SSH (the bastion role) and, once logged in, use
# the psql / ldap-utils clients installed below to administer patient-db
# and LDAP directly from this session (rather than hopping to a second SSH
# server, since patient-db and LDAP are not themselves SSH-reachable
# machines). The same box also runs rsyslog, receiving logs from every
# service on net_sci_admin.
#
# This is itself worth carrying into the risk analysis: compromising this
# one box gives an attacker BOTH the administrative jump point AND the
# entire log trail in one step -- a realistic, and non-trivial, weakness.
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        rsyslog openssh-server postgresql-client ldap-utils && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd /opt/keys

COPY logging/rsyslog.conf /etc/rsyslog.conf
COPY logging/sshd_config /etc/ssh/sshd_config
COPY bastion/keys/bastion_it_key.pub /opt/keys/bastion_it_key.pub
COPY logging/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 514/udp 514/tcp 22

ENTRYPOINT ["/entrypoint.sh"]
