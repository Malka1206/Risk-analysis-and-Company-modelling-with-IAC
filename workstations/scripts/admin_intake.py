"""
BioLab Analytics - admin workstation: intake (Plan_Maquette.txt section 0,
workflow step 2).

Registers the patient + medical record, generates the internal barcode,
and creates a "pending" invoice -- all BEFORE anything scientific happens.

Usage (from inside the admin-workstation container):
  python admin_intake.py \\
      --last-name Durand --first-name Alice --dob 1985-03-12 \\
      --national-id 2850312123456 --hospital "Hopital Saint-Martin" \\
      --test-type sequencage_adn --amount 350.00
"""

import argparse
import sys
import uuid

from db import db_conn

TEST_PRICES = {
    "sequencage_adn": 350.00,
    "test_genetique": 420.00,
}


def get_or_create_patient(cur, args) -> int:
    cur.execute(
        "SELECT id FROM patients WHERE last_name=%s AND first_name=%s AND date_of_birth=%s",
        (args.last_name, args.first_name, args.dob),
    )
    row = cur.fetchone()
    if row:
        return row[0]

    cur.execute(
        """
        INSERT INTO patients (last_name, first_name, date_of_birth, national_id, address, phone, email)
        VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id
        """,
        (args.last_name, args.first_name, args.dob, args.national_id,
         args.address, args.phone, args.email),
    )
    return cur.fetchone()[0]


def get_hospital_id(cur, name: str) -> int:
    cur.execute("SELECT id FROM hospitals WHERE name = %s", (name,))
    row = cur.fetchone()
    if not row:
        sys.exit(f"Unknown hospital '{name}'. Register it in hospitals first.")
    return row[0]


def generate_barcode() -> str:
    return f"BC-2026-{uuid.uuid4().hex[:8].upper()}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--last-name", required=True)
    parser.add_argument("--first-name", required=True)
    parser.add_argument("--dob", required=True, help="YYYY-MM-DD")
    parser.add_argument("--national-id", default=None)
    parser.add_argument("--address", default=None)
    parser.add_argument("--phone", default=None)
    parser.add_argument("--email", default=None)
    parser.add_argument("--hospital", required=True)
    parser.add_argument("--test-type", required=True, choices=list(TEST_PRICES))
    parser.add_argument("--amount", type=float, default=None)
    args = parser.parse_args()

    amount = args.amount if args.amount is not None else TEST_PRICES[args.test_type]
    barcode = generate_barcode()

    conn = db_conn()
    try:
        with conn.cursor() as cur:
            patient_id = get_or_create_patient(cur, args)
            hospital_id = get_hospital_id(cur, args.hospital)

            cur.execute(
                """
                INSERT INTO medical_records (patient_id, hospital_id, barcode, test_type, status)
                VALUES (%s, %s, %s, %s, 'received') RETURNING id
                """,
                (patient_id, hospital_id, barcode, args.test_type),
            )
            record_id = cur.fetchone()[0]

            cur.execute(
                """
                INSERT INTO invoices (patient_id, hospital_id, record_id, amount, payment_status)
                VALUES (%s, %s, %s, %s, 'pending')
                """,
                (patient_id, hospital_id, record_id, amount),
            )
        conn.commit()
    finally:
        conn.close()

    print(f"[admin] patient_id={patient_id} record_id={record_id} barcode={barcode}")
    print(barcode)  # last line: easy to capture in scripts


if __name__ == "__main__":
    main()
