resource "kubernetes_deployment_v1" "indexer" {
  wait_for_rollout = false

  metadata {
    name      = var.instance_name
    namespace = var.namespace
    labels = {
      "role"                        = "indexer"
      "demeter.run/kind"            = "MumakIndexer"
      "cardano.demeter.run/network" = var.network
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "role"                        = "indexer"
        "demeter.run/instance"        = var.instance_name
        "cardano.demeter.run/network" = var.network
      }
    }

    template {

      metadata {
        name = var.instance_name
        labels = {
          "role"                        = "indexer"
          "demeter.run/instance"        = var.instance_name
          "cardano.demeter.run/network" = var.network
        }
      }

      spec {
        restart_policy = "Always"

        security_context {
          fs_group = 1000
        }

        container {
          name              = "indexer"
          image             = "ghcr.io/txpipe/oura:${var.image_tag}"
          args              = ["daemon", "--config", "/etc/oura/daemon.toml"]
          image_pull_policy = "IfNotPresent"

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

          env {
            name  = "RUST_LOG"
            value = "debug"
          }

          volume_mount {
            name       = "ipc"
            mount_path = "/ipc"
          }

          volume_mount {
            name       = "oura_config_${var.network}"
            mount_path = "/etc/oura"
          }
        }

        container {
          name  = "socat"
          image = "alpine/socat"
          args = [
            "UNIX-LISTEN:/ipc/node.socket,reuseaddr,fork,unlink-early",
            "TCP-CONNECT:${var.node_private_dns}"
          ]

          security_context {
            run_as_user  = 1000
            run_as_group = 1000
          }

          volume_mount {
            name       = "ipc"
            mount_path = "/ipc"
          }
        }

        volume {
          name = "ipc"
          empty_dir {}
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

