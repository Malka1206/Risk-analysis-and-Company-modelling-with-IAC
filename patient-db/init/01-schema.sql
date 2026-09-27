-- -----------------------------------------------------------------------------
-- BioLab Analytics - patient-db schema
-- See Description.md section 4.1 (v3) for the rationale.
--
-- Note: the LIMS (section 3.3) writes DIRECTLY into the `results` table
-- below -- there is intentionally no separate LIMS-owned database, to avoid
-- the consistency problems identified during the workflow review.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hospitals (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    address     TEXT,
    contact     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patients (
    id              SERIAL PRIMARY KEY,
    last_name       TEXT NOT NULL,
    first_name      TEXT NOT NULL,
    date_of_birth   DATE NOT NULL,
    national_id     TEXT,                 -- e.g. numero de securite sociale
    address         TEXT,
    phone           TEXT,
    email           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Workflow status values (Plan_Maquette.txt section 0):
--   received -> in_analysis -> assigned -> validated -> encrypted -> delivered
CREATE TABLE IF NOT EXISTS medical_records (
    id              SERIAL PRIMARY KEY,
    patient_id      INTEGER NOT NULL REFERENCES patients(id),
    hospital_id     INTEGER NOT NULL REFERENCES hospitals(id),
    barcode         TEXT NOT NULL UNIQUE,  -- the ONLY identifier that travels
                                            -- with the file through the
                                            -- scientific pipeline
    test_type       TEXT NOT NULL,
    sample_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    status          TEXT NOT NULL DEFAULT 'received'
                        CHECK (status IN (
                            'received', 'in_analysis', 'assigned',
                            'validated', 'encrypted', 'delivered'
                        )),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_medical_records_barcode ON medical_records(barcode);
CREATE INDEX IF NOT EXISTS idx_medical_records_status  ON medical_records(status);

-- Populated directly by the LIMS at workflow step 5 (assignment) and
-- completed by the medical validation step (step 6).
CREATE TABLE IF NOT EXISTS results (
    id                  SERIAL PRIMARY KEY,
    record_id           INTEGER NOT NULL REFERENCES medical_records(id),
    storage_reference    TEXT NOT NULL,   -- object key in the raw-results bucket
    assignment_date      TIMESTAMPTZ,
    technician_ldap_uid  TEXT,            -- uid from LDAP, no FK (external IAM)
    validation_date       TIMESTAMPTZ,
    biologist_ldap_uid    TEXT,           -- NULL until medically validated
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_results_record_id ON results(record_id);

-- Invoice lifecycle: pending (workflow step 2) -> sent (workflow step 10)
CREATE TABLE IF NOT EXISTS invoices (
    id              SERIAL PRIMARY KEY,
    patient_id      INTEGER NOT NULL REFERENCES patients(id),
    hospital_id     INTEGER NOT NULL REFERENCES hospitals(id),
    record_id       INTEGER REFERENCES medical_records(id),
    amount          NUMERIC(10, 2) NOT NULL,
    payment_status  TEXT NOT NULL DEFAULT 'pending'
                        CHECK (payment_status IN ('pending', 'sent', 'paid')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at         TIMESTAMPTZ
);

-- Minimal role table for the app layer (LIMS). Deliberately NOT enforced at
-- the LDAP level (see ldap.tf: single flat "employees" group) -- this table
-- is easy to bypass/spoof from application code, which is itself a weakness
-- worth carrying into the risk analysis (section 3.4 integrity gap).
CREATE TABLE IF NOT EXISTS app_users (
    ldap_uid    TEXT PRIMARY KEY,
    role        TEXT NOT NULL CHECK (role IN (
                    'biologiste', 'bioinformaticien', 'technicien',
                    'administratif', 'it'
                ))
);
