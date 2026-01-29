Terraform module to deploy Confidential Virtual Machines on GCP using Intel TDX (Trust Domain Extensions) secure execution environment.

The module focuses on deploying VMs for [BuilderNet](https://buildernet.org/) using custom images and does not rely on standard GCP VM provisioning features like cloud-init or OS Login.

## Overview

The module handles the following infrastructure components:

- Creates a GCS bucket for storing VM images (optional);
- Downloads images from remote HTTP(S) URLs (optional);
- Uploads local or downloaded image files to GCS (optional);
- Creates GCP Compute Images with TDX-capable guest OS features;
- Allocates static external IP addresses;
- Creates firewall rules for ingress/egress traffic;
- Deploys Confidential VMs with Intel TDX enabled.

## Prerequisites

Before using this module, you must:

- Have a GCP project with Compute Engine API enabled;
- Prepare your VM image as a `.tar.gz` file compatible with GCP;
- Provide the image via one of: local path, GCS URI, or remote HTTP(S) URL;
- Have `curl` installed locally (required only if downloading images from remote HTTP(S) URLs).

## Important Notes

- Intel TDX requires **C3 series machine types** (e.g., `c3-standard-44`);
- TDX VMs do not support live migration (`on_host_maintenance` is set to `TERMINATE`);
- The module creates empty secure boot certificates by default.

## Usage

Refer to the [examples](./examples/) directory for detailed configuration examples.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0.0 |


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_empty_secure_boot_keys"></a> [create\_empty\_secure\_boot\_keys](#input\_create\_empty\_secure\_boot\_keys) | Create empty secure boot keys for TDX images | `bool` | `true` | no |
| <a name="input_create_image_bucket"></a> [create\_image\_bucket](#input\_create\_image\_bucket) | Whether to create a new GCS bucket for storing VM images | `bool` | `true` | no |
| <a name="input_image_bucket_name"></a> [image\_bucket\_name](#input\_image\_bucket\_name) | Name of the GCS bucket for storing VM images. Used both for creating new bucket or referencing existing one | `string` | n/a | yes |
| <a name="input_images"></a> [images](#input\_images) | Map of image names to their source URI.<br/>The source type is auto-detected based on the URI scheme:<br/>- gs://bucket/path       - GCS URI, image already in cloud storage (used directly)<br/>- https://... or http:// - Remote URL, downloaded via curl then uploaded to GCS<br/>- /path/to/file          - Local file path, uploaded to GCS<br/><br/>Example:<pre>terraform<br/>images = {<br/>  # Existing image in GCS (used directly)<br/>  "buildernet-v2-0-0-rc4" = {<br/>    source_uri = "gs://buildernet-images/buildernet-gcp_2.0.0-rc4-88fd8d54-import.tar.gz"<br/>  }<br/>  # Local file (will be uploaded to GCS)<br/>  "buildernet-v2-0-1" = {<br/>    source_uri = "/path/to/local/image.tar.gz"<br/>  }<br/>  # Remote URL (will be downloaded then uploaded to GCS)<br/>  "buildernet-v2-2-0" = {<br/>    source_uri = "https://downloads.buildernet.org/buildernet-images/v2.2.0/buildernet-gcp_2.2.0-9818c3f0-import.tar.gz"<br/>  }<br/>}</pre> | <pre>map(object({<br/>    source_uri = string<br/>  }))</pre> | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | The GCP project ID where all resources will be created | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where resources will be created | `string` | n/a | yes |
| <a name="input_secure_boot_keys"></a> [secure\_boot\_keys](#input\_secure\_boot\_keys) | Custom secure boot keys in base64 format. Only used if create\_empty\_secure\_boot\_keys is false | <pre>object({<br/>    pk   = optional(string)<br/>    keks = optional(string)<br/>    dbs  = optional(string)<br/>    dbxs = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_vms"></a> [vms](#input\_vms) | Map of VM configurations keyed by VM name.<br/><br/>Example:<pre>terraform<br/>vms = {<br/>  "buildernet-flashbots-gcp-ap-01" = {<br/>    zone              = "asia-northeast1-b"<br/>    image_name        = "buildernet-v2-0-0-rc4"<br/>    machine_type      = "c3-standard-44"<br/>    data_disk_size_gb = 2250<br/>    network           = "base"<br/>    subnetwork        = "base-asia-northeast1"<br/>    firewall_ingress_rules = {<br/>      "22 | tcp | ssh"     = ["0.0.0.0/0"]<br/>      "30303 | tcp | p2p"  = ["0.0.0.0/0"]<br/>      "30303 | udp | p2p"  = ["0.0.0.0/0"]<br/>    }<br/>    firewall_egress_rules = {<br/>      "0 | all" = ["0.0.0.0/0"]<br/>    }<br/>  }<br/>}</pre> | <pre>map(object({<br/>    zone                   = string<br/>    image_name             = string<br/>    machine_type           = optional(string, "c3-standard-44")<br/>    enable_secure_boot     = optional(bool, false)<br/>    enable_vtpm            = optional(bool, false)<br/>    enable_display         = optional(bool, true)<br/>    os_disk_size_gb        = optional(number)<br/>    os_disk_type           = optional(string, "pd-ssd")<br/>    data_disk_size_gb      = number<br/>    data_disk_type         = optional(string, "pd-ssd")<br/>    data_disk_device_name  = optional(string, "persistent")<br/>    network                = string<br/>    subnetwork             = string<br/>    firewall_ingress_rules = optional(map(list(string)), {})<br/>    firewall_egress_rules  = optional(map(list(string)), {})<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_image_bucket"></a> [image\_bucket](#output\_image\_bucket) | Name of the GCS bucket used for VM images |
| <a name="output_images"></a> [images](#output\_images) | Map of created compute images |
| <a name="output_vm_details"></a> [vm\_details](#output\_vm\_details) | VM details |

## Image Source Options

The `source_uri` field auto-detects the source type based on the URI scheme:

| URI Scheme | Behavior |
|------------|----------|
| `gs://bucket/path` | GCS URI - used directly, no upload needed |
| `https://...` or `http://...` | Remote URL - downloaded via `curl`, then uploaded to GCS |
| `/path/to/file` | Local file path - uploaded to GCS |


**Note:** When using HTTP(S) URLs, the image is downloaded to `.terraform/image-downloads/` within the module directory using `curl`, then uploaded to GCS. Ensure you have sufficient disk space for large images.

## Firewall Rule Format

Firewall rules use a pipe-delimited format: `"PORT | PROTOCOL | DESCRIPTION"`

- **PORT**: Single port (`22`), port range (`8000-8100`), or `0` for all ports
- **PROTOCOL**: `tcp`, `udp`, `icmp`, or `all`
- **DESCRIPTION**: Optional human-readable description (used in rule naming)

Refer to the [examples](./examples/) directory for detailed configuration examples.

## Note for contributors

Make sure to use [terraform-docs](https://github.com/terraform-docs/terraform-docs) to generate the configuration parameters of the module (provider requirements, input variables, outputs) should you update them.

```
terraform-docs markdown --hide modules,resources,providers ./
```
