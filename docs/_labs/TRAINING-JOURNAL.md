---
title: "DevOps SRE Training Journal — Murali"
date: 2026-05-30
summary: "Complete 55-day training plan — real GCP infrastructure, zero simulations, optimized for free credits"
difficulty: beginner
duration: ongoing
tags:
  - training
  - journal
  - devops
  - sre
  - gcp
---

# DevOps SRE Training Plan — Murali
**Engineer:** Murali  
**Start Date:** 2026-05-30  
**Target:** Senior DevOps/SRE — 45-65 LPA  
**Timeline:** 55 days  
**Credits:** ₹28,114 (~$337) — GCP Free Trial  
**Environment:** payfast-devops-admin | GCP asia-south1 | Ubuntu 22.04  
**Rule:** Every lab runs on real GCP infrastructure — zero simulations

---

## ⚠️ Credit Management — Do This Every Single Day

```bash
# START VM before every session
gcloud compute instances start payfast-devops-admin \
  --zone=asia-south1-a \
  --project=murali-devops-lab

# STOP VM after every session — saves 70% credits
gcloud compute instances stop payfast-devops-admin \
  --zone=asia-south1-a \
  --project=murali-devops-lab
```

**Never leave VM running overnight.**  
e2-medium costs ~₹2,100/month running 24/7.  
Stopped VM costs ~₹200/month (disk only).  
Stopping after every session = credits last 4+ months.

---

## Progress Tracker

