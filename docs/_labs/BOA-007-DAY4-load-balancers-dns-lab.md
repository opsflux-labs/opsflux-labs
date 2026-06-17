---
title: "BOA-007 (Day 4): Load Balancers & DNS Deep Dive"
date: 2026-06-17
summary: "Stood up a real, publicly-delegated Cloud DNS zone with two record types, root-caused a firewall tag mismatch causing silent connection timeouts, then built a complete GCP HTTP Load Balancer from scratch with a passing health check — and cut DNS over to point at it."
difficulty: "Intermediate"
duration: "180 min"
tags: [networking, dns, load-balancing, gcp, firewall, troubleshooting]
---

## Ticket

**Ticket:** OPSFLUX-148
**Priority:** P2 – High
**Component:** Networking / Platform Readiness
**Reported by:** Platform Architecture Team
**Assigned to:** Murali Krishnan, DevOps Engineer
**Environment:** GCP project `murali-devops-lab`, region `asia-south1`, VM `boa-devops-admin`

**Description:**
Bank of Anthos's move to GKE is coming up in Phase 5, and the architecture review board flagged two gaps before sign-off:

1. No DNS strategy exists — once the frontend is live, how does a user-friendly domain name resolve to it?
2. No load balancing proof-of-concept exists — once there are multiple frontend replicas, how does traffic get distributed and health-checked across them?

A small POC was requested on `boa-devops-admin`: stand up a Cloud DNS managed zone, create test records, and put a basic HTTP Load Balancer in front of a sample backend with a passing health check — before the GKE migration work begins.

**Acceptance Criteria:**
- Cloud DNS managed zone created, at least 2 record types added and tested
- DNS resolution validated using Linux-native tools
- A working HTTP Load Balancer provisioned in front of a sample backend with a passing health check
- Able to explain, end to end: domain → DNS → load balancer → health-checked backend

---

## Windows → Linux / GCP Reference Table

| Windows / AD Concept | Linux / GCP Equivalent |
|---|---|
| `nslookup` | `dig` |
| AD-integrated forward lookup zone | Cloud DNS **private** managed zone |
| Public company DNS zone (registrar-hosted) | Cloud DNS **public** managed zone |
| Delegating a child domain via NS records | Same exact mechanism — NS records in the parent zone pointing at the child's authoritative nameservers |
| Alias (CNAME) record | CNAME record (identical concept, identical name) |
| Windows "DNS Client" service (local resolver cache) | `systemd-resolved`, listening on `127.0.0.1:53` |
| F5 / NLB health monitor on a pool | GCP Health Check resource |
| Windows Firewall rule scoped to one app/profile | GCP firewall rule scoped via network **tags** |
| "Run as Administrator" | `sudo` |
| Installing a Windows Server role (Server Manager) | `apt install` **plus** enabling the relevant GCP API |
| `Get-Service` / services.msc | `systemctl status` |
| Compute "Availability Zone" (e.g. `asia-south1-a`) | A *completely separate* concept from a DNS "zone" — GCP avoids the clash by calling DNS zones **"managed zones"** |

---

## Investigation Phases

### Phase 1 — Public DNS Zone Creation & Delegation

Checked for existing zones first (none existed, which also triggered enabling the `dns.googleapis.com` API — GCP projects start with almost no APIs enabled by default, similar to a fresh Windows Server needing roles added before features are usable).

```
gcloud dns managed-zones create boadns --dns-name=boa.opsflux.in --description="BOA DNS"
```
Creates a **public** Cloud DNS managed zone (default visibility). `boadns` is just an internal GCP label for this zone resource — it doesn't have to match the actual domain name, which is supplied separately via `--dns-name`.

```
gcloud dns managed-zones describe boadns
```
Returned the zone's four assigned Google nameservers (`ns-cloud-e1` through `e4` `.googledomains.com`) — the exact information needed to delegate this subdomain.

