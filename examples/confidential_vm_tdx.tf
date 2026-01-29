# Example: Deploy a confidential VM with Intel TDX on GCP
#
# This example replicates the following gcloud CLI workflow:
#
# 1. Upload image to GCS bucket
# 2. Create compute image with TDX guest OS features
# 3. Create persistent data disk
# 4. Allocate static public IP
# 5. Create firewall rules
# 6. Create VM instance with TDX confidential computing

provider "google" {
  project = "flashbots-buildernet"
  region  = "asia-northeast1"
}

module "confidential_vm" {
  source = "../"

  project = "flashbots-buildernet"
  region  = "asia-northeast1"

  # Image bucket configuration
  create_image_bucket = false
  image_bucket_name   = "buildernet-images"

  # Image configuration - reference existing image in GCS
  images = {
    "buildernet-v2-0-0-rc4" = {
      source_uri = "gs://buildernet-images/buildernet-gcp_2.0.0-rc4-88fd8d54-import.tar.gz"
    }
  }

  # Use empty secure boot keys for TDX (default behavior)
  create_empty_secure_boot_keys = true

  # VM configuration
  vms = {
    "buildernet-flashbots-gcp-tokyo-101" = {
      zone       = "asia-northeast1-b"
      image_name = "buildernet-v2-0-0-rc4"

      # C3 machine type required for Intel TDX
      machine_type = "c3-standard-44"

      # TDX typically doesn't use secure boot or vTPM
      enable_secure_boot = false
      enable_vtpm        = false
      enable_display     = true

      # Data disk configuration (2250 GB SSD)
      data_disk_size_gb     = 2250
      data_disk_type        = "pd-ssd"
      data_disk_device_name = "persistent"

      # Network configuration
      network    = "base"
      subnetwork = "base-asia-northeast1"

      # Firewall rules - ingress
      firewall_ingress_rules = {
        "22 | tcp | ssh"          = ["0.0.0.0/0"]
        "30303 | tcp | p2p"       = ["0.0.0.0/0"]
        "30303 | udp | p2p-udp"   = ["0.0.0.0/0"]
        "8545..8546 | tcp | rpc"  = ["10.0.0.0/8"] # Internal RPC only
      }

      # Firewall rules - egress (allow all outbound)
      firewall_egress_rules = {
        "0 | all | allow-all" = ["0.0.0.0/0"]
      }
    }
  }
}

# Output VM details
output "vm_details" {
  value       = module.confidential_vm.vm_details
  description = "Details of deployed VMs including public IPs"
}

# Example with local image upload
#
# module "confidential_vm_with_upload" {
#   source = "../"
#
#   project = "flashbots-buildernet"
#   region  = "asia-northeast1"
#
#   # Create new bucket for images
#   create_image_bucket = true
#   image_bucket_name   = "my-new-buildernet-images"
#
#   # Upload local image file
#   images = {
#     "buildernet-v2-0-1" = {
#       source_file = "/path/to/buildernet-gcp_2.0.1-import.tar.gz"
#     }
#   }
#
#   vms = {
#     "buildernet-test" = {
#       zone              = "us-central1-a"
#       image_name        = "buildernet-v2-0-1"
#       machine_type      = "c3-standard-8"
#       data_disk_size_gb = 500
#       network           = "default"
#       subnetwork        = "default"
#       firewall_ingress_rules = {
#         "22 | tcp | ssh" = ["0.0.0.0/0"]
#       }
#     }
#   }
# }