| Day | Ticket | Phase | Topic | Status |
|---|---|---|---|---|
| DAY-1 | PAYFAST-001 | Linux | Operational Readiness & System Audit | ✅ Complete |
| DAY-2 | PAYFAST-002 | Linux | Networking Diagnostics | ✅ Complete |
| DAY-3 | PAYFAST-003 | Linux | Storage & Disk Management | ⏳ Pending |
| DAY-4 | PAYFAST-004 | Linux | Process, Service Management & Shell Scripting | ⏳ Pending |
| DAY-5 | PAYFAST-005 | Linux | Users, Permissions, Security & Performance Tuning | ⏳ Pending |
| DAY-6 | PAYFAST-006 | Git | Fundamentals, Daily Workflow & Branching | ⏳ Pending |
| DAY-7 | PAYFAST-007 | GitHub | Repos, PRs, Actions & Collaboration | ⏳ Pending |
| DAY-8 | PAYFAST-008 | Networking | DNS Deep Dive on GCP | ⏳ Pending |
| DAY-9 | PAYFAST-009 | Networking | TLS/SSL, Certificates & HTTPS on GCP | ⏳ Pending |
| DAY-10 | PAYFAST-010 | Docker | Architecture & Fundamentals | ⏳ Pending |
| DAY-11 | PAYFAST-011 | Docker | Images & Dockerfile Best Practices | ⏳ Pending |
| DAY-12 | PAYFAST-012 | Docker | Networking & Volumes | ⏳ Pending |
| DAY-13 | PAYFAST-013 | Docker | Docker Compose & Multi-container Apps | ⏳ Pending |
| DAY-14 | PAYFAST-014 | Docker | Production Hardening, Security & Registry | ⏳ Pending |
| DAY-15 | PAYFAST-015 | Kubernetes | Architecture & Core Concepts | ⏳ Pending |
| DAY-16 | PAYFAST-016 | Kubernetes | Pods, Deployments & ReplicaSets | ⏳ Pending |
| DAY-17 | PAYFAST-017 | Kubernetes | Services, Ingress & DNS | ⏳ Pending |
| DAY-18 | PAYFAST-018 | Kubernetes | ConfigMaps, Secrets & Volumes | ⏳ Pending |
| DAY-19 | PAYFAST-019 | Kubernetes | RBAC & Security | ⏳ Pending |
| DAY-20 | PAYFAST-020 | Kubernetes | Resource Management & Autoscaling | ⏳ Pending |
| DAY-21 | PAYFAST-021 | Kubernetes | Helm & Package Management | ⏳ Pending |
| DAY-22 | PAYFAST-022 | Kubernetes | Troubleshooting & Debugging | ⏳ Pending |
| DAY-23 | PAYFAST-023 | Terraform | Fundamentals & HCL | ⏳ Pending |
| DAY-24 | PAYFAST-024 | Terraform | State Management & Remote Backend on GCP | ⏳ Pending |
| DAY-25 | PAYFAST-025 | Terraform | GCP Infrastructure Provisioning | ⏳ Pending |
| DAY-26 | PAYFAST-026 | Terraform | Modules, Workspaces & Environments | ⏳ Pending |
| DAY-27 | PAYFAST-027 | Ansible | Fundamentals, Playbooks & Roles | ⏳ Pending |
| DAY-28 | PAYFAST-028 | Ansible | GCP Dynamic Inventory & Production Automation | ⏳ Pending |
| DAY-29 | PAYFAST-029 | CI/CD | GitHub Actions Fundamentals | ⏳ Pending |
| DAY-30 | PAYFAST-030 | CI/CD | Docker Build & Push Pipeline to Artifact Registry | ⏳ Pending |
| DAY-31 | PAYFAST-031 | CI/CD | Deploy to GKE Pipeline | ⏳ Pending |
| DAY-32 | PAYFAST-032 | CI/CD | GitOps with ArgoCD on GKE | ⏳ Pending |
| DAY-33 | PAYFAST-033 | CI/CD | Pipeline Security, Secrets & Multi-env Promotion | ⏳ Pending |
| DAY-34 | PAYFAST-034 | Monitoring | Prometheus & Grafana on GKE | ⏳ Pending |
| DAY-35 | PAYFAST-035 | Monitoring | Alerting Rules, PagerDuty & On-call Workflow | ⏳ Pending |
| DAY-36 | PAYFAST-036 | Monitoring | Log Aggregation with Loki & GCP Cloud Logging | ⏳ Pending |
| DAY-37 | PAYFAST-037 | Monitoring | GCP Cloud Monitoring, Dashboards & Ops Agent | ⏳ Pending |
| DAY-38 | PAYFAST-038 | GCP | VPC, Subnets, Firewall Rules & Cloud DNS | ⏳ Pending |
| DAY-39 | PAYFAST-039 | GCP | GKE Production Cluster Setup & Node Pools | ⏳ Pending |
| DAY-40 | PAYFAST-040 | GCP | IAM, Service Accounts & Workload Identity | ⏳ Pending |
| DAY-41 | PAYFAST-041 | GCP | Cloud Storage, GCS Lifecycle & Bucket Policies | ⏳ Pending |
| DAY-42 | PAYFAST-042 | GCP | Cloud Run, Serverless & Cloud Functions | ⏳ Pending |
| DAY-43 | PAYFAST-043 | GCP | Cloud Load Balancing, SSL & Cloud Armor | ⏳ Pending |
| DAY-44 | PAYFAST-044 | GCP | Cost Optimization, Billing Alerts & Budget Control | ⏳ Pending |
| DAY-45 | PAYFAST-045 | Troubleshooting | Linux Performance Incidents | ⏳ Pending |
| DAY-46 | PAYFAST-046 | Troubleshooting | Network Incident Simulation on GCP | ⏳ Pending |
| DAY-47 | PAYFAST-047 | Troubleshooting | Kubernetes Production Failures on GKE | ⏳ Pending |
| DAY-48 | PAYFAST-048 | Troubleshooting | Full Stack Incident Simulation | ⏳ Pending |
| DAY-49 | PAYFAST-049 | SRE | SLI, SLO, SLA & Error Budgets on GCP | ⏳ Pending |
| DAY-50 | PAYFAST-050 | SRE | Runbooks, Postmortems & On-call Management | ⏳ Pending |
| DAY-51 | PAYFAST-051 | SRE | Capacity Planning, Load Testing & Chaos Engineering | ⏳ Pending |
| DAY-52 | PAYFAST-052 | AI for DevOps | AI Tools in Production DevOps Workflow | ⏳ Pending |
| DAY-53 | PAYFAST-053 | AI for DevOps | LLMs for Automation, Scripting & AI Runbooks | ⏳ Pending |
| DAY-54 | PAYFAST-054 | Interview Prep | System Design + GCP Architecture Scenarios | ⏳ Pending |
| DAY-55 | PAYFAST-055 | Interview Prep | Kubernetes Scenarios + Full Mock Interview | ⏳ Pending |

