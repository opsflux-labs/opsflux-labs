---
title: "PAYFAST-002: Linux Networking Production Diagnostics"
date: 2026-05-30
summary: "Production network baseline audit — interfaces, routing, DNS, connections, iptables, tcpdump on payfast-devops-admin"
difficulty: beginner
duration: 90 mins
tags:
  - linux
  - networking
  - ss
  - tcpdump
  - iptables
  - gcp
  - dns 
---

## Scenario

JIRA Ticket: PAYFAST-002
Priority: P1 — Critical
Assigned To: Murali
Reporter: Platform Lead

TITLE: Production VM — Network Baseline & Incident Readiness Audit

DESCRIPTION:
The on-call SRE reported intermittent connectivity issues on 
payfast-devops-admin last night. No root cause identified.
Before we onboard application workloads, we need:

- Full network interface audit
- Routing table verification
- DNS resolution health check
- Active connection state mapping
- Firewall rules review (iptables)
- Packet-level verification on key interfaces
- Port connectivity test to external services

This audit will become the network baseline document.
Any deviation from this baseline = incident trigger.

Deliverable: Network audit published to labs.opsflux.in
SLA: Complete within current session

## Investigation

# PHASE 1 — Network Interface Audit

# All interfaces — up or down
```bash
ip link show
```

# IP addresses assigned to each interface
```bash
ip addr show ens4
```

# Just the active interfaces with IPs
```bash
ip addr show | grep -E "inet |inet6 " | grep -v "127.0.0.1"
```

# Interface statistics — errors, drops, packets
```bash
ip -s link show
```

# What to look for:

Any interface showing errors or drops = hardware/driver issue
Multiple interfaces = check which one carries default route
ens4 or eth0 = your primary GCP interface


# PHASE 2 — Routing Table

# Full routing table
```bash
ip route show
```

# Default gateway — where does traffic exit?
```bash
ip route show default
```

# Which interface and gateway handles traffic to Google DNS?
```bash
ip route get 8.8.8.8
```

# Which interface handles internal GCP metadata?
```bash
ip route get 169.254.169.254
```

# What to look for:
```bash
Default route present via ens4 or eth0
GCP metadata server (169.254.169.254) routed via link-local
No duplicate default routes (split-brain routing)
```

# PHASE 3 — DNS Health Check

# What DNS servers is this VM using?
```bash
cat /etc/resolv.conf
```

# Who is actually handling DNS resolution?
```bash
resolvectl status
```

# Test external DNS resolution
```bash
dig google.com +short
dig google.com A +stats | grep "Query time"
```

# Test GCP internal DNS
```bash
dig metadata.google.internal +short
```

# Reverse DNS lookup on your own IP
```bash
curl -s ifconfig.me
```

# Then:
```bash
dig -x <YOUR_EXTERNAL_IP> +short
```


Query time above 100ms = DNS latency issue
systemd-resolved at 127.0.0.53 = normal for Ubuntu 22.04
GCP internal DNS should resolve metadata.google.internal


PHASE 4 — Active Connection State Mapping
bash# All connections — established, listening, time_wait
sudo ss -tanp

# Count connections by state
sudo ss -tan | awk 'NR>1 {print $1}' | sort | uniq -c | sort -rn

# Established connections only — who is connected right now?
sudo ss -tnp state established

# UDP connections
sudo ss -uanp

# Full socket summary
sudo ss -s
What to look for:

Large number of TIME_WAIT = connection leak or high traffic
Unexpected ESTABLISHED connections = potential unauthorized access
ss -s gives you a quick health snapshot


PHASE 5 — iptables Firewall Audit
bash# List all iptables rules
sudo iptables -L -n -v

# List with line numbers
sudo iptables -L -n -v --line-numbers

# NAT table rules (important for Docker)
sudo iptables -t nat -L -n -v

# Check if anything is being dropped
sudo iptables -L INPUT -n -v | grep -i drop
sudo iptables -L FORWARD -n -v | grep -i drop
What to look for:

Docker adds rules to FORWARD chain — you'll see them here
GCP firewall rules sit ABOVE iptables — so even if iptables allows, GCP can block
Any DROP rules on INPUT chain = restrictive firewall


PHASE 6 — Packet Capture with tcpdump
bash# Identify your primary interface first
ip route show default | awk '{print $5}'

# Capture 20 packets on primary interface
sudo tcpdump -i ens4 -c 20 -n

# Capture only SSH traffic
sudo tcpdump -i ens4 -c 10 -n port 22

# Capture DNS queries
sudo tcpdump -i ens4 -c 10 -n port 53

# Capture ICMP (ping traffic)
sudo tcpdump -i ens4 -c 10 -n icmp
What to look for:

Regular heartbeat packets from GCP metadata server
SSH keepalive packets on port 22
Any unexpected source IPs


