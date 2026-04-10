# Terraform Infrastructure

AWS infrastructure for the Mercury platform, defined as code with Terraform. Covers network topology (VPC, subnets, NAT), application layer (ALB, EC2, security groups), ECR registries, and GitHub Actions OIDC federation — all parameterized for multi-environment deployment.

---

## Structure

```
terraform-infra/
├── bootstrap/          # One-time setup: S3 state bucket, DynamoDB lock table, OIDC role
├── modules/
│   ├── network/        # VPC, public/private subnets, IGW, NAT gateway, route tables
│   ├── iam/            # IAM roles, instance profiles, OIDC trust policies
│   └── app/            # ALB, target groups, EC2 instances, security groups
└── infra/              # Root module — wires everything together, remote state config
```

---

## What it provisions

| Resource | Detail |
|----------|--------|
| **VPC** | Custom CIDR, public + private subnets across AZs |
| **NAT Gateway** | Private subnet egress with Elastic IP |
| **ALB** | Internet-facing load balancer with health check target groups |
| **EC2** | App instances in private subnets, bootstrapped via user data (Docker pull + run) |
| **Security groups** | ALB → App chaining; no direct internet access to instances |
| **ECR** | Container registries per service |
| **IAM OIDC** | GitHub Actions trust relationship — no stored AWS credentials |
| **Remote state** | S3 backend + DynamoDB locking for concurrent-safe plan/apply |

---

## Network topology

```
Internet
    │
    ▼
[IGW] → [ALB] (public subnet)
              │
              ▼
         [EC2 App] (private subnet)
              │
         [NAT GW] → Internet (egress only)
```

Application instances are never directly reachable from the internet. All inbound traffic goes through the ALB; outbound traffic (Docker pulls, package updates) exits via NAT.

---

## Design decisions

### Bootstrap is a separate apply

The `bootstrap/` directory creates the S3 bucket and DynamoDB table that the main modules use for remote state. This chicken-and-egg problem is solved by running bootstrap once with local state, then switching the main infra to remote.

### GitHub Actions OIDC — zero stored credentials

The IAM OIDC provider trusts GitHub's token issuer. GitHub Actions jobs assume a role via `sts:AssumeRoleWithWebIdentity` using a short-lived token — no AWS access keys are stored in GitHub Secrets.

The trust policy restricts which repos and branches can assume the role (`sub` claim pattern matching), so a compromised fork can't deploy.

### Cross-stack references via remote state datasource

The `app` module reads VPC IDs and subnet IDs from the `network` module's remote state rather than duplicating outputs. This means network changes propagate to app infrastructure automatically on the next plan.

### EC2 user data for container deployment

Instances pull and run Docker images on boot via base64-encoded user data scripts. This is intentionally simple — no orchestrator for a small platform. Kubernetes (via `url-shortener-service`) handles services that need rolling deployments and health-based routing.

---

## Usage

```bash
# One-time bootstrap
cd bootstrap
terraform init && terraform apply

# Deploy infrastructure
cd ../infra
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

CI/CD runs `terraform plan` on PRs and `terraform apply` on merge to main via the reusable workflow in [reusable-workflows](../reusable-workflows).
