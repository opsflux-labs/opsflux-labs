---
title: "BOA-REVIEW-01: Linux for DevOps — Phase Review"
date: 2026-06-08
summary: "Phase 1 review session covering Linux navigation, permissions, processes, networking, bash scripting and log analysis."
difficulty: intermediate
duration: "60 mins"
description: "Validation review for BOA-001 through BOA-005. Written questions, terminal tasks and a live incident investigation on boa-devops-admin."
tags: [phase-review, linux, permissions, processes, networking, bash, logs]
---

# BOA-REVIEW-01 — Linux for DevOps: Phase Review

## Ticket

| Field | Detail |
|-------|--------|
| Ticket ID | BOA-REVIEW-01 |
| Priority | P2 — Phase Validation |
| Assigned To | Murali |
| Phase | Phase 1 — Linux for DevOps |
| Labs Covered | BOA-001 through BOA-005 |
| Date | 2026-06-08 |
| Status | PASSED ✅ |

---

## Overview

This review session validates all skills learned in Phase 1 — Linux for DevOps.
Three parts: written questions, terminal tasks, and a live incident investigation.

---

## Part 1 — Written Questions

### Q1 — File Permissions (BOA-001)

**Question:** You run `ls -la` and see `-rwxr-x---`. Who can do what?

**Answer:**
- Owner: read, write, execute
- Group: read and execute (no write — the `-` in position 2 means no write)
- Others: no access at all

**Key learning:** Permission string is always three blocks of three — owner, group, others.
Each block follows the same order: read (r), write (w), execute (x).
A dash `-` in any position means that permission is denied.

---

### Q2 — systemctl (BOA-002)

**Question:** Two Linux commands that replace services.msc — check status and enable auto-start on reboot.

**Answer:**
```bash
systemctl status nginx    # check if service is running
systemctl enable nginx    # auto-start on reboot
```

**Windows equivalent:**

| Windows (services.msc) | Linux (systemctl) |
|------------------------|-------------------|
| Check service status | `systemctl status nginx` |
| Startup Type → Automatic | `systemctl enable nginx` |
| Start service now | `systemctl start nginx` |

---

### Q3 — Network Investigation (BOA-003)

**Question:** Three commands to investigate "app is down, can't reach server."

**Answer:**

| Command | What it tells you |
|---------|------------------|
| `ping <server>` | Is the server reachable on the network? |
| `ss -tulnp` | Which ports are open and listening? |
| `curl -i <url>` | Is the app responding? What HTTP status is it returning? |

**Key learning:** Always investigate in layers — network first, then ports, then app response.

---

### Q4 — Bash Variables (BOA-004)

**Question:** What does this do and why is `$` important?
```bash
SERVICE_NAME="nginx"
echo "Checking $SERVICE_NAME status..."
```

**Answer:**
Prints `Checking nginx status...` to the terminal.
The `$` tells bash "this is a variable — go fetch its value."
Without `$` bash would print the literal text `SERVICE_NAME` instead of `nginx`.

**Windows equivalent:**

| Windows CMD | Linux Bash |
|-------------|------------|
| `%SERVICE_NAME%` | `$SERVICE_NAME` |

---

### Q5 — Live Log Monitoring (BOA-005)

**Question:** Which command watches live log entries as they're written, and what flag makes it follow in real time?

**Answer:**
```bash
tail -f /var/log/auth.log
```
The `-f` flag means follow — keeps the file open and prints new lines as they arrive.

**Windows equivalent:** Like continuously refreshing Event Viewer — except `tail -f` does it automatically.

---

## Part 2 — Terminal Tasks

All tasks run on `boa-devops-admin` as `learning_gcp_devops`.

### Task 1 — Find root-owned files modified in last 7 days

```bash
find /etc -user root -mtime -7
```

**Output (sample):**
/etc
/etc/ld.so.cache
/etc/systemd/system
/etc/netplan/50-cloud-init.yaml
/etc/hostname
find: '/etc/ssl/private': Permission denied

