resource "kubernetes_stateful_set_v1" "utxo_indexer" {
  wait_for_rollout = false

  metadata {
    name      = local.utxo_instance_name
    namespace = var.namespace
    labels = {
      "role"                        = "UtxoIndexer"
      "demeter.run/kind"            = "MumakUtxoIndexer"
      "cardano.demeter.run/network" = var.network
    }
  }


  spec {
    replicas     = 1
    service_name = "mumak-utxo-indexer"

    selector {
      match_labels = {
        "role"                        = "UtxoIndexer"
        "demeter.run/instance"        = local.utxo_instance_name
        "cardano.demeter.run/network" = var.network
      }
    }

    volume_claim_template {
      metadata {
        name      = "data"
        namespace = var.namespace
        labels = {
          "demeter.run/instance" = local.utxo_instance_name
        }
      }
      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "1Gi"
          }
        }
        storage_class_name = "gp3"
      }
    }

    template {

      metadata {
        name = local.utxo_instance_name
        labels = {
          "role"                        = "UtxoIndexer"
          "demeter.run/instance"        = local.utxo_instance_name
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
          image             = "${var.image}:${var.image_tag}"
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
            name  = "OURA_SINK_CONNECTION"
            value = "postgres://postgres:$(POSTGRES_PASSWORD)@${var.postgres_host}:5432/${var.db}"
          }

          port {
            container_port = 9186
            name           = "metrics"
          }

          volume_mount {
            name       = "ipc"
            mount_path = "/ipc"
          }

          volume_mount {
            name       = "configs"
            mount_path = "/etc/oura"
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
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

        volume {
          name = "configs"
          config_map {
            name = local.utxo_configmap_name
          }
        }

        dynamic "toleration" {
          for_each = var.tolerations

          content {
            effect   = toleration.value.effect
            key      = toleration.value.key
            operator = toleration.value.operator
            value    = toleration.value.value
          }
        }
      }
    }
  }
}

