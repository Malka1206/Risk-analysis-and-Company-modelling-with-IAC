FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd /opt/keys

COPY sshd_config /etc/ssh/sshd_config
COPY keys/biolab_partner_key.pub /opt/keys/biolab_partner_key.pub
COPY keys/former_contractor_key.pub /opt/keys/former_contractor_key.pub
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
