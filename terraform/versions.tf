terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.6.0"
    }
  }
}

provider "docker" {
  # Uses the local Docker daemon (unix socket) by default.
  # Override with DOCKER_HOST if needed.
}
