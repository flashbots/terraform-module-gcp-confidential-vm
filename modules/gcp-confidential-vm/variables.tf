variable "project" {
  type        = string
  description = "The GCP project ID"
}

variable "region" {
  type        = string
  description = "The GCP region for regional resources (e.g., static IP)"
}

variable "zone" {
  type        = string
  description = "The GCP zone where the VM will be created"
}

variable "source_image" {
  type        = string
  description = "Self-link or name of the source image for the VM boot disk"
}

variable "vm_name" {
  type        = string
  description = "Name for the VM and associated resources"
  default     = "builder"
  nullable    = false
}

variable "machine_type" {
  type        = string
  description = "GCP machine type. Must be from C3 series for TDX support (e.g., c3-standard-44)"
  default     = "c3-standard-44"
  nullable    = false

  validation {
    condition     = can(regex("^c3-", var.machine_type))
    error_message = "Intel TDX requires C3 series machine types (e.g., c3-standard-44)"
  }
}

variable "enable_secure_boot" {
  type        = bool
  description = "Enable Secure Boot for the VM (typically disabled for TDX)"
  default     = false
  nullable    = false
}

variable "enable_vtpm" {
  type        = bool
  description = "Enable vTPM for the VM (typically disabled for TDX)"
  default     = false
  nullable    = false
}

variable "enable_display" {
  type        = bool
  description = "Enable display device for the VM"
  default     = true
  nullable    = false
}

variable "os_disk_size_gb" {
  type        = number
  description = "Size of the OS boot disk in GB. If not specified, uses the image size"
  default     = null
}

variable "os_disk_type" {
  type        = string
  description = "Type of the OS boot disk (pd-standard, pd-balanced, pd-ssd, pd-extreme)"
  default     = "pd-ssd"
  nullable    = false

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd", "pd-extreme"], var.os_disk_type)
    error_message = "OS disk type must be one of: pd-standard, pd-balanced, pd-ssd, pd-extreme"
  }
}

variable "data_disk_size_gb" {
  type        = number
  description = "Size of the persistent data disk in GB"
}

variable "data_disk_type" {
  type        = string
  description = "Type of the data disk (pd-standard, pd-balanced, pd-ssd, pd-extreme)"
  default     = "pd-ssd"
  nullable    = false

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd", "pd-extreme"], var.data_disk_type)
    error_message = "Data disk type must be one of: pd-standard, pd-balanced, pd-ssd, pd-extreme"
  }
}

variable "data_disk_device_name" {
  type        = string
  description = "Device name for the data disk attachment"
  default     = "persistent"
  nullable    = false
}

variable "network" {
  type        = string
  description = "Name or self-link of the VPC network"
}

variable "subnetwork" {
  type        = string
  description = "Name or self-link of the subnetwork"
}

variable "metadata" {
  type        = map(string)
  description = "Metadata key-value pairs to attach to the VM"
  default     = {}
  nullable    = false
}

variable "firewall_ingress_rules" {
  type        = map(list(string))
  description = "Ingress firewall rules. See ../gcp-firewall/variables.tf for format"
  default     = {}
  nullable    = false
}

variable "firewall_egress_rules" {
  type        = map(list(string))
  description = "Egress firewall rules. See ../gcp-firewall/variables.tf for format"
  default     = {}
  nullable    = false
}
