---
layout: lab
title: "BOA-007: Networking Deep Dive"
phase: 3
lab_number: "007"
difficulty: intermediate
tags: [networking, tcp-ip, dns, ports, firewall, tcpdump, gcp-vpc]
date: 2026-06-10
---

# BOA-007 — Networking Deep Dive (Day 1)

## JIRA Ticket

| Field | Value |
|-------|-------|
| **Ticket ID** | BOA-007 |
| **Priority** | High |
| **Assigned To** | Murali (DevOps Engineer) |
| **Reporter** | Platform Engineering Lead |
| **Environment** | boa-devops-admin · GCP asia-south1 |

**Summary:** Production alert — Bank of Anthos payment services are intermittently unreachable. The networking team suspects a combination of DNS misconfiguration, firewall rule gaps, and routing issues in the VPC. You have been paged as the on-call DevOps engineer. Investigate and document your findings.

**Description:** The `ledgerwriter` service (handles money transfers) is not receiving traffic from the `frontend`. Initial triage suggests the issue may be at the network layer — DNS resolution failure, blocked port, or misconfigured routing. You must investigate the full network stack from your `boa-devops-admin` VM before the banking system goes live.

---

## Windows → Linux Reference

| Windows | Linux | What It Does |
|---------|-------|-------------|
| `ipconfig /all` | `ip addr show` | Show network interfaces and IPs |
| `ipconfig /all` → DNS Servers | `resolvectl status` | Show DNS server configuration |
| `nslookup hostname` | `dig hostname` | DNS lookup |
| `nslookup -type=PTR ip` | `dig -x ip` | Reverse DNS lookup |
| `ping -n 4 host` | `ping -c 4 host` | ICMP reachability test |
| `tracert host` | `traceroute host` | Trace network path hop by hop |
| No equivalent | `mtr --report host` | Live continuous traceroute with stats |
| `netstat -ano` | `ss -tlnp` | Show listening ports with process IDs |
| `telnet host port` | `nc -zv host port` | Test if specific port is open |
| Wireshark | `tcpdump` | Capture and inspect live network traffic |

---

## Investigation Phases

### Phase 1 — TCP/IP Fundamentals

Before touching commands, understand the 4 layers every on-call engineer uses:

| Layer | What | Breaks When | Tools |
|-------|------|-------------|-------|
| Application | HTTP, DNS, SSH, TLS | App crashes, wrong config, cert expired | `curl`, `dig`, `openssl` |
| Transport | TCP and UDP — ports | Port blocked, service not listening | `ss`, `netstat`, `nc` |
| Network (IP) | IP addresses, routing | Wrong route, VPC firewall, no path | `ping`, `traceroute`, `ip route` |
| Link/Physical | Interfaces, MAC | NIC down, wrong IP assigned | `ip addr`, `ip link` |

**Golden rule:** Always start at Layer 1 and work UP.

#### Command: Check Network Interfaces

```bash
ip addr show
```

**What this does:** Shows every network interface on the VM — its name, IP address, and whether it is UP or DOWN. Exactly like `ipconfig /all` but more detailed.

**Output observed:**

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
    inet 127.0.0.1/8 scope host lo

2: ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 state UP
    inet 10.160.0.13/32 metric 100 scope global dynamic ens4

3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> state DOWN
    inet 172.17.0.1/16 brd 172.17.255.255
```

**What to look for:**

| Interface | Purpose | Status |
|-----------|---------|--------|
| `lo` | Loopback — localhost only | UP — normal |
| `ens4` | Primary NIC — real network | UP — VM is reachable |
| `docker0` | Docker virtual bridge | DOWN — no containers running |

**Key observations:**
- `ens4` shows `state UP` — VM is connected and reachable
- `docker0` shows `state DOWN` — expected with no containers running
- GCP uses `/32` subnet on `ens4` — routing handled at VPC level, not on the VM

---

### Phase 2 — DNS Investigation

#### Command: Check DNS Configuration

```bash
resolvectl status
```

**What this does:** Shows which DNS server the VM is using and which search domains are configured. Windows equivalent: `ipconfig /all` → DNS Servers section.

**Output observed:**

```
Current DNS Server: 169.254.169.254
DNS Domain: asia-south1-a.c.murali-devops-lab.internal
            c.murali-devops-lab.internal
            google.internal
