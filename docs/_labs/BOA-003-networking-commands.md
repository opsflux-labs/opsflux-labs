BOA-003 — Networking Commands
File: BOA-003-networking-commands.md
Location: ~/opsflux-labs/docs/_labs/
Published: labs.opsflux.in

JIRA-Style Ticket
FieldValueTicket IDBOA-003PriorityP2 — HighAssigned ToMuraliEnvironmentboa-devops-admin / Ubuntu 22.04Labelslinux, networking, devops-foundation, day-3SprintMonth 1 — Phase 1: Linux for DevOps
Ticket Description

[BOA-003] Linux Networking Commands — Operations Reference
The Bank of Anthos platform runs across 8 microservices communicating over internal Kubernetes networks.
As the operator, you must be able to verify connectivity, inspect DNS resolution, check open ports, and
diagnose network failures — all from the command line on boa-devops-admin.
This lab covers the core networking toolkit every DevOps/SRE engineer uses daily in production.
You will use these exact commands when Bank of Anthos services fail to communicate in later labs.

Acceptance Criteria:

 Can verify connectivity to any host using ping
 Can make HTTP requests and inspect responses using curl
 Can list listening ports and active connections using ss and netstat
 Can resolve DNS names using dig and nslookup
 Can inspect network interface configuration using ip
 Lab file pushed to GitHub and live on labs.opsflux.in


Windows → Linux Networking Reference Table

Before we start — your Windows muscle memory mapped to Linux equivalents.

What You Want To DoWindows CommandLinux EquivalentNotesTest connectivity to a hostping google.comping google.comSame syntax. Linux pings forever — use Ctrl+C to stopMake an HTTP requestBrowser / Invoke-WebRequestcurl https://example.comLike PowerShell's Invoke-WebRequest but CLI-nativeSee open ports and connectionsnetstat -anss -tulnp or netstat -tulnpss is the modern replacement for netstatFind what's using a portnetstat -ano + Task Managerss -tulnp | grep :8080Pipe to grep to filterLook up DNS for a hostnamenslookup google.comnslookup google.com or dig google.comdig gives much more detailSee your IP addressipconfigip addr or ip aip = Linux's ipconfigSee your routing tableroute printip routeShows how traffic exits the machineTrace the path to a hosttracert google.comtraceroute google.comSame concept, different nameDownload a fileInvoke-WebRequest -Uri URL -OutFile filecurl -O URL or wget URLcurl -O saves to same filenameCheck if a port is open on remoteTest-NetConnection -Port 443curl -v telnet://host:443 or nc -zv host portnc = netcatFlush DNS cacheipconfig /flushdnssudo resolvectl flush-cachesDNS resolver is systemd-resolved on Ubuntu 22.04

Lab Overview — What You're Building
[ boa-devops-admin ]
        |
        |--- ping        → Is the host alive?
        |--- curl        → Is the HTTP service responding?
        |--- ss          → What ports are open on THIS machine?
        |--- dig         → What does DNS resolve this hostname to?
        |--- ip          → What is my IP and routing config?
        |--- traceroute  → What path does traffic take to reach the host?
In Kubernetes (coming in BOA-010 onwards), you'll use these same commands
inside pods to debug why Service A can't reach Service B.

Phase 1 — Verify Your Starting Point

Goal: Confirm your machine is on the network before testing anything else.
This is the "are my cables plugged in?" check — in Linux.

Step 1.1 — Check your IP address
baship addr
What this command does, broken down:

ip → The main networking tool on Linux (replaces the older ifconfig)
addr → Short for "address" — show me all network interface addresses

What you'll see:
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo

2: ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460
    link/ether 42:01:08:e7:62:05 brd ff:ff:ff:ff:ff:ff
    inet 10.160.0.X/32 scope global dynamic ens4
What to look for:

lo → Loopback interface. Like Windows' 127.0.0.1. Only talks to itself.
ens4 → Your actual network interface (GCP names it ens4). This is your real NIC.
inet 10.160.0.X → Your internal/private IP on the GCP VPC. This is what other VMs see.
The external IP (8.231.98.123) is handled by GCP's NAT — it's not visible here.


