variable "project" {
  type        = string
  description = "The GCP project ID where all resources will be created"
}

variable "region" {
  type        = string
  description = "The GCP region where resources will be created"
}

variable "create_image_bucket" {
  type        = bool
  description = "Whether to create a new GCS bucket for storing VM images"
  default     = true
}

variable "image_bucket_name" {
  type        = string
  description = "Name of the GCS bucket for storing VM images. Used both for creating new bucket or referencing existing one"
}

variable "images" {
  type = map(object({
    source_uri   = optional(string)
    source_image = optional(string)
  }))
  description = <<-EOT
    Map of image names to their source.

    Each image must set exactly one of:
    - source_uri:   Create a new compute image from a raw disk file.
                    Auto-detected based on URI scheme:
                    - https://storage.googleapis.com/bucket/path - GCS URI (used directly)
                    - https://... or http://... - Remote URL (downloaded then uploaded to GCS)
                    - /path/to/file - Local file path (uploaded to GCS)
    - source_image: Reference an existing GCP image. Accepts any format supported by
                    google_compute_instance boot_disk (self-link, image name, family, etc.)

    Example:
    ```terraform
    images = {
      # Existing image in GCS (will create a compute image)
      "buildernet-v2-0-0-rc4" = {
        source_uri = "https://storage.googleapis.com/buildernet-images/buildernet-gcp_2.0.0-rc4-88fd8d54-import.tar.gz"
      }
      # Local file (will be uploaded to GCS and create a compute image)
      "buildernet-v2-0-1" = {
        source_uri = "/path/to/local/image.tar.gz"
      }
      # Remote URL (will be downloaded, uploaded to GCS, and create a compute image)
      "buildernet-v2-2-0" = {
        source_uri = "https://downloads.buildernet.org/buildernet-images/v2.2.0/buildernet-gcp_2.2.0-9818c3f0-import.tar.gz"
      }
      # Pre-existing GCP image (used directly, no resources created)
      "buildernet-v2-3-0" = {
        source_image = "projects/my-project/global/images/buildernet-v2-3-0"
      }
    }
    ```
  EOT

  validation {
    condition = alltrue([
      for k, v in var.images :
      (v.source_uri != null) != (v.source_image != null)
    ])
    error_message = "Each image must set exactly one of 'source_uri' or 'source_image'."
  }
}

variable "create_empty_secure_boot_keys" {
  type        = bool
  description = "Create empty secure boot keys for TDX images"
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

variable "vms" {
  type = map(object({
    zone                   = string
    image_name             = string
    machine_type           = optional(string, "c3-standard-44")
    min_cpu_platform       = optional(string)
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
    external_ip            = optional(string)
    metadata               = optional(map(string), {})
    service_account = optional(object({
      email  = optional(string)
      scopes = optional(list(string), ["cloud-platform"])
    }))
    firewall_ingress_rules = optional(map(list(string)), {})
    firewall_egress_rules  = optional(map(list(string)), {})
  }))
  description = <<-EOT
    Map of VM configurations keyed by VM name.

    Example:
    ```terraform
    vms = {
      "buildernet-flashbots-gcp-ap-01" = {
        zone              = "asia-northeast1-b"
        image_name        = "buildernet-v2-0-0-rc4"
        machine_type      = "c3-standard-44"
        data_disk_size_gb = 2250
        network           = "base"
        subnetwork        = "base-asia-northeast1"
        firewall_ingress_rules = {
          "22 \| tcp \| ssh"     = ["0.0.0.0/0"]
          "30303 \| tcp \| p2p"  = ["0.0.0.0/0"]
          "30303 \| udp \| p2p"  = ["0.0.0.0/0"]
        }
        firewall_egress_rules = {
          "0 \| all" = ["0.0.0.0/0"]
        }
      }
    }
    ```
  EOT
}