**Key learning:** `Permission denied` on some directories is normal — sensitive dirs like
`/etc/ssl/private` and `/etc/sudoers.d` are locked to root only.
On Windows this is equivalent to "Access Denied" on `C:\Windows\System32\config`.

---

### Task 2 — Check SSH service status

```bash
systemctl status ssh
```

**Findings:**
- Service: `active (running)` ✅
- Auto-start: `enabled` ✅
- Real brute force attempts spotted in logs from multiple external IPs

**Key learning:** SSH logs show live attack attempts on every public IP.
Server is protected by SSH key authentication — password attempts are useless.

---

### Task 3 — Find Docker process

```bash
ps aux | grep docker
```

**Output:**
root  594  0.0  2.1  ...  /usr/bin/dockerd

**Key learning:** Docker daemon runs as root with PID 594.
The grep command itself also appears in the process list — this is normal, ignore it.

---

### Task 4 — Last 20 lines of syslog filtered for kernel

```bash
tail /var/log/syslog -n 20 | grep -i kernel
```

**Output:** No output — no kernel messages in the last 20 lines.

**Key learning:** No output from grep is a valid result — it means nothing matched.
Always verify by running without the filter first to confirm the command worked.
Last 20 lines contained GCP agent activity — OSConfigAgent, gce_workload_cert_refresh, CRON.

---

### Task 5 — Check disk space

```bash
df -h
```

**Output:**
Filesystem      Size  Used Avail Use% Mounted on
/dev/root        29G  7.4G   22G  26% /

**Key learning:** Production disk health thresholds:

| Use% | Status |
|------|--------|
| Below 70% | ✅ Healthy |
| 70% — 85% | ⚠️ Watch it |
| Above 85% | 🔴 Investigate immediately |
| 100% | 💀 Server starts failing |

At 26% the server is healthy with plenty of room for upcoming labs.

---

## Part 3 — Mini Incident Scenario

### Ticket
INCIDENT TICKET — INC-0042
Priority  : P2 — High
Assigned  : Murali
Title: boa-devops-admin — Suspicious behaviour reported
Findings to investigate:

Unknown process consuming high memory
Unauthorised SSH access attempts
Critical file in /etc modified in last 24 hours


---

### Finding 1 — High Memory Process

**Command used:**
```bash
top
```

**Investigation:**

| PID | Process | User | %MEM | Verdict |
|-----|---------|------|------|---------|
| 1243 | node | learning_gcp_devops | 14.0% | ✅ VS Code Remote SSH server |
| 739 | otelopscol | root | 2.7% | ✅ GCP OpenTelemetry monitoring agent |
| 1215 | node | learning_gcp_devops | 2.5% | ✅ VS Code helper process |

**Verdict:** No suspicious processes. All high memory consumers are legitimate.
Total memory usage healthy — 1GB used of 3.9GB total.

---

### Finding 2 — Unauthorised SSH Access

**Command used:**
```bash
sudo grep "Invalid user\|Failed\|Accepted" /var/log/auth.log | tail -20
```

**Investigation:**

Multiple brute force attempts from external IPs:

| Username Tried | Source IP | Verdict |
|---------------|-----------|---------|
| `solv` (10+ attempts) | 80.94.92.184 | 🔴 Automated brute force bot |
| `admin` | 45.148.10.121 | 🔴 Common username attack |
| `admin` | 185.156.73.233 | 🔴 Different IP, same attack |
| `user`, `username` | 80.94.95.115 | 🔴 Generic username attempt |
| `support` | 87.251.64.149 | 🔴 Service account name attempt |
| `ai` | 43.155.24.42 | 🔴 Trying trendy usernames |

Only successful login:
Accepted publickey for learning_gcp_devops from 49.43.250.172

**Verdict:** Brute force attacks confirmed from 6+ IPs. All attempts failed.
Server secure — SSH key authentication enforced, no password logins possible.

---

### Finding 3 — Modified File in /etc

**Command used:**
```bash
find /etc -user root -mtime -1
sudo cat /etc/netplan/50-cloud-init.yaml
```

