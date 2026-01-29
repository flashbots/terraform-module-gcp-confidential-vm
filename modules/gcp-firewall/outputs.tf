output "firewall_name" {
  value       = var.name
  description = "The base name used for firewall rules"
}

output "ingress_firewall_ids" {
  value       = { for k, fw in google_compute_firewall.ingress : k => fw.id }
  description = "Map of ingress firewall rule names to their IDs"
}

output "egress_firewall_ids" {
  value       = { for k, fw in google_compute_firewall.egress : k => fw.id }
  description = "Map of egress firewall rule names to their IDs"
}
