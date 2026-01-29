variable "name" {
  type        = string
  description = "Base name for the firewall rules"
}

variable "project" {
  type        = string
  description = "The GCP project ID"
}

variable "network" {
  type        = string
  description = "Name or self-link of the VPC network where firewall rules will be created"
}

variable "target_tags" {
  type        = list(string)
  description = "Network tags to apply the firewall rules to"
  default     = []
}

variable "ingress_rules" {
  type    = map(list(string))
  default = {}

  description = <<-EOT
    Ingress firewall rules to create.
    Format: "PORT | PROTOCOL | DESCRIPTION" = ["CIDR_RANGE1", "CIDR_RANGE2"]

    - PORT: Single port (e.g., "22"), port range (e.g., "8000..8100"), or "0" for all ports
    - PROTOCOL: "tcp", "udp", "icmp", or "all"
    - DESCRIPTION: Optional human-readable description (used in rule name)

    Example:
    ```terraform
    ingress_rules = {
      "22 | tcp | ssh"        = ["0.0.0.0/0"]
      "30303 | tcp | p2p"     = ["0.0.0.0/0"]
      "30303 | udp | p2p-udp" = ["0.0.0.0/0"]
      "8545..8546 | tcp | rpc" = ["10.0.0.0/8"]
    }
    ```
  EOT
}

variable "egress_rules" {
  type    = map(list(string))
  default = {}

  description = <<-EOT
    Egress firewall rules to create.
    Format: "PORT | PROTOCOL | DESCRIPTION" = ["CIDR_RANGE1", "CIDR_RANGE2"]

    - PORT: Single port (e.g., "443"), port range (e.g., "8000..8100"), or "0" for all ports
    - PROTOCOL: "tcp", "udp", "icmp", or "all"
    - DESCRIPTION: Optional human-readable description (used in rule name)

    Example:
    ```terraform
    egress_rules = {
      "0 | all | allow-all" = ["0.0.0.0/0"]
      "443 | tcp | https"   = ["0.0.0.0/0"]
    }
    ```
  EOT
}