💡 Windows analogy: ip addr = ipconfig in CMD. The ens4 interface = your Ethernet adapter in Windows.


Step 1.2 — Check your routing table
baship route
What this command does:

ip route → Shows the routing table — "given a destination IP, which interface and gateway should I use?"

What you'll see:
default via 10.160.0.1 dev ens4 proto dhcp src 10.160.0.X metric 100
10.160.0.1 dev ens4 proto dhcp scope link src 10.160.0.X metric 100
What to look for:

default via 10.160.0.1 → Default gateway. All traffic that doesn't match a specific route goes here.
dev ens4 → Go out through the ens4 interface.


💡 Windows analogy: ip route = route print in CMD. The default line = your Default Gateway in ipconfig.


Phase 2 — ping: Is The Host Alive?

Goal: Confirm basic connectivity — can we reach a host at all?
In production, this is your first check before anything else.

Step 2.1 — Ping Google's DNS
bashping -c 4 8.8.8.8
What this command does, broken down:

ping → Send ICMP echo requests to a host. Like knocking on a door and waiting for a response.
-c 4 → Send exactly 4 packets, then stop. Without -c, Linux pings forever.
8.8.8.8 → Google's public DNS server. Reliable target for connectivity tests.

Expected output:
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=1.23 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=117 time=1.19 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=117 time=1.21 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=117 time=1.22 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 1.19/1.21/1.23/0.015 ms
What to look for:

0% packet loss → Network path is clean. Good.
time=1.xx ms → Round-trip latency. Single-digit ms from GCP asia-south1 to Google is excellent.
If you see 100% packet loss → Host is unreachable, firewall is blocking ICMP, or DNS isn't resolving.


Step 2.2 — Ping by hostname (tests DNS + connectivity)
bashping -c 4 google.com
What this tests:

First, your machine resolves google.com to an IP via DNS
Then it sends ICMP packets to that IP

If this works but ping -c 4 8.8.8.8 also works, your network AND DNS are both fine.
If ping 8.8.8.8 works but ping google.com fails → DNS is broken, not the network.

💡 Production tip: When a Bank of Anthos service can't reach another service,
this DNS-vs-IP distinction is often how you find the root cause.


Step 2.3 — Ping the GCP metadata server
bashping -c 4 metadata.google.internal
What this is:
GCP provides a special internal endpoint at 169.254.169.254 (or metadata.google.internal)
that every VM can reach to get its own metadata — project ID, service account tokens, etc.
If this is unreachable, something is seriously wrong with your GCP network config.

Phase 3 — curl: Test HTTP Services

Goal: Make actual HTTP requests from the command line.
In production, you'll use curl to test if a service endpoint is responding correctly.

Step 3.1 — Basic HTTP GET
bashcurl https://example.com
What this command does:

curl → Command-line tool for transferring data over URLs
https://example.com → Makes a GET request to this URL, prints the response body

You'll see raw HTML output. That's the body of the HTTP response.

Step 3.2 — Show response headers (most useful in production)
bashcurl -I https://example.com
What the flags mean:

-I → "HEAD request only" — fetch only the headers, not the body

Expected output:
HTTP/2 200
content-type: text/html; charset=UTF-8
date: Fri, 05 Jun 2026 06:00:00 GMT
expires: Sun, 07 Jun 2026 06:00:00 GMT
cache-control: public, max-age=172800
server: ECS (nyb/1D19)
content-length: 1256
What to look for:

HTTP/2 200 → Status code 200 = OK. Service is responding correctly.
content-type → What type of content is being returned.
Common status codes you'll see in incidents:

200 OK → All good
404 Not Found → URL doesn't exist
503 Service Unavailable → Backend service is down
401 Unauthorized / 403 Forbidden → Auth/permission issue




Step 3.3 — Verbose output (see everything)
bashcurl -v https://example.com 2>&1 | head -40
What the flags mean:

-v → Verbose — show me the full request AND response including TLS handshake
2>&1 → Redirect stderr (where curl writes verbose info) to stdout so we can see it
| head -40 → Show only the first 40 lines (verbose output is long)

