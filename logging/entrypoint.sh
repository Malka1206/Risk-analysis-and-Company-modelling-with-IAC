#!/bin/sh
set -e

# Real SSH admin account for IT, meant to be reached ONLY via the bastion
# (Description.md section 6.6). NOTE (documented weakness): this is a
# process/policy expectation, not a technically enforced one -- sshd here
# accepts connections from anywhere on the reachable networks, there is no
# source-IP restriction to "only the bastion". See Plan_Maquette.txt
# section 14 for the residual weakness this represents.
id -u itsys >/dev/null 2>&1 || useradd -m -s /bin/bash itsys
mkdir -p /home/itsys/.ssh
cp /opt/keys/bastion_it_key.pub /home/itsys/.ssh/authorized_keys
chown -R itsys:itsys /home/itsys/.ssh
chmod 700 /home/itsys/.ssh
chmod 600 /home/itsys/.ssh/authorized_keys

mkdir -p /var/run/sshd
touch /var/log/central.log /var/log/rsyslog-status.log

rsyslogd
exec /usr/sbin/sshd -D -e
