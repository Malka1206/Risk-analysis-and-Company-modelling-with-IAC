# BioLab Analytics Mockup — Operations Manual

This manual explains how to deploy the mockup and how to operate every
component in it. It assumes you have already read `Plan_Maquette.txt` and
`Description.md` for the rationale behind each design choice; this document
is purely practical — commands, credentials, ports, and step-by-step
procedures.

No diagrams are included by request; everything below is prose, tables, and
shell commands.

---

## 1. Prerequisites

- Docker Engine (with the Docker daemon running) on the host that will run
  `terraform apply`.
- Terraform >= 1.5.0.
- An `openssl`, `ssh`/`sftp` client, and `psql` client on your own machine
  are convenient for manual testing, but not strictly required — most
  interactions happen through `docker exec` into the mockup's own
  containers, which already carry the right client tools.
- Ports `2200`, `2222`, `5000`, `5001`, `8081`, `8082` must be free on the
  host (see section 4, "Published ports").

This environment was authored and syntax-checked without a live Docker
daemon available to the author. Run `terraform init` and
`terraform validate` yourself before `terraform apply`, and be ready to
adjust minor issues (image tags moving, provider quirks) if any turn up.

---

## 2. Repository layout

```
terraform/          All Terraform resources (*.tf files, one per component)
ldap/                LDAP bootstrap LDIF files
patient-db/           Patient database schema + seed data
pki/                  Self-signed internal CA + LIMS/MinIO server certificates
compute-node/         Compute node (Flask app)
lims/                 LIMS (Flask app + templates)
homemade-crypto/       Weak homemade encryption watcher
sftp-server/           SFTP server (image, sshd config, shared keys)
workstations/          Shared workstation image + per-role scripts
external/              External stakeholders (hospital, former contractor, attacker)
automate/              Simulated lab automation device (Modbus TCP)
bastion/               Bastion SSH key (used by the bastion+logs container)
logging/               Bastion + central log server (image, rsyslog config)
firewall/              Perimeter firewall (image, iptables rules)
sample-data/           Demo FASTA file
```

---

## 3. Deploying the mockup

```bash
cd terraform
terraform init
terraform validate
terraform apply
```

Confirm with `yes` when prompted. The apply builds ~10 local Docker images
(compute node, LIMS, SFTP server, workstation image, hospital, former
contractor, attacker, automate, bastion+logs, firewall) and starts roughly
25 containers. A first run can take a few minutes while images build and
`pip install` layers download.

Once it finishes, run:

```bash
terraform output
```

to see every connection hint documented as a Terraform output (URLs, SSH
commands, the full end-to-end workflow walkthrough). Everything in this
manual mirrors those outputs, written out in full with explanations.

### Tearing down

```bash
terraform destroy
```

This removes every container/image/network/volume Terraform created. It
does **not** delete the files under `pki/`, `ldap/`, `sftp-server/keys/`,
or `bastion/keys/` — those are source material, not managed infrastructure.

---

## 4. Access points reference

### 4.1 Published ports (host → container)

| Host port | Service | Protocol | Notes |
|---|---|---|---|
| 2200 | Bastion + log server | SSH | Key-only, user `itsys` |
| 2222 | SFTP server | SSH/SFTP | Routed through the firewall container (DNAT), key-only |
| 5000 | Compute node | HTTP | `POST /analyze` |
| 5001 | LIMS | HTTPS (self-signed) | Browser will warn unless you import `pki/ca.crt` |
| 8081 | phpLDAPAdmin | HTTP | Deliberately unrestricted |
| 8082 | Adminer | HTTP | Deliberately unrestricted, points at patient-db |

MinIO (9000 API / 9001 console) and the patient database (5432) are **not**
published to the host — they are only reachable from inside
`net-sci-admin`, i.e. from other containers on that network (workstations,
LIMS, compute node) or via the bastion.

### 4.2 Container names

