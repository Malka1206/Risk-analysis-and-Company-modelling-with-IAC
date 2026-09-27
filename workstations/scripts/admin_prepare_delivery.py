"""
BioLab Analytics - admin workstation: prepare delivery (workflow step 7).

Only proceeds if the record has been medically validated (workflow step 6).
Fetches the raw result from storage (MinIO) and uploads it, over the SAME
real SFTP connection used for inbound retrieval, into the sftp-server's
"to_encrypt" folder -- which is the exact directory the homemade-crypto
watcher polls (they share the "exchange" Docker volume; see
terraform/sftp-crypto.tf).

Usage:
  python admin_prepare_delivery.py --barcode BC-2026-00001
"""

import argparse
import os
import sys
import tempfile

import boto3
import paramiko
from botocore.client import Config

from db import db_conn

SFTP_HOST = os.environ.get("SFTP_HOST", "sftp-server")
SFTP_PORT = int(os.environ.get("SFTP_PORT", "22"))
SFTP_USER = os.environ.get("SFTP_USER", "biolab_admin")
SFTP_KEY_PATH = os.environ.get("SFTP_KEY_PATH", "/keys/biolab_partner_key.key")

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin123")
MINIO_BUCKET = os.environ.get("MINIO_BUCKET", "raw-results")


def s3_client():
    return boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        config=Config(signature_version="s3v4"),
        verify=False,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--barcode", required=True)
    args = parser.parse_args()

    conn = db_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, status FROM medical_records WHERE barcode = %s",
                (args.barcode,),
            )
            row = cur.fetchone()
            if not row:
                sys.exit(f"No medical record for barcode '{args.barcode}'.")
            record_id, status = row
            if status != "validated":
                sys.exit(
                    f"Record {args.barcode} is not medically validated yet "
                    f"(status='{status}'). Refusing to prepare delivery."
                )

            object_key = f"{args.barcode}.json"
            client = s3_client()
            with tempfile.NamedTemporaryFile(delete=False, suffix=".json") as tmp:
                client.download_fileobj(MINIO_BUCKET, object_key, tmp)
                local_path = tmp.name

            key = paramiko.RSAKey.from_private_key_file(SFTP_KEY_PATH)
            transport = paramiko.Transport((SFTP_HOST, SFTP_PORT))
            transport.connect(username=SFTP_USER, pkey=key)
            sftp = paramiko.SFTPClient.from_transport(transport)
            remote_path = f"to_encrypt/{args.barcode}.json"
            sftp.put(local_path, remote_path)
            sftp.close()
            transport.close()
            os.remove(local_path)

            # Simplification (documented): we mark the record 'encrypted' as
            # soon as the file is handed off for encryption, rather than
            # waiting for a callback from the watcher (which has no DB
            # access by design -- it only touches the shared filesystem).
            cur.execute(
                "UPDATE medical_records SET status = 'encrypted', updated_at = now() WHERE id = %s",
                (record_id,),
            )
        conn.commit()
    finally:
        conn.close()

    print(f"[admin] {object_key} uploaded to to_encrypt/, record marked 'encrypted'.")


if __name__ == "__main__":
    main()
