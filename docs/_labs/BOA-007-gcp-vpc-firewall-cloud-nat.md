---
title: "BOA-007 (Day 2) — GCP Networking Deep Dive: VPC, Firewall Hardening & Cloud NAT"
tags: [networking, gcp, vpc, firewall, cloud-nat, security]
phase: "Phase 3 - Networking"
day: 12
---

## 🎫 JIRA Ticket — OPSFLUX-312

**Priority:** P2 – Medium
**Assigned to:** Murali (DevOps Engineer)
**Reported by:** Platform Lead, OpsFlux Infra Team
**Component:** GCP Networking / `murali-devops-lab`

**Summary:** Network foundation review ahead of GKE rollout (Phase 5)

**Description:**
The `murali-devops-lab` GCP project was running on the default auto-mode VPC network with no audit of firewall exposure. Before GKE provisioning in Phase 5, the network layer needed to be audited and hardened:

- Document current VPC, subnets, and firewall rules
- Identify risks in the default configuration (overly broad SSH/RDP exposure)
- Tighten firewall rules to least-privilege
- Configure Cloud NAT for future private workloads (GKE nodes without external IPs)
- Confirm VM connectivity is maintained throughout — no SSH lockout

---

## Windows → Linux/GCP Reference Table

| Windows/Familiar Concept | Linux/GCP Equivalent | Context Used Today |
|---|---|---|
| AD group membership (permissions) | IAM roles | What an identity is *allowed* to do |
| Kerberos ticket claims (limited scope) | OAuth scopes on a credential | What a *token* is allowed to request — VM service account had IAM access but token lacked Compute API scope |
| "Network Service" built-in account | GCE default service account | Active gcloud identity was the VM's service account, not Murali's user |
| `netstat -an` "Foreign Address" column | `$SSH_CONNECTION` env var | Finding the source IP of the current session |
| Windows Firewall "Allow All" profile | GCP `default` network's open rules | `0.0.0.0/0` on SSH/RDP — audit finding #1 |
| Home router NAT (private devices share public IP) | Cloud NAT | Outbound-only internet access for IP-less resources |
| PowerShell unclosed string → `>>` prompt | Bash unclosed quote → `>` prompt | Diagnosing a malformed `--format` command |
| `Get-VM \| Format-List *` | `gcloud compute instances describe` | Dumping full VM configuration |

---

## Investigation Phases

### Phase 1 — Investigate Current Network State

**Unplanned incident en route:** first `gcloud compute networks list` failed with `insufficient authentication scopes`.

```bash
gcloud auth list
gcloud config list
```
**Finding:** active account was `25770327604-compute@developer.gserviceaccount.com` — the VM's default service account, whose token lacked Compute API scope.

**Fix:**
```bash
gcloud auth login --no-launch-browser
```
Authenticated as `learning.gcp.devops@gmail.com` via device-code flow (URL opened on Windows browser, code pasted back into SSH session). This becomes the active gcloud credential going forward.

---

