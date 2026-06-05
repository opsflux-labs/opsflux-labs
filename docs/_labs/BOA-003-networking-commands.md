---
title: "BOA-003: Networking Commands"
date: 2026-06-06
summary: "Verify connectivity, inspect DNS, check open ports, trace network paths — the complete Linux networking toolkit for DevOps operators on boa-devops-admin"
difficulty: beginner
duration: 2 hours
tags:
  - linux
  - networking
  - devops-foundation
  - foundation
---

# BOA-003 — Networking Commands

## JIRA-Style Ticket

| Field | Value |
|---|---|
| **Ticket ID** | BOA-003 |
| **Priority** | P2 — High |
| **Assigned To** | Murali |
| **Environment** | boa-devops-admin / Ubuntu 22.04 |
| **Labels** | linux, networking, devops-foundation, day-3 |
| **Sprint** | Month 1 — Phase 1: Linux for DevOps |

### Ticket Description

> **[BOA-003] Linux Networking Commands — Operations Reference**
>
> The Bank of Anthos platform runs across 8 microservices communicating over internal Kubernetes networks.
> As the operator, you must be able to verify connectivity, inspect DNS resolution, check open ports, and
> diagnose network failures — all from the command line on boa-devops-admin.
>
> This lab covers the core networking toolkit every DevOps/SRE engineer uses daily in production.
> You will use these exact commands when Bank of Anthos services fail to communicate in later labs.

**Acceptance Criteria:**
- [ ] Can verify connectivity to any host using ping
- [ ] Can make HTTP requests and inspect responses using curl
- [ ] Can list listening ports and active connections using ss
- [ ] Can resolve DNS names using dig and nslookup
- [ ] Can inspect network interface configuration using ip
- [ ] Lab file pushed to GitHub and live on labs.opsflux.in

---

## Windows to Linux Networking Reference Table

| What You Want To Do | Windows Command | Linux Equivalent | Notes |
|---|---|---|---|
| Test connectivity to a host | ping google.com | ping google.com | Same syntax. Linux pings forever — use Ctrl+C to stop |
| Make an HTTP request | Invoke-WebRequest | curl https://example.com | Like PowerShell's Invoke-WebRequest but CLI-native |
| See open ports and connections | netstat -an | ss -tulnp | ss is the modern replacement for netstat |
| Find what is using a port | netstat -ano | ss -tulnp pipe grep :8080 | Pipe to grep to filter |
| Look up DNS for a hostname | nslookup google.com | dig google.com | dig gives much more detail |
| See your IP address | ipconfig | ip addr | ip = Linux ipconfig |
| See your routing table | route print | ip route | Shows how traffic exits the machine |
| Trace the path to a host | tracert google.com | traceroute google.com | Same concept, different name |
| Download a file | Invoke-WebRequest -OutFile | curl -O URL | curl -O saves to same filename |
| Flush DNS cache | ipconfig /flushdns | sudo resolvectl flush-caches | DNS resolver is systemd-resolved on Ubuntu 22.04 |

---

## Lab Overview — What You Are Building

```
[ boa-devops-admin ]
        |
        |--- ping        → Is the host alive?
        |--- curl        → Is the HTTP service responding?
        |--- ss          → What ports are open on THIS machine?
        |--- dig         → What does DNS resolve this hostname to?
        |--- ip          → What is my IP and routing config?
        |--- traceroute  → What path does traffic take to reach the host?
```

In Kubernetes (BOA-010 onwards) you will run these same commands inside pods
to debug why Service A cannot reach Service B.

---

## Phase 1 — Verify Your Starting Point

**Goal:** Confirm your machine is on the network before testing anything else.
This is the "are my cables plugged in?" check — in Linux.

### Step 1.1 — Check your IP address

```bash
ip addr
```

**What this command does, broken down:**
- `ip` — The main networking tool on Linux. Replaces the older ifconfig.
- `addr` — Short for address. Show all network interface addresses.

**What you will see:**
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
    inet 127.0.0.1/8 scope host lo

2: ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460
    inet 10.160.0.X/32 scope global dynamic ens4
