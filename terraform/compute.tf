# -----------------------------------------------------------------------------
# Compute node / HPC pipeline (Description.md section 3.1)
#
# Built locally from ../compute-node (Flask app performing a real, if
# simplified, FASTA-in / result-file-out analysis, auto-uploaded to MinIO).
# -----------------------------------------------------------------------------

resource "docker_image" "compute_node" {
  name = "${var.project_name}-compute-node:latest"

  build {
    context = abspath("${path.module}/../compute-node")
  }
}

resource "docker_container" "compute_node" {
  name  = "${var.project_name}-compute-node"
  image = docker_image.compute_node.image_id

  env = [
    "MINIO_ENDPOINT=https://${docker_container.minio.name}:9000",
    "MINIO_ACCESS_KEY=${var.minio_root_user}",
    "MINIO_SECRET_KEY=${var.minio_root_password}",
    "MINIO_BUCKET=${var.minio_bucket_raw_results}",
  ]

  ports {
    internal = 5000
    external = 5000
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  depends_on = [docker_container.minio_init]

  labels {
    label = "purpose"
    value = "compute-node"
  }

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "compute-node"
  }
}
