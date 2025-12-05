# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains Terraform infrastructure for managing cloud resources across AWS and Cloudflare. The infrastructure is organized into three independent modules:

- **bootstrap/**: One-time setup that creates the S3 backend and DynamoDB table for Terraform state management
- **k8s/**: AWS Kubernetes cluster infrastructure (1 bastion, 1 control plane, 3 workers)
- **dns/**: Cloudflare DNS management for kd3bwz.net and mckinnie.org domains

Each module has its own Terraform state stored in the shared S3 backend (except bootstrap, which uses local state).

## Secrets Management

Secrets are managed using SOPS encryption with age:

```bash
# Encrypt secrets (requires SOPS_PUBLIC_KEY environment variable)
make encrypt_secrets

# Decrypt for local use (requires age private key)
sops -d secrets.enc.yaml > secrets.yaml
```

The `secrets.yaml` file contains:
- AWS credentials (access key ID and secret access key)
- Cloudflare API token and account ID

**Important**: Never commit `secrets.yaml` (unencrypted) to version control. Only `secrets.enc.yaml` should be committed.

## Working with Terraform Modules

Each module (bootstrap, k8s, dns) is independent and must be managed separately:

```bash
# Navigate to the specific module directory
cd k8s/  # or dns/, or bootstrap/

# Standard Terraform workflow
terraform init      # Initialize (required after cloning or updating providers)
terraform validate  # Validate configuration
terraform plan      # Preview changes
terraform apply     # Apply changes
terraform destroy   # Destroy infrastructure
terraform show      # Show current state
terraform state list  # List resources in state
```

### Bootstrap Module

Run this **only once** with local state to create the shared infrastructure:
- S3 bucket: `jmckinnie-cloud-infra` (versioned, encrypted, public access blocked)
- DynamoDB table: `terraform-state-lock` (for state locking)

This module uses local state (`terraform.tfstate` in the bootstrap directory).

### K8s Module

Provisions a Kubernetes cluster on AWS for CKA exam practice. See `k8s/CLAUDE.md` for detailed architecture documentation.

Key outputs:
```bash
terraform output bastion_ip    # Get bastion host public IP
terraform output natgw_eip     # Get NAT gateway elastic IP
```

**Note**: The cloudinit.sh script installs prerequisites but doesn't fully initialize Kubernetes. Manual `kubeadm init` and `kubeadm join` steps are required.

### DNS Module

Manages Cloudflare DNS records for two domains. Uses remote state from the k8s module to automatically update the bastion host DNS record.

Key features:
- Reads bastion IP from k8s module's remote state (`data.terraform_remote_state.aws`)
- Manages email security records (SPF, DKIM, DMARC)
- Creates A record for bastion.kd3bwz.net pointing to the k8s bastion host

## State Backend Configuration

All modules (except bootstrap) use the same S3 backend:
- Bucket: `jmckinnie-cloud-infra`
- Region: `us-east-1`
- Encryption: Enabled
- DynamoDB table: `terraform-state-lock`

State keys:
- `k8s/terraform.tfstate` - Kubernetes infrastructure
- `dns/terraform.tfstate` - DNS records

## Cross-Module Dependencies

The DNS module depends on the k8s module's state:
```hcl
data "terraform_remote_state" "aws" {
  backend = "s3"
  config = {
    bucket = "jmckinnie-cloud-infra"
    key    = "k8s/terraform.tfstate"
    region = "us-east-1"
  }
}
```

This allows DNS records to automatically use the bastion host's public IP.

## Key Files Structure

```
.
├── secrets.yaml           # Unencrypted secrets (gitignored)
├── secrets.enc.yaml       # Encrypted secrets (committed)
├── Makefile              # Helper commands for SOPS encryption
├── bootstrap/
│   ├── main.tf           # S3 bucket and DynamoDB table definitions
│   └── README.md
├── k8s/
│   ├── main.tf           # VPC, instances, security groups, IAM
│   ├── cloudinit.sh      # Instance initialization script
│   ├── providers.tf      # AWS provider with SOPS credentials
│   ├── backend.tf        # S3 backend configuration
│   ├── secrets.tf        # SOPS data source
│   ├── outputs.tf        # Bastion and NAT gateway IPs
│   └── CLAUDE.md         # Detailed k8s architecture docs
└── dns/
    ├── main.tf           # Cloudflare zones and DNS records
    ├── providers.tf      # Cloudflare provider
    ├── backend.tf        # S3 backend configuration
    └── secrets.tf        # SOPS data source
```

## Common Workflows

### Deploying the Full Stack
```bash
# 1. Bootstrap (if not already done)
cd bootstrap/
terraform init && terraform apply
cd ..

# 2. Deploy K8s cluster
cd k8s/
terraform init && terraform apply
cd ..

# 3. Update DNS records
cd dns/
terraform init && terraform apply
```

### Updating Only DNS
```bash
cd dns/
terraform plan   # Preview changes
terraform apply  # Apply changes
```

### Destroying Infrastructure
```bash
# Destroy in reverse order to respect dependencies
cd dns/ && terraform destroy
cd ../k8s/ && terraform destroy
# Keep bootstrap infrastructure (S3 + DynamoDB) unless decommissioning entirely
```

## Important Considerations

- The bootstrap module should rarely need changes after initial setup
- Changes to k8s module outputs (like bastion IP) will automatically trigger DNS updates when dns module is applied
- All modules use SOPS-encrypted secrets; ensure age private key is available for decryption
- SSH key from `~/.ssh/id_ed25519.pub` is used for all EC2 instances