What to look for in verbose output:
* Trying 93.184.216.34:443...          ← IP it resolved to
* Connected to example.com             ← TCP connection established
* SSL connection using TLSv1.3         ← TLS negotiated (HTTPS is working)
> GET / HTTP/2                         ← Your request
> Host: example.com
< HTTP/2 200                           ← Server's response

💡 Production use: When a Bank of Anthos service returns an unexpected response,
curl -v shows you exactly what's happening at every layer — DNS, TCP, TLS, HTTP.


Step 3.4 — Test against your own VM
bashcurl http://localhost
This will fail with "Connection refused" because no web server is running on port 80 yet.
That's expected — and it tells you the port is closed. You'll use this pattern in Kubernetes
labs to test services from inside pods.

Step 3.5 — curl with a specific port
bashcurl http://localhost:8080
What this does:
Tests if anything is listening on port 8080 on this machine.
Again, "Connection refused" is the expected response right now — nothing is running there.
In Kubernetes labs, this is how you'll test if a service is exposed correctly.

Step 3.6 — Download a file with curl
bashcurl -O https://raw.githubusercontent.com/GoogleCloudPlatform/bank-of-anthos/main/README.md
What the flags mean:

-O → Capital O = "save to a file with the same name as the URL"
This downloads README.md into your current directory

Verify it downloaded:
bashls -lh README.md
cat README.md | head -20

💡 Windows analogy: curl -O URL = Invoke-WebRequest -Uri URL -OutFile filename in PowerShell.


Phase 4 — ss: What Ports Are Open on THIS Machine?

Goal: See what network services are currently running and listening on your VM.
This is how you answer "what's running on this machine?" from a network perspective.

Step 4.1 — Show all listening ports
bashss -tulnp
What each flag means — memorise this combination:

-t → TCP connections only (not UDP)
-u → Include UDP connections too
-l → Show only listening sockets (waiting for connections)
-n → Show numbers not names (show port 22 not "ssh", show IP not hostname)
-p → Show the process that owns each socket

Expected output:
Netid  State   Recv-Q Send-Q  Local Address:Port   Peer Address:Port  Process
tcp    LISTEN  0      128     0.0.0.0:22            0.0.0.0:*          users:(("sshd",pid=1234,fd=3))
tcp    LISTEN  0      128     127.0.0.1:53          0.0.0.0:*          users:(("systemd-r",pid=567,fd=18))
What to look for:

0.0.0.0:22 → SSH is listening on all interfaces on port 22. This is how you SSH in.
127.0.0.1:53 → DNS resolver (systemd-resolved) listening only on localhost.
0.0.0.0 = "any interface" (accessible from anywhere)
127.0.0.1 = "loopback only" (not accessible from outside)


Step 4.2 — Check if a specific port is in use
bashss -tulnp | grep :22
What this does:

Runs ss -tulnp then pipes the output to grep
grep :22 → Filter lines containing :22 (the SSH port)


💡 Windows analogy: ss -tulnp = netstat -an in CMD. ss is faster and more modern.


Step 4.3 — Show all active connections (not just listening)
bashss -tnp
Difference from before:

Removed -l → Now shows ALL connections, not just listening ones
You'll see active sessions including your current SSH connection

What to look for:
State    Recv-Q Send-Q  Local Address:Port   Peer Address:Port
ESTAB    0      0       10.160.0.X:22        YOUR_IP:PORT

ESTAB = ESTABLISHED = active connection
This line is YOUR current SSH session from Windows to boa-devops-admin


Phase 5 — dig and nslookup: DNS Lookups

Goal: Resolve hostnames to IPs and inspect DNS records.
In production, DNS failures are one of the most common causes of service outages.

Step 5.1 — Basic DNS lookup with nslookup
bashnslookup google.com
What this does:
Asks your configured DNS server "what IP address does google.com resolve to?"
Expected output:
Server:         127.0.0.53
Address:        127.0.0.53#53

Non-authoritative answer:
Name:    google.com
Address: 142.250.192.46
Address: 2404:6800:4007:80e::200e
What to look for:

