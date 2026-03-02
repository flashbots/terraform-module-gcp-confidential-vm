locals {
  # Parse ingress rules from "PORT | PROTOCOL | DESCRIPTION" format
  parsed_ingress = [
    for key, ranges in var.ingress_rules : {
      port       = trimspace(split("|", key)[0])
      protocol   = lower(trimspace(split("|", key)[1]))
      ranges_key = join(",", sort(ranges))
      ranges     = sort(ranges)
    }
  ]

  # Parse egress rules from "PORT | PROTOCOL | DESCRIPTION" format
  parsed_egress = [
    for key, ranges in var.egress_rules : {
      port       = trimspace(split("|", key)[0])
      protocol   = lower(trimspace(split("|", key)[1]))
      ranges_key = join(",", sort(ranges))
      ranges     = sort(ranges)
    }
  ]

  # Group by CIDR ranges — rules with the same ranges become one firewall rule
  # with multiple allow blocks (one per protocol, each listing all ports for that protocol)
  ingress_by_ranges = { for rule in local.parsed_ingress : rule.ranges_key => rule... }
  egress_by_ranges  = { for rule in local.parsed_egress : rule.ranges_key => rule... }
}

resource "google_compute_firewall" "ingress" {
  for_each = local.ingress_by_ranges

  name    = length(local.ingress_by_ranges) == 1 ? "${var.name}-ingress" : "${var.name}-ingress-${substr(md5(each.key), 0, 8)}"
  project = var.project
  network = var.network

  direction     = "INGRESS"
  source_ranges = each.value[0].ranges
  target_tags   = var.target_tags

  dynamic "allow" {
    for_each = { for rule in each.value : rule.protocol => rule... }
    content {
      protocol = allow.key
      ports    = contains(["tcp", "udp", "sctp"], allow.key) && !contains([for r in allow.value : r.port], "0") ? distinct([for r in allow.value : r.port]) : null
    }
  }
}

resource "google_compute_firewall" "egress" {
  for_each = local.egress_by_ranges

  name    = length(local.egress_by_ranges) == 1 ? "${var.name}-egress" : "${var.name}-egress-${substr(md5(each.key), 0, 8)}"
  project = var.project
  network = var.network

  direction          = "EGRESS"
  destination_ranges = each.value[0].ranges
  target_tags        = var.target_tags

  dynamic "allow" {
    for_each = { for rule in each.value : rule.protocol => rule... }
    content {
      protocol = allow.key
      ports    = contains(["tcp", "udp", "sctp"], allow.key) && !contains([for r in allow.value : r.port], "0") ? distinct([for r in allow.value : r.port]) : null
    }
  }
}
