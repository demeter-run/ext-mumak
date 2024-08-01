locals {
  users_volume         = "/etc/pgbouncer"
  tiers_configmap_name = "mumak-tiers"
}

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
                name = var.postgres_secret_name
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

          volume_mount {
            name       = "pgbouncer-users"
            mount_path = local.users_volume
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

        container {
          name  = "pgbouncer-reloader"
          image = "ghcr.io/demeter-run/pgbouncer-reloader:${var.pgbouncer_reloader_image_tag}"

          resources {
            limits = {
              memory = "250Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "250Mi"
            }
          }

          env {
            name  = "TIERS_PATH"
            value = "/etc/tiers/tiers.toml"
          }

          env {
            name  = "API_RESOURCE_GROUP"
            value = "demeter.run"
          }

          env {
            name  = "API_RESOURCE_VERSION"
            value = "v1alpha1"
          }

          env {
            name  = "API_RESOURCE_API_VERSION"
            value = "demeter.run/v1alpha1"
          }

          env {
            name  = "API_RESOURCE_KIND"
            value = "MumakPort"
          }

          env {
            name  = "API_RESOURCE_PLURAL"
            value = "mumakports"
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
            name  = "CONNECTION_OPTIONS"
            value = "host=localhost user=pgbouncer password=${var.auth_user_password} dbname=pgbouncer port=6432"
          }

          env {
            name  = "PGBOUNCER_PASSWORD"
            value = var.auth_user_password
          }

          env {
            name  = "USERS_INI_FILEPATH"
            value = "${local.users_volume}/users.ini"
          }

          env {
            name  = "USERLIST_FILEPATH"
            value = "${local.users_volume}/userlist.txt"
          }

          volume_mount {
            name       = "pgbouncer-users"
            mount_path = local.users_volume
          }

          volume_mount {
            name       = "tiers"
            mount_path = "/etc/tiers"
          }
        }

        init_container {
          name  = "init-user-files"
          image = "busybox:1.28"
          command = [
            "sh", "-c",
            "touch ${local.users_volume}/users.ini ${local.users_volume}/userlist.txt; echo '\"pgbouncer\" \"${var.auth_user_password}\"' > ${local.users_volume}/userlist.txt"
          ]

          volume_mount {
            name       = "pgbouncer-users"
            mount_path = local.users_volume
          }
        }

        volume {
          name = "pgbouncer-users"
          empty_dir {}
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

        volume {
          name = "tiers"
          config_map {
            name = local.tiers_configmap_name
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


resource "kubernetes_config_map" "mumak_pgbouncer_tiers" {
  metadata {
    namespace = var.namespace
    name      = local.tiers_configmap_name
  }

  data = {
    "tiers.toml" = file("${path.module}/tiers.toml")
  }
}


resource "kubernetes_config_map" "mumak_pgbouncer_ini_config" {
  metadata {
    namespace = var.namespace
    name      = "${var.instance_name}-pgbouncer-ini"
  }

  data = {
    "pgbouncer.ini" = "${templatefile("${path.module}/pgbouncer.ini.tftpl", {
      db_host      = "${var.postgres_instance_name}",
      users        = var.user_settings,
      users_volume = local.users_volume
    })}"
    # Empty file to bypass bitnami userlist bootstrapping, which we do ourselves.
    "userlist.txt" = ""
  }
}
