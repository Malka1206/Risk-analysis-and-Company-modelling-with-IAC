# -----------------------------------------------------------------------------
# Patient database (Description.md section 4.1)
#
# Deliberate weaknesses:
#   - Weak/default credentials (see variables.tf).
#   - Reachable from the merged SCIENTIFIC + ADMINISTRATIVE network only
#     (net_sci_admin) -- i.e. reachable from every workstation and every
#     scientific service on that flat network, which is exactly the
#     segmentation weakness documented in Plan_Maquette.txt section 8.
#   - No TLS enforced on the Postgres connection (deliberately left off;
#     pairs with the "no internal PKI" weakness elsewhere in the mockup).
# -----------------------------------------------------------------------------

resource "docker_image" "postgres" {
  name = "postgres:16"
}

resource "docker_container" "patient_db" {
  name  = "${var.project_name}-patient-db"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_DB=${var.patient_db_name}",
    "POSTGRES_USER=${var.patient_db_user}",
    "POSTGRES_PASSWORD=${var.patient_db_password}",
  ]

  volumes {
    host_path      = abspath("${path.module}/../patient-db/init")
    container_path = "/docker-entrypoint-initdb.d"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  labels {
    label = "purpose"
    value = "patient-database"
  }

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "patient-db"
  }
}