```

**What to look for:**
- `169.254.169.254` — GCP's internal metadata DNS server. Every GCP VM uses this automatically
- DNS search domains allow short hostnames to resolve to full internal FQDNs automatically
- `docker0` shows `Current Scopes: none` — no DNS for Docker since no containers are running

---

#### Command: DNS Query

```bash
dig google.com
```

**What this does:** Sends a full DNS query and shows the complete response — IP addresses, TTL, and which server answered. More detailed than `nslookup`.

**Output observed:**

```
status: NOERROR
ANSWER: 6
google.com.  300  IN  A  142.250.143.102
(+ 5 more IPs)
Query time: 4 msec
SERVER: 127.0.0.53#53
```

**What to look for:**
- `status: NOERROR` — DNS is healthy
- `ANSWER: 6` — Google returns multiple IPs for load balancing
- `TTL 300` — answer cached for 5 minutes. Critical during cutovers — wait for TTL to expire before declaring success
- `SERVER: 127.0.0.53` — local `systemd-resolved` stub, which forwards to `169.254.169.254`

**Quick reference — DNS record types:**

| Record | Stores | When Used |
|--------|--------|-----------|
| `A` | IPv4 address | Most common |
| `AAAA` | IPv6 address | IPv6 environments |
| `CNAME` | Alias to another hostname | Load balancers, CDNs |
| `PTR` | IP to hostname (reverse) | Identify unknown IPs in logs |
| `MX` | Mail server | Email routing issues |
| `TXT` | Text records | SSL verification, SPF |

---

#### Command: Reverse DNS Lookup

```bash
dig -x 8.8.8.8
```

**What this does:** Given an IP, find the hostname. Essential during incidents when unknown IPs appear in logs.

**Output observed:**

```
8.8.8.8.in-addr.arpa.  21600  IN  PTR  dns.google.
```

**What to look for:**
- `PTR` record type — pointer record, IP to hostname
- IP is written backwards in the query (`8.8.8.8` → `8.8.8.8.in-addr.arpa`)
- TTL 21600 (6 hours) — reverse records change rarely

---

#### Command: Internal GCP DNS Verification

```bash
dig boa-devops-admin.asia-south1-a.c.murali-devops-lab.internal
```

**What this does:** Verifies GCP's internal DNS is healthy by resolving this VM's own fully-qualified internal hostname.

**Output observed:**

```
boa-devops-admin.asia-south1-a.c.murali-devops-lab.internal. 30 IN A 10.160.0.13
```

**What to look for:**
- Resolves to `10.160.0.13` — matches `ens4` IP from `ip addr show`. Full circle confirmed
- TTL only 30 seconds — GCP uses short TTLs on internal records so VM replacements are picked up quickly

---

### Phase 3 — Ports and Connections

#### Command: Show Listening Ports

```bash
ss -tlnp
```

**Flags explained:**

| Flag | Meaning |
|------|---------|
| `-t` | TCP sockets only |
| `-l` | Listening sockets only |
| `-n` | Show port numbers not service names |
| `-p` | Show which process owns each socket |

**Output observed:**

```
LISTEN  0.0.0.0:22      SSH server
LISTEN  127.0.0.53:53   systemd-resolved (DNS stub)
LISTEN  127.0.0.1:35465 VS Code internal (code-41dd792b5e)
LISTEN  0.0.0.0:20202   VS Code tunnel
LISTEN  *:20201         VS Code tunnel
LISTEN  [::]:22         SSH server (IPv6)
```

**What to look for — binding address matters:**

| Bound To | Reachable From |
|----------|----------------|
| `127.0.0.1:PORT` | Localhost only — not reachable from outside |
| `0.0.0.0:PORT` | All IPv4 — anyone with network access |
| `*:PORT` | All interfaces including IPv6 |

A service bound to `127.0.0.1` instead of `0.0.0.0` is completely unreachable from outside even if running. This is one of the most common production misconfigurations.

---

#### Command: Test Port Reachability

```bash
nc -zv google.com 443
```

**Flags explained:**

| Flag | Meaning |
|------|---------|
| `-z` | Zero I/O mode — just test if port is open |
| `-v` | Verbose — show what happened |

**Output observed (port open):**
```
Connection to google.com (142.250.67.174) 443 port [tcp/https] succeeded!
```

**Three outcomes in production:**

| Result | Meaning | Investigation Direction |
|--------|---------|------------------------|
| `succeeded!` | Port open, service running | Application layer next |
| `Connection refused` | Machine reachable, nothing listening | Service is down |
| `Connection timed out` | Firewall silently dropping packets | Firewall rule investigation |

---

#### Command: Test Closed Port

```bash
nc -zv google.com 23
```

**Output observed:**
```
connect to google.com (142.250.67.174) port 23 (tcp) failed: Connection timed out
connect to google.com (2404:6800:...) port 23 (tcp) failed: Network is unreachable
```

**What to look for:**
- `Connection timed out` on IPv4 — firewall dropping packets silently at Google's edge
- `Network is unreachable` on IPv6 — no IPv6 route on this VM. Normal for this GCP VPC

---

### Phase 4 — Network Path Tracing

#### Command: Trace Network Path

```bash
traceroute google.com
```

**What this does:** Shows each hop a packet takes to the destination. Windows equivalent: `tracert google.com`.

**Output observed:**

```
1  * * *
2  172.253.69.53    0.5ms
3  142.251.251.54   1.3ms
4  192.178.110.105  5.1ms
5  108.170.231.79   1.2ms
6  del12s10-in-f14.1e100.net (142.250.207.206)  0.9ms
```

**What to look for:**
- `* * *` at hop 1 — GCP gateway ignores probes. Not an error
- `172.253.x.x` at hop 2 — already inside Google's backbone network
- `del12s10` at hop 6 — Google Delhi data center. Under 1ms from GCP asia-south1
- All traffic stays inside Google's network — never touches public internet

---

#### Command: Live Continuous Trace

```bash
mtr --report --report-cycles 5 google.com
```

**Flags explained:**

| Flag | Meaning |
|------|---------|
| `--report` | Non-interactive mode — print results when done |
| `--report-cycles 5` | Send 5 packets per hop then stop |

**Output observed:**

```
HOST: boa-devops-admin      Loss%  Snt  Last  Avg  Best  Wrst  StDev
  1.|-- ???                 100.0    5   0.0   0.0   0.0   0.0   0.0
  2.|-- 192.178.82.91        0.0%    5   0.4   0.5   0.4   0.6   0.1
  3.|-- 142.251.230.106      0.0%    5   1.0   0.8   0.5   1.0   0.2
  4.|-- 108.170.250.147      0.0%    5   2.3   2.4   1.6   3.1   0.7
  5.|-- 142.250.208.223      0.0%    5   1.5   1.4   1.1   1.7   0.2
  6.|-- del12s10-in-f14      0.0%    5   0.9   0.9   0.8   1.3   0.2
