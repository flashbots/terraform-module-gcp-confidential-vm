variable "project" {
  type        = string
  description = "The GCP project ID where all resources will be created"
}

variable "region" {
  type        = string
  description = "The GCP region where resources will be created"
}

# Image bucket configuration

variable "create_image_bucket" {
  type        = bool
  description = "Whether to create a new GCS bucket for storing VM images"
  default     = true
}

variable "image_bucket_name" {
  type        = string
  description = "Name of the GCS bucket for storing VM images. Used both for creating new bucket or referencing existing one"
}

# Image configuration

variable "images" {
  type = map(object({
    source_file = optional(string)
    source_uri  = optional(string)
  }))
  description = <<-EOT
    Map of image names to their source configuration.
    Either source_file (local path to upload) or source_uri (existing GCS URI) must be provided.

    Example:
    ```terraform
    images = {
      "buildernet-v2-0-0-rc4" = {
        source_uri = "gs://buildernet-images/buildernet-gcp_2.0.0-rc4-88fd8d54-import.tar.gz"
      }
      "buildernet-v2-0-1" = {
        source_file = "/path/to/local/image.tar.gz"
      }
    }
    ```
  EOT

  validation {
    condition = alltrue([
      for name, img in var.images : img.source_file != null || img.source_uri != null
    ])
    error_message = "Each image must have either source_file or source_uri specified"
  }
}

# Secure boot keys configuration

variable "create_empty_secure_boot_keys" {
  type        = bool
  description = "Create empty secure boot keys for TDX images (matches the gcloud CLI behavior with empty .der files)"
  default     = true
}

variable "secure_boot_keys" {
  type = object({
    pk   = optional(string)
    keks = optional(string)
    dbs  = optional(string)
    dbxs = optional(string)
  })
  description = "Custom secure boot keys in base64 format. Only used if create_empty_secure_boot_keys is false"
  default     = {}
}

# VM configuration

variable "vms" {
  type = map(object({
    zone                   = string
    image_name             = string
    machine_type           = optional(string, "c3-standard-44")
    enable_secure_boot     = optional(bool, false)
    enable_vtpm            = optional(bool, false)
    enable_display         = optional(bool, true)
    os_disk_size_gb        = optional(number)
    os_disk_type           = optional(string, "pd-ssd")
    data_disk_size_gb      = number
    data_disk_type         = optional(string, "pd-ssd")
    data_disk_device_name  = optional(string, "persistent")
    network                = string
    subnetwork             = string
    firewall_ingress_rules = optional(map(list(string)), {})
    firewall_egress_rules  = optional(map(list(string)), {})
  }))
  description = <<-EOT
    Map of VM configurations keyed by VM name.

    Example:
    ```terraform
    vms = {
      "buildernet-flashbots-gcp-tokyo-101" = {
        zone              = "asia-northeast1-b"
        image_name        = "buildernet-v2-0-0-rc4"
        machine_type      = "c3-standard-44"
        data_disk_size_gb = 2250
        network           = "base"
        subnetwork        = "base-asia-northeast1"
        firewall_ingress_rules = {
          "22 | tcp | ssh"     = ["0.0.0.0/0"]
          "30303 | tcp | p2p"  = ["0.0.0.0/0"]
          "30303 | udp | p2p"  = ["0.0.0.0/0"]
        }
        firewall_egress_rules = {
          "0 | all" = ["0.0.0.0/0"]
        }
      }
    }
    ```
  EOT
}
