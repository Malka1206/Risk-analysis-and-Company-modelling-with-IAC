# BioLab Analytics — Mockup Description 

> Living document. v4 reflects the actual Terraform/Docker implementation
> `OPERATIONS_MANUAL.md` for hands-on commands, credentials, and the full
> end-to-end walkthrough.

## 1. Purpose

This document describes, component by component, the vulnerable-but-functional
mockup of **BioLab Analytics** as it now actually exists.

---

## 2. Reference Business Workflow (unchanged, now provably executable)

The 10-step workflow (hospital intake → analysis →
assignment → medical validation → encryption → delivery → closure) is now
executable end-to-end — see `OPERATIONS_MANUAL.md` section 5 for the exact
sequence. No step relies on manual filesystem manipulation from the host;
everything goes through either a workstation script (real SFTP/HTTP/DB calls) 
or the LIMS web UI.

---

## 3. Network segmentation (as built)

- **net-sci-admin** (10.10.1.0/24): compute node, MinIO, LIMS, patient-db,
  the automation device, the homemade-crypto watcher, all 5 workstations,
  Adminer.
- **net-it** (10.10.2.0/24): LDAP, phpLDAPAdmin, the bastion+log server
  (static IP 10.10.2.10 here).
- **net-dmz** (10.10.3.0/24): SFTP server, firewall.
- **net-external** (10.10.4.0/24): hospital, former contractor, attacker,
  clinic/research-center/pharma placeholders.

**Documented adjustment**: LDAP and the bastion+log server are dual-homed
(net-it + net-sci-admin, static IP 10.10.1.10 on the latter) because many
services need to reach them for authentication/logging. The admin
workstation, the hospital, and the former contractor are **also**
dual-homed directly onto net-dmz, pending a deeper network redesign —
consequence: that traffic does **not** pass through the firewall (section
13 covers exactly what the firewall does control).

---

## 4. LDAP / IAM 

OpenLDAP + phpLDAPAdmin (port 8081). 5 real accounts, each
with its **own, distinct, weak** password, all still in one flat
"employees" group as validated. Anonymous bind is **genuinely disabled**: 
every connection must authenticate. Every workstation performs an LDAP 
bind on container startup.

---

## 5. Compute node + storage 

**Compute node**: Flask app (port 5000, plain HTTP), parses a FASTA
file, computes sequence length / GC content / a deterministic mock variant
count, automatically pushes the JSON result to MinIO (bucket
`raw-results`) under the same barcode.

**Storage**: MinIO, now served over HTTPS with the self-signed certificate
issued by the internal CA (section 12). The compute node's client
deliberately connects **without verifying** that certificate
(`verify=False`, hardcoded)

---

## 6. LIMS 

Flask app served over HTTPS (port 5001, self-signed cert verifiable via
`pki/ca.crt`). Writes **directly** into patient-db. Two LDAP-authenticated 
screens: `/assign` (role `technicien`) and `/validate` (role `biologiste`). 
Role separation is enforced **only** via the `patient-db.app_users` application
table — LDAP itself distinguishes nothing (flat group) — a deliberate, validated
weakness. No hash/signature ties assignment to validation; the validation
screen itself displays this as an explicit reminder.

---

## 7. Homemade encryption + SFTP (bidirectional)

**Homemade encryption**: standalone container, continuously watching a
shared Docker volume (`exchange`), encrypting (static XOR key, hardcoded,
no IV/salt) anything dropped in `to_encrypt/`, writing the result to
`outbound/`. XOR being involutive, encryption and decryption are the exact
same operation — a strong point to demonstrate later in the risk report.

**SFTP server**: a purpose-built image (not an off-the-shelf one), sshd
configured with per-user chroot, **key-only authentication**. Genuinely
**bidirectional**: `inbound/` (hospital writes, admin reads via shared Unix
group) and `outbound/` (admin/watcher write, hospital reads). Real fixed
UID/GID permissions, consistent across the SFTP server and watcher images.

**Major, actually-coded weakness**: both the `biolab_admin` and
`hopital_saint_martin` accounts authenticate with the **same** SSH keypair,
generated once and never rotated. On top of that, a **second** key —
belonging to a former external contractor who used to maintain the
homemade-encryption tool — was added to `biolab_admin`'s authorized_keys
and never removed: a genuinely exploitable residual access path (section
9, "former contractor").

---

## 8. User workstations (5 roles)

A **single** shared Docker image ("standard corporate workstation"),
differentiated only by the injected LDAP identity and mounted volumes.
Every workstation performs a LDAP bind at startup (fails loudly on
bad credentials — no anonymous fallback exists anywhere).

