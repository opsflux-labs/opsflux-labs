---
Title: "PAYFAST-001 Infrastructure Foundation and Linux Operations"
date: 2026-05-26
summary: "Validated Linux VM baseline, inspected networking, analyzed system services, and prepared the cloud engineering environment for future DevOps labs."
difficulty: beginner
duration: 45 mins
tags: [linux, gcp, networking, devops, sre]
github_link: https://github.com/opsflux-labs/opsflux-app/tree/main/runbooks/

---

# PAYFAST-001 — Infrastructure Foundation and Linux Operations

## Objective

Validate and document the baseline cloud engineering environment running on GCP.

---

## Scenario

A new Linux VM has been provisioned for the OpsFlux platform engineering team.

The environment must be validated before onboarding future workloads including:
- Docker
- Kubernetes
- Terraform
- monitoring stack
- CI/CD tooling

Tasks include:
- validating VM resources
- inspecting networking
- reviewing running services
- verifying DevOps tooling installation
- documenting operational findings

---

## Environment

| Component     | Details |
|---        |      ---|
| Cloud Provider | GCP |
| VM Name | payfast-devops-admin |
| OS | Ubuntu 22.04 |
| Access Method | VS Code Remote SSH |
| Repository | opsflux-app |

---

## Investigation

---

### Validate System Information

```bash
hostname
uname -a
uptime
lscpu
free -m
df -h
```
---

### Inspect Networking

```bash
ip addr
ss -tulnp
```
---

### Inspect Services

```bash
systemctl status ssh
systemctl list-units --type=service
```
---

### Verify DevOps Toolchain

```bash
docker ps
kubectl version --client
terraform version
helm version
ansible --version
gcloud version
```

---

## Findings

- VM resources were correctly allocated
- Docker service operational
- Kubernetes CLI installed successfully
- Terraform and Helm available
- SSH connectivity stable
- Static public IP configured
- Repository structure validated

---

## Root Cause / Operational Risk

Potential operational risks identified:
- accidental exposure of secrets in public GitHub repository
- inconsistent Git authentication workflow
- lack of `.gitignore` baseline initially

---

## Fix / Improvements Applied

---

### Configure SSH Git Authentication

```bash
ssh-keygen -t ed25519 -C "opsflux-gcp-vm"
ssh -T git@github.com
```

---

### Configure GitHub Pages

```bash
mv index.html docs/
git add .
git commit -m "Move GitHub Pages site into docs directory"
git push origin main
```

---

### Repository Cleanup

```bash
rm -rf opsflux-app
tree -L 2
```

---

## Result

Successfully established:
- production-style cloud engineering lab
- GitHub SSH authentication
- GitHub Pages deployment
- custom domain integration
- VS Code remote workflow
- DevOps tooling baseline

Website:
- https://opsflux.in

Repository:
- https://github.com/opsflux-labs/opsflux-app

---

## Key Learnings

- Linux operational basics are foundational for DevOps work
- SSH authentication is cleaner than HTTPS + PAT workflows
- GitHub Pages supports `/docs` structure effectively
- Infrastructure organization matters early
- Public repositories require strict secret management discipline

---

## Next Steps

Upcoming focus areas:
- VPC architecture
- subnet design
- firewall rules
- Docker fundamentals
- Terraform basics
- observability tooling

---

> Time taken: 45 minutes  
> Difficulty: Beginner  
> Status: Completed