```

**What to look for:**
- `lo` — Loopback interface. Like Windows 127.0.0.1. Only talks to itself.
- `ens4` — Your actual network interface. GCP names it ens4. This is your real NIC.
- `inet 10.160.0.X` — Your internal private IP on the GCP VPC.
- The external IP 8.231.98.123 is handled by GCP Cloud NAT — it is not visible here.

**Windows analogy:** `ip addr` = `ipconfig`. The ens4 interface = your Ethernet adapter in Windows.

---

### Step 1.2 — Check your routing table

```bash
ip route
```

**What you will see:**
```
default via 10.160.0.1 dev ens4 proto dhcp src 10.160.0.X metric 100
```

**What to look for:**
- `default via 10.160.0.1` — Default gateway. All traffic goes here if no specific route matches.
- `dev ens4` — Send traffic out through the ens4 interface.

**Windows analogy:** `ip route` = `route print`. The default line = your Default Gateway in ipconfig.

---

## Phase 2 — ping: Is The Host Alive?

**Goal:** Confirm basic connectivity — can we reach a host at all?
In production, ping is your first check before anything else.

### Step 2.1 — Ping Google DNS by IP

```bash
ping -c 4 8.8.8.8
```

**What this command does, broken down:**
- `ping` — Send ICMP echo requests. Like knocking on a door and waiting for a response.
- `-c 4` — Send exactly 4 packets then stop. Without -c Linux pings forever.
- `8.8.8.8` — Google public DNS. Reliable target for connectivity tests.

**Expected output:**
```
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=1.23 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=117 time=1.19 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=117 time=1.21 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=117 time=1.22 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss
rtt min/avg/max/mdev = 1.19/1.21/1.23/0.015 ms
```

**What to look for:**
- `0% packet loss` — Network path is clean.
- `time=1.xx ms` — Round-trip latency. Single-digit ms from GCP asia-south1 to Google is excellent.
- `100% packet loss` — Host unreachable, firewall blocking ICMP, or DNS not resolving.

---

### Step 2.2 — Ping by hostname (tests DNS plus connectivity)

```bash
ping -c 4 google.com
```

**Why this is different from Step 2.1:**

| Test | What it checks |
|---|---|
| `ping 8.8.8.8` | Network connectivity only |
| `ping google.com` | Network connectivity AND DNS resolution |

If `ping 8.8.8.8` works but `ping google.com` fails — DNS is broken, not the network.

**Production tip:** This DNS-vs-IP distinction is how you separate two completely different problems.
In Bank of Anthos incidents, this is often the first fork in the investigation.

---

### Step 2.3 — Ping the GCP metadata server

```bash
ping -c 4 metadata.google.internal
```

GCP provides an internal endpoint every VM can reach to get its own metadata —
project ID, service account tokens, instance name.
If this is unreachable, something is seriously wrong with your GCP network config.

---

## Phase 3 — curl: Test HTTP Services

**Goal:** Make HTTP requests from the command line and inspect responses.
In production, curl is how you test whether a service endpoint is responding correctly.

### Step 3.1 — Basic HTTP GET

```bash
curl https://example.com
```

Makes a GET request to the URL and prints the raw HTML response body.

---

### Step 3.2 — Show response headers only

```bash
curl -I https://example.com
```

**What the flag means:**
- `-I` — HEAD request. Fetch headers only, not the body.

**Expected output:**
```
HTTP/2 200
content-type: text/html; charset=UTF-8
date: Fri, 05 Jun 2026 06:00:00 GMT
server: ECS
content-length: 1256
```

**Common HTTP status codes in incidents:**

| Code | Meaning | What it usually means in production |
|---|---|---|
| 200 OK | All good | Service is healthy |
| 404 Not Found | URL does not exist | Wrong path or service misconfigured |
| 503 Service Unavailable | Backend is down | Pod crashed or deployment failed |
| 401 Unauthorized | Not authenticated | Missing or wrong credentials |
| 403 Forbidden | Not permitted | IAM or RBAC issue |

---

### Step 3.3 — Verbose output (see everything including TLS)

```bash
curl -v https://example.com 2>&1 | head -40
```

**What the flags mean:**
- `-v` — Verbose. Show the full request and response including TLS handshake.
- `2>&1` — Redirect stderr (where curl writes verbose info) to stdout so you can see it.
- `| head -40` — Show only the first 40 lines.

**What to look for:**
```
* Trying 93.184.216.34:443...      <- IP it resolved to
* Connected to example.com         <- TCP connection established
* SSL connection using TLSv1.3     <- TLS negotiated, HTTPS is working
> GET / HTTP/2                     <- Your request sent
< HTTP/2 200                       <- Server response received
```

**Production use:** When Bank of Anthos returns an unexpected response,
`curl -v` shows exactly what happened at every layer — DNS, TCP, TLS, HTTP.

---

### Step 3.4 — Test a specific port

```bash
curl http://localhost:8080
```

Expected result: `Connection refused` — nothing is running on 8080 yet.
That is correct and expected. It tells you the port is closed.
In Kubernetes labs you will use this exact pattern to test whether a service is exposed.

---

### Step 3.5 — Download a file

```bash
curl -O https://raw.githubusercontent.com/GoogleCloudPlatform/bank-of-anthos/main/README.md
ls -lh README.md
head -20 README.md
```

`-O` (capital O) = save to a file using the same name as in the URL.

**Windows analogy:** `curl -O URL` = `Invoke-WebRequest -Uri URL -OutFile filename` in PowerShell.

---

## Phase 4 — ss: What Ports Are Open on This Machine?

**Goal:** See what network services are currently listening on your VM.
This answers "what is running on this machine?" from a network perspective.

### Step 4.1 — Show all listening ports

```bash
ss -tulnp
```

**What each flag means — memorise this combination:**

| Flag | Meaning |
|---|---|
| `-t` | TCP sockets |
| `-u` | UDP sockets |
| `-l` | Listening only — waiting for connections |
| `-n` | Show numbers not names (port 22 not "ssh") |
| `-p` | Show the process that owns each socket |

**Expected output:**
```
Netid  State   Local Address:Port   Process
tcp    LISTEN  0.0.0.0:22           users:(("sshd",pid=1234,fd=3))
tcp    LISTEN  127.0.0.1:53         users:(("systemd-r",pid=567,fd=18))
```

**What to look for:**
- `0.0.0.0:22` — SSH listening on all interfaces on port 22. This is your SSH entry point.
- `127.0.0.1:53` — DNS resolver listening loopback only — not accessible from outside.
- `0.0.0.0` = accessible from any interface
- `127.0.0.1` = loopback only, not reachable from outside the machine

**Windows analogy:** `ss -tulnp` = `netstat -an` in CMD. ss is the modern, faster replacement.

---

### Step 4.2 — Check a specific port

```bash
ss -tulnp | grep :22
```

Filters the ss output to lines containing :22 (the SSH port).

---

### Step 4.3 — Show all active connections

```bash
ss -tnp
```

Removing `-l` shows ALL connections, not just listening ones. You will see your current SSH session here.

**What to look for:**
```
State    Local Address:Port   Peer Address:Port
ESTAB    10.160.0.X:22        YOUR_IP:PORT
```

ESTAB = ESTABLISHED = that line is your active SSH connection from Windows.

---

## Phase 5 — dig and nslookup: DNS Lookups

**Goal:** Resolve hostnames to IPs and inspect DNS records.
DNS failures are one of the most common causes of service outages in production.

### Step 5.1 — Basic lookup with nslookup

```bash
nslookup google.com
```

**Expected output:**
```
Server:         127.0.0.53
Address:        127.0.0.53#53

