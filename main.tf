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

  # Directory for downloading remote images
  download_dir = "${path.root}/.terraform/image-downloads"

  # Split images into those that need to be created vs pre-existing references
  images_to_create = { for k, v in var.images : k => v if v.source_uri != null }
  images_existing  = { for k, v in var.images : k => v if v.source_image != null }

  # Categorize images to create by source type based on URI scheme
  # GCS images: https://storage.googleapis.com/...
  images_from_gcs = { for k, v in local.images_to_create : k => v if startswith(v.source_uri, "https://storage.googleapis.com/") }

  # Remote URL images: http://, https:// (excluding GCS URLs) or s3:// (private
  # Cloudflare R2 bucket)
  images_from_url = { for k, v in local.images_to_create : k => v if can(regex("^(https?|s3)://", v.source_uri)) && !startswith(v.source_uri, "https://storage.googleapis.com/") }

  # Local file images: everything else (local paths)
  images_from_local = { for k, v in local.images_to_create : k => v if !can(regex("^(https?|s3)://", v.source_uri)) }

  # Images that need to be uploaded to GCS (local files + downloaded URLs)
  images_to_upload = merge(
    { for k, v in local.images_from_local : k => { source = v.source_uri, name = "${filesha256(v.source_uri)}-${basename(v.source_uri)}" } },
    { for k, v in local.images_from_url : k => { source = "${local.download_dir}/${k}.tar.gz", name = "${k}.tar.gz" } }
  )

  # Empty DER header bytes for TDX secure boot keys
  # \x30\x82\x01\x0a\x02\x82\x01\x01
  empty_der_base64 = "MIIBCgKCAQE="
}

resource "null_resource" "download_image" {
  for_each = local.images_from_url

  triggers = {
    # Re-download if URL changes
    url = each.value.source_uri
  }

  # s3:// sources: sign a GET URL with the CLOUDFLARE_API_TOKEN environment
  # variable right before the download, so only applies that download need it.
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      mkdir -p "${local.download_dir}"
      echo "Downloading ${each.value.source_uri}..."
      %{if startswith(each.value.source_uri, "s3://")~}
      url=$(python3 "${path.module}/scripts/r2-presign.py" "${each.value.source_uri}" "${coalesce(var.r2_account_id, "-")}" 3600)
      %{else~}
      url="${each.value.source_uri}"
      %{endif~}
      curl -fSL --progress-bar -o "${local.download_dir}/${each.key}.tar.gz" "$url"
    EOT
  }

  lifecycle {
    precondition {
      condition     = !startswith(each.value.source_uri, "s3://") || var.r2_account_id != null
      error_message = "Image \"${each.key}\" has an s3:// source_uri, but r2_account_id is not set."
    }
  }
}

resource "google_storage_bucket_object" "image" {
  for_each = local.images_to_upload

  name   = each.value.name
  bucket = local.bucket_name
  source = each.value.source

  lifecycle {
    ignore_changes = [detect_md5hash]
  }

  depends_on = [null_resource.download_image]
}

locals {
  uploaded_image_uris = {
    for k, obj in google_storage_bucket_object.image :
    k => obj.self_link
  }

  image_gcs_sources = merge(
    { for k, v in local.images_from_gcs : k => v.source_uri },
    local.uploaded_image_uris
  )
}

resource "google_compute_image" "this" {
  for_each = local.images_to_create

  name    = each.key
  project = var.project

  raw_disk {
    source = local.image_gcs_sources[each.key]
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

  shielded_instance_initial_state {
    pk {
      content   = var.create_empty_secure_boot_keys ? local.empty_der_base64 : var.secure_boot_keys.pk
      file_type = "X509"
    }

    keks {
      content   = var.create_empty_secure_boot_keys ? local.empty_der_base64 : var.secure_boot_keys.keks
      file_type = "X509"
    }

    dbs {
      content   = var.create_empty_secure_boot_keys ? local.empty_der_base64 : var.secure_boot_keys.dbs
      file_type = "X509"
    }

    dbxs {
      content   = var.create_empty_secure_boot_keys ? local.empty_der_base64 : var.secure_boot_keys.dbxs
      file_type = "X509"
    }
  }

  depends_on = [google_storage_bucket_object.image]
}

locals {
  # Unified image reference map: created images use self_link, existing images pass through directly
  image_refs = merge(
    { for k, img in google_compute_image.this : k => img.self_link },
    { for k, v in local.images_existing : k => v.source_image },
  )
}

module "cvm" {
  source = "./modules/gcp-confidential-vm"

  for_each = var.vms

  project = var.project
  region  = var.region
  zone    = each.value.zone

  vm_name                          = each.key
  source_image                     = local.image_refs[each.value.image_name]
  machine_type                     = each.value.machine_type
  min_cpu_platform                 = each.value.min_cpu_platform
  enable_secure_boot               = each.value.enable_secure_boot
  enable_vtpm                      = each.value.enable_vtpm
  enable_display                   = each.value.enable_display
  os_disk_size_gb                  = each.value.os_disk_size_gb
  os_disk_type                     = each.value.os_disk_type
  data_disk_size_gb                = each.value.data_disk_size_gb
  data_disk_type                   = each.value.data_disk_type
  data_disk_provisioned_iops       = each.value.data_disk_provisioned_iops
  data_disk_provisioned_throughput = each.value.data_disk_provisioned_throughput
  data_disk_device_name            = each.value.data_disk_device_name
  network                          = each.value.network
  subnetwork                       = each.value.subnetwork
  external_ip                      = each.value.external_ip
  network_tier                     = each.value.network_tier
  metadata                         = each.value.metadata
  service_account                  = each.value.service_account

  firewall_ingress_rules = each.value.firewall_ingress_rules
  firewall_egress_rules  = each.value.firewall_egress_rules
}
