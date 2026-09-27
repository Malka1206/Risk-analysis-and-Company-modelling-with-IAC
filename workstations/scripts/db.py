import os

import psycopg2


def db_conn():
    return psycopg2.connect(
        host=os.environ.get("PGHOST", "patient-db"),
        dbname=os.environ.get("PGDATABASE", "patient_db"),
        user=os.environ.get("PGUSER", "biolab_app"),
        password=os.environ.get("PGPASSWORD", "biolab_app_pwd"),
    )
