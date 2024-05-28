variable "db_volume_claim" {
  type = string
}

variable "namespace" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "databases" {
  type = string
  description = "Space separated list."
}

variable "topology_zone" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "postgres_config_name" {
  default = "postgres-config"
}

variable "postgres_resources" {
  type = object({
    requests = map(string)
    limits   = map(string)
  })

  default = {
    "limits" = {
      memory = "2Gi"
      cpu    = "4000m"
    }
    "requests" = {
      memory = "2Gi"
      cpu    = "100m"
    }
  }
}

variable "postgres_secret_name" {
  type = string
}
