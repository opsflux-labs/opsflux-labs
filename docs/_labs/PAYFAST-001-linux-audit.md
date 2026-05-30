# PAYFAST-001 — Linux Operational Readiness Audit
**Date:** $(date +%Y-%m-%d)
**Engineer:** Murali
**Environment:** payfast-devops-admin | GCP asia-south1 | Ubuntu 22.04

---

## Production Scenario
JIRA PAYFAST-001 | P2-High
New SRE onboarding — baseline server audit before any infra work begins.
Required by Security and Platform teams.

---

## Guided Lab Steps

### Phase 1 — System Identity
```bash
whoami && hostname && uname -a && cat /etc/os-release && uptime
```

### Phase 2 — Resource Utilization
```bash
lscpu | grep -E "Architecture|CPU\(s\)|Model name"
free -h
df -hT
iostat -x 1 3
```

### Phase 3 — Process & Service Health
```bash
ps aux --sort=-%cpu | head -11
ps aux --sort=-%mem | head -11
systemctl list-units --type=service --state=running
```

### Phase 4 — Network State
```bash
sudo ss -tulnp
ip route show
dig google.com +short
```

### Phase 5 — Users & Privileges
```bash
who && w
last | head -20
sudo lastb | head -10
grep -E "/bin/bash|/bin/sh" /etc/passwd
```

### Phase 6 — Scheduled Jobs
```bash
crontab -l
sudo crontab -l
systemctl list-timers --all
```

### Phase 7 — System Events
```bash
sudo journalctl -n 50 --no-pager
sudo dmesg | grep -iE "error|fail|warn" | tail -20
last reboot | head -5
```

---

## Challenge Tasks

Challenge 1 — Memory Pressure Point ✅ PASS

Your finding: VS Code Server process (PID 20896) — 13.5% RAM = ~543 MB RSS

Senior Review:
Good catch. But let's be precise about what you're seeing:
learnin+   20896   0.4  13.5  54788428  543364  Sl   /vscode-server/node

543 MB consumed by a single VS Code remote server process
That's your heaviest process — more than Docker (104MB), more than containerd (32MB)
Production insight: VS Code Remote SSH is a development tool running on a production-class VM. In a real environment, this would be flagged — dev tooling eating 13.5% RAM on a server is a cost and stability concern
You have NO swap configured — Swap: 0 0 0. This is a time bomb. When RAM fills up, the OOM killer fires and starts killing processes. On a prod server, that means your app dies, not VS Code

Action you should note: sudo swapon --show — confirm no swap. This needs to be addressed before running containers at scale.

Challenge 2 — Port Audit ✅ PASS (with gaps)
Your output:
:53    → systemd-resolved  (DNS)
:22    → sshd              (SSH - 0.0.0.0 and ::)
:20202 → fluent-bit        (GCP Ops Agent log receiver)
:37703 → VS Code server    (localhost only)
:20201 → otelopscol        (OpenTelemetry collector)
Senior Review:
You found all 6 listening sockets. Good. Now the analysis layer — this is what separates L1 from Senior:
PortProcessRisk Assessment22sshd✅ Expected. Bound to 0.0.0.0 — accessible externally53systemd-resolved✅ Localhost only — internal DNS. Safe20201otelopscol⚠️ Bound to * — all interfaces. GCP Ops Agent telemetry. Confirm GCP firewall blocks this externally20202fluent-bit⚠️ Same — all interfaces. Log shipping agent37703VS Code✅ 127.0.0.1 only — localhost only. Safe
Critical observation you missed: Ports 20201 and 20202 are bound to * (all interfaces). On GCP, your VM firewall rules determine if these are reachable externally. You should verify:
bashgcloud compute firewall-rules list --project=murali-devops-lab
This is a real security audit step.

Challenge 3 — Disk Space Risk Assessment ✅ PASS
Your finding: /dev/root — 22% used, 6.3G of 29G
Senior Review:
Correct answer. But your analysis needs to go one level deeper in production:
/dev/root    29G   6.3G   23G   22%   /
/dev/sda15   105M  6.1M   99M    6%   /boot/efi

