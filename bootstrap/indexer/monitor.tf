resource "kubernetes_manifest" "indexer_podmonitor" {
  manifest = {
    "apiVersion" = "monitoring.coreos.com/v1"
    "kind"       = "PodMonitor"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/component" = "o11y"
        "app.kubernetes.io/part-of"   = "demeter"
      }
      "name"      = "${var.instance_name}-indexer"
      "namespace" = var.namespace
    }
    "spec" = {
      podMetricsEndpoints = [
        {
          port = "metrics",
          path = "/metrics"
        }
      ]
      "selector" = {
        "matchLabels" = {
          "demeter.run/instance" = "${var.instance_name}-indexer"
        }
      }
    }
  }
}
