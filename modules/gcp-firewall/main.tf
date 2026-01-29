locals {
  # Parse ingress rules from the "PORT | PROTOCOL | DESCRIPTION" format
  ingress_rules = flatten([for k, ranges in var.ingress_rules : [for r in ranges : {
    name = lower(replace(replace(join("-", [
      var.name,
      "ingress",
      (length(split("|", k)) == 3 ? trimspace(split("|", k)[2]) : replace(trimspace(split("|", k)[0]), "..", "-")),
    ]), "*", "any"), " ", "-"))

    port     = trimspace(split("|", k)[0])
    protocol = lower(trimspace(split("|", k)[1]))
    range    = r
  }]])

  # Parse egress rules from the "PORT | PROTOCOL | DESCRIPTION" format
  egress_rules = flatten([for k, ranges in var.egress_rules : [for r in ranges : {
    name = lower(replace(replace(join("-", [
      var.name,
      "egress",
      (length(split("|", k)) == 3 ? trimspace(split("|", k)[2]) : replace(trimspace(split("|", k)[0]), "..", "-")),
    ]), "*", "any"), " ", "-"))

    port     = trimspace(split("|", k)[0])
    protocol = lower(trimspace(split("|", k)[1]))
    range    = r
  }]])

  # Group ingress rules by name to consolidate
  ingress_by_name = { for rule in local.ingress_rules : rule.name => rule... }
  egress_by_name  = { for rule in local.egress_rules : rule.name => rule... }
}

# Ingress firewall rules
resource "google_compute_firewall" "ingress" {
  for_each = local.ingress_by_name

  name    = each.key
  project = var.project
  network = var.network

  direction = "INGRESS"

  source_ranges = [for r in each.value : r.range]
  target_tags   = var.target_tags

  dynamic "allow" {
    for_each = { for r in each.value : r.protocol => r... }
    content {
      protocol = allow.value[0].protocol == "all" ? "all" : allow.value[0].protocol
      ports    = allow.value[0].protocol == "all" || allow.value[0].port == "0" ? null : [for v in allow.value : v.port]
    }
  }
}

# Egress firewall rules
resource "google_compute_firewall" "egress" {
  for_each = local.egress_by_name

  name    = each.key
  project = var.project
  network = var.network

  direction = "EGRESS"

  destination_ranges = [for r in each.value : r.range]
  target_tags        = var.target_tags

  dynamic "allow" {
    for_each = { for r in each.value : r.protocol => r... }
    content {
      protocol = allow.value[0].protocol == "all" ? "all" : allow.value[0].protocol
      ports    = allow.value[0].protocol == "all" || allow.value[0].port == "0" ? null : [for v in allow.value : v.port]
    }
  }
}
