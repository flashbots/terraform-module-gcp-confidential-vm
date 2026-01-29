output "vm_id" {
  value       = google_compute_instance.cvm.id
  description = "The unique identifier of the VM instance"
}

output "vm_self_link" {
  value       = google_compute_instance.cvm.self_link
  description = "The self-link URI of the VM instance"
}

output "vm_public_ip" {
  value       = google_compute_address.this.address
  description = "The static external IP address of the VM"
}

output "vm_private_ip" {
  value       = google_compute_instance.cvm.network_interface[0].network_ip
  description = "The private IP address of the VM"
}

output "data_disk_id" {
  value       = google_compute_disk.data.id
  description = "The unique identifier of the data disk"
}

output "firewall_name" {
  value       = module.firewall.firewall_name
  description = "The name of the firewall rule created for this VM"
}
