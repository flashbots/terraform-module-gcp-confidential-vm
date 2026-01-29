output "vm_details" {
  value = {
    for k, vm in module.cvm : k => {
      id            = vm.vm_id
      public_ip     = vm.vm_public_ip
      firewall_name = vm.firewall_name
    }
  }
  description = "VM details"
}

output "image_bucket" {
  value       = var.create_image_bucket ? google_storage_bucket.images[0].name : var.image_bucket_name
  description = "Name of the GCS bucket used for VM images"
}

output "images" {
  value = {
    for k, img in google_compute_image.this : k => {
      id        = img.id
      self_link = img.self_link
    }
  }
  description = "Map of created compute images"
}
