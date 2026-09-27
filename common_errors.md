# Common Errors --- Terraform + Docker Lab

## Purpose

This document records the main errors encountered while deploying the
BioLab Analytics infrastructure with Terraform and Docker.

------------------------------------------------------------------------

## 1. Docker Network Destruction Timeout

### Error

Terraform reported several errors of this form:

``` text
Error: timeout while waiting for state to become 'removed'
(last state: 'pending', timeout: 30s)
```

This occurred while Terraform was trying to remove Docker networks.

### Diagnosis

The Docker networks were not being removed within Terraform's 30-second
timeout. This can happen when Docker containers or network endpoints are
still attached to the network.

### Fix / Resolution

The infrastructure was destroyed and recreated cleanly:

``` powershell
terraform destroy
```

followed by:

``` powershell
terraform apply
```

This cleared the previous infrastructure state before attempting a fresh
deployment.

------------------------------------------------------------------------

## 2. `archive/tar: invalid tar header` During Terraform Docker Builds

### Error

Terraform reported:

``` text
Error: Error running legacy build:
failed to read dockerfile: archive/tar: invalid tar header
```

This occurred for:

-   `docker_image.bastion_logs`
-   `docker_image.ext_hospital`

A related compression error occurred for the former-contractor image:

``` text
unpigz: skipping: <stdin>: corrupted -- invalid deflate data
(invalid literal/length code)
```

### Diagnosis

The Dockerfiles themselves were not invalid.

The three Dockerfiles were successfully built manually with Docker:

``` powershell
docker build -f ..\logging\Dockerfile ..
docker build -f ..\external\hospital\Dockerfile ..
docker build -f ..\external\former-contractor\Dockerfile ..
```

Therefore, the problem was specific to Terraform/provider handling of
the Docker build context rather than a syntax error in the Dockerfiles.

### Fix / Action Taken

The Docker provider version was updated in `versions.tf` to:

``` hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.6.0"
    }
  }
}
```

Then Terraform was reinitialized:

``` powershell
terraform init -upgrade
```

and checked with:

``` powershell
terraform providers
terraform plan
```

------------------------------------------------------------------------

## 3. MinIO Image Pull --- `pull access denied`

### Error

Terraform initially failed to pull:

``` text
minio/minio:latest
```

Docker returned:

``` text
pull access denied for minio/minio, repository does not exist
or may require 'docker login'
```

The same issue occurred with:

``` text
minio/mc:latest
```

### Diagnosis

The image references used by the Terraform configuration were no longer
usable from the configured Docker registry path.

### Fix

The Terraform resources were changed to:

``` hcl
resource "docker_image" "minio" {
  name = "quay.io/minio/aistor/minio:RELEASE.2026-08-07T18-34-35Z"
}
```

and:

``` hcl
resource "docker_image" "minio_client" {
  name = "quay.io/minio/aistor/mc:latest"
}
```

Then:

``` powershell
terraform plan
```

completed successfully without errors.

------------------------------------------------------------------------

## 4. Firewall Container --- `container exited immediately`

### Error

Terraform reported:

``` text
Error: container exited immediately

with docker_container.firewall,
on firewall.tf line 15
```

### Diagnosis

The firewall container used:

``` dockerfile
ENTRYPOINT ["/entrypoint.sh"]
```

The entrypoint script attempted to resolve the SFTP server with:

``` sh
SFTP_TARGET_IP=$(getent hosts sftp-server | awk '{print $1}')
```

The actual Docker container name was:

``` text
biolab-sftp-server
```

because Terraform defined:

``` hcl
name = "${var.project_name}-sftp-server"
```

The SFTP server was correctly attached to:

``` text
biolab-net-dmz
```

and had the IP:

``` text
10.10.3.2
```

However, testing:

``` powershell
docker run --rm --network biolab-net-dmz alpine:3.19 getent hosts sftp-server
```

returned no address.

The firewall therefore could not resolve `sftp-server` and exited.

### Fix

The minimal fix is to change the hostname used by the firewall
entrypoint from:

``` sh
SFTP_TARGET_IP=$(getent hosts sftp-server | awk '{print $1}')
```

to:

``` sh
SFTP_TARGET_IP=$(getent hosts biolab-sftp-server | awk '{print $1}')
```

Then rebuild/reapply:

``` powershell
terraform apply
```

------------------------------------------------------------------------

## 6. Docker Container Drift --- LDAP

### Warning

Terraform detected that:

``` text
docker_container.ldap
```

had been deleted outside Terraform.

This is a Terraform state drift situation rather than a Docker build
error.

### Meaning

Terraform expected the LDAP container to exist according to its state,
but Docker no longer had that container.

### Resolution

A fresh deployment with:

``` powershell
terraform destroy
terraform apply
```

