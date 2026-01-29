# Static external IP address
resource "google_compute_address" "this" {
  name    = var.vm_name
  project = var.project
  region  = var.region

  address_type = "EXTERNAL"
}

# Persistent data disk
resource "google_compute_disk" "data" {
  name    = "${var.vm_name}-${var.data_disk_device_name}"
  project = var.project
  zone    = var.zone

  size = var.data_disk_size_gb
  type = var.data_disk_type

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

# Confidential VM instance with Intel TDX
resource "google_compute_instance" "cvm" {
  name         = var.vm_name
  project      = var.project
  zone         = var.zone
  machine_type = var.machine_type

  # TDX VMs don't support live migration
  scheduling {
    on_host_maintenance = "TERMINATE"
    automatic_restart   = true
  }

  # Intel TDX confidential computing configuration
  confidential_instance_config {
    confidential_instance_type = "TDX"
  }

  # Shielded VM settings (typically disabled for TDX)
  shielded_instance_config {
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = var.enable_vtpm
    enable_integrity_monitoring = var.enable_vtpm
  }

  # Enable display device
  enable_display = var.enable_display

  # Boot disk from custom image
  boot_disk {
    initialize_params {
      image = var.source_image
      size  = var.os_disk_size_gb
      type  = var.os_disk_type
    }
  }

  # Attach persistent data disk
  attached_disk {
    source      = google_compute_disk.data.self_link
    device_name = var.data_disk_device_name
    mode        = "READ_WRITE"
  }

  # Network interface with external IP
  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    access_config {
      nat_ip = google_compute_address.this.address
    }
  }

  # Network tags for firewall rules
  tags = [var.vm_name]

  # Metadata can be extended as needed
  metadata = var.metadata

  # Prevent replacement when certain attributes change
  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"],
    ]
  }
}

# Firewall rules for this VM
module "firewall" {
  source = "../gcp-firewall"

  name    = var.vm_name
  project = var.project
  network = var.network

  target_tags = [var.vm_name]

  ingress_rules = var.firewall_ingress_rules
  egress_rules  = var.firewall_egress_rules
}