Non-authoritative answer:
Name:    google.com
Address: 142.250.192.46
```

**What to look for:**
- `Server: 127.0.0.53` — Your local systemd-resolved is handling DNS queries.
- `Non-authoritative answer` — Answer came from cache or upstream server, not google.com's own nameserver.

---

### Step 5.2 — dig: the production DNS toolkit

```bash
dig google.com
```

**Expected output:**
```
;; ANSWER SECTION:
google.com.    300    IN    A    142.250.192.46

;; Query time: 2 msec
;; SERVER: 127.0.0.53#53
```

**Breaking down the ANSWER SECTION:**

| Field | Example Value | Meaning |
|---|---|---|
| Name | google.com. | The hostname queried |
| TTL | 300 | Cached for 300 seconds |
| Class | IN | Internet record |
| Type | A | IPv4 address record |
| Data | 142.250.192.46 | The resolved IP |

---

### Step 5.3 — Query specific record types

```bash
# Mail server records
dig google.com MX

# Nameserver records
dig google.com NS

# Text records (SPF, domain verification)
dig google.com TXT
```

**Why this matters in Bank of Anthos:**
In Kubernetes, every service gets a DNS name like `userservice.default.svc.cluster.local`.
When a pod cannot reach userservice, you run `dig userservice.default.svc.cluster.local`
inside the pod to confirm whether DNS resolution is working before touching anything else.

---

### Step 5.4 — Query a specific DNS server directly

```bash
dig @8.8.8.8 google.com
```

**What @8.8.8.8 means:**
Use this specific DNS server instead of your system's configured one.

**Production use:** If you suspect your internal DNS is returning wrong answers,
query Google's public DNS to compare. If @8.8.8.8 resolves correctly but your
local DNS does not — the problem is your DNS config, not the domain.

---

### Step 5.5 — Short output only

```bash
dig google.com +short
```

Returns only the IP address. No headers, no stats. Useful in scripts and one-liners.

---

### Step 5.6 — Reverse DNS lookup (IP to hostname)

```bash
dig -x 8.8.8.8
```

**Expected output:**
```
;; ANSWER SECTION:
8.8.8.8.in-addr.arpa.   18491   IN   PTR   dns.google.
```

dns.google is the reverse DNS hostname for Google's 8.8.8.8 server.

---

## Phase 6 — ip: Full Network Interface Toolkit

**Goal:** Inspect interfaces, routing, and statistics in detail.

### Step 6.1 — Show one specific interface

```bash
ip addr show ens4
```

**What to look for:**
- `inet 10.160.0.X/32` — Your GCP internal IP. The /32 is GCP-specific — GCP uses host routes.
- `state UP` — Interface is active and connected.

---

### Step 6.2 — Show interface TX/RX statistics

```bash
ip -s link show ens4
```

`-s` adds transmitted and received byte/packet counters and error counts.

**What to look for:**
```
RX:  bytes    packets  errors  dropped
     1234567  9876     0       0
