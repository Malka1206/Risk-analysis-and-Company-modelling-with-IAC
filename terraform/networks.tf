# -----------------------------------------------------------------------------
# Network segmentation for the BioLab Analytics mockup.
# See Plan_Maquette.txt section 8 for the rationale.
#
# - net_sci_admin : SCIENTIFIC + ADMINISTRATIVE, deliberately merged.
#                    Hosts the compute node, storage, LIMS, patient-db,
#                    the lab automation device, and most workstations.
# - net_it        : IT / MANAGEMENT network (LDAP, log server, bastion).
#                    Services that must be reachable for authentication /
#                    centralized logging / administration across the whole
#                    company (LDAP, log server, bastion) are dual-attached
#                    to net_it AND net_sci_admin -- this mirrors how a real
#                    directory service or SIEM collector is usually reachable
#                    from every internal segment, while true perimeter
#                    control is only enforced at the DMZ boundary (see
#                    firewall.tf, added in a later section).
# - net_dmz       : DMZ, hosts the SFTP server.
# - net_external  : simulates partner endpoints (hospitals, clinics...) and
#                    the generic attacker node. Only reaches the DMZ.
# -----------------------------------------------------------------------------

resource "docker_network" "sci_admin" {
  name = "${var.project_name}-net-sci-admin"

  ipam_config {
    subnet = var.subnet_sci_admin
  }
}

resource "docker_network" "it" {
  name = "${var.project_name}-net-it"

  ipam_config {
    subnet = var.subnet_it
  }
}

resource "docker_network" "dmz" {
  name = "${var.project_name}-net-dmz"

  ipam_config {
    subnet = var.subnet_dmz
  }
}

resource "docker_network" "external" {
  name = "${var.project_name}-net-external"

  ipam_config {
    subnet = var.subnet_external
  }
}