```

**What to look for:**

| Column | Meaning |
|--------|---------|
| `Loss%` | Packet loss at this hop |
| `Avg` | Average latency |
| `StDev` | Latency consistency — lower is better |

**The 100% loss rule:** If hop N shows 100% loss but hop N+1 responds — hop N is just ignoring probes. Not a real problem. If both N and N+1 show loss — that is a real block.

**StDev above 10ms** in production = jitter = packet loss and timeouts even when average latency looks acceptable.

---

### Phase 5 — GCP VPC and Firewall

#### Command: Query GCP Metadata Server

```bash
curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/?recursive=true
```

**Output observed:**

```
NETWORK    : projects/murali-devops-lab/global/networks/default
SUBNETWORK : projects/murali-devops-lab/regions/asia-south1/subnetworks/default
NETWORK_IP : 10.160.0.13
NAT_IP     : 8.231.98.123
```

**What to look for:**
- Internal IP `10.160.0.13` confirmed across `ip addr show`, internal DNS, and metadata server
- NAT IP `8.231.98.123` is the reserved external IP — the VM doesn't know about it directly, GCP handles translation at the VPC boundary
- `metadata.google.internal` is always accessible from inside any GCP VM without authentication

---

#### Command: List GCP Firewall Rules

```bash
gcloud compute firewall-rules list \
  --format="table(name,direction,priority,sourceRanges.list():label=SRC_RANGES,allowed[].map().firewall_rule().list():label=ALLOW,targetTags.list():label=TARGET_TAGS)"
