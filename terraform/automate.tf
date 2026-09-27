# -----------------------------------------------------------------------------
# Lab automation device (Description.md section 2.6 / Plan_Maquette.txt
# section 6)
#
# Real Modbus TCP server. On net_sci_admin -- the same flat network as the
# administrative workstations -- with no authentication, because Modbus TCP
# has none by design. See workstations/scripts/modbus_demo.py for a
# ready-made demonstration once deployed.
# -----------------------------------------------------------------------------

resource "docker_image" "automate" {
  name = "${var.project_name}-automate:latest"

  build {
    context = abspath("${path.module}/../automate")
  }
}

resource "docker_container" "automate" {
  name  = "${var.project_name}-automate"
  image = docker_image.automate.image_id

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "automate"
  }

  labels {
    label = "purpose"
    value = "lab-automation-device"
  }
}