- **Admin workstation**: 4 scripts using actual SFTP (paramiko) —
  intake (patient/record/invoice creation), inbound retrieval, delivery
  prep (refuses unless the record is medically validated), delivery
  confirmation.
- **Bioinformatician workstation**: submission to the compute node
  from the `handoff` volume shared with the admin workstation.
- **Technician / biologist workstations**: prove LDAP authentication;
  business interaction happens through the LIMS web UI.
- **IT workstation**: ships the Modbus demonstration script (section 9).

---

## 9. Lab automation device 

Modbus TCP server (pymodbus), simulated registers (sample count,
temperature, machine status, door sensor) that evolve continuously via a
background simulation thread. **No authentication whatsoever** (Modbus TCP
has none by protocol design), placed on the flat net-sci-admin network. A
ready-made demo script proves both read AND write access with zero
credentials, runnable from any workstation on that network.

---

## 10. External stakeholders 

- **Partner hospital**: full, bidirectional SFTP flow (same scripts
  pattern as the admin workstation, same shared key — documented
  weakness: BioLab cannot revoke the hospital's access without also
  breaking its own admin access).
- **Former developer / external contractor**: dedicated container that
  genuinely connects to the SFTP server *as* `biolab_admin`, using a key
  that was never revoked after the engagement ended. Its demo script lists
  what's reachable and explicitly states the privileges obtained.
- **Generic attacker**: minimal container (nmap, curl, an SSH client, dig),
  deliberately isolated on net-external only (not attached to net-dmz), so
  the firewall (section 13) has a real perimeter to demonstrate, unlike
  the pragmatically-attached hospital/admin.
- **Clinic / research center / pharma company**: lightweight placeholders
  (idle Alpine containers).

---

## 11. Patient database + billing 

Postgres, full schema (patients, hospitals, medical_records, results,
invoices, app_users). Record status lifecycle matches the workflow
(`received → in_analysis → assigned → validated → encrypted → delivered`).
Billing genuinely tracked (`pending → sent`), reachable/editable via
**Adminer**, published with **no restriction** on the internal network
(port 8082) — an additional deliberate weakness.

---

## 12. Logging 

Docker's native `syslog` log driver genuinely forwards logs from LDAP,
phpLDAPAdmin, patient-db, MinIO, the compute node, LIMS, the
homemade-crypto watcher, and all 5 workstations to the central log server,
over **unencrypted, unauthenticated UDP/514**. A static IP
(10.10.1.10) is used because Docker's syslog driver resolves addresses in
the daemon's own network context, where container hostnames don't
reliably resolve. Single flat log file, no correlation or alerting — the
basis for a future SIEM recommendation in the risk report (not implemented
here).

**Documented gap**: the SFTP server (DMZ) and every external stakeholder
do **not** forward logs here — there is no established network route to
the log server from those segments. This blind spot is left in place
deliberately, to be called out in the risk analysis rather than quietly
patched.

---

## 13. Bastion + log server (MERGED)

**Documented adjustment**: the plan originally described two separate
boxes. In the implementation they are the **same container** — since
patient-db and LDAP are not themselves SSH-reachable machines, "hopping"
via SSH from a bastion to a second SSH server made no sense here; instead,
the bastion is an SSH landing point (dedicated key, host port 2200)
equipped with admin CLI tools (`psql`, `ldap-utils`) to act on those
services directly from that session. Worth flagging for the risk report:
compromising this one box yields both the administrative foothold **and**
the entire audit trail at once.

---

## 14. PKI / certificates (SELF-SIGNED — important point, validated)

A **self-signed** internal certificate authority ("BioLab
Analytics Internal CA") was generated (a reproducible script is included),
which in turn signs two real server certificates: LIMS and MinIO. This is
**not** a managed enterprise PKI — no intermediate CA, no CRL/OCSP, the CA
key sits in the same folder as the server keys. **Real verification** happens on the
technician/biologist → LIMS flow (a demo script proves it against the
CA bundle); verification is **deliberately disabled** on the compute node
→ MinIO flow.

---

## 15. Firewall (intentionally scoped perimeter)

A dedicated container, `NET_ADMIN` capability, IP forwarding enabled, inspectable `iptables` rules (`iptables -L`). It now owns the
host-published port 2222 and DNATs it to the SFTP server; everything else
is dropped by default — "minimal filtering" implemented
literally. **Documented, accepted limitation**: because the admin
workstation and the hospital are already directly attached to net-dmz
(section 3), their traffic does **not** transit through this firewall —
Docker does not automatically route traffic between containers on the
same network through a third party without a heavier network redesign
(macvlan, static routes), judged out of reasonable scope here.

---