All container names are prefixed with the project name (`biolab` by
default, see `terraform/variables.tf`'s `project_name`). Full list:

```
biolab-ldap                          biolab-phpldapadmin
biolab-patient-db                    biolab-minio                biolab-minio-init
biolab-compute-node                  biolab-lims
biolab-sftp-server                   biolab-homemade-crypto
biolab-ws-admin  biolab-ws-bioinfo   biolab-ws-technicien  biolab-ws-biologiste  biolab-ws-it
biolab-ext-hopital-saint-martin      biolab-ext-former-contractor  biolab-ext-attacker
biolab-ext-clinique-du-parc          biolab-ext-centre-recherche   biolab-ext-pharma-corp
biolab-automate                      biolab-bastion-logs           biolab-firewall
biolab-adminer
```

### 4.3 Credentials reference

All of these are **deliberately weak**, per the validated risk-mockup plan.
Never reuse them anywhere real.

**LDAP accounts** (bind DN: `uid=<uid>,ou=people,dc=biolab-analytics,dc=local`):

| uid | password | role (app_users) |
|---|---|---|
| biologiste1 | `Bio2024!` | biologiste |
| bioinfo1 | `Genome99` | bioinformaticien |
| technicien1 | `Labo1234` | technicien |
| admin1 | `Accueil2023` | administratif |
| it1 | `Support01` | it |

LDAP admin (`cn=admin,dc=biolab-analytics,dc=local`): `admin`. LDAP config
password: `config`. Anonymous bind is disabled — every connection needs one
of the accounts above.

**Patient database**: host `patient-db`, db `patient_db`, user `biolab_app`,
password `biolab_app_pwd`.

**MinIO**: access key `minioadmin`, secret key `minioadmin123`. Endpoint
from inside the network: `https://minio:9000` (self-signed, see section 6).

**SSH/SFTP keys** (all under `.key` extensions, gitignored, but present in
this deliverable):

| Key file | Used by | Purpose |
|---|---|---|
| `sftp-server/keys/biolab_partner_key.key` | `biolab_admin` and `hopital_saint_martin` accounts | Shared/unrotated partner key |
| `sftp-server/keys/former_contractor_key.key` | Also authorized as `biolab_admin` | Residual, never-revoked access |
| `bastion/keys/bastion_it_key.key` | `itsys` on the bastion | IT admin access |

**PKI**: `pki/ca.crt` is BioLab's internal self-signed root CA. Import it
into your browser/OS trust store if you don't want certificate warnings
when opening `https://localhost:5001`.

---

## 5. End-to-end workflow walkthrough

This reproduces the full business workflow (hospital submission → analysis
→ delivery) documented in `Plan_Maquette.txt` section 0, using the actual
running containers. Replace `<BARCODE>` with whatever `admin_intake.py`
prints out in step 1.

### Step 1 — Administrative intake

```bash
docker exec -it biolab-ws-admin python admin_intake.py \
  --last-name Durand --first-name Alice --dob 1985-03-12 \
  --hospital "Hopital Saint-Martin" --test-type sequencage_adn
```

This creates the patient (if new), a medical record with status
`received`, a `pending` invoice, and prints a barcode such as
`BC-2026-A1B2C3D4`. Keep it — every following command needs it.

### Step 2 — Hospital submits the genetic sample (real SFTP)

```bash
docker exec -it biolab-ext-hopital-saint-martin \
  python hospital_submit_sample.py \
  --local-file /samples/demo_sample_BC-2026-00002.fasta \
  --remote-filename patient_alice.fasta
```

The admin workstation then retrieves it, over the same real SFTP channel,
and labels it with the barcode (pseudonymization: the file itself never
carries the patient's name):

```bash
docker exec -it biolab-ws-admin python admin_fetch_inbound.py \
  --remote-filename patient_alice.fasta --barcode <BARCODE>
```

### Step 3 — Bioinformatician submits the file for analysis

```bash
docker exec -it biolab-ws-bioinfo python bioinfo_submit_analysis.py --barcode <BARCODE>
```

This calls the compute node's `/analyze` endpoint. The compute node
computes sequence length, GC content, and a mock variant count, then
automatically uploads the raw JSON result to MinIO under the same barcode.
The medical record's status becomes `in_analysis`.

### Step 4 — Technician assigns the result

Open `https://localhost:5001/assign` in a browser (accept or import the
self-signed certificate) and log in as `technicien1` / `Labo1234`. Enter
the barcode. The LIMS confirms the raw result exists in storage and links
it to the medical record (status becomes `assigned`).

### Step 5 — Biologist validates the result

Open `https://localhost:5001/validate`, log in as `biologiste1` /
`Bio2024!`, and validate the pending result for that barcode. Status
becomes `validated`. Note the on-screen reminder: no hash/signature check
is performed here against what the technician originally assigned — this
is a deliberate, documented gap.

### Step 6 — Admin prepares delivery

```bash
docker exec -it biolab-ws-admin python admin_prepare_delivery.py --barcode <BARCODE>
```

This refuses to run unless the record is `validated`. It downloads the raw
result from MinIO and uploads it (real SFTP) into the `to_encrypt/` folder
on the SFTP server. Status becomes `encrypted` (see the script's docstring
for why this is set optimistically rather than via a callback).

Within a few seconds, the `homemade-crypto` watcher (running continuously
in the background — nothing to trigger manually) notices the new file,
encrypts it with the weak static-XOR cipher, and drops
`<BARCODE>.json.enc` into `outbound/`.

### Step 7 — Admin confirms delivery

```bash
docker exec -it biolab-ws-admin python admin_confirm_delivery.py --barcode <BARCODE>
```

Checks (over SFTP) that the encrypted file exists in `outbound/`. If it
does, the record becomes `delivered` and the invoice becomes `sent`. If you
get a "not found yet" error, wait a couple of seconds for the watcher and
retry.

### Step 8 — Hospital retrieves its result

```bash
docker exec -it biolab-ext-hopital-saint-martin \
  python hospital_fetch_result.py --barcode <BARCODE>
```

The hospital only ever receives the **encrypted** file — it has no
decryption capability of its own in this mockup, which is itself worth
noting for the eventual risk analysis.

---

## 6. Component-by-component operations reference

### 6.1 LDAP / IAM

- Console: `http://localhost:8081` (phpLDAPAdmin, no restriction).
- Login DN for the console: `cn=admin,dc=biolab-analytics,dc=local` /
  `admin`.
- Command-line, from the bastion or any workstation with `ldap-utils`:
  ```bash
  ldapsearch -x -H ldap://ldap -D "uid=it1,ou=people,dc=biolab-analytics,dc=local" \
    -w Support01 -b "dc=biolab-analytics,dc=local"
  ```
- Anonymous bind is disabled (`ldap/bootstrap/02-disable-anonymous-bind.ldif`):
  every query needs one of the 5 accounts, or the admin DN.

### 6.2 Patient database

From the bastion (recommended) or any container with `psql`:

```bash
psql -h patient-db -U biolab_app -d patient_db
```

Password `biolab_app_pwd` (or set `PGPASSWORD` first). Useful queries:

```sql
SELECT barcode, status FROM medical_records ORDER BY created_at DESC;
SELECT * FROM invoices WHERE payment_status = 'pending';
SELECT * FROM results WHERE validation_date IS NULL;  -- awaiting the biologist
```

Or, via Adminer (`http://localhost:8082`): system PostgreSQL, server
`patient-db`, username `biolab_app`, password `biolab_app_pwd`, database
`patient_db`.

### 6.3 MinIO (raw results storage)

Not published to the host. From inside the network (e.g. from
`biolab-ws-admin` or any container with the AWS CLI/boto3):

```python
import boto3
from botocore.client import Config
client = boto3.client("s3", endpoint_url="https://minio:9000",
                       aws_access_key_id="minioadmin",
                       aws_secret_access_key="minioadmin123",
                       config=Config(signature_version="s3v4"),
                       verify=False)  # self-signed cert, deliberately unverified here
print(client.list_objects_v2(Bucket="raw-results"))
```

### 6.4 Compute node

```bash
curl -F barcode=TEST-0001 -F file=@sample-data/demo_sample_BC-2026-00002.fasta \
  http://localhost:5000/analyze
```

The compute node itself serves plain HTTP on port 5000 (only its outbound
connection to MinIO uses HTTPS, with verification deliberately disabled —
see section 6.3 and `compute-node/app.py`). In normal operation you don't
call this directly — the bioinformatician workstation script does it for
you (section 5, step 3).

### 6.5 LIMS

Web UI at `https://localhost:5001`. Two protected screens:
`/assign` (role `technicien`), `/validate` (role `biologiste`), both
requiring LDAP login. Role is looked up from `patient-db.app_users` after
a successful LDAP bind — see `lims/app.py` for the exact logic and its
documented limitations (role separation is app-level only).

### 6.6 Homemade encryption watcher

No manual interaction — it polls `to_encrypt/` on the shared `exchange`
Docker volume every few seconds and encrypts anything it finds. To watch
it work in real time:

```bash
docker logs -f biolab-homemade-crypto
```

### 6.7 SFTP server

Reachable on host port 2222 (through the firewall, see section 6.11).
Both accounts (`biolab_admin`, `hopital_saint_martin`) use the same shared
key:

```bash
sftp -i sftp-server/keys/biolab_partner_key.key -P 2222 biolab_admin@localhost
sftp -i sftp-server/keys/biolab_partner_key.key -P 2222 hopital_saint_martin@localhost
```

Once connected, each account is chrooted into `/` (mapped to the shared
`exchange` volume) and can `ls`, `get`, `put` within the folders their
Unix permissions allow (`inbound/`, `outbound/`, and — for `biolab_admin`
only — `to_encrypt/`).

### 6.8 Workstations

Every workstation is `docker exec`-able directly; each proves its LDAP
identity at container startup (check with `docker logs biolab-ws-<role>`).
Available scripts per role:

- `biolab-ws-admin`: `admin_intake.py`, `admin_fetch_inbound.py`,
  `admin_prepare_delivery.py`, `admin_confirm_delivery.py`.
- `biolab-ws-bioinfo`: `bioinfo_submit_analysis.py`.
- `biolab-ws-technicien` / `biolab-ws-biologiste`: no CLI script beyond
  `ldap_login_test.py` — use the LIMS web UI. You can also run
  `lims_https_check.py` from either to demonstrate real certificate
  verification against BioLab's internal CA.
- `biolab-ws-it`: `modbus_demo.py` (see section 6.9).
- Every workstation: `python ldap_login_test.py` re-runs the login check
  manually if you want to see it again.

### 6.9 Lab automation device (Modbus)

No credentials of any kind — that's the point. Demonstrate it from any
workstation on `net-sci-admin` (the workstation image ships `pymodbus`):

```bash
docker exec -it biolab-ws-it python modbus_demo.py --read
docker exec -it biolab-ws-it python modbus_demo.py --write-status 2
```

The second command changes the simulated machine's status register with
zero authentication.

### 6.10 Bastion + central log server

```bash
ssh -i bastion/keys/bastion_it_key.key -p 2200 itsys@localhost
```

From that session:

```bash
psql -h patient-db -U biolab_app -d patient_db
ldapsearch -x -H ldap://ldap -D "uid=it1,ou=people,dc=biolab-analytics,dc=local" -w Support01 -b "dc=biolab-analytics,dc=local"
tail -f /var/log/central.log        # every service's forwarded logs, one flat file
tail -f /var/log/rsyslog-status.log
```

### 6.11 Perimeter firewall

Owns host port 2222 and forwards it to the SFTP server via real `iptables`
DNAT rules. Inspect the live rules:

```bash
docker exec -it biolab-firewall iptables -t nat -L -n
docker exec -it biolab-firewall iptables -L FORWARD -n
```

Remember the documented scope limitation: this controls the host-facing
path only. The admin workstation and the hospital/former-contractor
containers reach the SFTP server directly over `net-dmz` (they are
dual-homed there), bypassing this firewall entirely — see
`firewall/entrypoint.sh` for the full explanation.

### 6.12 External stakeholders

- Hospital (`biolab-ext-hopital-saint-martin`): see section 5, steps 2 and
  8.
- Former contractor (`biolab-ext-former-contractor`):
  ```bash
  docker exec -it biolab-ext-former-contractor python residual_access_demo.py
  ```
  Connects as `biolab_admin` using a key that was supposed to have been
  revoked years ago, and lists the shared exchange directory to prove the
  access still works.
- Generic attacker (`biolab-ext-attacker`): ships `nmap`, `curl`, an SSH
  client, `dig`, `ping` — nothing pre-loaded beyond common recon tooling.
  It sits on `net-external` only (not `net-dmz`), so, unlike the hospital,
  it cannot reach the SFTP server directly inside the Docker network; it
  can only attempt the same host-facing port (2222) anyone on the internet
  could reach, e.g.:
  ```bash
  docker exec -it biolab-ext-attacker nmap -p 2222 host.docker.internal
  ```
  (exact reachability of `host.docker.internal` depends on your Docker
  setup — verify locally).
- Clinic / research center / pharma placeholders
  (`biolab-ext-clinique-du-parc`, `biolab-ext-centre-recherche`,
  `biolab-ext-pharma-corp`): idle containers, no flow implemented, present
  only for stakeholder-mapping completeness in the risk analysis.

### 6.13 Adminer (billing)

`http://localhost:8082` — System: PostgreSQL, Server: `patient-db`,
Username: `biolab_app`, Password: `biolab_app_pwd`, Database: `patient_db`.
No authentication in front of Adminer itself: anyone who can reach port
8082 gets to this login form.

---

## 7. Troubleshooting

- **`admin_confirm_delivery.py` says the file isn't in `outbound/` yet**:
  the homemade-crypto watcher polls every few seconds
  (`POLL_INTERVAL_SECONDS`, default 3). Wait and retry.
- **LDAP bind failures at workstation startup**: check
  `docker logs biolab-ws-<role>` — a failed bind exits non-zero and prints
  the LDAP error; confirm the LDAP container is healthy
  (`docker logs biolab-ldap`).
- **Browser refuses `https://localhost:5001`**: expected — it's a
  self-signed certificate. Either accept the browser warning or import
  `pki/ca.crt` as a trusted root.
- **`terraform apply` fails building an image**: most likely a transient
  `pip install` / `apt-get` network hiccup during the Docker build: rerun
  `terraform apply`.
- **Static IP conflicts** (`10.10.1.10` / `10.10.2.10` already assigned):
  these are hardcoded via `log_server_ip_sci_admin` /
  `log_server_ip_it` in `terraform/variables.tf`; change them there (and
  nowhere else) if they collide with something on your machine.

---

## 8. Regenerating secrets (optional)

- **PKI**: `pki/generate-pki.sh` regenerates the CA and both server
  certificates from scratch. Re-running it invalidates any certificate
  pinned elsewhere until you re-`apply`.
- **SFTP / bastion keys**: regenerate with `ssh-keygen -t rsa -b 2048 -f
  <name> -N ""`, then update the corresponding `authorized_keys` logic in
  `sftp-server/entrypoint.sh` / `logging/entrypoint.sh` and the matching
  `host_path` references in `terraform/*.tf`.

Regenerating any of these is *not* required to run the mockup — it is only
useful if you want to demonstrate what proper key/certificate rotation
would look like, in contrast with the "never rotated" weaknesses the
mockup deliberately reproduces.
