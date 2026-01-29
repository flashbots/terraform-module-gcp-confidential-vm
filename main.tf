# Storage bucket for VM images
resource "google_storage_bucket" "images" {
  count = var.create_image_bucket ? 1 : 0

  name     = var.image_bucket_name
  location = var.region
  project  = var.project

  uniform_bucket_level_access = true

  force_destroy = false
}

locals {
  bucket_name = var.create_image_bucket ? google_storage_bucket.images[0].name : var.image_bucket_name

  # Filter images that need to be uploaded (have source_file)
  images_to_upload = { for k, v in var.images : k => v if v.source_file != null }

  # Empty DER header bytes for TDX secure boot keys
  # This matches: printf '\x30\x82\x01\x0a\x02\x82\x01\x01' > /tmp/empty.der
  empty_der_base64 = "MIIBCgKCAQE="
}

# Upload image tar.gz from local to GCS
resource "google_storage_bucket_object" "image" {
  for_each = local.images_to_upload

  name   = basename(each.value.source_file)
  bucket = local.bucket_name
  source = each.value.source_file
}

# Compute images with TDX support
resource "google_compute_image" "this" {
  for_each = var.images

  name    = each.key
  project = var.project

  raw_disk {
    source = each.value.source_uri != null ? each.value.source_uri : "gs://${local.bucket_name}/${google_storage_bucket_object.image[each.key].name}"
  }

  guest_os_features {
    type = "GVNIC"
  }

  guest_os_features {
    type = "TDX_CAPABLE"
  }

  guest_os_features {
    type = "UEFI_COMPATIBLE"
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }

  # Shielded instance initial state for TDX (empty certificates)
  # This matches the gcloud --key-exchange-key-file, --signature-database-file, --forbidden-database-file flags
  shielded_instance_initial_state {
    pk {
      content   = var.create_empty_secure_boot_keys ? local.empty_der_base64 : var.secure_boot_keys.pk
      file_type = "BIN"
    }

    keks {
      content   = var.create_empty_secure_boot_keys ? local.empty_der_base64 : var.secure_boot_keys.keks
      file_type = "BIN"
    }

    dbs {
      content   = var.create_empty_secure_boot_keys ? local.empty_der_base64 : var.secure_boot_keys.dbs
      file_type = "BIN"
    }

    dbxs {
      content   = var.create_empty_secure_boot_keys ? local.empty_der_base64 : var.secure_boot_keys.dbxs
      file_type = "BIN"
    }
  }

  depends_on = [google_storage_bucket_object.image]
}

# Confidential VM instances
module "cvm" {
  source = "./modules/gcp-confidential-vm"

  for_each = var.vms

  project = var.project
  region  = var.region
  zone    = each.value.zone

  vm_name               = each.key
  source_image          = google_compute_image.this[each.value.image_name].self_link
  machine_type          = each.value.machine_type
  enable_secure_boot    = each.value.enable_secure_boot
  enable_vtpm           = each.value.enable_vtpm
  enable_display        = each.value.enable_display
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_disk_type          = each.value.os_disk_type
  data_disk_size_gb     = each.value.data_disk_size_gb
  data_disk_type        = each.value.data_disk_type
  data_disk_device_name = each.value.data_disk_device_name
  network               = each.value.network
  subnetwork            = each.value.subnetwork

  firewall_ingress_rules = each.value.firewall_ingress_rules
  firewall_egress_rules  = each.value.firewall_egress_rules
}
