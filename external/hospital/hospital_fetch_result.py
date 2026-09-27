"""
External stakeholder - partner hospital: retrieve the delivered result
(workflow step 9). The hospital only ever sees the ENCRYPTED file -- it has
no access to BioLab's homemade decryption key, so in a real (non-mockup)
setting it would need an out-of-band arrangement to read it. That gap is
itself worth carrying into the risk analysis.

Usage:
  python hospital_fetch_result.py --barcode BC-2026-00001
"""

import argparse
import os

import paramiko

SFTP_HOST = os.environ.get("SFTP_HOST", "sftp-server")
SFTP_PORT = int(os.environ.get("SFTP_PORT", "22"))
SFTP_USER = os.environ.get("SFTP_USER", "hopital_saint_martin")
SFTP_KEY_PATH = os.environ.get("SFTP_KEY_PATH", "/keys/biolab_partner_key.key")
DOWNLOAD_DIR = os.environ.get("DOWNLOAD_DIR", "/downloads")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--barcode", required=True)
    args = parser.parse_args()

    key = paramiko.RSAKey.from_private_key_file(SFTP_KEY_PATH)
    transport = paramiko.Transport((SFTP_HOST, SFTP_PORT))
    transport.connect(username=SFTP_USER, pkey=key)
    sftp = paramiko.SFTPClient.from_transport(transport)

    remote_name = f"{args.barcode}.json.enc"
    remote_path = f"outbound/{remote_name}"
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)
    local_path = os.path.join(DOWNLOAD_DIR, remote_name)

    sftp.get(remote_path, local_path)

    sftp.close()
    transport.close()
    print(f"[hopital-saint-martin] downloaded {remote_path} -> {local_path}")


if __name__ == "__main__":
    main()
