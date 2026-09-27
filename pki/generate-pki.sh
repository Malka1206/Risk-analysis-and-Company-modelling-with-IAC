#!/bin/sh
# -----------------------------------------------------------------------------
# BioLab Analytics - internal PKI generation (Description.md section 6.4)
#
# Generates a SELF-SIGNED internal root CA ("BioLab Analytics Internal CA"),
# then issues (CA-signed) server certificates for LIMS and MinIO. Flat
# layout on purpose: terraform/lims.tf, terraform/storage.tf and
# terraform/workstations.tf all bind-mount these files directly as
# pki/ca.crt, pki/lims.crt, pki/lims.key, pki/minio.crt, pki/minio.key.
#
# This is the "homemade" internal PKI described in the plan: real
# certificates, a real signature by a real (if self-signed) root, but NOT a
# managed/audited enterprise PKI -- one ad hoc CA, no intermediate, no
# revocation (no CRL/OCSP), server keys sitting in the same folder as the
# CA key. Already run once to produce the committed files; re-run only to
# regenerate/rotate everything from scratch.
# -----------------------------------------------------------------------------
set -e

cd "$(dirname "$0")"

# --- Root CA (self-signed) --------------------------------------------------

openssl genrsa -out ca.key 4096

openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -out ca.crt \
  -subj "/C=FR/O=BioLab Analytics/OU=IT/CN=BioLab Analytics Internal CA"

# --- LIMS server certificate -------------------------------------------------

openssl genrsa -out lims.key 2048
openssl req -new -key lims.key -out lims.csr -subj "/C=FR/O=BioLab Analytics/OU=IT/CN=lims"

cat > lims.ext <<EOF
subjectAltName = DNS:biolab-lims, DNS:lims, DNS:localhost, IP:127.0.0.1
EOF

openssl x509 -req -in lims.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out lims.crt -days 825 -sha256 -extfile lims.ext

rm -f lims.csr lims.ext

# --- MinIO server certificate -------------------------------------------------

openssl genrsa -out minio.key 2048
openssl req -new -key minio.key -out minio.csr -subj "/C=FR/O=BioLab Analytics/OU=IT/CN=minio"

cat > minio.ext <<EOF
subjectAltName = DNS:biolab-minio, DNS:minio, DNS:localhost, IP:127.0.0.1
EOF

openssl x509 -req -in minio.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out minio.crt -days 825 -sha256 -extfile minio.ext

rm -f minio.csr minio.ext ca.srl

echo "PKI generated: ca.crt (+ca.key), lims.crt/.key, minio.crt/.key"
