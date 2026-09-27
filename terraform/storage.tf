# -----------------------------------------------------------------------------
# High-performance storage (Description.md section 3.2)
#
# MinIO is used as the S3-compatible bucket receiving raw results
# automatically from the compute node (compute.tf). A one-shot "mc" job
# creates the bucket on first apply.
#
# Deliberate weaknesses:
#   - Weak/default root credentials (see variables.tf).
#   - Plain HTTP for now (no TLS): the PKI section of the mockup will later
#     wrap this with the internal CA, at which point the compute node's
#     upload flow will KEEP verification disabled on purpose (see
#     compute-node/app.py) -- documented inconsistency in the internal PKI.
#   - Reachable only from net_sci_admin, i.e. from the same flat network as
#     the administrative workstations and the patient database.
# -----------------------------------------------------------------------------

resource "docker_image" "minio" {
  name = "quay.io/minio/aistor/minio:RELEASE.2026-08-07T18-34-35Z"
}

resource "docker_container" "minio" {
  name  = "${var.project_name}-minio"
  image = docker_image.minio.image_id

  command = ["server", "/data", "--console-address", ":9001"]

  env = [
    "MINIO_ROOT_USER=${var.minio_root_user}",
    "MINIO_ROOT_PASSWORD=${var.minio_root_password}",
  ]

  # Real HTTPS with a certificate signed by BioLab's internal CA (see
  # pki/). MinIO auto-detects TLS when public.crt/private.key are present
  # under /root/.minio/certs.
  volumes {
    host_path      = abspath("${path.module}/../pki/minio.crt")
    container_path = "/root/.minio/certs/public.crt"
    read_only      = true
  }

  volumes {
    host_path      = abspath("${path.module}/../pki/minio.key")
    container_path = "/root/.minio/certs/private.key"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  labels {
    label = "purpose"
    value = "raw-results-storage"
  }

  log_driver = "syslog"
  log_opts = {
    "syslog-address" = "udp://${var.log_server_ip_sci_admin}:514"
    "tag"            = "minio"
  }
}

resource "docker_image" "minio_client" {
  name = "quay.io/minio/aistor/mc:latest"
}

# One-shot job: waits for MinIO, then creates the raw-results bucket.
resource "docker_container" "minio_init" {
  name       = "${var.project_name}-minio-init"
  image      = docker_image.minio_client.image_id
  entrypoint = ["/bin/sh", "-c"]
  command = [
    <<-EOT
      until mc --insecure alias set local https://${docker_container.minio.name}:9000 ${var.minio_root_user} ${var.minio_root_password}; do
        sleep 2
      done
      mc --insecure mb -p local/${var.minio_bucket_raw_results}
    EOT
  ]

  networks_advanced {
    name = docker_network.sci_admin.name
  }

  must_run = false
  rm       = false

  depends_on = [docker_container.minio]
}
