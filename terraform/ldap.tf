# -----------------------------------------------------------------------------
# LDAP / IAM (Description.md section 6.1)
#
# Deliberate weaknesses:
#   - LDAP_TLS = false -> plaintext LDAP (port 389), no encryption in transit.
#   - Weak/default admin & config passwords (see variables.tf).
#   - Every account has its own password, but all of them are weak
#     (short, dictionary-based, no complexity policy) -- see the table at
#     the top of 01-users.ldif.
#   - Every account lives in a single flat "employees" group (01-users.ldif):
#     no privilege separation between technician / biologist / etc.
#   - phpLDAPAdmin (the management UI) is published on the host with no
#     network restriction.
#
# Anonymous bind is explicitly DISABLED (02-disable-anonymous-bind.ldif):
# every workstation and service must authenticate with a real account.
# There is intentionally no unauthenticated read/search path anymore.
#
# Reachability: dual-attached to net_it (its home network) and
# net_sci_admin, since every workstation across the company needs to bind
# against it for authentication (see networks.tf for the rationale).
# -----------------------------------------------------------------------------

resource "docker_image" "openldap" {
  name = "osixia/openldap:1.5.0"
}

resource "docker_image" "phpldapadmin" {
  name = "osixia/phpldapadmin:0.9.0"
}

resource "docker_container" "ldap" {
  name  = "${var.project_name}-ldap"
  image = docker_image.openldap.image_id

  env = [
    "LDAP_ORGANISATION=${var.ldap_organisation}",
    "LDAP_DOMAIN=${var.ldap_domain}",
    "LDAP_ADMIN_PASSWORD=${var.ldap_admin_password}",
    "LDAP_CONFIG_PASSWORD=${var.ldap_config_password}",
    # Deliberate weakness: no TLS on the directory service.
    "LDAP_TLS=false",
  ]

  volumes {
    host_path      = abspath("${path.module}/../ldap/bootstrap")
    container_path = "/container/service/slapd/assets/config/bootstrap/ldif/custom"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.it.name
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  labels {
    label = "purpose"
    value = "iam-directory"
  }

  # Centralized logging (Description.md section 6.2): unauthenticated,
  # unencrypted UDP syslog to the bastion/log server.
  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "ldap"
  }
}

resource "docker_container" "phpldapadmin" {
  name  = "${var.project_name}-phpldapadmin"
  image = docker_image.phpldapadmin.image_id

  env = [
    "PHPLDAPADMIN_LDAP_HOSTS=${docker_container.ldap.name}",
    "PHPLDAPADMIN_HTTPS=false", # deliberate: plain HTTP admin console
  ]

  # Deliberate weakness: published on the host without any access
  # restriction (no VPN / IP allowlist / reverse-proxy auth in front of it).
  ports {
    internal = 80
    external = 8081
  }

  networks_advanced {
    name = docker_network.it.name
  }

  depends_on = [docker_container.ldap]

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_it}:514"
    "tag"            = "phpldapadmin"
  }
}
