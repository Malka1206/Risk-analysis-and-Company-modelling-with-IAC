# -----------------------------------------------------------------------------
# External stakeholders (Description.md section 6 / Plan_Maquette.txt
# section 15)
# -----------------------------------------------------------------------------

# --- Partner hospital: full SFTP flow implemented ---------------------------

resource "docker_image" "ext_hospital" {
  name = "${var.project_name}-ext-hospital:latest"

  build {
    context    = abspath("${path.module}/..")
    dockerfile = "external/hospital/Dockerfile"
  }
}

resource "docker_container" "ext_hospital" {
  name  = "${var.project_name}-ext-hopital-saint-martin"
  image = docker_image.ext_hospital.image_id

  env = [
    "SFTP_HOST=${docker_container.sftp_server.name}",
    "SFTP_USER=hopital_saint_martin",
    "SFTP_KEY_PATH=/keys/biolab_partner_key.key",
    "DOWNLOAD_DIR=/downloads",
  ]

  volumes {
    host_path      = abspath("${path.module}/../sftp-server/keys/biolab_partner_key.key")
    container_path = "/keys/biolab_partner_key.key"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.external.name
  }

  # Placeholder until firewall.tf exists (see external/attacker/Dockerfile
  # header for the asymmetry this creates with the attacker node).
  networks_advanced {
    name = docker_network.dmz.name
  }

  depends_on = [docker_container.sftp_server]

  labels {
    label = "purpose"
    value = "external-stakeholder-hospital"
  }
}

# --- Former developer / external contractor: residual access ---------------

resource "docker_image" "ext_former_contractor" {
  name = "${var.project_name}-ext-former-contractor:latest"

  build {
    context    = abspath("${path.module}/..")
    dockerfile = "external/former-contractor/Dockerfile"
  }
}

resource "docker_container" "ext_former_contractor" {
  name  = "${var.project_name}-ext-former-contractor"
  image = docker_image.ext_former_contractor.image_id

  env = [
    "SFTP_HOST=${docker_container.sftp_server.name}",
    "SFTP_KEY_PATH=/keys/former_contractor_key.key",
  ]

  volumes {
    host_path      = abspath("${path.module}/../sftp-server/keys/former_contractor_key.key")
    container_path = "/keys/former_contractor_key.key"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.external.name
  }

  networks_advanced {
    name = docker_network.dmz.name
  }

  depends_on = [docker_container.sftp_server]

  labels {
    label = "purpose"
    value = "external-stakeholder-former-contractor"
  }
}

# --- Generic attacker: perimeter-only, minimal tooling ----------------------

resource "docker_image" "ext_attacker" {
  name = "${var.project_name}-ext-attacker:latest"

  build {
    context = abspath("${path.module}/../external/attacker")
  }
}

resource "docker_container" "ext_attacker" {
  name  = "${var.project_name}-ext-attacker"
  image = docker_image.ext_attacker.image_id

  networks_advanced {
    name = docker_network.external.name
  }

  labels {
    label = "purpose"
    value = "external-stakeholder-attacker"
  }
}

# --- Lighter, simulated-only endpoints --------------------------------------
# Description.md section 6: "represented more lightly, mainly for the
# risk-analysis narrative and stakeholder richness". No protocol/flow
# implemented for these -- idle placeholders on the external network.

resource "docker_image" "alpine" {
  name = "alpine:3.19"
}

resource "docker_container" "ext_clinique" {
  name    = "${var.project_name}-ext-clinique-du-parc"
  image   = docker_image.alpine.image_id
  command = ["sleep", "infinity"]
  networks_advanced {
    name = docker_network.external.name
  }
  labels {
    label = "purpose"
    value = "external-stakeholder-clinic-placeholder"
  }
}

resource "docker_container" "ext_recherche" {
  name    = "${var.project_name}-ext-centre-recherche"
  image   = docker_image.alpine.image_id
  command = ["sleep", "infinity"]
  networks_advanced {
    name = docker_network.external.name
  }
  labels {
    label = "purpose"
    value = "external-stakeholder-research-center-placeholder"
  }
}

resource "docker_container" "ext_pharma" {
  name    = "${var.project_name}-ext-pharma-corp"
  image   = docker_image.alpine.image_id
  command = ["sleep", "infinity"]
  networks_advanced {
    name = docker_network.external.name
  }
  labels {
    label = "purpose"
    value = "external-stakeholder-pharma-placeholder"
  }
}
