resource "kubernetes_config_map" "config" {
  metadata {
    namespace = var.namespace
    name      = local.configmap_name
  }

  data = {
    "daemon.json" = jsonencode({
      "source" : {
        "type" : "N2C",
        "path" : "/ipc/node.socket"
        "min_depth" : 2
      },
      "intersect" : var.intersect_config
      "chain" : {
        "type" : var.network
      },
      "cursor" : {
        "type" : "Redis",
        "key" : "mumak:cursor:network:${var.network}",
        "url": var.redis_url
      }
      "policy" : {
        "missing_data" : "Skip"
        "cbor_errors" : "Warn"
      }
    })
  }
}
