# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains Terraform infrastructure code for provisioning a Kubernetes cluster on AWS. The architecture consists of:
- 1 bastion host in a public subnet (for secure access)
- 1 control plane node in a private subnet
- 3 worker nodes in a private subnet
- VPC with separate public/private subnets and NAT gateway

## Terraform Commands

```bash
# Initialize Terraform (required after cloning or updating providers)
terraform init

# Validate configuration
terraform validate

# Plan changes (preview what will be created/modified/destroyed)
terraform plan

# Apply changes to provision infrastructure
terraform apply

# Destroy all infrastructure
terraform destroy

# Show current state
terraform show

# List resources in state
terraform state list

# Get specific output values
terraform output bastion_ip
terraform output natgw_eip
```

## Architecture Details

### Network Architecture
- **VPC CIDR**: 10.0.0.0/16
- **Public subnet**: 10.0.1.0/28 (11 usable IPs) in us-east-1a
- **Private subnet**: 10.0.10.0/27 (27 usable IPs) in us-east-1a
- Public subnet routes through Internet Gateway
- Private subnet routes through NAT Gateway for outbound traffic

### Security Groups
The infrastructure uses three security groups with specific port allowances:

**bastion-sg**: SSH (22) from home IP only, all outbound

**k8s-control-plane-sg**:
- SSH (22) from bastion only
- Kubernetes API (6443) from private subnet
- etcd (2379-2380) from self
- Kubelet API (10250) from private subnet
- kube-scheduler (10259) from self
- kube-controller-manager (10257) from self

**k8s-worker-sg**:
- SSH (22) from bastion only
- Kubelet API (10250) from control plane
- NodePort services (30000-32767) from private subnet
- All traffic from control plane and self (pod-to-pod)

### IAM Roles
**Control Plane**: Broad EC2/ELB permissions (marked with TODO to narrow down) + ECR read access

**Worker Nodes**: Limited EC2 describe permissions, volume management in us-east-1, and ECR read access

### Instance Configuration
- **Bastion**: c6gd.medium, 10GB GP3 encrypted root volume
- **Control Plane**: c6gd.large, 30GB GP3 encrypted root volume
- **Workers**: c6gd.large (count=3), 20GB GP3 encrypted root volumes
- All instances use ARM-based AMI (ami-083f1fc4f8bcff379)
- All instances require IMDSv2 (http_tokens = "required")
- SSH key from ~/.ssh/id_ed25519.pub

### Cloud-Init Script
The `cloudinit.sh` script (main.tf:292, main.tf:318) runs on control plane and worker nodes to:
1. Install containerd with systemd cgroup driver
2. Configure kernel modules (overlay, br_netfilter) and sysctl for Kubernetes networking
3. Add Docker and Kubernetes v1.34 apt repositories
4. Note: The script is incomplete - it installs dependencies but doesn't initialize kubeadm

### State Management
- **Backend**: S3 bucket `jmckinnie-cloud-infra` with key `k8s/terraform.tfstate`
- **State Locking**: DynamoDB table `terraform-state-lock`
- **Region**: us-east-1
- State is encrypted

### Secrets Management
Secrets are managed using SOPS (secrets.enc.yaml in parent directory):
- AWS access credentials loaded from `../secrets.enc.yaml`
- Source IP dynamically fetched from checkip.amazonaws.com

## File Structure

- **main.tf**: Primary infrastructure definitions (VPC, subnets, instances, security groups, IAM)
- **providers.tf**: AWS provider configuration with credentials from SOPS
- **backend.tf**: S3 backend configuration for state storage
- **versions.tf**: Terraform version constraints and required providers
- **secrets.tf**: SOPS data source and locals for credentials/config
- **outputs.tf**: Bastion and NAT gateway public IPs
- **cloudinit.sh**: User data script for instance initialization

## Important Notes

- The control plane IAM policy has overly broad ec2:* and elasticloadbalancing:* permissions (main.tf:382) - this should be narrowed down
- The cloudinit.sh script is incomplete and doesn't fully initialize Kubernetes - manual kubeadm init/join steps are required
- All security group rules reference specific ports based on Kubernetes documentation
- The bastion is the only public-facing resource; all K8s nodes are in private subnet
