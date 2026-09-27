# Resources are split across dedicated files for readability:
#   networks.tf        -> Docker networks (segmentation)
#   ldap.tf             -> LDAP / IAM (directory + admin UI)
#   patient-db.tf       -> Patient database (Postgres)
#   storage.tf          -> MinIO (raw results) + bucket init job
#   compute.tf          -> Compute node (genomic pipeline)
#   lims.tf             -> LIMS (assignment + medical validation)
#   sftp-crypto.tf      -> SFTP server + homemade-encryption watcher
#   workstations.tf     -> 5 user workstations (admin/bioinfo/technicien/biologiste/it)
#   external.tf         -> External stakeholders (hospital, former contractor, attacker, placeholders)
#   automate.tf         -> Lab automation device (Modbus TCP)
#   bastion-logs.tf     -> Bastion + central log server (combined)
#   firewall.tf         -> Perimeter firewall (iptables DNAT for SFTP)
#   billing.tf          -> Adminer (billing / patient-db admin panel)
#
# Terraform automatically loads every *.tf file in this directory, so there
# is no need to centralize resources in this file.

locals {
  common_labels = {
    project = var.project_name
    purpose = "risk-analysis-mockup"
  }
}