TX:  bytes    packets  errors  dropped
     987654   5432     0       0
```

`errors: 0` and `dropped: 0` = healthy interface. Non-zero values signal a NIC or upstream network issue.

---

## Phase 7 — traceroute: Path Discovery

**Goal:** Trace the network path from your machine to a destination hop by hop.

### Step 7.1 — Install traceroute if needed

```bash
which traceroute || sudo apt install -y traceroute
```

**What this does:**
- `which traceroute` — Check if already installed. Prints path if yes, exits non-zero if no.
- `||` — OR. If left command fails, run the right command.
- `-y` — Install without prompting for confirmation.

---

### Step 7.2 — Trace route to Google

```bash
traceroute 8.8.8.8
```

**Expected output:**
```
traceroute to 8.8.8.8, 30 hops max
 1  10.160.0.1 (10.160.0.1)     0.5 ms
 2  * * *
 3  209.85.254.X (209.85.254.X)  1.2 ms
 5  8.8.8.8 (8.8.8.8)            1.3 ms
```

**What to look for:**
- First hop 10.160.0.1 — Your GCP gateway. Always the first stop.
- `* * *` — Router does not respond to traceroute probes. Normal on cloud networks.
- Latency increasing per hop — Expected. Each router adds a small delay.
- Sudden large latency jump at one specific hop — Bottleneck lives at that router.

**Windows analogy:** `traceroute` = `tracert` in CMD. Same concept, different name.

---

## Phase 8 — Full Investigation Workflow (Production Scenario)

**Goal:** Run the complete network health check sequence used in a real incident.

**Scenario:** "I cannot reach google.com from boa-devops-admin."

Run through this exact sequence:

```bash
# 1 — Is my interface up and does it have an IP?
ip addr show ens4

# 2 — Do I have a default route?
ip route show

# 3 — Can I reach the gateway?
ping -c 3 10.160.0.1

# 4 — Can I reach a known IP? (pure connectivity, bypasses DNS)
ping -c 3 8.8.8.8

# 5 — Is DNS resolving?
dig google.com +short

# 6 — Can I reach google.com by hostname?
ping -c 3 google.com

# 7 — Is the HTTPS service responding correctly?
curl -I https://google.com

