# -----------------------------------------------------------------------------
# LIMS (Description.md sections 3.3 and 3.4)
#
# Built locally from ../lims. Handles workflow step 5 (technician assignment)
# and step 6 (biologist validation). Authenticates against LDAP, writes
# directly into patient-db (no separate LIMS database, per the workflow
# review corrections).
#
# Deliberate weakness reminder: role separation (technicien / biologiste) is
# enforced only by the app_users table in patient-db, not by LDAP itself
# (single flat "employees" group) -- see lims/app.py docstring.
# -----------------------------------------------------------------------------

resource "docker_image" "lims" {
  name = "${var.project_name}-lims:latest"

  build {
    context = abspath("${path.module}/../lims")
  }
}

resource "docker_container" "lims" {
  name  = "${var.project_name}-lims"
  image = docker_image.lims.image_id

  env = [
    "FLASK_SECRET_KEY=change-me-in-a-real-deployment",
    "LDAP_HOST=${docker_container.ldap.name}",
    "LDAP_BASE_DN=dc=biolab-analytics,dc=local",
    "PGHOST=${docker_container.patient_db.name}",
    "PGDATABASE=${var.patient_db_name}",
    "PGUSER=${var.patient_db_user}",
    "PGPASSWORD=${var.patient_db_password}",
    "MINIO_ENDPOINT=https://${docker_container.minio.name}:9000",
    "MINIO_ACCESS_KEY=${var.minio_root_user}",
    "MINIO_SECRET_KEY=${var.minio_root_password}",
    "MINIO_BUCKET=${var.minio_bucket_raw_results}",
  ]

  volumes {
    host_path      = abspath("${path.module}/../pki/lims.crt")
    container_path = "/pki/lims.crt"
    read_only      = true
  }

  volumes {
    host_path      = abspath("${path.module}/../pki/lims.key")
    container_path = "/pki/lims.key"
    read_only      = true
  }

  ports {
    internal = 5001
    external = 5001
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  depends_on = [
    docker_container.ldap,
    docker_container.patient_db,
    docker_container.minio_init,
  ]

  labels {
    label = "purpose"
    value = "lims"
  }

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "lims"
  }
}
