"""
BioLab Analytics - LIMS (Description.md section 3.3 / 3.4)

Real, functional web app covering workflow steps 5 (assignment) and 6
(medical validation). Writes DIRECTLY into patient-db -- there is no
separate LIMS-owned database (merge decision from the workflow review).

Auth: every user must authenticate against LDAP (uid + password). Anonymous
access is not possible (see ldap/bootstrap/02-disable-anonymous-bind.ldif).

Deliberate weaknesses kept from the validated plan (Description.md
section 3.4 / 6.1):
  - Role separation (technician vs biologist) is enforced ONLY at the
    application level, by looking up the LDAP uid in patient-db.app_users.
    LDAP itself has a single flat group ("employees") with no role
    attribute -- so this app-level table is the only thing standing
    between a technician account and the "validate" screen. If app_users
    is misconfigured (or an admin adds the wrong role), nothing in LDAP
    would catch it.
  - No integrity proof (hash/signature) ties what the technician saw and
    assigned (step 5) to what the biologist reviews and validates (step 6):
    the validation screen re-reads the SAME object key from storage,
    without recomputing or comparing any hash. A file silently swapped in
    storage between the two steps would go undetected.
"""

import os
from datetime import datetime, timezone

import boto3
import psycopg2
import psycopg2.extras
from botocore.client import Config
from flask import Flask, redirect, render_template, request, session, url_for
from ldap3 import Server, Connection, ALL

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-not-for-prod")

LDAP_HOST = os.environ.get("LDAP_HOST", "ldap")
LDAP_BASE_DN = os.environ.get("LDAP_BASE_DN", "dc=biolab-analytics,dc=local")

PG_HOST = os.environ.get("PGHOST", "patient-db")
PG_DB = os.environ.get("PGDATABASE", "patient_db")
PG_USER = os.environ.get("PGUSER", "biolab_app")
PG_PASSWORD = os.environ.get("PGPASSWORD", "biolab_app_pwd")

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "https://minio:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin123")
MINIO_BUCKET = os.environ.get("MINIO_BUCKET", "raw-results")


def db_conn():
    return psycopg2.connect(
        host=PG_HOST, dbname=PG_DB, user=PG_USER, password=PG_PASSWORD
    )


def s3_client():
    return boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        config=Config(signature_version="s3v4"),
        verify=False,  # see module docstring: PKI inconsistency, deliberate
    )


def ldap_authenticate(uid: str, password: str) -> bool:
    """Real LDAP bind. Returns True only if the password is correct for
    this uid. Anonymous bind is disabled server-side, so an empty/blank
    password will always fail here."""
    if not uid or not password:
        return False
    server = Server(LDAP_HOST, get_info=ALL)
    user_dn = f"uid={uid},ou=people,{LDAP_BASE_DN}"
    try:
        conn = Connection(server, user=user_dn, password=password, auto_bind=True)
        conn.unbind()
        return True
    except Exception:
        return False


def get_role(uid: str):
    conn = db_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT role FROM app_users WHERE ldap_uid = %s", (uid,))
            row = cur.fetchone()
            return row[0] if row else None
    finally:
        conn.close()


def login_required(role=None):
    def decorator(fn):
        def wrapper(*args, **kwargs):
            if "uid" not in session:
                return redirect(url_for("login"))
            if role and session.get("role") != role:
                return "Forbidden: this screen requires role '%s'." % role, 403
            return fn(*args, **kwargs)

        wrapper.__name__ = fn.__name__
        return wrapper

    return decorator


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        uid = request.form.get("uid", "").strip()
        password = request.form.get("password", "")
        if ldap_authenticate(uid, password):
            role = get_role(uid)
            session["uid"] = uid
            session["role"] = role
            return redirect(url_for("dashboard"))
        error = "Authentication failed."
    return render_template("login.html", error=error)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/")