# 8 — What path does traffic take?
traceroute 8.8.8.8
```

**Investigation logic — narrowing down the problem:**

| Observation | What it means |
|---|---|
| ping 8.8.8.8 fails | Network or routing issue |
| ping 8.8.8.8 works, ping google.com fails | DNS issue only |
| ping google.com works, curl https:// fails | HTTP or TLS issue |
| curl http:// works, curl https:// fails | TLS or certificate issue |

Now run this as a single chained command:

```bash
ip addr show ens4 && ip route show && ping -c 3 8.8.8.8 && dig google.com +short && curl -I https://example.com
```

**What && does:**
Runs each command only if the previous one succeeded.
If ip addr fails, the chain stops — no point running the rest when the interface is down.

---

## Root Cause (Lab Context)

No active incident in this lab. This lab builds the diagnostic toolkit that will be applied
in every network investigation from BOA-013 through BOA-022. The 8-step sequence above
is real production methodology, not a lab construct.

---

## Fix / Outcome

All networking commands verified and functional on boa-devops-admin:
- Active ens4 interface with GCP internal IP confirmed
- Default route via GCP gateway 10.160.0.1 confirmed
- DNS resolution working via systemd-resolved (127.0.0.53)
- Internet connectivity confirmed to 8.8.8.8, google.com, example.com
- SSH confirmed listening on port 22 via ss -tulnp

---

## Result

```
Phase 1 — ip addr, ip route — Interface and routing confirmed         PASS
Phase 2 — ping — Connectivity to IPs and hostnames verified           PASS
Phase 3 — curl — HTTP/HTTPS responses tested, status codes read       PASS
Phase 4 — ss — Open ports on boa-devops-admin inspected               PASS
Phase 5 — dig/nslookup — DNS resolution verified, record types done   PASS
Phase 6 — ip toolkit — Interface stats and details reviewed            PASS
Phase 7 — traceroute — Network path to 8.8.8.8 mapped                 PASS
Phase 8 — Full investigation workflow completed end-to-end             PASS
```

---

## Key Learnings

- `ping IP` vs `ping hostname` isolates network problems from DNS problems — this is a critical diagnostic fork
- `curl -I` gives the HTTP status code without downloading the full response body
- `curl -v` shows TLS handshake, request headers, response headers — use for deep HTTP debugging
- `ss -tulnp` answers "what is listening on this machine right now?" — memorise these five flags
- `dig` is more powerful than nslookup — shows TTL, query time, which server answered
- `dig @8.8.8.8 hostname` bypasses local DNS — compare results to isolate a DNS config problem
- `dig +short` returns just the IP — clean output for scripts
- `ip addr` = Linux ipconfig — shows interfaces and assigned IPs
- `ip route` = Linux route print — shows how traffic exits the machine
- `&&` chaining creates a dependent health check sequence — stops at the first failure, which is exactly what you want
- The 8-step investigation sequence is real production workflow, not a lab exercise

---

## Command Reference Table

| Command | What It Does | Key Flags | Windows Equivalent |
|---|---|---|---|
| `ip addr` | Show all interfaces and IPs | — | ipconfig |
| `ip addr show ens4` | Show one specific interface | — | ipconfig (filtered) |
| `ip route show` | Show routing table | — | route print |
| `ip -s link show ens4` | Interface with TX/RX stats | -s = stats | — |
| `ping -c 4 host` | Send 4 ICMP packets to host | -c = count | ping host |
| `curl https://url` | HTTP GET, print body | — | Invoke-WebRequest |
| `curl -I https://url` | HTTP HEAD — headers only | -I = HEAD only | — |
| `curl -v https://url` | Verbose — full detail | -v = verbose | — |
| `curl -O https://url/file` | Download and save file | -O = save to file | Invoke-WebRequest -OutFile |
| `ss -tulnp` | All listening ports and process | -t -u -l -n -p | netstat -an |
| `ss -tnp` | All active connections | — | netstat -ano |
| `nslookup hostname` | Basic DNS lookup | — | nslookup (identical) |
| `dig hostname` | Detailed DNS lookup | +short = IP only | Enhanced nslookup |
| `dig hostname MX` | Lookup MX records | — | nslookup -type=mx |
| `dig @8.8.8.8 hostname` | Query specific DNS server | — | nslookup hostname 8.8.8.8 |
| `dig -x IP` | Reverse DNS lookup | -x = reverse | nslookup IP |
| `traceroute host` | Trace path hop by hop | — | tracert host |

---

## Production Notes

### GCP Professional Cloud Engineer Refresh

**GCP networking concepts surfaced in this lab:**

- **GCP VPC** — Your ens4 is connected to a GCP Virtual Private Cloud. The /32 subnet mask is GCP-specific — GCP assigns host routes, not network ranges, to each VM.
- **Cloud NAT** — The reason your external IP 8.231.98.123 is not visible in ip addr. Cloud NAT translates your private IP to the public IP at the network edge.
- **GCP Firewall Rules** — Port 22 shows in ss -tulnp because a GCP Firewall Rule explicitly allows TCP:22 inbound. Without that rule, traffic would be dropped before reaching the VM even though port 22 is listening.
- **GCP Internal DNS** — Every GCP VM gets an internal DNS name: boa-devops-admin.asia-south1-a.c.murali-devops-lab.internal. This is resolved by the GCP metadata DNS server at 169.254.169.254.
- **Metadata server** — `curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/` returns VM metadata including service account tokens used by workloads to authenticate to GCP APIs.

