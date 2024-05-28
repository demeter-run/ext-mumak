resource "kubernetes_config_map" "config" {
  metadata {
    namespace = var.namespace
    name      = local.configmap_name
  }

  data = {
    "daemon.toml" = "${templatefile("${path.module}/daemon.toml.tftpl", { network = var.network })}"
  }
}
