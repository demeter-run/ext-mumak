// Each cell of the mumak extension containes 1 PVC, 1 Postgres instance, 1
// PGBouncer that acts proxy and an amount of indexers (commonly 3, one per
// network).
locals {
  postgres_host = "postgres-${var.salt}"
}
module "mumak_pvc" {
  source             = "../pvc"
  namespace          = var.namespace
  volume_name        = var.volume_name
  storage_size       = var.storage_size
  storage_class_name = var.storage_class_name
  name               = "pvc-${var.salt}"
}

module "mumak_postgres" {
  source = "../postgres"

  namespace            = var.namespace
  db_volume_claim      = "pvc-${var.salt}"
  instance_name        = local.postgres_host
  databases            = var.databases
  postgres_config_name = "postgres-config-${var.salt}"
  topology_zone        = var.topology_zone
  image_tag            = var.postgres_image_tag
  postgres_secret_name = var.postgres_secret_name
  postgres_resources   = var.postgres_resources
  postgres_tolerations = coalesce(var.postgres_tolerations, [
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-profile"
      operator = "Exists"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-arch"
      operator = "Exists"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/availability-sla"
      operator = "Equal"
      value    = "consistent"
    }
  ])
}

module "mumak_pgbouncer" {
  source = "../pgbouncer"

  namespace                    = var.namespace
  replicas                     = var.pgbouncer_replicas
  certs_configmap_name         = var.certs_configmap_name
  user_settings                = var.pgbouncer_user_settings
  auth_user_password           = var.pgbouncer_auth_user_password
  instance_role                = "pgbouncer"
  postgres_secret_name         = var.postgres_secret_name
  instance_name                = "pgbouncer-${var.salt}"
  postgres_instance_name       = local.postgres_host
  pgbouncer_reloader_image_tag = var.pgbouncer_reloader_image_tag
}

module "mumak_indexers" {
  source   = "../indexer"
  for_each = var.indexers

  namespace            = var.namespace
  instance_name        = "indexer-${each.key}-${var.salt}"
  image_tag            = coalesce(each.value.image_tag, "latest")
  image                = coalesce(each.value.image, "ghcr.io/txpipe/oura")
  network              = each.value.network
  db                   = each.value.db
  testnet_magic        = each.value.testnet_magic
  node_private_dns     = each.value.node_private_dns
  postgres_host        = local.postgres_host
  postgres_secret_name = var.postgres_secret_name
  tolerations = coalesce(each.value.tolerations, [
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-profile"
      operator = "Equal"
      value    = "general-purpose"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-arch"
      operator = "Equal"
      value    = "x86"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/availability-sla"
      operator = "Exists"
    }
  ])
  resources = coalesce(each.value.resources, {
    limits : {
      cpu : "200m",
      memory : "1Gi"
    }
    requests : {
      cpu : "200m",
      memory : "500Mi"
    }
  })
}
