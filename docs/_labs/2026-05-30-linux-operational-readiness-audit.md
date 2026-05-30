---
title: "PAYFAST-001: Linux Operational Readiness Audit"
date: 2026-05-30
---

## Scenario
New SRE onboarding on payfast-devops-admin (GCP, Ubuntu 22.04, asia-south1).
Security and Platform teams required a baseline audit before any infra work begins.
Covers: OS identity, resource utilization, process health, network state, user privileges, scheduled jobs, system events.

## Investigation

### Phase 1 — System Identity
```bash
whoami && hostname && uname -a && uptime
cat /etc/os-release
```

### Phase 2 — Resource Utilization
```bash
free -h
df -hT
iostat -x 1 3
ps aux --sort=-%mem | head -11
```

### Phase 3 — Network State
```bash
sudo ss -tulnp
ip route show
dig google.com +short
```

### Phase 4 — Users & Privileges
```bash
who && last | head -20
grep -E "/bin/bash|/bin/sh" /etc/passwd
grep -E '^sudo' /etc/group
sudo grep -r "" /etc/sudoers.d/
```

### Phase 5 — Scheduled Jobs
```bash
crontab -l
sudo crontab -l
systemctl list-timers --all
```

### Phase 6 — System Events
```bash
sudo journalctl -n 50 --no-pager
sudo dmesg | grep -iE "error|fail|warn" | tail -20
last reboot | head -5
```

## Root Cause
No issues found. Baseline audit complete. Key observations:
- VS Code Remote SSH consuming 13.5% RAM (543MB) — highest single process
- No swap configured — OOM risk under memory pressure
- Ports 20201 and 20202 bound to all interfaces (GCP Ops Agent) — verify firewall rules
- GCP OS Login managing sudo via IAM, not /etc/sudoers directly

## Fix
No remediation required for Day 1 audit.
Recommendations logged:
- Configure swap before running containers at scale
- Verify GCP firewall rules block ports 20201/20202 externally
- Disable apt-daily auto-upgrade timer in production

## Result
Baseline audit completed and documented.
All 5 challenge tasks passed.
System healthy — cleared for Docker and Kubernetes workloads.

## Key Learnings
- ss -tulnp replaces netstat on modern Linux
- No swap on a production VM = OOM killer risk — always check
- GCP OS Login controls sudo via IAM roles, not /etc/group
- systemctl list-timers reveals background jobs cron alone won't show
- Ports bound to * on GCP need firewall rule verification — not just local checks
- df -hT shows filesystem type — critical for GCP persistent disk debugging
- journalctl is single source of truth for all systemd service logs

## Command Reference

| Command | What it does | When to use |
|---|---|---|
| uname -a | Kernel version + arch | System ID, upgrade planning |
| free -h | RAM usage human readable | Memory pressure investigation |
| df -hT | Disk usage + filesystem type | Disk full alerts, mount audit |
| iostat -x 1 3 | Disk I/O stats | Slow app, disk bottleneck debug |
| ps aux --sort=-%mem | Processes sorted by RAM | Memory leak investigation |
| ss -tulnp | Open ports + owning process | Security audit, port conflicts |
| systemctl list-timers --all | All systemd timers | Modern cron audit |
| journalctl -n 50 | Last 50 system log lines | First step in any incident |
| lastb | Failed login attempts | Security incident investigation |