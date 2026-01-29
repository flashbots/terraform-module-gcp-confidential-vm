provider "google" {
  project = "flashbots-buildernet"
  region  = "europe-west4"
}

module "confidential_vm" {
  source = "../"

  project = "buildernet"
  region  = "europe-west4"

  create_image_bucket = false
  image_bucket_name   = "buildernet-images"

  images = {
    "buildernet-v2-2-0" = {
      source_uri = "gs://buildernet-images/buildernet-gcp_2.2.0-9818c3f0-import.tar.gz"
    }
  }

  create_empty_secure_boot_keys = true

  vms = {
    "cvm-01" = {
      zone       = "europe-west4-b"
      image_name = "buildernet-v2-2-0"

      machine_type = "c3-standard-44"

      enable_secure_boot = false
      enable_vtpm        = false
      enable_display     = true

      data_disk_size_gb     = 2250
      data_disk_type        = "pd-ssd"
      data_disk_device_name = "persistent"

      network    = "core"
      subnetwork = "core-europe-west4"

      firewall_ingress_rules = {
        "22 | tcp | ssh"         = ["0.0.0.0/0"]
        "30303 | tcp | p2p"      = ["0.0.0.0/0"]
        "30303 | udp | p2p-udp"  = ["0.0.0.0/0"]
        "8545-8546 | tcp | rpc"  = ["0.0.0.0/"]
      }

      firewall_egress_rules = {
        "0 | all | allow-all" = ["0.0.0.0/0"]
      }
    }
  }
}

output "vm_details" {
  value       = module.confidential_vm.vm_details
  description = "Details of deployed VMs including public IPs"
}
