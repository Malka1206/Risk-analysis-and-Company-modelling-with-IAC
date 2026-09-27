output "network_names" {
  description = "Docker networks created for the mockup."
  value = {
    sci_admin = docker_network.sci_admin.name
    it        = docker_network.it.name
    dmz       = docker_network.dmz.name
    external  = docker_network.external.name
  }
}

output "ldap_container" {
  description = "LDAP directory container name (bind DN base: dc=biolab-analytics,dc=local)."
  value       = docker_container.ldap.name
}

output "phpldapadmin_url" {
  description = "phpLDAPAdmin console (deliberately unrestricted)."
  value       = "http://localhost:8081"
}

output "patient_db_container" {
  description = "Patient database container name."
  value       = docker_container.patient_db.name
}

output "minio_console_url" {
  description = "MinIO web console (internal network only unless you publish a port)."
  value       = "http://${docker_container.minio.name}:9001"
}

output "compute_node_url" {
  description = "Compute node HTTP API (POST /analyze with 'barcode' + 'file')."
  value       = "http://localhost:5000"
}

output "lims_url" {
  description = "LIMS web app over HTTPS (self-signed, signed by BioLab's internal CA in pki/ca.crt -- your browser will warn unless you import it). Log in with an LDAP account, e.g. technicien1 / Labo1234."
  value       = "https://localhost:5001"
}

output "sftp_connection_hint" {
  description = "How to connect to the SFTP server from the host, THROUGH the firewall container (see firewall/entrypoint.sh). Both accounts share the same key, see sftp-server/keys/README.txt."
  value       = "sftp -i sftp-server/keys/biolab_partner_key.key -P 2222 biolab_admin@localhost   (or hopital_saint_martin@localhost)"
}

output "bastion_connection_hint" {
  description = "SSH into the combined bastion + log server, then use psql/ldapsearch/tail from there (see bastion/keys/README.txt)."
  value       = "ssh -i bastion/keys/bastion_it_key.key -p 2200 itsys@localhost"
}

output "adminer_url" {
  description = "Adminer (unrestricted DB admin panel) for patient-db / billing. Server=patient-db, user/password from variables.tf."
  value       = "http://localhost:8082"
}

output "automate_demo_hint" {
  description = "Demonstrate the Modbus automation device requires no authentication."
  value       = "docker exec -it biolab-ws-it python modbus_demo.py --read"
}

output "workflow_walkthrough" {
  description = "End-to-end demo commands, once `terraform apply` has finished."
  value       = <<-EOT
    1) Admin intake (creates patient/record/invoice, prints a barcode):
       docker exec -it biolab-ws-admin python admin_intake.py \
         --last-name Durand --first-name Alice --dob 1985-03-12 \
         --hospital "Hopital Saint-Martin" --test-type sequencage_adn

    2) Hospital drops the genetic sample over real SFTP:
       docker exec -it biolab-ext-hopital-saint-martin \
         python hospital_submit_sample.py \
         --local-file /samples/demo_sample_BC-2026-00002.fasta \
         --remote-filename patient_alice.fasta

       Admin fetches it (also real SFTP, same shared key):
       docker exec -it biolab-ws-admin python admin_fetch_inbound.py \
         --remote-filename patient_alice.fasta --barcode <BARCODE>

    3) Bioinformatician submits the file to the compute node:
       docker exec -it biolab-ws-bioinfo python bioinfo_submit_analysis.py --barcode <BARCODE>

    4) Technician assigns the result: https://localhost:5001/assign (login technicien1 / Labo1234)
    5) Biologist validates it: https://localhost:5001/validate (login biologiste1 / Bio2024!)

    6) Admin prepares delivery (uploads to to_encrypt/, watcher encrypts automatically):
       docker exec -it biolab-ws-admin python admin_prepare_delivery.py --barcode <BARCODE>

    7) Admin confirms delivery once the watcher has processed it:
       docker exec -it biolab-ws-admin python admin_confirm_delivery.py --barcode <BARCODE>

    8) Hospital retrieves its (encrypted) result:
       docker exec -it biolab-ext-hopital-saint-martin \
         python hospital_fetch_result.py --barcode <BARCODE>

    --- Residual-access demonstration (former contractor, section 6) ---
    docker exec -it biolab-ext-former-contractor python residual_access_demo.py

    --- Modbus automation device: no authentication required ---
    docker exec -it biolab-ws-it python modbus_demo.py --read
    docker exec -it biolab-ws-it python modbus_demo.py --write-status 2

    --- Bastion + log server ---
    ssh -i bastion/keys/bastion_it_key.key -p 2200 itsys@localhost
    # then, from inside that session:
    #   psql -h patient-db -U biolab_app -d patient_db
    #   tail -f /var/log/central.log
  EOT
}
