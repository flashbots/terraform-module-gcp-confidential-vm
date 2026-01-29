Terraform module to deploy Confidential Virtual Machines on GCP using Intel TDX (Trust Domain Extensions) secure execution environment.

The module focuses on deploying VMs for [BuilderNet](https://buildernet.org/) using custom images and does not rely on standard GCP VM provisioning features like cloud-init or OS Login.

## Overview

The module handles the following infrastructure components:

- Creates a GCS bucket for storing VM images (optional);
- Uploads local image files to GCS (optional);
- Creates GCP Compute Images with TDX-capable guest OS features;
- Allocates static external IP addresses;
- Creates firewall rules for ingress/egress traffic;
- Deploys Confidential VMs with Intel TDX enabled.

## Prerequisites

Before using this module, you must:

- Have a GCP project with Compute Engine API enabled;
- Prepare your VM image as a `.tar.gz` file compatible with GCP;
- Either upload the image to GCS manually or provide a local path for the module to upload.

## Important Notes

- Intel TDX requires **C3 series machine types** (e.g., `c3-standard-44`);
- TDX VMs do not support live migration (`on_host_maintenance` is set to `TERMINATE`);
- The module creates empty secure boot certificates by default (matching the gcloud CLI behavior with empty `.der` files);
- Firewall rules use the same format as the Azure module: `"PORT | PROTOCOL | DESCRIPTION"`.

## Usage

Refer to the [examples](./examples/) directory for detailed configuration examples.

### Basic Example

```hcl
module "confidential_vm" {
  source = "path/to/terraform-module-gcp-confidential-vm"

  project = "my-gcp-project"
  region  = "asia-northeast1"

  create_image_bucket = false
  image_bucket_name   = "my-existing-bucket"

  images = {
    "my-image-v1" = {
      source_uri = "gs://my-existing-bucket/my-image.tar.gz"
    }
  }

  vms = {
    "my-vm" = {
      zone              = "asia-northeast1-b"
      image_name        = "my-image-v1"
      machine_type      = "c3-standard-44"
      data_disk_size_gb = 500
      network           = "default"
      subnetwork        = "default"
      firewall_ingress_rules = {
        "22 | tcp | ssh" = ["0.0.0.0/0"]
      }
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.1 |
| google | >= 6.0.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 6.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project | The GCP project ID where all resources will be created | `string` | n/a | yes |
| region | The GCP region where resources will be created | `string` | n/a | yes |
| image\_bucket\_name | Name of the GCS bucket for storing VM images. Used both for creating new bucket or referencing existing one | `string` | n/a | yes |
| images | Map of image names to their source configuration. Either source\_file (local path) or source\_uri (GCS URI) must be provided | <pre>map(object({<br>  source_file = optional(string)<br>  source_uri  = optional(string)<br>}))</pre> | n/a | yes |
| vms | Virtual machine configurations | <pre>map(object({<br>  zone                   = string<br>  image_name             = string<br>  machine_type           = optional(string, "c3-standard-44")<br>  enable_secure_boot     = optional(bool, false)<br>  enable_vtpm            = optional(bool, false)<br>  enable_display         = optional(bool, true)<br>  os_disk_size_gb        = optional(number)<br>  os_disk_type           = optional(string, "pd-ssd")<br>  data_disk_size_gb      = number<br>  data_disk_type         = optional(string, "pd-ssd")<br>  data_disk_device_name  = optional(string, "persistent")<br>  network                = string<br>  subnetwork             = string<br>  firewall_ingress_rules = optional(map(list(string)), {})<br>  firewall_egress_rules  = optional(map(list(string)), {})<br>}))</pre> | n/a | yes |
| create\_image\_bucket | Whether to create a new GCS bucket for storing VM images | `bool` | `true` | no |
| create\_empty\_secure\_boot\_keys | Create empty secure boot keys for TDX images (matches the gcloud CLI behavior with empty .der files) | `bool` | `true` | no |
| secure\_boot\_keys | Custom secure boot keys in base64 format. Only used if create\_empty\_secure\_boot\_keys is false | <pre>object({<br>  pk   = optional(string)<br>  keks = optional(string)<br>  dbs  = optional(string)<br>  dbxs = optional(string)<br>})</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vm\_details | Virtual Machine details including ID, public IP, and associated firewall name |
| image\_bucket | Name of the GCS bucket used for VM images |
| images | Map of created compute images with their IDs and self-links |

## Firewall Rule Format

Firewall rules use a pipe-delimited format: `"PORT | PROTOCOL | DESCRIPTION"`

- **PORT**: Single port (`22`), port range (`8000..8100`), or `0` for all ports
- **PROTOCOL**: `tcp`, `udp`, `icmp`, or `all`
- **DESCRIPTION**: Optional human-readable description (used in rule naming)

Example:
```hcl
firewall_ingress_rules = {
  "22 | tcp | ssh"         = ["0.0.0.0/0"]
  "30303 | tcp | p2p"      = ["0.0.0.0/0"]
  "30303 | udp | p2p-udp"  = ["0.0.0.0/0"]
  "8545..8546 | tcp | rpc" = ["10.0.0.0/8"]
}

firewall_egress_rules = {
  "0 | all | allow-all" = ["0.0.0.0/0"]
}
```

## Note for contributors

Make sure to use [terraform-docs](https://github.com/terraform-docs/terraform-docs) to generate the configuration parameters of the module (provider requirements, input variables, outputs) should you update them.
