---
title: "Provisioning a GCP VPC with Terraform Modules"
date: 2026-05-25
summary: "Wrote a reusable Terraform module to provision a custom VPC network on GCP with private subnets, Cloud NAT, and firewall rules following the principle of least privilege."
difficulty: intermediate
duration: 60 mins
tags: [terraform, gcp, networking, iac]
github_link: https://github.com/opsflux-labs/daily-labs/tree/main/terraform/gcp-vpc-module
---

## Scenario

Set up a production-grade VPC on GCP that follows least-privilege networking principles — private subnets only, outbound internet via Cloud NAT, no public IPs on compute instances.

## Module Structure

```
modules/
  gcp-vpc/
    main.tf
    variables.tf
    outputs.tf
```

## Implementation

**`variables.tf`** — define inputs:

```hcl
variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}
```

**`main.tf`** — VPC, subnet, NAT, firewall:

```hcl
resource "google_compute_network" "vpc" {
  name                    = "opsflux-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "private" {
  name          = "opsflux-private-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

resource "google_compute_router" "router" {
  name    = "opsflux-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "opsflux-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  project                            = var.project_id
}
```

## Plan & Apply

```bash
terraform init
terraform plan -var="project_id=opsflux-prod"
terraform apply -var="project_id=opsflux-prod" -auto-approve
```

Output:
```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

## Verification

```bash
gcloud compute networks list --project=opsflux-prod
gcloud compute routers nats list --router=opsflux-router --region=asia-south1
```

## Key Learnings

- `auto_create_subnetworks = false` is essential for custom VPC layouts
- Cloud NAT must be attached to a Router, not directly to the VPC
- Always use variables + outputs for reusable modules — hardcoding project IDs breaks reuse

---

> **Time taken:** 60 minutes | **Difficulty:** Intermediate