Server: 127.0.0.53 → Your local systemd-resolved is handling DNS
Address: 142.250.x.x → IPv4 address for google.com
Non-authoritative answer → This DNS server got the answer from another server (cache or upstream), not from google.com's own nameserver


Step 5.2 — dig: The production DNS toolkit
bashdig google.com
What this command does:
dig is the more powerful, more detailed DNS query tool.
Every senior DevOps/SRE engineer uses dig over nslookup.
Expected output:
; <<>> DiG 9.18.x <<>> google.com
;; ANSWER SECTION:
google.com.         300     IN      A       142.250.192.46

;; Query time: 2 msec
;; SERVER: 127.0.0.53#53(127.0.0.53)
;; WHEN: Fri Jun 05 06:00:00 UTC 2026
;; MSG SIZE  rcvd: 55
Breaking down the output:

ANSWER SECTION → The actual DNS answer
google.com. → The name queried
300 → TTL (Time To Live) in seconds — how long this answer is cached
IN A → Record class (IN = Internet) and type (A = IPv4 address)
142.250.192.46 → The IP address


Step 5.3 — dig with specific record types
bash# Look up MX records (mail servers for a domain)
dig google.com MX

# Look up NS records (nameservers for a domain)
dig google.com NS

# Look up TXT records (often used for domain verification and SPF)
dig google.com TXT
Why this matters in Bank of Anthos:
In Kubernetes, every service gets a DNS name like userservice.default.svc.cluster.local.
When a pod can't reach userservice, you'll run dig userservice.default.svc.cluster.local
inside the pod to check if DNS resolution is working — before you even look at the service config.

Step 5.4 — Query a specific DNS server
bashdig @8.8.8.8 google.com
What the @8.8.8.8 means:
"Use this specific DNS server (8.8.8.8) instead of my system's configured DNS."

💡 Production use: When you suspect your internal DNS is returning wrong answers,
you query Google's public DNS directly to compare. If @8.8.8.8 resolves correctly
but your local DNS doesn't, the problem is your DNS config, not the domain.


Step 5.5 — Reverse DNS lookup (IP to hostname)
bashdig -x 8.8.8.8
What -x does:
"Reverse lookup" — given an IP, what hostname does it resolve to?
Expected output:
;; ANSWER SECTION:
8.8.8.8.in-addr.arpa.   18491   IN      PTR     dns.google.
dns.google = the reverse DNS name for Google's 8.8.8.8 DNS server.

Phase 6 — ip: Full Network Interface Toolkit

Goal: Inspect and understand your network interfaces and routing.
ip is the modern Linux replacement for ifconfig, route, and arp.

Step 6.1 — Show interface details
baship addr show ens4
What this does:

ip addr show → Show address info
ens4 → For this specific interface only

What to look for:

inet 10.160.0.X/32 → Your internal GCP IP
/32 → Subnet mask (in CIDR notation). /32 means "just this one IP, no network neighbours"
state UP → Interface is active


Step 6.2 — Show routing table
baship route show
Reading the routing table:
default via 10.160.0.1 dev ens4 proto dhcp src 10.160.0.X metric 100

default → This rule applies to ALL destinations not matched by other rules
via 10.160.0.1 → Send traffic to this gateway (router)
dev ens4 → Using the ens4 interface
proto dhcp → This route was set by DHCP (assigned automatically)
metric 100 → Priority (lower = higher priority)


💡 Windows analogy: ip route show = route print in CMD. The default row is your Default Gateway.


Step 6.3 — Show interface statistics
baship -s link show ens4
What -s adds:
Statistics — transmitted/received bytes, errors, drops.
What to look for:
RX:  bytes  packets  errors  dropped
     1234567  9876    0       0
TX:  bytes  packets  errors  dropped
     987654   5432    0       0

errors: 0 and dropped: 0 → Healthy interface
If you see non-zero errors or drops → NIC or network issue


Phase 7 — traceroute: Path Discovery

Goal: Trace the network path from your machine to a destination.
Every hop in the path is a router your traffic passes through.