**Exam tip:** GCP VPC firewall rules are stateful — allowing inbound traffic automatically allows the return traffic. You do not need a separate outbound rule for responses.

---

### CKA / CKAD Cert Refresh

**How these commands are used inside Kubernetes pods:**

```bash
# Exec into a running pod — like SSH into a container
kubectl exec -it <pod-name> -- /bin/sh

# Once inside — test service DNS resolution
nslookup userservice.default.svc.cluster.local
dig userservice.default.svc.cluster.local

# Test if the service HTTP endpoint is responding
curl http://userservice:8080/health

# Check what is listening inside the container
ss -tulnp
```

**Kubernetes internal DNS format:**
```
<service-name>.<namespace>.svc.cluster.local
```

Bank of Anthos examples:
- userservice.default.svc.cluster.local
- frontend.default.svc.cluster.local
- ledgerwriter.default.svc.cluster.local
- balancereader.default.svc.cluster.local

**CKA exam tip:** `kubectl exec -it <pod> -- curl http://<service>:<port>` is tested directly in the exam.
The commands you practised today are exactly what you run inside that exec shell.

---

## Challenges

Complete these independently before checking the phases above.
These are real incident-style tasks — exactly what you would face in production.

---

**Challenge 1 — Port Investigation**

Alert fires: "Something is using port 22 on boa-devops-admin — confirm which process is bound to it and verify it is the expected SSH daemon."

What single ss command would you run? What does the output tell you?

```
Your command:

Your output:

What you found:
```

---

**Challenge 2 — DNS Discrepancy**

Your team suspects labs.opsflux.in is returning different IPs from different DNS servers.
Write two dig commands — one using your system DNS, one querying Google DNS 8.8.8.8 directly.
How would you compare the results?

```
Command 1 (system DNS):

Command 2 (Google DNS @8.8.8.8):

Are the IPs the same?

What does it mean if they differ?
```

---

**Challenge 3 — HTTP Status Code Check**

The Bank of Anthos frontend service is suspected to be returning HTTP 503 instead of 200.
You want to check the HTTP status code without downloading the page body.

What curl command do you use? What part of the output tells you the status code?

```
Your command:

What to look for in the output:
```

---

**Challenge 4 — Interface Health Check**

A junior engineer asks: "How do I quickly check if the VM's network interface is up and what IP it has?"
Write the exact Linux commands you would give them, with the Windows equivalent for each.

```
Linux command 1:
Windows equivalent:

Linux command 2:
Windows equivalent:

What to look for in the output:
```

---

**Challenge 5 — Full Health Check One-Liner**

After a GCP maintenance window, write a single-line chained command using && that:
1. Confirms the default route exists
2. Pings 8.8.8.8 three times
3. Resolves google.com via dig (short output only)
4. Checks HTTPS response headers from example.com

```
Your one-liner:

Expected output if everything is healthy:
```

---

## Git Push — End of Session

Every lab ends with a push to GitHub. No exceptions.

```bash
# Navigate to the labs repo
cd ~/opsflux-labs

# Check what has changed
git status

# Create a feature branch for this lab
git checkout -b feature/BOA-003-networking-commands

# Stage the new lab file
git add docs/_labs/BOA-003-networking-commands.md

# Commit with a clear message
git commit -m "feat: add BOA-003 networking commands lab

- Covers ping, curl, ss, dig, nslookup, ip, traceroute
- Windows-to-Linux reference table
- 8-phase investigation workflow
- Full incident investigation sequence with && chaining
- GCP Pro and CKA cert refresh notes
- 5 production incident challenges"

# Push the feature branch
git push origin feature/BOA-003-networking-commands
```

Then on GitHub:
1. Open a Pull Request: feature/BOA-003-networking-commands to main
2. Title: feat: BOA-003 Networking Commands
3. Review, approve, squash and merge

After merge the lab auto-publishes to labs.opsflux.in.

**Verify it is live:**
```bash
curl -I https://labs.opsflux.in
```

Look for HTTP/2 200 — lab is live.

---

*BOA-003 complete. Next: BOA-004 — Bash Scripting Basics (Day 4)*