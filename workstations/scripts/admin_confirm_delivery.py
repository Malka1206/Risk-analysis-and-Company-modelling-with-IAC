"""
BioLab Analytics - admin workstation: confirm delivery (workflow steps 9-10).

Checks, over the real SFTP connection, whether the homemade-crypto watcher
has produced the encrypted file in /outbound yet. If so, closes the loop:
record -> 'delivered', invoice -> 'sent'.

Usage:
  python admin_confirm_delivery.py --barcode BC-2026-00001
"""

import argparse
import os
import sys

import paramiko

from db import db_conn

SFTP_HOST = os.environ.get("SFTP_HOST", "sftp-server")
SFTP_PORT = int(os.environ.get("SFTP_PORT", "22"))
SFTP_USER = os.environ.get("SFTP_USER", "biolab_admin")
SFTP_KEY_PATH = os.environ.get("SFTP_KEY_PATH", "/keys/biolab_partner_key.key")


def outbound_file_exists(remote_name: str) -> bool:
    key = paramiko.RSAKey.from_private_key_file(SFTP_KEY_PATH)
    transport = paramiko.Transport((SFTP_HOST, SFTP_PORT))
    transport.connect(username=SFTP_USER, pkey=key)
    sftp = paramiko.SFTPClient.from_transport(transport)
    try:
        sftp.stat(f"outbound/{remote_name}")
        return True
    except FileNotFoundError:
        return False
    finally:
        sftp.close()
        transport.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--barcode", required=True)
    args = parser.parse_args()

    remote_name = f"{args.barcode}.json.enc"
    if not outbound_file_exists(remote_name):
        sys.exit(
            f"'{remote_name}' not found in outbound/ yet -- the homemade-crypto "
            f"watcher may not have processed it yet. Try again shortly."
        )

    conn = db_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM medical_records WHERE barcode = %s", (args.barcode,)
            )
            row = cur.fetchone()
            if not row:
                sys.exit(f"No medical record for barcode '{args.barcode}'.")
            record_id = row[0]

            cur.execute(
                "UPDATE medical_records SET status = 'delivered', updated_at = now() WHERE id = %s",
                (record_id,),
            )
            cur.execute(
                "UPDATE invoices SET payment_status = 'sent', sent_at = now() WHERE record_id = %s",
                (record_id,),
            )
        conn.commit()
    finally:
        conn.close()

    print(f"[admin] {args.barcode}: delivered, invoice marked 'sent'.")


if __name__ == "__main__":
    main()