Step 7.1 — Install traceroute (if needed)
bashwhich traceroute || sudo apt install -y traceroute
What this does:

which traceroute → Check if it's already installed (prints path if yes)
|| → "OR" — if the left command fails (not installed), run the right command
sudo apt install -y traceroute → Install it without asking for confirmation


Step 7.2 — Trace route to Google
bashtraceroute 8.8.8.8
What this does:
Sends packets with increasing TTL (Time-To-Live) values to map each router hop.
Each router decrements TTL by 1. When TTL=0, the router sends back an error message
revealing its IP — that's how traceroute discovers each hop.
Expected output:
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  10.160.0.1 (10.160.0.1)    0.5 ms  0.4 ms  0.4 ms
 2  * * *
 3  209.85.254.X (209.85.254.X)  1.2 ms  1.1 ms  1.1 ms
 4  142.251.X.X (142.251.X.X)   1.0 ms  0.9 ms  0.9 ms
 5  8.8.8.8 (8.8.8.8)           1.3 ms  1.2 ms  1.3 ms
What to look for:

First hop (10.160.0.1) → Your GCP gateway
* * * → Router doesn't respond to traceroute probes (firewall blocks ICMP). Normal on cloud networks.
Latency increasing per hop → Expected. Each hop adds a tiny delay.
Sudden huge latency jump → Bottleneck at that router.


💡 Windows analogy: traceroute = tracert in CMD. Exact same concept, different name.


Phase 8 — Putting It All Together (Production Scenario)

Goal: Simulate a real incident investigation workflow using all commands together.

Scenario: Someone reports "I can't reach google.com from boa-devops-admin."
Here's the exact investigation sequence a DevOps engineer would follow:
bash# Step 1 — Is my network interface up?
ip addr show ens4

# Step 2 — Do I have a default route (gateway)?
ip route show

# Step 3 — Can I reach the gateway itself?
ping -c 3 10.160.0.1

# Step 4 — Can I reach a known IP (bypass DNS)?
ping -c 3 8.8.8.8

# Step 5 — Is DNS resolving? (tests DNS separately from connectivity)
dig google.com

# Step 6 — Can I reach google.com by name now?
ping -c 3 google.com

# Step 7 — Is the HTTPS service responding?
curl -I https://google.com

# Step 8 — Trace the path (if something is slow)
traceroute google.com
Investigation Logic — Narrowing Down:
ping 8.8.8.8 FAILS  → Network issue (routing or firewall)
ping 8.8.8.8 WORKS but ping google.com FAILS → DNS issue
ping google.com WORKS but curl https://google.com FAILS → HTTP/TLS issue
curl http:// WORKS but curl https:// FAILS → TLS/certificate issue
Run through this entire sequence now on boa-devops-admin:
baship addr show ens4 && ip route show && ping -c 3 8.8.8.8 && dig google.com +short && curl -I https://example.com
What && does:

Runs each command only if the previous one succeeded
If ip addr fails, it stops — no point continuing
This chains a health check in a single line


Root Cause (Lab Context)
No active incident in this lab. This lab builds the diagnostic toolkit that identifies root causes in future incidents. The systematic ping → dig → curl → ss → ip → traceroute workflow will be the foundation of every network investigation in BOA-013 through BOA-022.

Fix / Outcome
All networking commands verified and functional on boa-devops-admin. The machine has:

Active ens4 interface with GCP internal IP
Default route via GCP gateway 10.160.0.1
DNS resolution working via systemd-resolved (127.0.0.53)
Connectivity to internet (8.8.8.8, google.com, example.com)
SSH listening on port 22 (confirmed via ss -tulnp)


Result
✅ Phase 1 — ip addr, ip route — Interface and routing confirmed
✅ Phase 2 — ping — Connectivity to IPs and hostnames verified
✅ Phase 3 — curl — HTTP/HTTPS responses tested
✅ Phase 4 — ss — Open ports on boa-devops-admin inspected
✅ Phase 5 — dig/nslookup — DNS resolution working
✅ Phase 6 — ip toolkit — Interface details and stats reviewed
✅ Phase 7 — traceroute — Network path to 8.8.8.8 mapped
✅ Phase 8 — Full investigation workflow completed end-to-end

