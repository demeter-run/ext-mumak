variable "namespace" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "1.21.0"
}

variable "pgbouncer_tier_updater_image_tag" {
  type = string
}

variable "replicas" {
  default = 1
}

variable "load_balancer" {
  default = false
}

variable "certs_configmap_name" {
  type = string
}

variable "user_settings" {
  default = []
  type = list(object({
    name            = string
    password        = string
    max_connections = number
  }))
}

variable "auth_user_password" {
  type = string
}

variable "postgres_secret_name" {
  type = string
}

variable "instance_role" {
  type    = string
  default = "pgbouncer"
}

variable "postgres_instance_name" {
  type = string
}
