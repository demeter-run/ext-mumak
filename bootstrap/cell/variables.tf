variable "namespace" {
  type = string
}

variable "salt" {
  type        = string
  description = "Salt used to identify all components as part of the cell. Should be unique between cells."
}

variable "certs_configmap_name" {
  type    = string
  default = "pgbouncer-certs"
}

// PVC
variable "volume_name" {
  type = string
}

variable "storage_size" {
  type = string
}

// Postgres
variable "databases" {
  type        = string
  description = "Space separated list"
}

variable "topology_zone" {
  type = string
}

variable "postgres_image_tag" {
  type = string
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

// PGBouncer
variable "pgbouncer_image_tag" {
  default = "1.21.0"
}

variable "pgbouncer_replicas" {
  default = 1
}

variable "pgbouncer_user_settings" {
  default = []
  type = list(object({
    name            = string
    password        = string
    max_connections = number
  }))
}

variable "pgbouncer_auth_user_password" {
  type = string
}

// Indexers
variable "indexers" {
  type = map(object({
    image_tag        = optional(string)
    image            = optional(string)
    network          = string
    db               = string
    testnet_magic    = string
    node_private_dns = string
    intersect_config = optional(any)
    resources = optional(object({
      limits = object({
        cpu    = string
        memory = string
      })
      requests = object({
        cpu    = string
        memory = string
      })
    }))
  }))
}