Root at 22% — currently healthy. No immediate action needed
But watch /boot/efi at 6%. It's tiny (105M). Old kernels accumulate here. When it fills, apt upgrade fails silently
Production standard: Set alert at 70%, page at 85%
Your df output confirms this is an ext4 filesystem on a GCP Persistent Disk — which means you can resize it online without downtime using gcloud compute disks resize. That's a GCP Pro exam point worth knowing cold


Challenge 4 — User Privilege Audit ⚠️ PARTIAL PASS
Your finding:
Users with bash shells: root, ubuntu, learning_gcp_devops
Sudo group: ubuntu
sudoers file: Permission denied
Senior Review:
You got the data — but the cat /etc/sudoers failing without sudo is actually correct behavior (sudoers is 440 permission). The fix:
bashsudo cat /etc/sudoers | grep -v "^#" | grep -v "^$"
# or better:
sudo visudo -c   # validates sudoers syntax
sudo grep -r "learning_gcp_devops\|ubuntu\|ALL" /etc/sudoers.d/
What you correctly identified:

ubuntu is in sudo group ✅
learning_gcp_devops is NOT in sudo group

What you missed: On GCP VMs with OS Login, sudo access comes from IAM roles, not /etc/group. Your user has sudo because of the GCP IAM role roles/compute.osAdminLogin — not because they're in the sudoers file. This is a key GCP Pro concept.
Verify it:
bashsudo grep -r "" /etc/sudoers.d/
# You'll see a google_oslogin entry

Challenge 5 — Cron & Timer Inventory ✅ STRONG PASS
Your finding: 16 timers listed, with next trigger times
Senior Review:
Excellent output. Let me show you how a senior reads this:
GCP-specific timers (flag these):

google-oslogin-cache.timer — runs every 6 hours. Syncs SSH keys from GCP IAM. If this breaks, no one can SSH in after their key rotates
gce-workload-cert-refresh.timer — just ran 30ms ago when you listed it. Refreshes workload identity certs. Critical for GKE/service auth

Security-relevant:

apt-daily.timer + apt-daily-upgrade.timer — auto-updates enabled. In prod, you'd disable these and manage updates via Ansible/patch management. Surprise reboots during auto-upgrades kill SLAs

Observation: snapd.snap-repair.timer shows n/a for next run — snapd repair is not scheduled. Worth noting — snap packages won't auto-repair.


---

## Key Learnings
- ss -tulnp replaces netstat on modern Linux
- df -hT shows filesystem type — critical for GCP persistent disk debugging
- systemctl list-timers reveals scheduled jobs cron alone won't show
- lastb is first check during security incidents
- journalctl is single source of truth for all systemd service logs
- Disk above 80% in prod = immediate alert — kills databases silently
- Process sorting by %mem and %cpu tell different stories

---

## Command Reference

| Command | What it does | When to use |
|---|---|---|
| uname -a | Kernel version + arch | System ID, upgrade planning |
| uptime | Load average + uptime | First check during slowness |
| free -h | RAM usage human readable | Memory pressure investigation |
| df -hT | Disk usage + filesystem type | Disk full alerts, mount audit |
| iostat -x 1 3 | Disk I/O stats (3 samples) | Slow app, disk bottleneck debug |
| ps aux --sort=-%cpu | Processes sorted by CPU | CPU spike investigation |
| ps aux --sort=-%mem | Processes sorted by RAM | Memory leak investigation |
| ss -tulnp | Open ports + owning process | Security audit, port conflicts |
| journalctl -n 50 | Last 50 system log lines | First step in any incident |
| lastb | Failed login attempts | Security incident investigation |
| systemctl list-timers --all | All systemd timers | Modern cron audit |

---

## Production Notes

### GCP Pro Cert Refresh
- GCP Persistent Disks mount as /dev/sda on e2 VMs — df -hT shows ext4
- VM metadata server at 169.254.169.254 — will appear in ss output
- GCP OS Login changes /etc/passwd behavior vs standard Linux

### CKA/CKAD Cert Refresh
- kubectl debug node/ drops you into this exact Linux environment
- Node troubleshooting in CKA = these exact Phase 1-7 commands
- Kubelet is a systemctl service — systemctl status kubelet is daily use