Key Learnings

ping tests ICMP reachability — always first check in any connectivity issue
ping IP vs ping hostname — separates network issues from DNS issues
curl -I gives HTTP status codes without downloading the full page body
curl -v shows everything — TLS handshake, request headers, response headers — use for deep HTTP debugging
ss -tulnp is your go-to for "what's listening on this machine?" — memorise these flags
dig is more powerful than nslookup — shows TTL, query time, which DNS server answered
dig @8.8.8.8 hostname queries a specific DNS server — use to compare your DNS vs public DNS
ip addr shows interfaces and IPs (ipconfig equivalent)
ip route shows how traffic is routed out (route print equivalent)
The 8-step investigation sequence (ip → ping IP → ping hostname → dig → curl) is a real production workflow
&& chaining runs the next command only if the previous one passed — useful for health checks


Command Reference Table
CommandWhat It DoesKey FlagsWindows Equivalentip addrShow all network interfaces and IPs-s = with statsipconfigip addr show ens4Show specific interface—ipconfig (NIC-specific)ip route showShow routing table—route printip -s link show ens4Interface with TX/RX statistics-s = stats—ping -c 4 hostSend 4 ICMP packets to host-c = countping hostcurl https://urlHTTP GET request, print body—Invoke-WebRequestcurl -I https://urlHTTP HEAD request, headers only-I = HEAD—curl -v https://urlVerbose — full request/response detail-v = verbose—curl -O https://url/fileDownload file-O = save to filewget / Invoke-WebRequest -OutFiless -tulnpShow all listening ports + process-t TCP -u UDP -l listen -n numbers -p processnetstat -anss -tnpShow all active connections—netstat -anonslookup hostnameBasic DNS lookup—nslookup (identical)dig hostnameDetailed DNS lookup+short = just the IPEnhanced nslookupdig hostname MXDNS lookup for MX records—nslookup -type=mxdig @8.8.8.8 hostnameDNS lookup via specific server—nslookup hostname 8.8.8.8dig -x IPReverse DNS (IP → hostname)-x = reversenslookup IPtraceroute hostTrace network path, hop by hop—tracert host

Production Notes
GCP Professional Cloud Engineer Refresh
Networking concepts from this lab that appear in the GCP Pro cert:

GCP VPC — Your ens4 interface is connected to a GCP Virtual Private Cloud. The /32 subnet mask you saw is GCP-specific (GCP uses host routes).
Cloud NAT — The reason your external IP (8.8.8.123) doesn't appear in ip addr. GCP's Cloud NAT translates your private IP to the public IP at the network edge.
GCP Firewall Rules — The ss -tulnp output showed port 22 open. That port is accessible because a GCP Firewall Rule allows TCP:22 inbound.
Internal DNS — GCP provides internal DNS (e.g., boa-devops-admin.asia-south1-a.c.murali-devops-lab.internal) using the same 169.254.169.254 metadata server.
GCP metadata server — curl http://metadata.google.internal/computeMetadata/v1/ (with header Metadata-Flavor: Google) provides VM metadata including service account tokens.

Exam tip: VPC firewall rules are stateful — if you allow inbound traffic on a port, the return traffic is automatically allowed. You don't need a separate outbound rule for responses.

CKA / CKAD Cert Refresh
How these commands are used inside Kubernetes:
bash# In Kubernetes troubleshooting, you run these commands INSIDE pods:

# 1. Exec into a pod (like SSH into a container)
kubectl exec -it podname -- /bin/sh

# 2. Then inside the pod, test service DNS resolution
nslookup userservice.default.svc.cluster.local
dig userservice.default.svc.cluster.local

# 3. Test if the service is responding
curl http://userservice:8080/health

# 4. Check what's listening inside the container
ss -tulnp
Kubernetes DNS format:
<service-name>.<namespace>.svc.cluster.local
Example for Bank of Anthos:

userservice.default.svc.cluster.local
frontend.default.svc.cluster.local
ledgerwriter.default.svc.cluster.local

