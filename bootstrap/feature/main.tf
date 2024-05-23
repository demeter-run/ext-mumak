variable "namespace" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "operator_image_tag" {
  type = string
}

variable "key_salt" {
  type = string
}

variable "metrics_delay" {
  default = 30
}

variable "db_max_connections" {
  default = 2
}

variable "dcu_per_second" {
  type = map(string)
  default = {
    "mainnet" = "10"
    "preprod" = "5"
    "preview" = "5"
  }
}


variable "postgres_hosts" {
  type = list(string)
}

variable "postgres_secret_name" {
  type = string
}

variable "postgres_password" {
  type = string
}

variable "pgbouncer_server_crt" {
  type = string
}

variable "pgbouncer_server_key" {
  type = string
}

variable "resources" {
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "1"
      memory = "512Mi"
    }
    requests = {
      cpu    = "50m"
      memory = "512Mi"
    }
  }
}
