# -----------------------------------------------------------------------------
# SFTP server + homemade encryption watcher
# (Description.md sections 3.5 and 6.5 / Plan_Maquette.txt sections 5 and 13)
#
# Real, bidirectional SFTP exchange with a partner hospital, and a real
# automatic weak-encryption step in between. Both containers share the same
# Docker volume ("exchange"), which is how files move between them without
# any network call:
#
#   admin workstation (later section) -> /exchange/to_encrypt (step 7)
#   homemade-crypto watcher            -> /exchange/outbound   (step 8, auto)
#   sftp-server (biolab_admin's view)  -> /data/outbound        (same dir, step 9)
#   sftp-server (hospital's view)      -> /data/outbound (read) / /data/inbound (write)
#
# Deliberate weaknesses: see homemade-crypto/crypto_maison.py (static XOR
# key) and sftp-server/sshd_config + entrypoint.sh (shared, unrotated SSH
# key across both accounts).
# -----------------------------------------------------------------------------

resource "docker_volume" "exchange" {
  name = "${var.project_name}-exchange"
}

# --- SFTP server (DMZ) -------------------------------------------------------

resource "docker_image" "sftp_server" {
  name = "${var.project_name}-sftp-server:latest"

  build {
    context = abspath("${path.module}/../sftp-server")
  }
}

resource "docker_container" "sftp_server" {
  name  = "${var.project_name}-sftp-server"
  image = docker_image.sftp_server.image_id

  # Runs its entrypoint as root (required to create users / chown before
  # sshd drops privileges per session), so no `user` override here.

  volumes {
    volume_name    = docker_volume.exchange.name
    container_path = "/data"
  }

  # NOTE (firewall.tf): the host-facing port used to be published directly
  # here (22 -> 2222). It is now published by the firewall container
  # instead, which DNATs it to this container -- see firewall.tf for the
  # full explanation and its documented scope limitation.

  networks_advanced {
    name = docker_network.dmz.name
  }

  labels {
    label = "purpose"
    value = "sftp-server"
  }
}

# --- Homemade encryption watcher (scientific/admin network) -----------------

resource "docker_image" "homemade_crypto" {
  name = "${var.project_name}-homemade-crypto:latest"

  build {
    context = abspath("${path.module}/../homemade-crypto")
  }
}

resource "docker_container" "homemade_crypto" {
  name  = "${var.project_name}-homemade-crypto"
  image = docker_image.homemade_crypto.image_id

  volumes {
    volume_name    = docker_volume.exchange.name
    container_path = "/exchange"
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  depends_on = [docker_container.sftp_server]

  labels {
    label = "purpose"
    value = "homemade-encryption-watcher"
  }

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "homemade-crypto"
  }
}