CKA exam tip: kubectl exec -it <pod> -- curl http://<service>:<port> is a common troubleshooting pattern you will be tested on. The commands you learned today are the ones you'll run inside that shell.

Challenges

Instructions: Complete these independently. Don't look at the commands above.
These are real incident-style tasks — exactly what you'd face in production.
After attempting each one, note your answer and the output you observed.


Challenge 1 — Port Investigation

An alert fires: "Something is using port 22 on boa-devops-admin — confirm which process and verify it's the expected SSH daemon."

What single ss command would you run to find this? What does the output tell you?
Your command: sudo ss -tulnp | grep :22

Your output: sudo ss -tulnp | grep :22
tcp   LISTEN 0      128             0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=733,fd=3))            
tcp   LISTEN 0      128                [::]:22            [::]:*    users:(("sshd",pid=733,fd=4)) 

What you found: SSH is running

Challenge 2 — DNS Discrepancy

Your team suspects that labs.opsflux.in is returning different IPs from different DNS servers.

Write two dig commands — one that queries your system's DNS, and one that queries Google's DNS (8.8.8.8) directly. How would you compare the results?

Command 1: dig labs.opsflux.in
Command 2: dig @8.8.8.8 labs.opsflux.in +short
Same IPs: Yes
What it means if they differ: local DNS cache is stale or misconfigured

Challenge 3 — HTTP Response Investigation

The Bank of Anthos frontend service is suspected to be returning HTTP 503 instead of 200.
You want to check the HTTP status code WITHOUT downloading the page content.

What curl command do you use? What part of the output tells you the status code?
Your command: curl -I https://example.com

What to look for in the output: HTTP/2 200

Challenge 4 — Interface Health Check

A new junior engineer asks you: "How do I quickly check if the VM's network interface is up and what IP it has?"

Write the exact commands you'd tell them. Include the Windows equivalent so they understand the analogy.
Linux command:

Windows equivalent:
Linux: ip addr     Windows: ipconfig
Linux: ip route    Windows: route print

What to look for in the output:
ip addr   =   ipconfig      ← shows your IP address
ip route  =   route print   ← shows your routing table / default gateway

Challenge 5 — Connectivity Chain

After a GCP maintenance window, you need to verify that boa-devops-admin has full network health.
Write a single-line command chain using && that:

Confirms the default route exists
Pings 8.8.8.8 (3 times)
Resolves google.com via dig (short output only)
Checks HTTPS response headers from example.com


Your one-liner: ip addr show ens4 && ping -c 3 8.8.8.8 && dig google.com +short && curl -I https://example.com

Expected output if everything is healthy:

Git Push — End of Session
Every lab ends with a push to GitHub. No exceptions.
bash# Step 1 — Navigate to the labs repo
cd ~/opsflux-labs

# Step 2 — Check current status (what changed?)
git status

# Step 3 — Create a feature branch for this lab
git checkout -b feature/BOA-003-networking-commands

# Step 4 — Stage the new lab file
git add docs/_labs/BOA-003-networking-commands.md

# Step 5 — Commit with a clear message
git commit -m "feat: add BOA-003 networking commands lab

- Covers ping, curl, ss, dig, nslookup, ip, traceroute
- Includes Windows-to-Linux reference table
- 8-phase investigation workflow
- GCP Pro + CKA cert refresh notes
- 5 production incident challenges"

# Step 6 — Push the feature branch
git push origin feature/BOA-003-networking-commands
Then on GitHub:

Open a Pull Request: feature/BOA-003-networking-commands → main
Title: feat: BOA-003 Networking Commands
Review, approve, squash and merge

After merge, the lab auto-publishes to labs.opsflux.in.
Verify it's live:
bashcurl -I https://labs.opsflux.in/labs/BOA-003-networking-commands
Look for HTTP/2 200 — lab is live. ✅

BOA-003 complete. Next: BOA-004 — Bash Scripting Basics (Day 4)Project contentMurali DevOps Mastery — Bank of AnthosCreated by youAdd PDFs, documents, or other text to reference in this project.