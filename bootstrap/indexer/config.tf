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
      "filters" : [
        {
          type : "EmitCbor"
        }
      ]
      "sink" : {
        "type" : "SqlDb"
        "apply_cbor_block_template" : "INSERT INTO blocks (slot, cbor) VALUES ('{{point.slot}}', decode('{{record.hex}}', 'hex'));"
        "undo_cbor_block_template" : "DELETE FROM blocks WHERE slot = {{point.slot}}"
        "apply_cbor_tx_template" : "INSERT INTO txs (slot, cbor) VALUES ('{{point.slot}}', decode('{{record.hex}}', 'hex'));"
        "undo_cbor_tx_template" : "DELETE FROM txs WHERE slot = {{point.slot}}"
        "reset_cbor_block_template" : "DELETE FROM blocks WHERE slot > {{point.slot}};"
        "reset_cbor_tx_template" : "DELETE FROM txs WHERE slot > {{point.slot}};"
      }
      "chain" : {
        "type" : var.network
      },
      "cursor" : {
        "type" : "File",
        "path" : "cursor"
      }
      "policy" : {
        "missing_data" : "Skip"
        "cbor_errors" : "Warn"
      }
    })
  }
}
