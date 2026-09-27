#!/bin/sh
set -e

# -----------------------------------------------------------------------------
# Provisions, on every start, the two SFTP accounts and the shared exchange
# directory layout under /data (a mounted volume, shared with the
# homemade-crypto watcher container).
#
# Fixed numeric IDs (must match homemade-crypto's Dockerfile so the watcher
# container, running as 1001:2000, can write into /data/outbound):
#   group biolab-svc         gid 2000
#   user  biolab_admin       uid 1001
#   user  hopital_saint_martin uid 1002
# -----------------------------------------------------------------------------

groupadd -g 2000 biolab-svc 2>/dev/null || true

id -u biolab_admin >/dev/null 2>&1 || \
  useradd -u 1001 -g biolab-svc -d /home/biolab_admin -s /usr/sbin/nologin -m biolab_admin

id -u hopital_saint_martin >/dev/null 2>&1 || \
  useradd -u 1002 -g biolab-svc -d /home/hopital_saint_martin -s /usr/sbin/nologin -m hopital_saint_martin

# Deliberate weakness: both accounts trust the SAME static, never-rotated
# public key (see keys/biolab_partner_key.pub / .key).
for user in biolab_admin hopital_saint_martin; do
  home_dir="/home/${user}"
  mkdir -p "${home_dir}/.ssh"
  cp /opt/keys/biolab_partner_key.pub "${home_dir}/.ssh/authorized_keys"
  chown -R "${user}:biolab-svc" "${home_dir}/.ssh"
  chmod 700 "${home_dir}/.ssh"
  chmod 600 "${home_dir}/.ssh/authorized_keys"
done

# Deliberate weakness (Description.md section 6 - "Former developer /
# external contractor"): a residual key, belonging to a contractor whose
# engagement ended long ago, was never removed from biolab_admin's
# authorized_keys. It is appended here so it keeps working release after
# release -- exactly like a real forgotten entry would.
cat /opt/keys/former_contractor_key.pub >> /home/biolab_admin/.ssh/authorized_keys

# Shared exchange directory (also mounted into homemade-crypto at /exchange).
# ChrootDirectory requires /data itself to be root-owned and not
# group/world-writable.
mkdir -p /data/to_encrypt /data/inbound /data/outbound
chown root:root /data
chmod 755 /data

# hospital drops incoming genetic files here (workflow step 1); admin reads.
chown hopital_saint_martin:biolab-svc /data/inbound
chmod 770 /data/inbound

# admin/crypto watcher drop the encrypted result here (workflow step 9);
# hospital reads.
chown biolab_admin:biolab-svc /data/outbound
chmod 770 /data/outbound

# internal staging area for validated-but-not-yet-encrypted files
# (workflow step 7). Not shared with the hospital account.
chown biolab_admin:biolab-svc /data/to_encrypt
chmod 700 /data/to_encrypt

mkdir -p /var/run/sshd
exec /usr/sbin/sshd -D -e
