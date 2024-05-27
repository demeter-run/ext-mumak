locals {
  postgres_urls          = [for host in var.postgres_hosts : "postgres://postgres:$(POSTGRES_PASSWORD)@${host}:5432"]
  combined_postgres_urls = join(",", local.postgres_urls)
}

resource "kubernetes_deployment_v1" "operator" {
  wait_for_rollout = false

  metadata {
    namespace = var.namespace
    name      = "operator"
    labels = {
      role = "operator"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        role = "operator"
      }
    }

    template {
      metadata {
        labels = {
          role = "operator"
        }
      }

      spec {
        container {
          image = "ghcr.io/demeter-run/ext-mumak:${var.operator_image_tag}"
          name  = "main"

          env {
            name  = "K8S_IN_CLUSTER"
            value = "true"
          }

          env {
            name  = "METRICS_DELAY"
            value = var.metrics_delay
          }

          env {
            name  = "ADDR"
            value = "0.0.0.0:5000"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = "password"
              }
            }
          }

          env {
            name  = "DCU_PER_SECOND"
            value = "mainnet=${var.dcu_per_second["mainnet"]},preprod=${var.dcu_per_second["preprod"]},preview=${var.dcu_per_second["preview"]}"
          }

          env {
            name  = "DB_URLS"
            value = local.combined_postgres_urls
          }

          env {
            name  = "DB_NAMES"
            value = "mainnet=mumak-mainnet,preprod=mumak-preprod,preview=mumak-preview,vector-testnet=mumak-vector-testnet"
          }

          env {
            name  = "DB_MAX_CONNECTIONS"
            value = var.db_max_connections
          }

          env {
            name  = "RUST_BACKTRACE"
            value = "1"
          }

          env {
            name  = "PROMETHEUS_URL"
            value = "http://prometheus-operated.demeter-system.svc.cluster.local:9090/api/v1"
          }

          env {
            name  = "KEY_SALT"
            value = var.key_salt
          }


          resources {
            limits = {
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
            requests = {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }
          }

          port {
            name           = "metrics"
            container_port = 5000
            protocol       = "TCP"
          }
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-profile"
          operator = "Equal"
          value    = "general-purpose"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-arch"
          operator = "Equal"
          value    = "x86"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/availability-sla"
          operator = "Equal"
          value    = "consistent"
        }
      }
    }
  }
}

