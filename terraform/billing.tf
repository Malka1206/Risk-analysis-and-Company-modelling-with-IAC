# -----------------------------------------------------------------------------
# Billing / administrative DB access (Description.md section 3.2)
#
# The `invoices` table (patient-db/init/01-schema.sql) is BioLab's billing
# lifecycle (pending -> sent -> paid). Rather than build a dedicated admin
# UI for it, the admin workstation is given a generic DB admin tool
# (Adminer) reachable on the internal network with NO restriction in front
# of it -- a common, realistic shortcut, and the deliberate vulnerability
# documented in the plan ("si Adminer ou equivalent est expose sans
# restriction ... faille supplementaire").
# -----------------------------------------------------------------------------

resource "docker_image" "adminer" {
  name = "adminer:latest"
}

resource "docker_container" "adminer" {
  name  = "${var.project_name}-adminer"
  image = docker_image.adminer.image_id

  ports {
    internal = 8080
    external = 8082
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "adminer"
  }

  labels {
    label = "purpose"
    value = "billing-db-admin-panel"
  }
}
