locals {
  block_configmap_name = "oura-config-${var.instance_name}-blocks"
  tx_configmap_name    = "oura-config-${var.instance_name}-txs"
  utxo_configmap_name  = "oura-config-${var.instance_name}-utxos"

  block_instance_name = "${var.instance_name}-block"
  tx_instance_name    = "${var.instance_name}-tx"
  utxo_instance_name  = "${var.instance_name}-utxo"
}

variable "namespace" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "network" {
  type = string

  validation {
    condition     = contains(["mainnet", "preprod", "preview"], var.network)
    error_message = "Invalid network. Allowed values are mainnet, preprod, preview."
  }
}

variable "db" {
  type = string
}

variable "image" {
  type    = string
  default = "ghcr.io/txpipe/oura"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "testnet_magic" {
  type = string
}

variable "node_private_dns" {
  type = string
}

variable "intersect_config" {
  default = {
    "type" = "Origin"
  }
}

variable "postgres_host" {
  type = string
}

variable "postgres_secret_name" {
  type = string
}

variable "resources" {
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits : {
      cpu : "200m",
      memory : "1Gi"
    }
    requests : {
      cpu : "200m",
      memory : "500Mi"
    }
  }
}

variable "tolerations" {
  type = list(object({
    effect   = string
    key      = string
    operator = string
    value    = optional(string)
  }))
  default = [
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
  ]
}
