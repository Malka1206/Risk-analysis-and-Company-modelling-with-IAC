variable "project_name" {
  description = "Prefix used for all Docker resource names."
  type        = string
  default     = "biolab"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "subnet_sci_admin" {
  description = "Subnet for the merged SCIENTIFIC + ADMINISTRATIVE network (intentional flat-network weakness, see Plan_Maquette.txt section 8)."
  type        = string
  default     = "10.10.1.0/24"
}

variable "subnet_it" {
  description = "Subnet for the IT / MANAGEMENT network (LDAP, logs, bastion)."
  type        = string
  default     = "10.10.2.0/24"
}

variable "subnet_dmz" {
  description = "Subnet for the DMZ (SFTP server)."
  type        = string
  default     = "10.10.3.0/24"
}

variable "subnet_external" {
  description = "Subnet simulating external partners (hospitals, clinics...) and the generic attacker node."
  type        = string
  default     = "10.10.4.0/24"
}

# ---------------------------------------------------------------------------
# LDAP / IAM
# NOTE: default credentials below are DELIBERATELY weak and shared across
# accounts. This is the vulnerability documented in Plan_Maquette.txt
# section 9 (IAM vulnerable), not an oversight.
# ---------------------------------------------------------------------------

variable "ldap_domain" {
  description = "Base domain for the LDAP directory."
  type        = string
  default     = "biolab-analytics.local"
}

variable "ldap_organisation" {
  description = "Organisation name shown in the LDAP directory."
  type        = string
  default     = "BioLab Analytics"
}

variable "ldap_admin_password" {
  description = "LDAP admin password. Deliberately weak/default for the mockup (documented IAM vulnerability)."
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "ldap_config_password" {
  description = "LDAP config (cn=config) password. Deliberately weak/default for the mockup."
  type        = string
  default     = "config"
  sensitive   = true
}

# NOTE: individual employee passwords are no longer a single shared secret.
# Each account (biologiste1, bioinfo1, technicien1, admin1, it1) now has its
# own weak password, hardcoded directly in ldap/bootstrap/01-users.ldif
# (see the table at the top of that file). Anonymous bind is disabled via
# ldap/bootstrap/02-disable-anonymous-bind.ldif: authentication is required.
#
# The variables below simply MIRROR those same per-account passwords so
# that Terraform can inject them into each workstation container's
# environment (workstations.tf). Keep them in sync with the LDIF file.

variable "ldap_password_biologiste" {
  type      = string
  default   = "Bio2024!"
  sensitive = true
}

variable "ldap_password_bioinfo" {
  type      = string
  default   = "Genome99"
  sensitive = true
}

variable "ldap_password_technicien" {
  type      = string
  default   = "Labo1234"
  sensitive = true
}

variable "ldap_password_admin" {
  type      = string
  default   = "Accueil2023"
  sensitive = true
}

variable "ldap_password_it" {
  type      = string
  default   = "Support01"
  sensitive = true
}

# ---------------------------------------------------------------------------
# Patient database
# ---------------------------------------------------------------------------

variable "patient_db_name" {
  type    = string
  default = "patient_db"
}

variable "patient_db_user" {
  type    = string
  default = "biolab_app"
}

variable "patient_db_password" {
  description = "Patient DB password. Deliberately weak/default for the mockup (documented in Description.md section 4.1)."
  type        = string
  default     = "biolab_app_pwd"
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Storage (MinIO) - Description.md section 3.2
# ---------------------------------------------------------------------------

variable "minio_root_user" {
  description = "MinIO root access key. Deliberately weak/default for the mockup."
  type        = string
  default     = "minioadmin"
  sensitive   = true
}

variable "minio_root_password" {
  description = "MinIO root secret key. Deliberately weak/default for the mockup."
  type        = string
  default     = "minioadmin123"
  sensitive   = true
}

variable "minio_bucket_raw_results" {
  description = "Bucket receiving raw results automatically from the compute node."
  type        = string
  default     = "raw-results"
}

# ---------------------------------------------------------------------------
# Bastion + central log server (Description.md sections 6.2 / 6.6)
# Static IPs so every service's syslog log_driver can target a fixed
# address (Docker's syslog driver runs in the daemon's network namespace,
# not the container's, so a container NAME would not reliably resolve).
# ---------------------------------------------------------------------------

variable "log_server_ip_sci_admin" {
  description = "Static IP of the bastion/log server on net_sci_admin."
  type        = string
  default     = "10.10.1.10"
}

variable "log_server_ip_it" {
  description = "Static IP of the bastion/log server on net_it."
  type        = string
  default     = "10.10.2.10"
}