```bash
gcloud compute networks list
```
**Output:**
```
NAME         SUBNET_MODE  BGP_ROUTING_MODE
default      AUTO         REGIONAL
payfast-vpc  CUSTOM       REGIONAL
```
**What to look for:** Two networks — `default` (AUTO mode, GCP's auto-created network) and `payfast-vpc` (CUSTOM mode, pre-existing from earlier work).

---

```bash
gcloud compute networks subnets list
```
**Findings:**
- `default` network has a `/20` (4,096-address) subnet auto-created in **every GCP region globally** (~40+ regions) — massive unnecessary footprint for a project operating only in `asia-south1`
- `payfast-vpc` has 3 deliberately-designed `/24` subnets, all in `asia-south1`:
  - `payfast-web-subnet` — `10.0.1.0/24`
  - `payfast-db-subnet` — `10.0.2.0/24`
  - `payfast-cache-subnet` — `10.0.3.0/24`

---

```bash
gcloud compute instances describe boa-devops-admin --zone=asia-south1-a | grep -E "network:|subnetwork:|networkIP:"
```
**Output:**
```
network: .../networks/default
networkIP: 10.160.0.13
subnetwork: .../subnetworks/default
```
**Finding:** `boa-devops-admin` runs on the `default` network's `asia-south1` subnet (`10.160.0.0/20`), with external IP `8.231.98.123` via an "External NAT" access config (a 1:1 public IP mapping — distinct from Cloud NAT).

---

```bash
gcloud compute firewall-rules list
gcloud compute firewall-rules list --format="table(name,network,sourceRanges.list())"
```
**Findings — 10 rules total:**

| Rule | Network | Source | Port | Risk |
|---|---|---|---|---|
| `default-allow-ssh` | default | `0.0.0.0/0` | tcp:22 | 🔴 SSH open to internet |
| `default-allow-rdp` | default | `0.0.0.0/0` | tcp:3389 | 🔴 RDP open, unused (Linux VM) |
| `payfast-allow-ssh` | payfast-vpc | `0.0.0.0/0` | tcp:22 | 🔴 SSH open on unused VPC |
| `allow-jekyll` | default | `0.0.0.0/0` | tcp:4000 | 🟡 Needs review |
| `default-allow-http/https` | default | `0.0.0.0/0` | tcp:80/443 | 🟢 Expected |
| `payfast-allow-web` | payfast-vpc | `0.0.0.0/0` | tcp:80/443 | 🟢 Expected (unused VPC) |
| `default-allow-internal` | default | `10.128.0.0/9` | all ports | 🟡 Covers all global default-network subnets |
| `payfast-allow-internal` | payfast-vpc | `10.0.0.0/8` | tcp/udp/icmp | 🟡 Broader than 3 payfast subnets need |
| `default-allow-icmp` | default | `0.0.0.0/0` | icmp | 🟢 Normal |

---

### Phase 2 — Remediate Low-Risk Findings First

```bash
gcloud compute firewall-rules delete default-allow-rdp
```
Unused (Linux VM, no RDP service) — zero impact, removed cleanly.

```bash
gcloud compute firewall-rules delete payfast-allow-ssh payfast-allow-web payfast-allow-internal
```
**Decision:** since `payfast-vpc` has nothing deployed, we removed **all 3** rules for a clean slate — firewall rules for this network will be redesigned via Terraform in Phase 7 when something is actually deployed there. GCP firewalls are default-deny, so `payfast-vpc` now allows nothing in/out — the correct secure baseline for an empty network.

---

### Phase 3 — Lock Down SSH Access (Default Network)

```bash
echo $SSH_CONNECTION
```
**Output:** `49.43.250.104 50400 10.160.0.13 22` → client IP `49.43.250.104`

**Safety net:** opened a second, independent SSH connection (separate terminal window, not a multiplexed VS Code split) to test post-change — firewall changes don't kill *existing* connections, only new ones, so a fresh connection is the only valid test.

```bash
gcloud compute firewall-rules update default-allow-ssh --source-ranges=49.43.250.104/32
```
Restricted SSH from `0.0.0.0/0` to a single `/32` (one host). Verified with a brand-new `ssh learning_gcp_devops@8.231.98.123` connection from a separate terminal — succeeded, no lockout.

**Side finding:** previous login record showed `35.235.243.129` — within Google's IAP range (`35.235.240.0/20`), confirming GCP Console's browser-based SSH (via Identity-Aware Proxy) is a working fallback if ever locked out.

---

### Phase 4 — Set Up Cloud NAT (on `payfast-vpc`)

**Decision:** Cloud NAT was built on `payfast-vpc` (not `default`), since `boa-devops-admin` already has its own external IP, but `payfast-vpc` is the likely home for future GKE nodes (Phase 5), which typically run without external IPs.

```bash
gcloud compute routers create boa-nat-router --network=payfast-vpc --region=asia-south1
```
Cloud Router — a required parent resource for Cloud NAT, even without BGP/dynamic routing.

```bash
gcloud compute routers nats create boa-cloud-nat \
  --router=boa-nat-router \
  --region=asia-south1 \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges
```
NAT gateway attached to the router. `--auto-allocate-nat-external-ips` lets GCP manage outbound IPs automatically; `--nat-all-subnet-ip-ranges` covers all 3 `payfast-vpc` subnets in `asia-south1`.

```bash
gcloud compute routers nats describe boa-cloud-nat --router=boa-nat-router --region=asia-south1
```
**Output confirmed:**
```
natIpAllocateOption: AUTO_ONLY
sourceSubnetworkIpRangesToNat: ALL_SUBNETWORKS_ALL_IP_RANGES
type: PUBLIC
```

**Note:** configuration verified; live traffic testing deferred until GKE nodes are deployed in `payfast-vpc` during Phase 5.

---

## Root Cause

The project was running entirely on GCP defaults: an `AUTO`-mode `default` network with subnets sprawled across 40+ regions, SSH and RDP open to `0.0.0.0/0`, and a second unused network (`payfast-vpc`) with SSH also wide open. No Cloud NAT existed for future private workloads. None of this had been audited since the project was created.

## Fix

- Removed `default-allow-rdp` (unused)
- Removed all 3 `payfast-vpc` firewall rules (unused network, clean slate)
- Restricted `default-allow-ssh` to specific source IPs (`49.43.250.104/32`, later extended to include `203.0.113.77/32`)
- Removed `allow-jekyll` (tcp:4000, open to internet, confirmed nothing listening via `ss -tulnp`)
- Provisioned Cloud Router (`boa-nat-router`) + Cloud NAT gateway (`boa-cloud-nat`) on `payfast-vpc`, covering all subnets in `asia-south1`

## Result

- Firewall rule count: **10 → 5**
- SSH attack surface on `default` network: **0.0.0.0/0 → 2 specific IPs**
- `payfast-vpc`: zero open ports (secure baseline) + NAT-ready for future GKE private nodes
- VM connectivity verified throughout via fresh SSH connections — **zero lockouts**

---

## Key Learnings

- OAuth **scopes** (what a credential's token can request) ≠ IAM **permissions** (what an identity can do) — a VM's service account can have correct IAM roles but still fail API calls due to limited scopes set at VM creation
- `gcloud auth login --no-launch-browser` enables user-account authentication on headless/SSH-only machines via device-code flow
- GCP's `default` AUTO-mode network creates a `/20` subnet in every region globally — major unnecessary footprint for single-region projects
- Firewall rule **priority**: lower number = higher precedence; GCP's auto-created baseline rules sit at `65534`
- `gcloud compute firewall-rules update --source-ranges=` **replaces** the entire list — must specify the full comma-separated set to add an IP without dropping existing access
- `$SSH_CONNECTION` reveals the current session's source IP — useful for scoping firewall rules to "just me"
- Cloud NAT requires a **Cloud Router** as a prerequisite, even without BGP
- Cloud Router and Cloud NAT are **regional** resources — a setup in `asia-south1` does not extend to `asia-south2`
- An open firewall port with no listening service is latent risk, not active risk — `ss -tulnp` confirms what's actually listening before deciding a rule's fate
- Always test firewall changes affecting your own access with a **fresh, independent connection** — not a reused/multiplexed session

---

## Command Reference Table

| Command | Purpose |
|---|---|
| `gcloud auth list` | Show which account is currently active for gcloud |
| `gcloud config list` | Show active project/account configuration |
| `gcloud auth login --no-launch-browser` | Authenticate as a user via device-code flow (no browser on host) |
| `gcloud compute networks list` | List all VPC networks in the project |
| `gcloud compute networks subnets list` | List all subnets across all networks/regions |
| `gcloud compute instances describe <vm> --zone=<zone>` | Show full VM configuration |
| `grep -E "pattern1\|pattern2"` | Search for multiple patterns (OR) in command output |
| `gcloud compute firewall-rules list --format="table(name,network,sourceRanges.list())"` | List firewall rules with custom columns including source ranges |
| `gcloud compute firewall-rules delete <name> [<name2> ...]` | Delete one or more firewall rules (single confirmation for multiple) |
| `gcloud compute firewall-rules update <name> --source-ranges=<cidr1>,<cidr2>` | Replace a rule's allowed source IP ranges |
| `echo $SSH_CONNECTION` | Show client IP/port and server IP/port for current SSH session |
| `gcloud compute routers create <name> --network=<vpc> --region=<region>` | Create a Cloud Router (prerequisite for Cloud NAT) |
| `gcloud compute routers nats create <name> --router=<router> --region=<region> --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges` | Create a Cloud NAT gateway covering all subnets |
| `gcloud compute routers nats describe <name> --router=<router> --region=<region>` | Show Cloud NAT gateway configuration |
| `sudo ss -tulnp` | List listening TCP/UDP ports with owning process |

---

## Production Notes

**GCP Professional Cloud Engineer cert refresh:**
- Maps directly to "Implementing VPC networks" and "Designing for security and compliance" exam domains
- AUTO vs CUSTOM subnet modes, firewall rule priority/direction/source-ranges, and Cloud NAT architecture (Router + NAT gateway, `AUTO_ONLY` vs manual IP allocation) are all directly testable
- The scopes-vs-IAM distinction is a common exam trap — a service account can have the right role but the wrong token scope

**CKA/CKAD relevance:**
- Private GKE nodes (no external IP) depend on exactly this Cloud NAT pattern for pulling container images and OS updates — directly relevant when GKE is provisioned in Phase 5
- `kubectl`'s auth model (kubeconfig contexts, service account tokens, scopes) mirrors the credential-vs-permission distinction debugged today

**Real-world production parallel:**
- The audit → tighten → verify-connectivity → document cycle performed today mirrors periodic security reviews of Terraform-managed GCP infrastructure — a strong interview talking point ("I conducted a network security audit and reduced our firewall attack surface by 50% with zero downtime")

---

## Challenges

**Challenge 1 — Multi-source firewall access**
*A colleague needs SSH access to `boa-devops-admin` from a second IP without losing your own access. How would you update `default-allow-ssh`?*

**Your answer:**
```bash
gcloud compute firewall-rules update default-allow-ssh --source-ranges=49.43.250.104/32,203.0.113.77/32
```
`update --source-ranges=` replaces the entire list, so both IPs must be specified together, comma-separated, no spaces.

---

**Challenge 2 — Regional scope of Cloud NAT**
*If a disaster-recovery GKE cluster is deployed in `asia-south2`, will `boa-cloud-nat` cover it? What would need to be created?*

**Your answer:**
No. Cloud Router and Cloud NAT are regional resources tied to `asia-south1` and do not extend to `asia-south2` (a separate region, not a zone within `asia-south1`). For `asia-south2`, a new Cloud Router and Cloud NAT gateway would be required, plus new subnets in `payfast-vpc` for `asia-south2` (currently `payfast-vpc` only has subnets in `asia-south1`).

---

**Challenge 3 — Investigate `allow-jekyll`**
*`allow-jekyll` (tcp:4000, 0.0.0.0/0) was flagged as "needs review." Investigate and recommend keep/restrict/remove.*

**Your answer:**
```bash
sudo ss -tulnp
```
Confirmed nothing is listening on port 4000 (active listeners: 22/sshd, 20202/fluent-bit, 20201/otelopscol, 34525/VS Code remote on localhost only). Since `labs.opsflux.in` is served via Cloudflare Pages (not directly from this VM), the rule serves no purpose and represents latent risk. **Recommendation: remove.**
```bash
gcloud compute firewall-rules delete allow-jekyll
```

---

## Next Session

- BOA-007 Day 3: Network Troubleshooting (traceroute, tcpdump, connectivity debugging)
- Carry forward: `payfast-vpc` is now NAT-ready and earmarked for future GKE deployment (Phase 5); firewall redesign for it via Terraform planned for Phase 7