```

**Output observed and analysis:**

| Rule | Allow | Target Tags | Notes |
|------|-------|-------------|-------|
| `allow-jekyll` | tcp:4000 | None (all VMs) | Jekyll dev server — no tag restriction |
| `default-allow-ssh` | tcp:22 | None | SSH open to all — applies to this VM |
| `default-allow-icmp` | icmp | None | Ping open to all — applies to this VM |
| `default-allow-internal` | all ports | None | All `10.128.0.0/9` traffic open |
| `default-allow-http` | tcp:80 | `http-server` | Only VMs with tag — does NOT apply here |
| `default-allow-https` | tcp:443 | `https-server` | Only VMs with tag — does NOT apply here |
| `default-allow-rdp` | tcp:3389 | None | RDP open — hardening candidate |

**GCP firewall priority:** Lower number = higher priority = evaluated first. Custom rules at 1000 override defaults at 65534.

**GCP firewall targeting methods:**
- Network tags — rule applies to VMs with matching tag
- Service account — rule applies to VMs with matching service account
- All instances — rule applies to every VM in the VPC

This VM has no network tags — only untagged rules apply. Open ports: 22 (SSH), 3389 (RDP), 4000 (Jekyll), ICMP, and all internal `10.x.x.x` traffic.

---

### Phase 6 — Packet Capture with tcpdump

#### Command: Live Packet Capture

```bash
sudo tcpdump -i ens4 port 22 -c 10 -n
```

**Flags explained:**

| Flag | Meaning |
|------|---------|
| `-i ens4` | Listen on the ens4 interface |
| `port 22` | Filter to SSH traffic only |
| `-c 10` | Capture exactly 10 packets then stop |
| `-n` | Show raw IPs — no hostname resolution |

**Output observed:**

```
17:08:38.360873 IP 10.160.0.13.22 > 49.43.250.172.63894: Flags [P.] length 156
17:08:38.394234 IP 49.43.250.172.63894 > 10.160.0.13.22: Flags [P.] length 92
...
10 packets captured
0 packets dropped by kernel
```

**What to look for — TCP flags:**

| Flag | Name | Meaning |
|------|------|---------|
| `[S]` | SYN | Opening connection |
| `[S.]` | SYN-ACK | Connection accepted |
| `[.]` | ACK | Acknowledgement — no data |
| `[P.]` | PUSH-ACK | Sending actual data |
| `[F.]` | FIN-ACK | Closing connection |
| `[R]` | RST | Reset — abort, nothing listening |

**`0 packets dropped by kernel`** — critical health indicator. Non-zero means VM CPU cannot process packets fast enough.

Identified `49.43.250.172` as the Windows machine (VS Code SSH client) from Chennai.

---

#### Command: Capture to File

```bash
sudo tcpdump -i ens4 port 22 -c 20 -n -w /tmp/ssh-capture.pcap
```

```bash
sudo tcpdump -r /tmp/ssh-capture.pcap -n
```

**What this does:** Writes raw packets to a `.pcap` file. Can be shared with the team or opened in Wireshark for analysis. Essential for incident forensics and vendor support escalations.

**Timestamp your capture files in production:**
```bash
sudo tcpdump -i ens4 port 8080 -c 100 -n -w /tmp/incident-$(date +%Y%m%d-%H%M%S).pcap
```

---

### Phase 7 — End-to-End Troubleshooting

Full incident investigation checklist validated against `github.com` (simulating `ledgerwriter`):

| Step | Command | Result |
|------|---------|--------|
| 1. Interface check | `ip addr show ens4` | UP, `10.160.0.13` assigned |
| 2. DNS resolution | `dig github.com +short` | `20.207.73.82` — DNS healthy |
| 3. ICMP reachability | `ping -c 4 github.com` | 0% loss, avg 4.18ms |
| 4. Port reachability | `nc -zv github.com 443` | `succeeded!` — port open |
| 5. Local listener check | `ss -tlnp \| grep -E '443\|8080'` | No conflict — app not yet deployed |
| 6. Network path | `mtr --report --report-cycles 3 github.com` | 11 hops, 0% loss at destination |
| 7. Live traffic | `sudo tcpdump -i ens4 host github.com -c 10 -n &` + `curl` | Real packets flowing, 0 drops |

**All 7 layers clean** — in a real incident, if all steps pass, the problem is not in the network layer. Escalate to application layer: pod logs, Kubernetes service config, or application behaviour.

---

## Root Cause

The `ledgerwriter` unreachable scenario was used as a training frame. In a real incident, the investigation checklist above narrows the failure to one specific layer. This session confirmed all network tooling is functional on `boa-devops-admin` and established the complete diagnostic workflow.

---

## Fix

The standard remediation path based on which step fails:

| Step Fails | Root Cause | Fix |
|------------|------------|-----|
| Step 1 | Interface DOWN | `sudo ip link set ens4 up` |
| Step 2 | DNS `SERVFAIL` | Check CoreDNS pods in Kubernetes or `resolvectl status` |
| Step 3 | Ping timeout | Check routing table, GCP firewall ICMP rule |
| Step 4 | `Connection refused` | Service/pod is down — check `kubectl get pods` |
| Step 4 | `Connection timed out` | Firewall blocking — check GCP firewall rules and VM tags |
| Step 6 | Loss at middle hop | If destination still reachable — ignore (probe filtering). If destination also drops — escalate to GCP networking |

---

## Result

- Full network stack validated across 7 investigation phases
- All DNS checks passing — internal and external resolution healthy
- All port checks passing — correct services listening, correct binding addresses
- GCP VPC topology understood — network, subnet, internal IP, NAT IP confirmed
- GCP firewall ruleset reviewed — open ports identified, tag-based targeting understood
- tcpdump workflow established — live capture, file write, file read, background capture pattern
- End-to-end incident checklist completed and documented

---

## Key Learnings

- **`ip addr show` is `ipconfig /all`** — shows interfaces, IPs, and link state. Check `state UP` before anything else
- **GCP uses `/32` on VM interfaces** — routing handled at VPC level, not on the VM itself
- **`169.254.169.254` is GCP's metadata and DNS server** — always reachable from inside any GCP VM
- **`systemd-resolved` sits at `127.0.0.53`** — local DNS stub that forwards to GCP DNS
- **Short TTLs on internal GCP DNS (30s)** — allows rapid VM replacement without stale routing
- **`Connection refused` vs `Connection timed out`** — refused means nothing listening, timeout means firewall blocking. Different failures, different fixes
- **`ip link set ens4 up` brings a DOWN interface back** — not `systemctl`, not `service`. Direct interface control
- **Binding address matters** — `127.0.0.1:PORT` is invisible from outside even if the service is running
- **MTR 100% loss at a middle hop is not always real** — if the next hop responds, the router is just filtering probes
- **StDev in MTR** — jitter indicator. High StDev causes application timeouts even when average latency looks fine
- **GCP firewall tags must match** — a rule targeting tag `ledgerwriter-service` does nothing if the VM has no tags
- **tcpdump `[R]` RST flag** — machine received packet but nothing is listening. Not a firewall issue
- **`.pcap` files are evidence** — timestamp them in production for incident forensics
- **CoreDNS** is the DNS component inside Kubernetes — `SERVFAIL` on `.cluster.local` names means CoreDNS is down

---

## Command Reference

| Command | What It Does |
|---------|-------------|
| `ip addr show` | Show all network interfaces |
| `ip addr show ens4` | Show specific interface only |
| `sudo ip link set ens4 up` | Bring a DOWN interface back up |
| `resolvectl status` | Show DNS server and search domains |
| `dig hostname` | Full DNS query with details |
| `dig hostname +short` | DNS query — IP only, no noise |
| `dig -x ip` | Reverse DNS — IP to hostname |
| `dig fqdn @dns-server` | Query a specific DNS server directly |
| `ping -c 4 host` | ICMP reachability — 4 packets |
| `traceroute host` | Hop-by-hop network path |
| `mtr --report --report-cycles 5 host` | Live traceroute with loss and latency stats |
| `ss -tlnp` | All TCP listening ports with process |
| `ss -tlnp \| grep port` | Filter for specific port |
| `nc -zv host port` | Test TCP port reachability |
| `sudo tcpdump -i ens4 port 22 -c 10 -n` | Capture 10 packets on port 22 |
| `sudo tcpdump -i ens4 host IP -c 10 -n` | Capture packets to/from specific IP |
| `sudo tcpdump -i ens4 -c 20 -n -w /tmp/file.pcap` | Write capture to file |
| `sudo tcpdump -r /tmp/file.pcap -n` | Read capture from file |
| `curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/...` | Query GCP metadata server |
| `gcloud compute firewall-rules list` | List all GCP firewall rules |

---

## Production Notes

### GCP Professional Cloud Engineer Refresh

- **VPC is global** in GCP — subnets are regional. Your `default` VPC spans all regions; the `default` subnet is specific to `asia-south1`
- **GCP uses `/32` on VM interfaces** — unlike traditional networking where you'd see `/24`. All routing handled by VPC. This is why `ip route` on a GCP VM looks unusual
- **Metadata server `169.254.169.254`** serves DNS, instance metadata, service account tokens, and startup scripts. Link-local address — never leaves the VM's physical host
- **GCP firewall is stateful** — you only need ingress rules. Return traffic is automatically allowed
- **Default VPC comes with `default-allow-rdp`** — always delete or restrict this in production. RDP open to `0.0.0.0/0` is a security risk
- **Cloud NAT is separate from firewall** — your VM's `8.231.98.123` external IP goes through Cloud NAT. The VM itself only knows `10.160.0.13`

### CKA / CKAD Refresh

- **CoreDNS** runs as a Deployment in `kube-system` namespace — check it first on any `.cluster.local` DNS failure
- **Kubernetes service DNS format:** `service-name.namespace.svc.cluster.local`
- **`SERVFAIL` vs `NXDOMAIN`** — `SERVFAIL` means DNS server failed to process the query (CoreDNS issue). `NXDOMAIN` means record genuinely does not exist (service not created)
- **NetworkPolicy** in Kubernetes can block traffic even when GCP firewall allows it — two separate layers of firewall
- **Pod-to-pod communication** uses the `default-allow-internal` GCP firewall rule covering `10.128.0.0/9` — GKE assigns pod CIDRs from this range

---

## Challenges

**Challenge 1 — Interface Diagnosis**

You receive this alert:
```
ALERT: boa-payments VM cannot reach any external service
```
You run `ip addr show` and see:
```
ens4: <BROADCAST,MULTICAST> mtu 1460 state DOWN
    inet 10.160.0.14/32
