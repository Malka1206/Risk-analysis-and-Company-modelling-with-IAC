"""
External stakeholder - partner hospital (Description.md section 6).

Real SFTP client. Uses the SAME shared/never-rotated key as BioLab's own
admin workstation (see sftp-server/keys/README.txt) -- this is the
documented weakness, not a shortcut: from BioLab's side, connections from
"biolab_admin" and from "hopital_saint_martin" are cryptographically backed
by the identical key material.

Usage:
  python hospital_submit_sample.py --local-file /samples/demo.fasta --remote-filename patient_alice.fasta
"""

import argparse
import os

import paramiko

SFTP_HOST = os.environ.get("SFTP_HOST", "sftp-server")
SFTP_PORT = int(os.environ.get("SFTP_PORT", "22"))
SFTP_USER = os.environ.get("SFTP_USER", "hopital_saint_martin")
SFTP_KEY_PATH = os.environ.get("SFTP_KEY_PATH", "/keys/biolab_partner_key.key")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--local-file", required=True)
    parser.add_argument("--remote-filename", required=True)
    args = parser.parse_args()

    key = paramiko.RSAKey.from_private_key_file(SFTP_KEY_PATH)
    transport = paramiko.Transport((SFTP_HOST, SFTP_PORT))
    transport.connect(username=SFTP_USER, pkey=key)
    sftp = paramiko.SFTPClient.from_transport(transport)

    remote_path = f"inbound/{args.remote_filename}"
    sftp.put(args.local_file, remote_path)

    sftp.close()
    transport.close()
    print(f"[hopital-saint-martin] uploaded {args.local_file} -> {remote_path}")


if __name__ == "__main__":
    main()
