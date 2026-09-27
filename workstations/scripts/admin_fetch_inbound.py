"""
BioLab Analytics - admin workstation: fetch inbound file (workflow step 1
completion -> step 3 handoff).

Real SFTP: connects to the sftp-server with the (shared, never-rotated) key,
downloads a file the hospital dropped in /inbound, and places it in the
/handoff volume so the bioinformatician workstation can pick it up --
labeled ONLY with the barcode (pseudonymization, see Description.md
section 2 observations).

Usage:
  python admin_fetch_inbound.py --remote-filename patient_alice.fasta --barcode BC-2026-00001
"""

import argparse
import os

import paramiko

SFTP_HOST = os.environ.get("SFTP_HOST", "sftp-server")
SFTP_PORT = int(os.environ.get("SFTP_PORT", "22"))
SFTP_USER = os.environ.get("SFTP_USER", "biolab_admin")
SFTP_KEY_PATH = os.environ.get("SFTP_KEY_PATH", "/keys/biolab_partner_key.key")
HANDOFF_DIR = os.environ.get("HANDOFF_DIR", "/handoff")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--remote-filename", required=True, help="File name as dropped by the hospital in /inbound")
    parser.add_argument("--barcode", required=True, help="Internal barcode to (re)label the file with")
    args = parser.parse_args()

    key = paramiko.RSAKey.from_private_key_file(SFTP_KEY_PATH)
    transport = paramiko.Transport((SFTP_HOST, SFTP_PORT))
    transport.connect(username=SFTP_USER, pkey=key)
    sftp = paramiko.SFTPClient.from_transport(transport)

    remote_path = f"inbound/{args.remote_filename}"
    ext = os.path.splitext(args.remote_filename)[1] or ".fasta"
    local_path = os.path.join(HANDOFF_DIR, f"{args.barcode}{ext}")

    os.makedirs(HANDOFF_DIR, exist_ok=True)
    sftp.get(remote_path, local_path)

    sftp.close()
    transport.close()

    print(f"[admin] fetched {remote_path} -> {local_path} (barcode {args.barcode})")


if __name__ == "__main__":
    main()
