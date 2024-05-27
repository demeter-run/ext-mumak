resource "kubernetes_deployment_v1" "pgbouncer" {
  wait_for_rollout = false
  metadata {
    labels = {
      role                   = var.instance_role
      "demeter.run/instance" = "${var.instance_name}-pgbouncer"
    }
    name      = "${var.instance_name}-pgbouncer"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    strategy {
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    selector {
      match_labels = {
        role                   = var.instance_role
        "demeter.run/instance" = "${var.instance_name}-pgbouncer"
      }
    }

    template {
      metadata {
        labels = {
          role                   = var.instance_role
          "demeter.run/instance" = "${var.instance_name}-pgbouncer"
        }
      }

      spec {
        container {
          name  = "main"
          image = "bitnami/pgbouncer:${var.image_tag}"

          resources {
            limits = {
              memory = "250Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "250Mi"
            }
          }

          port {
            container_port = 6432
            name           = "pgbouncer"
            protocol       = "TCP"
          }

          env {
            name  = "PGBOUNCER_DATABASE"
            value = "*"
          }

          env {
            name  = "POSTGRESQL_USERNAME"
            value = "postgres"
          }

          env {
            name = "POSTGRESQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = "postgres.postgres-mumak-m1"
                key  = "password"
              }
            }
          }

          env {
            name  = "POSTGRESQL_HOST"
            value = var.postgres_instance_name
          }

          env {
            name  = "POSTGRESQL_PORT"
            value = "5432"
          }

          env {
            name  = "PGBOUNCER_USERLIST_FILE"
            value = "/etc/pgbouncer/users.txt"
          }

          volume_mount {
            name       = "pgbouncer-users"
            mount_path = "/etc/pgbouncer"
          }

          volume_mount {
            name       = "pgbouncer-ini"
            mount_path = "/bitnami/pgbouncer/conf"
          }

          volume_mount {
            name       = "pgbouncer-certs"
            mount_path = "/certs"
          }

        }

        container {
          name  = "exporter"
          image = "prometheuscommunity/pgbouncer-exporter:v0.7.0"
          port {
            container_port = 9127
            name           = "metrics"
            protocol       = "TCP"
          }
          args = [
            "--pgBouncer.connectionString=postgres://pgbouncer:${var.auth_user_password}@localhost:6432/pgbouncer?sslmode=disable",
          ]

        }

        volume {
          name = "pgbouncer-users"
          config_map {
            name = "${var.instance_name}-pgbouncer-users"
          }
        }

        volume {
          name = "pgbouncer-ini"
          config_map {
            name = "${var.instance_name}-pgbouncer-ini"
          }
        }

        volume {
          name = "pgbouncer-certs"
          config_map {
            name = var.certs_configmap_name
          }
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-profile"
          operator = "Exists"
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
          value    = "best-effort"
        }
      }
    }
  }
}


resource "kubernetes_config_map" "mumak_pgbouncer_users" {
  metadata {
    namespace = var.namespace
    name      = "${var.instance_name}-pgbouncer-users"
  }

  data = {
    "users.txt" = "${templatefile("${path.module}/users.txt.tftpl", { auth_user_password = "${var.auth_user_password}", users = var.user_settings })}"
  }
}


resource "kubernetes_config_map" "mumak_pgbouncer_ini_config" {
  metadata {
    namespace = var.namespace
    name      = "${var.instance_name}-pgbouncer-ini"
  }

  data = {
    "pgbouncer.ini" = "${templatefile("${path.module}/pgbouncer.ini.tftpl", { db_host = "${var.postgres_instance_name}", users = var.user_settings })}"
  }
}