**File found:** `/etc/netplan/50-cloud-init.yaml`

**Contents:**
```yaml
network:
  version: 2
  ethernets:
    ens4:
      match:
        macaddress: "42:01:0a:a0:00:0d"
      dhcp4: true
      dhcp6: true
      set-name: "ens4"
```

**Verdict:** Network config file touched by GCP cloud-init agent during boot.
Contents are normal — DHCP enabled, standard GCP VM network configuration.
No suspicious changes found.

---

### Incident INC-0042 — Final Report

| Finding | Investigation | Verdict |
|---------|--------------|---------|
| High memory process | `top` | ✅ No threat — VS Code + GCP agent |
| Unauthorised SSH access | `grep` on auth.log | ⚠️ Confirmed attempts, all blocked |
| Modified file in /etc | `find` + `cat` | ✅ No threat — GCP cloud-init |

**Overall verdict: Server is secure. No breach. No action required beyond monitoring.**

---

## Key Learnings

- File permissions follow owner/group/others — each block is always read/write/execute
- A dash `-` in a permission string means that permission is denied
- `systemctl enable` is the Linux equivalent of setting Startup Type to Automatic
- Always investigate connectivity in layers — network, ports, app response
- `$` prefix is mandatory to read a variable value in bash — without it bash treats it as plain text
- `tail -f` follows a log file live — the `-f` flag means follow
- `find` with `-mtime -N` means within the last N days — the minus sign is critical
- No output from `grep` is a valid result — it means nothing matched
- Every public IP gets brute force SSH attempts — SSH key auth makes them harmless
- `Permission denied` in find output is normal for sensitive system directories

---

## Command Reference

| Command | What it does |
|---------|-------------|
| `ls -la` | List files with permissions, owner, size |
| `chmod 755 file` | Set file permissions |
| `chown user:group file` | Change file owner |
| `systemctl status service` | Check if service is running |
| `systemctl enable service` | Auto-start service on reboot |
| `ping host` | Test network connectivity |
| `ss -tulnp` | Show open ports and listening services |
| `curl -i url` | HTTP request with response headers |
| `ps aux` | List all running processes |
| `top` | Live process and resource monitor |
| `find /path -user root -mtime -7` | Find files by owner and age |
| `grep -i pattern file` | Search file case-insensitively |
| `tail -f file` | Follow log file in real time |
| `tail -n 20 file` | Show last 20 lines of file |
| `df -h` | Disk space in human readable format |
| `journalctl -u service` | View systemd service logs |

---

## Production Notes

### GCP Professional Cloud Engineer
- GCP VMs run cloud-init on every boot — expect `/etc/netplan` and other config files to be touched
- OSConfigAgent enforces GCP OS policies — COMPLIANT state means your VM matches org policy
- OpenTelemetry collector (`otelopscol`) ships metrics to GCP Cloud Monitoring automatically
- Reserved external IPs in GCP are managed at VPC layer — not inside the VM's netplan config

### CKA / CKAD
- Linux permissions and process management are foundational for Kubernetes node troubleshooting
- `ps aux`, `top`, `df -h` are the same commands used when SSH-ing into a Kubernetes node
- SSH key authentication is the same model used for Kubernetes service accounts and kubeconfig

---

## Challenges — Answered

### Challenge 1
**Task:** Find all files in `/var` modified in the last 2 days owned by root.
```bash
find /var -user root -mtime -2
```

### Challenge 2
**Task:** Check if `docker` service is enabled and running.
```bash
systemctl status docker
```

### Challenge 3
**Task:** Show all processes running as root sorted by memory.
```bash
ps aux --sort=-%mem | grep root
```

### Challenge 4
**Task:** Watch `/var/log/syslog` live and filter for only `error` messages.
```bash
tail -f /var/log/syslog | grep -i error
```

### Challenge 5
**Task:** Check disk usage and identify if any filesystem is above 80%.
```bash
df -h | awk 'NR>1 {gsub("%","",$5); if($5+0 > 80) print $0}'
```

---

