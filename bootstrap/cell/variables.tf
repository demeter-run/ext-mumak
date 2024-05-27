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

variable "postgres_settings" {
  default = {
    listen_addresses                 = "*"
    max_connections                  = 101
    shared_buffers                   = "12GB"
    effective_cache_size             = "36GB"
    maintenance_work_mem             = "2GB"
    checkpoint_completion_target     = 0.9
    wal_buffers                      = "16MB"
    default_statistics_target        = 500
    random_page_cost                 = 1.1
    effective_io_concurrency         = 200
    work_mem                         = "15728kB"
    huge_pages                       = "try"
    min_wal_size                     = "4GB"
    max_wal_size                     = "16GB"
    max_worker_processes             = 8
    max_parallel_workers_per_gather  = 4
    max_parallel_workers             = 8
    max_parallel_maintenance_workers = 4
    ssl                              = "off"
    shared_preload_libraries         = "pg_stat_statements"
    max_pred_locks_per_transaction   = 256
  }
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
    network          = string
    testnet_magic    = string
    node_private_dns = string
    redis_url        = string
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
