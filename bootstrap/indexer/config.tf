resource "kubernetes_config_map" "block_config" {
  metadata {
    namespace = var.namespace
    name      = local.block_configmap_name
  }

  data = {
    "daemon.toml" = "${templatefile("${path.module}/block.daemon.toml.tftpl", { network = var.network })}"
  }
}

resource "kubernetes_config_map" "tx_config" {
  metadata {
    namespace = var.namespace
    name      = local.tx_configmap_name
  }

  data = {
    "daemon.toml" = "${templatefile("${path.module}/tx.daemon.toml.tftpl", { network = var.network })}"
  }
}

resource "kubernetes_config_map" "utxo_config" {
  metadata {
    namespace = var.namespace
    name      = local.utxo_configmap_name
  }

  data = {
    "daemon.toml" = "${templatefile("${path.module}/utxo.daemon.toml.tftpl", { network = var.network })}"
  }
}
