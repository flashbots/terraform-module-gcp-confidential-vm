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
  description = "GCP machine type. Must be from C3 or C4 series for TDX support (e.g., c3-standard-44, c4-standard-48)"
  default     = "c3-standard-4"
  nullable    = false

  validation {
    condition     = can(regex("^c[34]-", var.machine_type))
    error_message = "Intel TDX requires C3 or C4 series machine types (e.g., c3-standard-44, c4-standard-48)"
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
  description = "Enable vTPM for the VM"
  default     = false
  nullable    = false
}

variable "enable_display" {
  type        = bool
  description = "Enable display device for the VM"
  default     = true
  nullable    = false
}

variable "min_cpu_platform" {
  type        = string
  description = "Minimum CPU platform for the VM. Defaults to \"Intel Granite Rapids\" for c4-* machine types (required for C4 TDX placement); unset otherwise. Set explicitly to override."
  default     = null
}

variable "os_disk_size_gb" {
  type        = number
  description = "Size of the OS boot disk in GB. If not specified, uses the image size"
  default     = null
}

variable "os_disk_type" {
  type        = string
  description = "Type of the OS boot disk"
  default     = "pd-ssd"
  nullable    = false
}

variable "data_disk_size_gb" {
  type        = number
  description = "Size of the persistent data disk in GB"
}

variable "data_disk_type" {
  type        = string
  description = "Type of the data disk"
  default     = "pd-ssd" # pd-ssd is the best combination of latency and throughput
  nullable    = false
}

variable "data_disk_device_name" {
  type        = string
  description = "Device name for the data disk attachment"
  default     = "persistent"
  nullable    = false
}

variable "external_ip" {
  type        = string
  description = "Pre-allocated external IP address. If not set, a new static IP is created"
  default     = null
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

variable "service_account" {
  type = object({
    email  = optional(string)
    scopes = optional(list(string), ["cloud-platform"])
  })
  description = <<-EOT
    Service account to attach to the VM.

    - `null` (default): no service account is attached. The VM cannot use the
      GCE metadata identity endpoint (e.g. for Vault GCP auth) or call most
      Google Cloud APIs.
    - `{}`: uses the project's default compute service account
      (`<project-number>-compute@developer.gserviceaccount.com`) with the
      `cloud-platform` scope.
    - `{ email = "...", scopes = [...] }`: explicit SA and OAuth scopes.

    The `cloud-platform` scope is the recommended catch-all; finer-grained
    legacy scopes are not generally supported by newer GCP features.
  EOT
  default     = null
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
