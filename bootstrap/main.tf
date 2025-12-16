resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

// Feature
module "mumak_feature" {
  depends_on = [kubernetes_namespace.namespace]
  source     = "./feature"

  namespace          = var.namespace
  operator_image_tag = var.operator_image_tag
  key_salt           = var.key_salt
  metrics_delay      = var.metrics_delay
  db_max_connections = var.db_max_connections
  resources          = var.operator_resources

  postgres_password    = var.postgres_password
  postgres_secret_name = var.postgres_secret_name
  pgbouncer_server_crt = var.pgbouncer_server_crt
  pgbouncer_server_key = var.pgbouncer_server_key

  postgres_hosts = coalesce(var.postgres_hosts, [for key in keys(var.cells) : "postgres-${key}"])
}

// Service
module "mumak_service" {
  depends_on = [kubernetes_namespace.namespace]
  source     = "./service"

  namespace = var.namespace
}

// Cells
module "mumak_cells" {
  depends_on = [module.mumak_feature]
  for_each   = var.cells
  source     = "./cell"

  namespace = var.namespace
  salt      = each.key

  // PVC
  volume_name  = each.value.pvc.volume_name
  storage_size = each.value.pvc.storage_size

  // PG
  topology_zone        = each.value.postgres.topology_zone
  postgres_image_tag   = each.value.postgres.image_tag
  postgres_secret_name = var.postgres_secret_name
  postgres_resources   = each.value.postgres.resources
  databases            = each.value.postgres.databases

  // PGBouncer
  pgbouncer_image_tag          = var.pgbouncer_image_tag
  pgbouncer_replicas           = each.value.pgbouncer.replicas
  pgbouncer_user_settings      = var.pgbouncer_user_settings
  pgbouncer_auth_user_password = var.pgbouncer_auth_user_password
  pgbouncer_reloader_image_tag = var.pgbouncer_reloader_image_tag

  // Indexers
  indexers = each.value.indexers
}