---

## Phase Summary

| Phase | Days | GCP Services Used |
|---|---|---|
| Linux | DAY 1-5 | Compute Engine, Cloud Monitoring, Cloud Logging |
| Git & GitHub | DAY 6-7 | GitHub, Cloud Source Repositories |
| Networking | DAY 8-9 | Cloud DNS, Certificate Manager, Cloud Armor |
| Docker | DAY 10-14 | Compute Engine, Artifact Registry |
| Kubernetes | DAY 15-22 | GKE, Cloud Load Balancing, Artifact Registry |
| Terraform | DAY 23-26 | All GCP services via Terraform, GCS backend |
| Ansible | DAY 27-28 | Compute Engine, GCP dynamic inventory |
| CI/CD | DAY 29-33 | GitHub Actions, Cloud Build, Artifact Registry, GKE, ArgoCD |
| Monitoring | DAY 34-37 | GKE, Cloud Monitoring, Cloud Logging, Prometheus, Grafana |
| GCP Deep Dive | DAY 38-44 | VPC, GKE, IAM, GCS, Cloud Run, Cloud Load Balancing, Billing |
| Troubleshooting | DAY 45-48 | GKE, Compute Engine, Cloud Logging, Cloud Monitoring |
| SRE Practices | DAY 49-51 | Cloud Monitoring, GKE, Load testing tools |
| AI for DevOps | DAY 52-53 | Vertex AI, Cloud Monitoring, GKE |
| Interview Prep | DAY 54-55 | Full GCP stack review |

---

## GCP Services Across Training

| GCP Service | First Used | Phase |
|---|---|---|
| Compute Engine | DAY-1 | Linux |
| Cloud Monitoring | DAY-1 | Linux |
| Cloud Logging | DAY-1 | Linux |
| Cloud DNS | DAY-8 | Networking |
| Certificate Manager | DAY-9 | Networking |
| Artifact Registry | DAY-14 | Docker |
| GKE | DAY-15 | Kubernetes |
| Cloud Load Balancing | DAY-17 | Kubernetes |
| Cloud Storage (GCS) | DAY-24 | Terraform |
| Cloud Build | DAY-30 | CI/CD |
| Cloud Run | DAY-42 | GCP Deep Dive |
| Cloud Armor | DAY-43 | GCP Deep Dive |
| Vertex AI | DAY-52 | AI for DevOps |
| IAM | DAY-40 | GCP Deep Dive — used throughout |

---

## Cert Refresh Mapping

| Certification | Relevant Days |
|---|---|
| GCP Professional Cloud Engineer | DAY 8-9, DAY 38-44, DAY 54-55 |
| CKA (Certified Kubernetes Administrator) | DAY 15-22, DAY 45-48 |
| CKAD (Certified Kubernetes App Developer) | DAY 15-18, DAY 21 |

---

## Credit Burn Estimate

| Scenario | Monthly Cost | Notes |
|---|---|---|
| VM running 24/7 | ~₹2,100/month | Never do this |
| VM running 8hrs/day | ~₹700/month | Acceptable |
| VM stopped after every session | ~₹200/month | Target behaviour |
| GKE cluster running 24/7 | ~₹3,500/month | Never do this |
| GKE cluster deleted after each lab | ~₹150/session | Correct approach |

```bash
# Delete GKE cluster after every Kubernetes lab
gcloud container clusters delete <cluster-name> \
  --zone=asia-south1-a \
  --project=murali-devops-lab

# Check current spend
gcloud billing accounts list
gcloud beta billing projects describe murali-devops-lab
```