PHASE 7 — External Connectivity Test
bash# Basic ICMP test
ping -c 4 8.8.8.8
ping -c 4 google.com

# TCP connectivity test without telnet
nc -zv google.com 443
nc -zv google.com 80

# HTTP response from metadata server (GCP-specific)
curl -s -o /dev/null -w "%{http_code}" \
  http://metadata.google.internal/computeMetadata/v1/ \
  -H "Metadata-Flavor: Google"

# Trace route to Google DNS
traceroute 8.8.8.8
# If not installed:
sudo apt install traceroute -y && traceroute 8.8.8.8

## Root Cause

- Interface ens4 healthy — zero errors, zero drops
- MTU 1460 (GCP standard — 40 bytes reduced for VPC encapsulation)
- IP assigned as /32 (GCP-specific — VPC handles subnet routing)
- DNS local resolver (127.0.0.53) faster than 8.8.8.8 (4ms vs 8ms)
- 11 ESTABLISHED connections — all identified and legitimate
- Docker NAT rules present — MASQUERADE on 172.17.0.0/16
- GCP metadata server reachable — instance identity confirmed

## Fix
no remediation needed, baseline documented

## Result
Network baseline established for payfast-devops-admin.
All connections identified and verified legitimate.
Cleared for Docker and Kubernetes workload onboarding.

## Key Learnings

- ip route get <IP> shows exact routing decision — faster than reading full table
- /32 on GCP VMs is intentional — VPC handles broadcast/subnet at hypervisor level
- MTU 1460 on GCP — account for this in overlay networks (Kubernetes CNI)
- Local DNS resolver always faster than external — never point apps at 8.8.8.8 on GCP
- ss -tanp: process + IP + port together = full connection story
- 169.254.169.254 connections = GCP agents — always expected on GCP VMs
- tcpdump flags [P.][.][S] tell you exactly what type of traffic is flowing

## Command Reference
| Command | What it does | When to use |
|---|---|---|
| `ip link show` | All interfaces + state | Interface audit, link down debug |
| `ip addr show` | IPs assigned to interfaces | IP conflict, config verification |
| `ip route show` | Full routing table | Routing issue, gateway debug |
| `ip route get <IP>` | Routing decision for specific IP | Trace exactly how traffic exits |
| `ip -s link show` | Interface stats with errors/drops | Packet loss investigation |
| `cat /etc/resolv.conf` | Configured DNS servers | DNS misconfiguration debug |
| `resolvectl status` | systemd-resolved DNS state | Modern DNS debugging Ubuntu |
| `dig <host> +short` | Quick DNS resolution | DNS health check |
| `dig @<server> <host> +stats` | DNS query against specific server | Compare resolvers, latency test |
| `sudo ss -tanp` | All TCP connections + process | Connection audit, incident triage |
| `sudo ss -s` | Socket summary statistics | Quick network health snapshot |
| `sudo ss -tnp state established` | Active established connections | Who is connected right now |
| `sudo iptables -L -n -v` | All firewall rules verbose | Firewall audit, Docker rules |
| `sudo iptables -t nat -L -n -v` | NAT table rules | Docker networking debug |
| `sudo tcpdump -i <if> -c 20 -n` | Capture 20 packets | Packet-level incident debug |
| `ping -c 4 <host>` | ICMP connectivity test | Basic reachability check |
| `nc -zv <host> <port>` | TCP port connectivity test | Service reachability without telnet |
| `traceroute <host>` | Hop-by-hop path to destination | Routing loop, latency path debug |
| `curl metadata.google.internal` | GCP VM metadata query | Instance identity, zone, SA lookup |

#### Challenges

### Challenge 1 — Interface Health Report
**Command:**
```bash
ip addr show ens4
ip -s link show ens4
```
**Finding:** ens4 UP, IP 10.160.0.13/32, MTU 1460, zero errors, zero drops

---

### Challenge 2 — Routing Decision
**Command:**
```bash
ip route get 10.0.0.1
ip route get 8.8.8.8
```
**Finding:** Both routed via 10.160.0.1 gateway on ens4 — single exit point, GCP VPC handles the rest

---

### Challenge 3 — DNS Latency
**Command:**
```bash
dig @8.8.8.8 github.com +stats | grep "Query time"
dig @127.0.0.53 github.com +stats | grep "Query time"
```
**Finding:** Local resolver 4ms vs Google DNS 8ms — local cache wins

---

### Challenge 4 — Connection Inventory
**Command:**
```bash
sudo ss -tanp
sudo ss -s
```
**Finding:** 11 ESTABLISHED connections — SSH session, GCP agents, VS Code, OTel collector. All legitimate.

---

### Challenge 5 — GCP Metadata Server
**Command:**
```bash
curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google"
curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google"
```
**Finding:** Instance name — payfast-devops-admin, Zone — asia-south1-acd ~/opsflux-labs