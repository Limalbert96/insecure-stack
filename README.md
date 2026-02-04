# Tasky Infrastructure Demo

This project demonstrates a deliberately vulnerable infrastructure setup for educational purposes. It deploys a task management application (Tasky) on Google Cloud Platform using Terraform.

## Architecture Components

<br><br>![Alt text](<./screenshots/Insecure Diagram.jpg>) 

- **VPC Network**: Custom VPC with public and private subnets
- **GKE Cluster**: Private cluster running the Tasky application (Node.js 14.21.3)
- **MongoDB VM**: Standalone MongoDB 3.6 instance on Ubuntu 16.04
- **Cloud NAT**: For outbound internet access with comprehensive logging
- **Storage Bucket**: Public MongoDB backups (tasky-mongo-backup)
- **GH Container Registry**: Docker repository in GitHub Container Registry
- **IAM & Security**: Deliberately permissive configurations for demonstration

## Security Anti-Patterns (For Learning)

### Infrastructure Level
1. MongoDB VM:
   - Public SSH access (0.0.0.0/0)
   - Outdated Ubuntu 16.04 and MongoDB 3.6
   - Overly permissive service account scopes
   - Daily backups at 2 AM with public access

2. GKE Cluster:
   - Disabled pod security policies and network policies
   - Disabled master authorized networks
   - Disabled integrity monitoring
   - Node pools with container.admin and storage.admin roles
   - Full cloud-platform OAuth scope

3. Storage & IAM:
   - Public read access to backup bucket (allUsers)
   - Overly permissive IAM roles
   - Exposed service account credentials

### Application Level
1. Container Security:
   - Running as root with privileged mode
   - Exposed debug ports
   - All capabilities granted
   - HTTP-only ingress (no TLS)

2. CI/CD Security:
   - Exposed credentials in environment variables
   - No security scanning
   - Using latest tag
   - No signature verification

## Infrastructure Layout

```
terraform/
├── 0-locals.tf         # Project-wide variables and locals
├── 1-providers.tf      # Provider configurations
├── 2-apis.tf          # Required GCP APIs
├── 3-vpc.tf           # VPC network configuration
├── 4-subnets.tf       # Public and private subnets
├── 5-nat.tf           # Cloud NAT for private instances
├── 6-firewalls.tf     # Network security rules
├── 7-gke.tf           # GKE cluster configuration
├── 8-gke_nodes.tf     # GKE node pool settings
├── 9-mongo_vm.tf      # MongoDB instance
├── 10-storage_bucket.tf # Backup storage configuration
├── 11-deploy_k8.tf    # Kubernetes resources deployment
├── 12-audit-logs.tf    # Audit logs configuration
└── 13-cloud-armor.tf    # Cloud Armor Security Policy
```

## Prerequisites

- Google Cloud Project
- Terraform >= 1.0
- `gcloud` CLI configured
- Docker (for building Tasky)

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the plan:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

## Monitoring & Logging

- GKE control plane audit logging enabled
- Component logging for:
  - System components
  - API server
  - Controller manager
  - Scheduler
  - Workloads

## Important Notes

This infrastructure is intentionally designed with security vulnerabilities for educational purposes. DO NOT use this configuration in a production environment.

