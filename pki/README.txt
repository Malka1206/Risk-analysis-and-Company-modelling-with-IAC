Internal ("homemade") PKI - Description.md section 6.4 / Plan_Maquette.txt
section 12.

- `ca.crt` / `ca.key` : the internal root CA. Generated ONCE, offline, with
  a simple `openssl req -x509 ...` command -- exactly the "ad hoc, not a
  real enterprise PKI" weakness the plan describes. `ca.key` is named with
  a `.key` extension on purpose (excluded by the project's `.gitignore`).

- `lims.crt` / `lims.key` : server certificate for the LIMS, signed by the
  CA above. The LIMS now serves HTTPS with this cert (see lims/app.py and
  terraform/lims.tf).

- `minio.crt` / `minio.key` : server certificate for MinIO, signed by the
  same CA. MinIO now serves HTTPS with this cert.

Deliberate weaknesses (kept exactly as validated in the plan):
  - Certificate verification is REAL and enforced on at least one flow:
    workstation scripts that talk to the LIMS (see
    workstations/scripts/lims_https_check.py) pass `verify=pki/ca.crt` and
    will genuinely reject a bad/self-signed-by-someone-else certificate.
  - Certificate verification is DELIBERATELY DISABLED on the compute-node
    -> MinIO flow and the LIMS -> MinIO flow (`verify=False` in
    compute-node/app.py and lims/app.py), even though MinIO now serves a
    real cert signed by the same CA. This is the documented "inconsistent
    internal PKI" weakness: some code paths check, some don't, and there is
    no single enforced policy.
  - There is only ONE ad hoc CA for the whole company, created by hand,
    with no separate intermediate CA, no revocation mechanism (no CRL/OCSP),
    and both server keys living in the same repo folder as the CA key
    itself.