**Manual step:** Added four NS records in Cloudflare (where `opsflux.in` is managed) — name `boa`, one record per Google nameserver. This tells the internet "for anything under `boa.opsflux.in`, ask Google's DNS servers, not Cloudflare's" — the public-internet equivalent of delegating a child domain to a different DNS server in AD.

```
dig boa.opsflux.in NS
```
Confirmed `status: NOERROR`, `ANSWER: 4`, with all four Google nameservers returned — delegation verified.

**What to look for:** `status: NOERROR` and the expected nameservers in the `ANSWER SECTION` confirm delegation succeeded; an `NXDOMAIN` or empty answer would mean either delegation isn't live yet, or the wrong zone got created.

### Phase 2 — DNS Records & Resolution Testing

```
gcloud dns record-sets create boa.opsflux.in --zone=boadns --type=A --ttl=100 --rrdatas=8.231.98.123
```
Created an **A record** (the "forward lookup" record type) mapping the bare domain straight to the VM's static external IP.

```
dig boa.opsflux.in
```
(No type needed — A is `dig`'s default.) Returned `ANSWER: 1`, the IP resolving correctly.

```
gcloud dns record-sets create www.boa.opsflux.in --zone=boadns --type=CNAME --ttl=100 --rrdatas=boa.opsflux.in.
```
Created a **CNAME** — note the target requires a trailing dot (fully-qualified name) or Cloud DNS rejects it.

```
dig www.boa.opsflux.in
```
Returned `ANSWER: 2` — the CNAME pointer *and* the A record it resolves down to, in the same response. `dig` automatically chases CNAME chains to a final IP rather than stopping at the alias.

**What to look for:** for an alias, expect to see two answer records, not one — that's the chain resolving correctly, not a misconfiguration.

### Phase 3 — Backend Prep & Firewall Incident

```
sudo apt install nginx
```
Installed a placeholder web server to act as a stand-in backend (operator task — no application code written).

```
systemctl status nginx
```
Confirmed `Active: active (running)` and `enabled` (auto-starts on boot).

```
curl -i 127.0.0.1
```
Returned `HTTP/1.1 200 OK` with the default nginx page — confirmed nginx itself was fully working, isolated from any network/firewall variables.

**Incident:** Browsing to `http://boa.opsflux.in` from a separate external machine (Windows desktop) returned a **connection timeout** ("took too long to respond"), not "connection refused." That distinction mattered: refused would mean reaching the host but finding nothing listening; timeout meant packets were being silently dropped somewhere upstream of nginx — which had already been proven to be working fine.

```
gcloud compute firewall-rules list
```
Showed a `default-allow-http` rule already permitting `tcp:80` — on the surface, this should have worked.

```
gcloud compute firewall-rules describe default-allow-http
```
Revealed the real issue: the rule is scoped to `targetTags: [http-server]`. A firewall rule existing in the list does **not** mean it applies to every VM — many GCP default rules only apply to instances explicitly carrying a matching network tag.

```
gcloud compute instances describe boa-devops-admin --zone=asia-south1-a --format="get(tags.items)"
```
Returned **empty** — `boa-devops-admin` had zero tags, confirming the mismatch and the root cause.

**What to look for:** an empty tags output combined with a tag-scoped firewall rule is the smoking gun — the rule exists, but nothing makes it apply to this VM.

---

## Root Cause

The VPC firewall rule permitting inbound HTTP traffic (`default-allow-http`) was correctly configured but scoped to instances carrying the network tag `http-server`. `boa-devops-admin` had no network tags at all, so despite the rule's existence, it never matched this VM — causing all external HTTP traffic to be silently dropped (manifesting as a connection timeout, not a refusal), even though nginx itself was fully functional.

## Fix

```
gcloud compute instances add-tags boa-devops-admin --zone=asia-south1-a --tags=http-server
```
Attached the missing tag so the VM now matches the existing rule's scope. Chosen deliberately over the alternative (removing the tag requirement from the rule entirely), since that would have silently exposed port 80 on every future VM created on this network — tagging preserves least-privilege, opt-in exposure.

## Result

Verified via browser from the external Windows machine: `http://boa.opsflux.in` returned the nginx welcome page — confirmed working end-to-end (DNS → internet → firewall → nginx).

---

### Phase 4 — Building the HTTP Load Balancer

A GCP external HTTP Load Balancer isn't one resource — it's six, wired together:

```
gcloud compute health-checks create http boa-health-check --port=80
```
Defines what "healthy" means for a backend (an HTTP response on port 80).

```
gcloud compute instance-groups unmanaged create boa-instance-group --zone=asia-south1-a
gcloud compute instance-groups unmanaged add-instances boa-instance-group --zone=asia-south1-a --instances=boa-devops-admin
gcloud compute instance-groups unmanaged set-named-ports boa-instance-group --zone=asia-south1-a --named-ports=http:80
```
Created an unmanaged instance group (a labeled bucket of backend VMs), added the VM into it, then assigned a **named port** — backend services reference instance groups by a port *name* (`http`), not a raw port number.

```
gcloud compute backend-services create boa-backend-service --protocol=HTTP --port-name=http --health-checks=boa-health-check --global
gcloud compute backend-services add-backend boa-backend-service --instance-group=boa-instance-group --instance-group-zone=asia-south1-a --global
```
Created the backend service (ties protocol + port name + health check together) and attached the actual instance group to it as the real traffic destination.

```
gcloud compute url-maps create boa-url-map --default-service=boa-backend-service
gcloud compute target-http-proxies create boa-http-proxy --url-map=boa-url-map
```
Created the URL map (routing logic — currently a single default route) and the target HTTP proxy (terminates incoming client connections, consults the URL map).

```
gcloud compute addresses create boa-lb-ip --ip-version=IPV4 --global
gcloud compute forwarding-rules create boa-forwarding-rule --address=boa-lb-ip --global --target-http-proxy=boa-http-proxy --ports=80
```
Reserved a dedicated static external IP for the load balancer (separate from the VM's own IP) and created the forwarding rule — the piece that actually switches the listener on.

```
gcloud compute addresses list
```
Confirmed the reserved LB IP: `8.233.173.67`.

```
gcloud compute backend-services get-health boa-backend-service --global
```
Returned `healthState: HEALTHY` — confirmed via the VM's *internal* IP (`10.160.0.13`), since load balancers communicate with backends over the internal network even though their own frontend IP is public.

Verified by browsing directly to `http://8.233.173.67` — nginx page returned successfully.

**What to look for:** `healthState: HEALTHY` in `get-health` output is the definitive proof the load balancer is correctly wired — a successful browser test alone doesn't confirm the health check specifically is passing.

### Phase 5 — DNS Cutover to the Load Balancer

```
gcloud dns record-sets update boa.opsflux.in --zone=boadns --type=A --ttl=100 --rrdatas=8.233.173.67
```
Updated (not recreated) the existing A record to point at the load balancer's IP instead of the VM directly — the actual production pattern: DNS should always point at a load balancer, never at a single backend.

```
dig boa.opsflux.in
```
Confirmed the new IP (`8.233.173.67`) resolving correctly.

Final browser test of `http://boa.opsflux.in` confirmed the complete chain: domain → DNS → load balancer → health-checked backend → nginx.

---

## Key Learnings

- GCP requires explicit, per-service API enablement (e.g. `dns.googleapis.com`) before first use — similar to enabling a Windows Server role before its features become usable.
- "Managed zone" is GCP's deliberate naming choice to avoid colliding with "zone" as in Compute availability zones (`asia-south1-a`).
- Public DNS delegation works identically to AD child-domain delegation — NS records in the parent zone point at the child's authoritative nameservers.
- `dig` automatically chases CNAME chains down to a final A record — querying an alias returns both the pointer and the resolved IP.
- A firewall rule appearing in `firewall-rules list` does not guarantee it applies to a given VM — GCP frequently scopes rules by network tags, and a VM must explicitly carry the matching tag.
- "Connection timed out" (vs "connection refused") was the exact signal pointing at a silent network/firewall drop rather than a service-level failure — confirmed by first proving nginx worked locally before looking upstream.
- A GCP external HTTP Load Balancer is six separate resources (health check, instance group, backend service, URL map, target proxy, forwarding rule) working together, not one object.
- Load balancer health checks reach backends over their internal IP, even though the load balancer's own frontend IP is public.
- The same firewall tag fix that resolved external user access also resolves load balancer health check failures — both travel the identical network path.
- DNS in production should always point at a load balancer's IP, never directly at an individual backend server.

---

## Command Reference Table

| Command | Purpose |
|---|---|
| `gcloud dns managed-zones create` | Create a Cloud DNS zone (public or private) |
| `gcloud dns managed-zones describe` | View full zone detail, including assigned nameservers |
| `gcloud dns record-sets create` | Add a new DNS record (A, CNAME, etc.) |
| `gcloud dns record-sets update` | Modify an existing record's value in place |
| `dig <name> [TYPE]` | Query DNS records from the command line; defaults to type A |
| `gcloud compute firewall-rules list` / `describe` | List / inspect VPC firewall rules and their target tags |
| `gcloud compute instances describe ... --format="get(...)"` | Pull a single field from a resource's full config |
| `gcloud compute instances add-tags` | Attach a network tag to a VM, opting it into tag-scoped firewall rules |
| `gcloud compute health-checks create http` | Define backend health criteria for a load balancer |
| `gcloud compute instance-groups unmanaged create/add-instances/set-named-ports` | Build a backend grouping of VMs and assign a named port |
| `gcloud compute backend-services create/add-backend` | Tie protocol, port, health check, and backend group together |
| `gcloud compute url-maps create` | Define routing rules from URL/host to backend service |
| `gcloud compute target-http-proxies create` | Terminate client connections per the URL map |
| `gcloud compute addresses create --global` | Reserve a static public IP for a global load balancer |
| `gcloud compute forwarding-rules create` | Bind an IP + port to a target proxy, activating the load balancer |
| `gcloud compute backend-services get-health` | Real-time health status check of all backends behind a service |

---

## Production Notes

**GCP Professional Cloud Engineer / Architect refresh:** This lab directly covers several exam blueprint areas — Cloud DNS (public vs private zones, delegation), the full external HTTP(S) Load Balancer architecture (health check → backend service → URL map → target proxy → forwarding rule), and VPC firewall design via network tags. Worth revisiting the official GCP load balancer decision tree (regional vs global, internal vs external, L4 vs L7) before the actual exam.

**CKA/CKAD refresh:** None of this used Kubernetes directly, but it's a direct preview of Phase 5 — a Kubernetes `Service` of type `LoadBalancer` and an `Ingress` object will provision nearly this exact same chain of GCP resources automatically under the hood. Understanding it manually here will make Ingress troubleshooting later far less of a black box.

---

## Challenges

**Challenge 1 (INC-2201):** A teammate wants `staging.boa.opsflux.in` to resolve to the same backend as `boa.opsflux.in`, without ever needing to update two separate records if the IP changes again.

**Your answer:** Create a CNAME record — `staging.boa.opsflux.in` pointing to `boa.opsflux.in`. This future-proofs against IP changes because the alias only needs to be updated once, at the source A record; any aliases pointing at it automatically follow.

**Challenge 2 (INC-2202):** On-call is paged — `boa.opsflux.in` is unreachable, and `get-health` shows `UNHEALTHY` for the backend.

**Your answer:** Check whether the VM itself is down or unreachable; check whether the `http-server` network tag has been removed from the VM (which would silently block both user traffic and the health check probe on port 80); check whether the nginx service itself has stopped running on the VM.

**Challenge 3 (INC-2203):** A second VM added to `boa-instance-group` still shows `UNHEALTHY` a day later, despite nginx confirmed running fine on it directly.

**Your answer:** The new VM is almost certainly missing the `http-server` network tag, so the firewall rule scoped to that tag doesn't apply to it. Fix: `gcloud compute instances add-tags <new-vm-name> --zone=<zone> --tags=http-server`.