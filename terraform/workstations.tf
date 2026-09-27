# -----------------------------------------------------------------------------
# User workstations (Description.md section 2.4 / Plan_Maquette.txt section 0)
#
# All 5 roles share the SAME base image (workstations/) -- a realistic
# "corporate image" -- and differ only by which LDAP identity they log in
# as, and which extra volumes they need for their role:
#
#   - admin       : /keys (SFTP private key, read-only) + /handoff
#   - bioinfo     : /handoff only
#   - technicien / biologiste / it : no extra volume -- they interact with
#     the LIMS (technicien/biologiste) via the web UI published on
#     http://localhost:5001, reachable from this network. This container
#     mainly proves the workstation's real LDAP identity/session.
#
# Every workstation runs a REAL LDAP bind at startup (entrypoint.sh ->
# ldap_login_test.py). There is no anonymous/unauthenticated path: if the
# credentials are wrong, the login check fails loudly.
# -----------------------------------------------------------------------------

resource "docker_volume" "handoff" {
  name = "${var.project_name}-handoff"
}

resource "docker_image" "workstation" {
  name = "${var.project_name}-workstation:latest"

  build {
    context = abspath("${path.module}/../workstations")
  }
}

locals {
  common_workstation_env = [
    "LDAP_HOST=${docker_container.ldap.name}",
    "LDAP_BASE_DN=dc=biolab-analytics,dc=local",
    "PGHOST=${docker_container.patient_db.name}",
    "PGDATABASE=${var.patient_db_name}",
    "PGUSER=${var.patient_db_user}",
    "PGPASSWORD=${var.patient_db_password}",
  ]
}

# --- Administrative workstation ---------------------------------------------

resource "docker_container" "ws_admin" {
  name  = "${var.project_name}-ws-admin"
  image = docker_image.workstation.image_id

  env = concat(local.common_workstation_env, [
    "WORKSTATION_ROLE=administratif",
    "LDAP_UID=admin1",
    "LDAP_PASSWORD=${var.ldap_password_admin}",
    "SFTP_HOST=${docker_container.sftp_server.name}",
    "SFTP_USER=biolab_admin",
    "SFTP_KEY_PATH=/keys/biolab_partner_key.key",
    "HANDOFF_DIR=/handoff",
    "MINIO_ENDPOINT=https://${docker_container.minio.name}:9000",
    "MINIO_ACCESS_KEY=${var.minio_root_user}",
    "MINIO_SECRET_KEY=${var.minio_root_password}",
    "MINIO_BUCKET=${var.minio_bucket_raw_results}",
  ])

  volumes {
    host_path      = abspath("${path.module}/../sftp-server/keys/biolab_partner_key.key")
    container_path = "/keys/biolab_partner_key.key"
    read_only      = true
  }

  volumes {
    volume_name    = docker_volume.handoff.name
    container_path = "/handoff"
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  # Needed to actually reach the SFTP server, which lives in the DMZ.
  # NOTE (adjustment, documented like earlier sections): until the firewall
  # container exists (a later section), the admin workstation is pragmatically
  # dual-homed onto net_dmz directly, rather than routed through a firewall
  # that doesn't exist yet. Revisit once firewall.tf is added.
  networks_advanced {
    name = docker_network.dmz.name
  }

  depends_on = [docker_container.ldap, docker_container.patient_db, docker_container.sftp_server]

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "ws-admin"
  }
}

# --- Bioinformatician workstation --------------------------------------------

resource "docker_container" "ws_bioinfo" {
  name  = "${var.project_name}-ws-bioinfo"
  image = docker_image.workstation.image_id

  env = concat(local.common_workstation_env, [
    "WORKSTATION_ROLE=bioinformaticien",
    "LDAP_UID=bioinfo1",
    "LDAP_PASSWORD=${var.ldap_password_bioinfo}",
    "HANDOFF_DIR=/handoff",
    "COMPUTE_NODE_URL=http://${docker_container.compute_node.name}:5000",
  ])

  volumes {
    volume_name    = docker_volume.handoff.name
    container_path = "/handoff"
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  depends_on = [docker_container.ldap, docker_container.compute_node]

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "ws-bioinfo"
  }
}

# --- Technician workstation ---------------------------------------------------

resource "docker_container" "ws_technicien" {
  name  = "${var.project_name}-ws-technicien"
  image = docker_image.workstation.image_id

  env = concat(local.common_workstation_env, [
    "WORKSTATION_ROLE=technicien",
    "LDAP_UID=technicien1",
    "LDAP_PASSWORD=${var.ldap_password_technicien}",
    "LIMS_URL=https://${docker_container.lims.name}:5001",
    "CA_BUNDLE=/pki/ca.crt",
  ])

  volumes {
    host_path      = abspath("${path.module}/../pki/ca.crt")
    container_path = "/pki/ca.crt"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  depends_on = [docker_container.ldap]

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "ws-technicien"
  }
}

# --- Biologist workstation -----------------------------------------------------

resource "docker_container" "ws_biologiste" {
  name  = "${var.project_name}-ws-biologiste"
  image = docker_image.workstation.image_id

  env = concat(local.common_workstation_env, [
    "WORKSTATION_ROLE=biologiste",
    "LDAP_UID=biologiste1",
    "LDAP_PASSWORD=${var.ldap_password_biologiste}",
    "LIMS_URL=https://${docker_container.lims.name}:5001",
    "CA_BUNDLE=/pki/ca.crt",
  ])

  volumes {
    host_path      = abspath("${path.module}/../pki/ca.crt")
    container_path = "/pki/ca.crt"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  depends_on = [docker_container.ldap]

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "ws-biologiste"
  }
}

# --- IT workstation -------------------------------------------------------------

resource "docker_container" "ws_it" {
  name  = "${var.project_name}-ws-it"
  image = docker_image.workstation.image_id

  env = concat(local.common_workstation_env, [
    "WORKSTATION_ROLE=it",
    "LDAP_UID=it1",
    "LDAP_PASSWORD=${var.ldap_password_it}",
  ])

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  depends_on = [docker_container.ldap]

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "ws-it"
  }
}