@login_required()
def dashboard():
    conn = db_conn()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                """
                SELECT mr.id, mr.barcode, mr.status, p.last_name, p.first_name
                FROM medical_records mr
                JOIN patients p ON p.id = mr.patient_id
                ORDER BY mr.created_at DESC
                LIMIT 50
                """
            )
            records = cur.fetchall()
    finally:
        conn.close()
    return render_template(
        "dashboard.html", uid=session["uid"], role=session.get("role"), records=records
    )


@app.route("/assign", methods=["GET", "POST"])
@login_required(role="technicien")
def assign():
    """Workflow step 5: technician scans a barcode, LIMS finds the matching
    raw result in storage, and links it to the medical record."""
    message = None
    error = None

    if request.method == "POST":
        barcode = request.form.get("barcode", "").strip()

        conn = db_conn()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id, status FROM medical_records WHERE barcode = %s",
                    (barcode,),
                )
                row = cur.fetchone()
                if not row:
                    error = f"No medical record found for barcode '{barcode}'."
                else:
                    record_id, status = row
                    object_key = f"{barcode}.json"

                    # Confirm the raw result actually exists in storage
                    # before recording the assignment.
                    client = s3_client()
                    try:
                        client.head_object(Bucket=MINIO_BUCKET, Key=object_key)
                    except Exception:
                        error = (
                            f"No raw result found in storage for barcode "
                            f"'{barcode}' (object '{object_key}')."
                        )

                    if not error:
                        cur.execute(
                            """
                            INSERT INTO results
                                (record_id, storage_reference, assignment_date, technician_ldap_uid)
                            VALUES (%s, %s, %s, %s)
                            """,
                            (record_id, object_key, datetime.now(timezone.utc), session["uid"]),
                        )
                        cur.execute(
                            "UPDATE medical_records SET status = 'assigned', updated_at = now() WHERE id = %s",
                            (record_id,),
                        )
                        conn.commit()
                        message = f"Result '{object_key}' assigned to record {barcode}."
        finally:
            conn.close()

    return render_template("assign.html", uid=session["uid"], message=message, error=error)


@app.route("/validate", methods=["GET", "POST"])
@login_required(role="biologiste")
def validate():
    """Workflow step 6: biologist reviews an assigned result and validates
    it. NOTE (deliberate weakness): no hash/signature check is performed
    here against what the technician originally assigned."""
    conn = db_conn()
    message = None
    error = None
    try:
        if request.method == "POST":
            result_id = request.form.get("result_id")
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE results SET validation_date = %s, biologist_ldap_uid = %s WHERE id = %s RETURNING record_id",
                    (datetime.now(timezone.utc), session["uid"], result_id),
                )
                row = cur.fetchone()
                if row:
                    record_id = row[0]
                    cur.execute(
                        "UPDATE medical_records SET status = 'validated', updated_at = now() WHERE id = %s",
                        (record_id,),
                    )
                    conn.commit()
                    message = f"Result #{result_id} validated."
                else:
                    error = "Result not found."

        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                """
                SELECT r.id AS result_id, r.storage_reference, r.technician_ldap_uid,
                       r.assignment_date, mr.barcode, p.last_name, p.first_name
                FROM results r
                JOIN medical_records mr ON mr.id = r.record_id
                JOIN patients p ON p.id = mr.patient_id
                WHERE r.validation_date IS NULL
                ORDER BY r.assignment_date ASC
                """
            )
            pending = cur.fetchall()
    finally:
        conn.close()

    return render_template(
        "validate.html", uid=session["uid"], pending=pending, message=message, error=error
    )


@app.route("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    # Real HTTPS with the internal CA's server certificate (Description.md
    # section 6.4). This is the flow where certificate verification IS
    # meant to be honored by clients (see workstations/scripts/
    # lims_https_check.py) -- contrast with MINIO_ENDPOINT above, where
    # verification is deliberately disabled.
    app.run(
        host="0.0.0.0",
        port=5001,
        ssl_context=("/pki/lims.crt", "/pki/lims.key"),
    )