```
What is wrong and what command do you run to fix it?

Your answer: The network interface `ens4` is DOWN. The IP is assigned but the link is not active. Fix: `sudo ip link set ens4 up`

---

**Challenge 2 — DNS Failure**

A developer says `ledgerwriter.default.svc.cluster.local` is not resolving. You run:
```bash
dig ledgerwriter.default.svc.cluster.local
```
And get: `status: SERVFAIL` / `ANSWER: 0`

Name two possible causes and the next command you would run.

Your answer: (1) CoreDNS pod is down or crashing — Kubernetes internal DNS component is unhealthy. (2) The `ledgerwriter` Kubernetes service does not exist or is in the wrong namespace. Next command: `kubectl get pods -n kube-system | grep coredns`

---

**Challenge 3 — Port Investigation**

```
nc -zv 10.160.0.20 8080  →  Connection refused
nc -zv 10.160.0.20 8081  →  Connection timed out
```
What does each result tell you, and which one suggests a firewall problem?

Your answer: Port 8080 `Connection refused` — the machine is reachable but nothing is listening on 8080, meaning the service is down. Port 8081 `Connection timed out` — a firewall is silently dropping packets, the packet never arrives. Port 8081 suggests a firewall problem.

---

**Challenge 4 — Firewall Rule Gap**

```
NAME  : allow-ledgerwriter
ALLOW : tcp:8080
SRC   : 10.128.0.0/9
TAGS  : ledgerwriter-service
```
Frontend at `10.160.0.5` cannot reach ledgerwriter at `10.160.0.20:8080`. The ledgerwriter VM has no network tags. What is failing and why?

Your answer: The firewall rule targets VMs tagged `ledgerwriter-service`. The ledgerwriter VM has no tags so the rule never applies to it. The source range `10.128.0.0/9` covers `10.160.0.5` so that is not the issue. Fix: add tag `ledgerwriter-service` to the ledgerwriter VM.

---

**Challenge 5 — tcpdump Reading**

```
17:45:00.001 IP 10.160.0.5.45231 > 10.160.0.20.8080: Flags [S],  length 0
17:45:00.002 IP 10.160.0.20.8080 > 10.160.0.5.45231: Flags [R.], length 0
```
What does `[S]` mean, what does `[R.]` mean, and what is happening?

Your answer: `[S]` is SYN — frontend is initiating a TCP connection to ledgerwriter port 8080. `[R.]` is RST — ledgerwriter received the packet and reset the connection. This means ledgerwriter is reachable on the network but nothing is listening on port 8080. The service/pod is down. This is NOT a firewall issue — firewall blocking would cause a timeout, not an RST.