-- -----------------------------------------------------------------------------
-- Demo seed data for the BioLab Analytics mockup.
-- -----------------------------------------------------------------------------

INSERT INTO hospitals (name, address, contact) VALUES
    ('Hopital Saint-Martin', '12 rue de la Sante, Paris', 'contact@hopital-saint-martin.example'),
    ('Clinique du Parc',     '4 avenue des Tilleuls, Lyon', 'contact@clinique-du-parc.example'),
    ('Centre de Recherche Genomique', '9 boulevard Pasteur, Toulouse', 'contact@crg.example')
ON CONFLICT DO NOTHING;

INSERT INTO patients (last_name, first_name, date_of_birth, national_id, address, phone, email) VALUES
    ('Durand', 'Alice',   '1985-03-12', '2850312123456', '10 rue Victor Hugo, Paris', '0601020304', 'alice.durand@example.com'),
    ('Martin', 'Julien',  '1990-07-24', '1900724123456', '3 rue de la Paix, Lyon',    '0602030405', 'julien.martin@example.com'),
    ('Bernard','Sophie',  '1978-11-02', '2781102123456', '22 avenue Foch, Toulouse',  '0603040506', 'sophie.bernard@example.com'),
    ('Petit',  'Nicolas', '2001-01-30', '1010130123456', '5 impasse des Lilas, Paris','0604050607', 'nicolas.petit@example.com'),
    ('Robert', 'Claire',  '1995-09-18', '2950918123456', '8 rue des Fleurs, Lyon',    '0605060708', 'claire.robert@example.com')
ON CONFLICT DO NOTHING;

-- A handful of records at different workflow stages, for a realistic-looking
-- demo once the mockup is up (some still 'received', one already 'delivered').
INSERT INTO medical_records (patient_id, hospital_id, barcode, test_type, status) VALUES
    (1, 1, 'BC-2026-00001', 'sequencage_adn', 'received'),
    (2, 1, 'BC-2026-00002', 'sequencage_adn', 'in_analysis'),
    (3, 2, 'BC-2026-00003', 'test_genetique',  'assigned'),
    (4, 2, 'BC-2026-00004', 'sequencage_adn', 'validated'),
    (5, 3, 'BC-2026-00005', 'test_genetique',  'delivered')
ON CONFLICT DO NOTHING;

INSERT INTO invoices (patient_id, hospital_id, record_id, amount, payment_status, sent_at) VALUES
    (1, 1, 1, 350.00, 'pending', NULL),
    (2, 1, 2, 350.00, 'pending', NULL),
    (3, 2, 3, 420.00, 'pending', NULL),
    (4, 2, 4, 420.00, 'pending', NULL),
    (5, 3, 5, 500.00, 'sent',    now())
ON CONFLICT DO NOTHING;

INSERT INTO app_users (ldap_uid, role) VALUES
    ('biologiste1', 'biologiste'),
    ('bioinfo1',    'bioinformaticien'),
    ('technicien1', 'technicien'),
    ('admin1',      'administratif'),
    ('it1',         'it')
ON CONFLICT DO NOTHING;
