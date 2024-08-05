resource "kubernetes_manifest" "customresourcedefinition_mumakports_demeter_run" {
  manifest = {
    "apiVersion" = "apiextensions.k8s.io/v1"
    "kind" = "CustomResourceDefinition"
    "metadata" = {
      "name" = "mumakports.demeter.run"
    }
    "spec" = {
      "group" = "demeter.run"
      "names" = {
        "categories" = [
          "demeter-port",
        ]
        "kind" = "MumakPort"
        "plural" = "mumakports"
        "shortNames" = [
          "mumak",
        ]
        "singular" = "mumakport"
      }
      "scope" = "Namespaced"
      "versions" = [
        {
          "additionalPrinterColumns" = [
            {
              "jsonPath" = ".spec.network"
              "name" = "Network"
              "type" = "string"
            },
            {
              "jsonPath" = ".spec.throughputTier"
              "name" = "Throughput Tier"
              "type" = "string"
            },
            {
              "jsonPath" = ".status.username"
              "name" = "Username"
              "type" = "string"
            },
            {
              "jsonPath" = ".status.password"
              "name" = "Password"
              "type" = "string"
            },
          ]
          "name" = "v1alpha1"
          "schema" = {
            "openAPIV3Schema" = {
              "description" = "Auto-generated derived type for MumakPortSpec via `CustomResource`"
              "properties" = {
                "spec" = {
                  "properties" = {
                    "network" = {
                      "type" = "string"
                    }
                    "password" = {
                      "nullable" = true
                      "type" = "string"
                    }
                    "throughputTier" = {
                      "nullable" = true
                      "type" = "string"
                    }
                    "username" = {
                      "nullable" = true
                      "type" = "string"
                    }
                  }
                  "required" = [
                    "network",
                  ]
                  "type" = "object"
                }
                "status" = {
                  "nullable" = true
                  "properties" = {
                    "password" = {
                      "type" = "string"
                    }
                    "username" = {
                      "type" = "string"
                    }
                  }
                  "required" = [
                    "password",
                    "username",
                  ]
                  "type" = "object"
                }
              }
              "required" = [
                "spec",
              ]
              "title" = "MumakPort"
              "type" = "object"
            }
          }
          "served" = true
          "storage" = true
          "subresources" = {
            "status" = {}
          }
        },
      ]
    }
  }
}
