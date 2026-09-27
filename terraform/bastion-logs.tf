# -----------------------------------------------------------------------------
# Bastion + central log server (Description.md sections 6.2 and 6.6 /
# Plan_Maquette.txt sections 10 and 14)
#
# See logging/Dockerfile header for the documented design adjustment
# (bastion and log server merged into one box).
#
# Static IPs on both networks it serves, so every other container's
# syslog log_driver (see their respective .tf files) can point at a fixed
# address rather than relying on Docker-daemon-side name resolution, which
# does not reliably see container-network hostnames.
# -----------------------------------------------------------------------------

resource "docker_volume" "central_logs" {
  name = "${var.project_name}-central-logs"
}

resource "docker_image" "bastion_logs" {
  name = "${var.project_name}-bastion-logs:latest"

  build {
    context    = abspath("${path.module}/..")
    dockerfile = "logging/Dockerfile"
  }
}

resource "docker_container" "bastion_logs" {
  name  = "${var.project_name}-bastion-logs"
  image = docker_image.bastion_logs.image_id

  volumes {
    volume_name    = docker_volume.central_logs.name
    container_path = "/var/log"
  }

  # Published to the host on a non-standard port so it doesn't collide
  # with the person's own SSH usage.
  ports {
    internal = 22
    external = 2200
  }

  networks_advanced {
    name         = docker_network.it.name
    ipv4_address = var.log_server_ip_it
  }

  networks_advanced {
    name         = docker_network.sci_admin.name
    ipv4_address = var.log_server_ip_sci_admin
  }

  labels {
    label = "purpose"
    value = "bastion-and-log-server"
  }
}
