"""
BioLab Analytics - bioinformatician workstation: submit analysis
(workflow step 3 handoff completion -> step 4).

Picks up the barcode-labeled file the admin placed in /handoff, marks the
record 'in_analysis', and submits it to the compute node. The compute node
itself auto-uploads the raw result to storage (see compute-node/app.py) --
this script does not touch storage directly.

Usage:
  python bioinfo_submit_analysis.py --barcode BC-2026-00001
"""

import argparse
import glob
import os
import sys

import requests

from db import db_conn

HANDOFF_DIR = os.environ.get("HANDOFF_DIR", "/handoff")
COMPUTE_NODE_URL = os.environ.get("COMPUTE_NODE_URL", "http://compute-node:5000")


def find_handoff_file(barcode: str) -> str:
    matches = glob.glob(os.path.join(HANDOFF_DIR, f"{barcode}.*"))
    if not matches:
        sys.exit(f"No file found in {HANDOFF_DIR} for barcode '{barcode}'.")
    return matches[0]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--barcode", required=True)
    args = parser.parse_args()

    file_path = find_handoff_file(args.barcode)

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
            if status not in ("received", "in_analysis"):
                print(
                    f"[bioinfo] warning: record status is '{status}', proceeding anyway.",
                    file=sys.stderr,
                )

            cur.execute(
                "UPDATE medical_records SET status = 'in_analysis', updated_at = now() WHERE id = %s",
                (record_id,),
            )
        conn.commit()
    finally:
        conn.close()

    with open(file_path, "rb") as f:
        response = requests.post(
            f"{COMPUTE_NODE_URL}/analyze",
            data={"barcode": args.barcode},
            files={"file": f},
            timeout=30,
        )

    if response.status_code != 201:
        sys.exit(f"[bioinfo] compute node error {response.status_code}: {response.text}")

    print(f"[bioinfo] submitted {file_path} for barcode {args.barcode}")
    print(response.json())


if __name__ == "__main__":
    main()
