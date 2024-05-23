variable "namespace" {
  type = string
}

variable "instance_name" {
  default = "mumak-m1-pgbouncer"
}

variable "service_name" {
  default = "mumak-m1-pgbouncer"
}

variable "pg_bouncer_image_tag" {
  default = "1.21.0"
}

# variable "dbsync_probe_image_tag" {
#   default = "27a9dbc30253e7d2036f1d6648d406f3d17a90e2"
# }

variable "pg_bouncer_replicas" {
  default = 1
}

variable "load_balancer" {
  default = false
}

variable "certs_configmap_name" {
  type = string
  default = "pgbouncer-certs"
}

variable "pg_bouncer_user_settings" {
  default = []
  type = list(object({
    name            = string
    password        = string
    max_connections = number
  }))
}

variable "pg_bouncer_auth_user_password" {
  type = string
  default = ""
}

variable "postgres_secret_name" {
  type = string
  default = ""
}

variable "instance_role" {
  type = string
  default = "pgbouncer"
}

variable "postgres_instance_name" {
  type = string
  default = "postgres-mumak-m1-ar9"
}

resource "kubernetes_service_v1" "_pgbouncer_elb" {
  count = var.load_balancer ? 1 : 0
  metadata {
    namespace = var.namespace
    name      = var.service_name
    annotations = {
      "beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"  = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-type"    = "external"
    }
  }

  spec {
    type                = "LoadBalancer"
    load_balancer_class = "service.k8s.aws/nlb"

    port {
      protocol    = "TCP"
      port        = 5432
      target_port = 6432
    }

    selector = {
      "role" = var.instance_role
    }
  }
}
