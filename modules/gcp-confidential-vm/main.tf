resource "google_compute_address" "this" {
  count = var.external_ip == null ? 1 : 0

  name    = var.vm_name
  project = var.project
  region  = var.region

  address_type = "EXTERNAL"
}

locals {
  public_ip = var.external_ip != null ? var.external_ip : google_compute_address.this[0].address
}

resource "google_compute_disk" "data" {
  name    = "${var.vm_name}-${var.data_disk_device_name}"
  project = var.project
  zone    = var.zone

  size = var.data_disk_size_gb
  type = var.data_disk_type

  provisioned_iops       = var.data_disk_provisioned_iops
  provisioned_throughput = var.data_disk_provisioned_throughput

  lifecycle {
    ignore_changes = [
      image,
      snapshot,
      source_disk,
      source_image_encryption_key,
      source_snapshot_encryption_key,
    ]
  }
}

resource "google_compute_instance" "cvm" {
  name                      = var.vm_name
  project                   = var.project
  zone                      = var.zone
  machine_type = var.machine_type
  # C4 TDX requires Granite Rapids hosts; without the pin, placement fails
  min_cpu_platform = var.min_cpu_platform != null ? var.min_cpu_platform : (startswith(var.machine_type, "c4-") ? "Intel Granite Rapids" : null)
  allow_stopping_for_update = true
  enable_display            = var.enable_display
  tags                      = [var.vm_name]
  metadata                  = var.metadata

  # TDX VMs don't support live migration
  scheduling {
    on_host_maintenance = "TERMINATE"
    automatic_restart   = true
  }

  confidential_instance_config {
    confidential_instance_type = "TDX"
  }

  shielded_instance_config {
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = var.enable_vtpm
    enable_integrity_monitoring = var.enable_vtpm
  }

  boot_disk {
    initialize_params {
      image = var.source_image
      size  = var.os_disk_size_gb
      type  = var.os_disk_type
    }
  }

  attached_disk {
    source      = google_compute_disk.data.self_link
    device_name = var.data_disk_device_name
    mode        = "READ_WRITE"
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    access_config {
      nat_ip = local.public_ip
    }
  }

  # If `service_account` is null (the default), no block is emitted and the
  # VM is created without an attached SA — same behavior as before this
  # variable existed. When set, the VM gets an SA and can use the metadata
  # identity endpoint (required for, e.g., Vault GCP auth from the host).
  dynamic "service_account" {
    for_each = var.service_account != null ? [var.service_account] : []
    content {
      email  = service_account.value.email
      scopes = service_account.value.scopes
    }
  }

  lifecycle {
    ignore_changes = [
      # SSH keys managed externally (e.g., OS Login, manual updates)
      metadata["ssh-keys"],
      # GCP may add automatic labels
      labels,
      # Boot disk size might be computed from image if not explicitly set
      boot_disk[0].initialize_params[0].size,
      boot_disk[0].initialize_params[0].labels,
    ]
  }
}

module "firewall" {
  source = "../gcp-firewall"

  name    = var.vm_name
  project = var.project
  network = var.network

  target_tags = [var.vm_name]

  ingress_rules = var.firewall_ingress_rules
  egress_rules  = var.firewall_egress_rules
}
