# -----------------------------------------------------------------------------
# Perimeter firewall (Description.md section 6.3 / Plan_Maquette.txt
# section 11). See firewall/entrypoint.sh for the full rationale and the
# documented scope limitation.
# -----------------------------------------------------------------------------

resource "docker_image" "firewall" {
  name = "${var.project_name}-firewall:latest"

  build {
    context = abspath("${path.module}/../firewall")
  }
}

resource "docker_container" "firewall" {
  name  = "${var.project_name}-firewall"
  image = docker_image.firewall.image_id

  capabilities {
    add = ["NET_ADMIN"]
  }

  sysctls = {
    "net.ipv4.ip_forward" = "1"
  }

  ports {
    internal = 2222
    external = 2222
  }

  networks_advanced {
    name = docker_network.dmz.name
  }

  depends_on = [docker_container.sftp_server]

  labels {
    label = "purpose"
    value = "perimeter-firewall"
  }
}
