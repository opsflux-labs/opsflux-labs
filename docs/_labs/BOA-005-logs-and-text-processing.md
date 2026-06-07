---
title: "BOA-005: Logs & Text Processing"
date: 2026-06-07
summary: "Learn to read, search, filter, and extract data from Linux logs using grep, tail, awk, cut, and journalctl — using real log files on boa-devops-admin."
difficulty: beginner
duration: "90 minutes"
description: "Linux log analysis for DevOps engineers — grep, tail, awk, cut, journalctl — investigated on a live GCP VM with real security events."
tags: [linux, logs, grep, awk, journalctl, text-processing, security]
---

## JIRA Ticket

**Ticket ID:** BOA-005
**Priority:** P2 — High
**Assigned To:** Murali (learning_gcp_devops)
**Environment:** boa-devops-admin (Ubuntu 22.04)
**Reported By:** Platform Team

**Summary:**
> *"We're getting complaints that the Bank of Anthos health check script is running fine, but nobody can read the output — it scrolls too fast, there's no filtering, and finding errors means reading every single line manually. On top of that, the app team wants log files shipped from the VM, but nobody knows where they are or how to read them."*

**Description:**
In production, logs are your primary debugging tool. When a pod crashes at 2 AM, you don't watch the logs — you search them. You grep for ERROR, you tail the last 50 lines, you cut the timestamp out of a wall of text. This lab teaches you those exact tools — the ones every DevOps/SRE engineer uses every single day.

**Acceptance Criteria:**
- [x] Read and navigate live and historical logs
- [x] Search logs with `grep`
- [x] Monitor logs in real-time with `tail -f`
- [x] Extract specific columns with `cut` and `awk`
- [x] Query system logs with `journalctl`
- [x] Parse health_script.sh output like a pro

---

## Windows → Linux Reference Table

| Windows Concept | Linux Equivalent | Notes |
|---|---|---|
| Event Viewer | `journalctl` | System logs, service logs |
| `findstr` in CMD | `grep` | Search text in files |
| `Get-Content -Tail 10` | `tail -n 10` | Last N lines of a file |
| `Get-Content -Wait` | `tail -f` | Follow file in real-time |
| Excel column split | `cut -d',' -f1` | Cut text by delimiter |
| Advanced filter in Excel | `awk` | Powerful column/pattern processor |
| `%TEMP%\app.log` | `/var/log/syslog` | Where logs live |
| Services Console log view | `journalctl -u servicename` | Per-service log view |

---

## Phase 1 — Where Do Logs Live on Linux?

Linux logs live in `/var/log/`. Think of it as your Event Viewer categories — except they are plain text files.

```bash
ls /var/log/
ls -lh /var/log/ | head -20
```

### Key Log Files on boa-devops-admin

| Log File | Windows Equivalent | What It Contains |
|---|---|---|
| `syslog` | System Event Log | General system activity |
| `auth.log` | Security Event Log | SSH logins, sudo, failed logins |
| `kern.log` | Hardware Events | Kernel messages |
| `dmesg` | Boot events | Hardware at boot time |
| `cloud-init.log` | Startup scripts log | GCP VM first-boot setup |
| `auth.log.1` | Archived logs | Yesterday's logs, rotated |
| `syslog.2.gz` | Compressed archive | Logs older than 2 days |
| `journal/` | Event Viewer database | Read with `journalctl` |
| `google-cloud-ops-agent/` | GCP agent logs | Cloud Monitoring agent |

**Log rotation** — Linux automatically compresses old logs to save disk space. `.1` = yesterday, `.2.gz` = older compressed.

---

## Phase 2 — Reading Logs with `tail`

`tail` is your most-used log command in production.

```bash
# Last 10 lines (default)
tail /var/log/syslog

# Last 30 lines
tail -n 30 /var/log/syslog

# Last 5 lines of security log
tail -n 5 /var/log/auth.log
```

### Syslog Line Format

```
Jun  7 15:00:26   boa-devops-admin   systemd[1]   Started PackageKit Daemon.
  ↑ timestamp        ↑ hostname        ↑ process      ↑ message
```

Same as Event Viewer columns — Date/Time, Source, Event ID, Description.

### What We Found in auth.log

```
Jun  7 14:55:56  sshd[1049]: session opened for user learning_gcp_devops
```
Your SSH login recorded automatically. In production, 50 lines of `Invalid user admin` here = brute-force attack in progress.

---

## Phase 3 — `grep`: Find the Needle in the Haystack

`grep` is `findstr` from Windows CMD — give it a pattern, it prints only matching lines.

```bash
# Find every login event
grep "session opened" /var/log/auth.log

# Search for error (lowercase only)
grep "error" /var/log/syslog

# Case-insensitive — always use this when hunting errors
grep -i "error" /var/log/syslog

# Find errors, show last 10 only
grep -i "error" /var/log/syslog | tail -n 10
```

### grep Flags Reference

| Flag | Meaning | Example |
|---|---|---|
| `-i` | Case-insensitive | `grep -i "error"` |
| `-c` | Count matching lines | `grep -c "error" file` |
| `-v` | Invert — exclude pattern | `grep -v "containerd"` |
| `-n` | Show line numbers | `grep -n "session"` |

### Real Production Pattern — Filter Noise

```bash
grep -i "ERROR" /var/log/syslog | grep -v "containerd" | grep -v "dockerd"
```

First find all errors, then strip known-good noise. What remains needs attention.

### Important Finding on boa-devops-admin

```
ERROR non_windows_accounts.go:219 invalid ssh key entry - expired key
expireOn":"2026-06-02T17:31:09+0000"
```

Two GCP SSH keys expired on June 2nd. Found by reading real logs with `grep`.

---

## Phase 4 — `cut` and `awk`: Extracting Columns

### `cut` — Split by delimiter

`cut` is like Excel Text to Columns — split by a character, take specific fields.

```bash
# Fields 1,2,3 = date and time
tail -n 20 /var/log/auth.log | cut -d' ' -f1,2,3

# Field 5 = hostname
tail -n 20 /var/log/auth.log | cut -d' ' -f5
```

**Warning:** `cut` is dumb about multiple spaces — it counts every space as a separate field. If your log has `Jun  7` (two spaces), `cut -f1,2,3` will only give you `Jun  7` because the empty field between them counts.

### `awk` — Smarter Column Extraction

`awk` treats any amount of whitespace as one separator — much better for log files.

```bash
# First three fields
tail -n 20 /var/log/syslog | awk '{print $1, $2, $3}'

# Date + username from auth.log session lines
grep "session opened" /var/log/auth.log | awk '{print $1, $2, $3, $11}'
```

**Rule:** For log files, prefer `awk` over `cut`. Use `cut` only when delimiter is consistent (CSV with commas).

### `$NF` — Always Get the Last Field

```bash
grep "WARN\|ERROR\|OK" ~/scripts/health.log | awk '{print $1, $2, $NF}'
```

`$NF` = last field on the line, regardless of how many columns there are.

---

## Phase 5 — Security Audit with grep + awk + sort + uniq

```bash
grep "session opened" /var/log/auth.log | awk '{print $11}' | sort | uniq -c
```

**Output on boa-devops-admin:**
```
2 learning_gcp_devops(uid=1001)
12 root(uid=0)
```

`sort` alphabetically sorts. `uniq -c` counts consecutive duplicates. Together: who logged in and how many times. Real security audit command.

---

## Phase 6 — `journalctl`: Linux Event Viewer

`journalctl` reads from `/var/log/journal/` — structured, filterable, faster than raw log files.

```bash
# Last 20 entries across all services
journalctl -n 20

# SSH service only
journalctl -u ssh -n 20

# Last hour
journalctl --since "1 hour ago"

# Errors only
journalctl -p err -n 20

# Today's errors only
journalctl -p err --since "2026-06-07 00:00:00"
```

### journalctl Flags Reference

| Flag | Meaning |
|---|---|
| `-n 20` | Last 20 lines |
| `-u ssh` | Filter by service unit |
| `--since "1 hour ago"` | Time-based filter |
| `-p err` | Priority: error and above |
| `--since "YYYY-MM-DD"` | From specific date |

---

## Phase 7 — `tail -f`: Live Log Monitoring

`tail -f` keeps the file open and streams new lines in real time — like Event Viewer with auto-refresh.

```bash
# Terminal 1 — watch live
sudo tail -f /var/log/auth.log

# Terminal 2 — trigger an event
sudo ls /root
```

The moment the sudo command runs in Terminal 2, Terminal 1 shows:
```
sudo: learning_gcp_devops : TTY=pts/0 ; COMMAND=/usr/bin/ls /root
sudo: pam_unix(sudo:session): session opened for user root
```

Linux records the exact command, path, and user. Full audit trail.

---

## Phase 8 — Connecting to health_script.sh

```bash
# Append health check output to log file
health_script.sh >> ~/scripts/health.log 2>&1
```

`>>` = append (not overwrite). `2>&1` = capture errors into the same file.

```bash
# Search health log
grep "DOWN" ~/scripts/health.log | wc -l
grep "Run Time" ~/scripts/health.log | awk '{print $4, $5}'
grep "DOWN" ~/scripts/health.log | awk '{print $2}'
```

---

## Root Cause

The Platform Team could not search or filter health check output because it was only being printed to screen — never written to a file. Log files did not exist for the health script. Additionally, the team did not know which system log files to check for service and security events on Linux.

---

## Fix

1. Redirect `health_script.sh` output to `~/scripts/health.log` using `>>` and `2>&1`
2. Use `grep`, `awk`, and `wc -l` to search and report from the log
3. Use `journalctl -p err` and `auth.log` for system and security investigation
4. Added `~/.bashrc` PATH export to persist `~/scripts` across reboots

---

## Result

- Health check output now captured to persistent log file
- nginx DOWN events confirmed: 3 occurrences
- Real brute-force attack discovered and confirmed blocked: 93 attempts from 103.85.66.217
- Today's system errors: 5 — all non-critical boot-time events
- Live log monitoring confirmed working with `tail -f`

---

## Key Learnings

- `/var/log/` is Linux's Event Viewer — `syslog`, `auth.log`, `kern.log` are the main files
- `tail -n 20` shows last N lines; `tail -f` follows a file live in real time
- `grep -i` is case-insensitive; always use it when hunting errors
- `grep -v` excludes patterns — use it to filter known-good noise
- `grep | grep -v | grep -v` chains filters to isolate real problems
- `awk` handles multiple spaces in log files better than `cut`
- `$NF` in awk always gives the last field — useful when column count varies
- `grep | awk | sort | uniq -c` is the standard security audit pipeline
- `journalctl -p err --since` is faster than grepping raw files for errors
- `>>` appends to a file; `>` overwrites — always use `>>` for log files
- `2>&1` captures stderr (error output) into the same file as stdout
- `~/.bashrc` is the permanent home for PATH exports — survives reboots
- Every public-facing server on the internet receives automated SSH attacks — key-based auth stops them all

---

## Command Reference Table

| Command | What It Does | Windows Equivalent |
|---|---|---|
| `tail -n 20 file` | Last 20 lines | `Get-Content -Tail 20` |
| `tail -f file` | Follow file live | Event Viewer auto-refresh |
| `grep "pattern" file` | Find matching lines | `findstr` |
| `grep -i "pattern"` | Case-insensitive search | `findstr /i` |
| `grep -c "pattern"` | Count matches | `(Select-String).Count` |
| `grep -v "pattern"` | Exclude matches | `findstr /v` |
| `grep -n "pattern"` | Show line numbers | — |
| `awk '{print $1,$2}'` | Extract columns | Excel Text to Columns |
| `awk '{print $NF}'` | Last field on line | — |
| `cut -d' ' -f1,2` | Split by delimiter | — |
| `sort` | Sort lines alphabetically | Excel Sort |
| `uniq -c` | Count unique values | Excel COUNTIF |
| `wc -l` | Count lines | `Measure-Object -Line` |
| `journalctl -n 20` | Last 20 journal entries | Event Viewer |
| `journalctl -u ssh` | Filter by service | Event Viewer filter by Source |
| `journalctl -p err` | Errors only | Event Viewer filter by Level |
| `journalctl --since` | Time-based filter | Event Viewer date filter |
| `cmd >> file 2>&1` | Append output + errors to file | Redirect operator |

---

## Production Notes

### GCP Professional Cloud Engineer Refresh

- GCP VMs write boot and agent logs to `/var/log/cloud-init.log` and `google-cloud-ops-agent/`
- The Google Guest Agent manages SSH key injection from GCP metadata — expired keys show as ERROR in syslog
- Cloud Logging (formerly Stackdriver) aggregates these same logs at the project level — `journalctl` is the local equivalent
- `gcloud logging read` is the Cloud Logging equivalent of `journalctl` for GCP-wide log queries

### CKA/CKAD Refresh

- In Kubernetes, `kubectl logs podname` is the equivalent of `tail` on a log file
- `kubectl logs -f podname` = `tail -f` — follows pod logs live
- `kubectl logs podname | grep ERROR` = same grep pipeline you used today
- Pod logs stream from container stdout/stderr — same `2>&1` concept applies
- `kubectl logs --previous podname` = reading the previous crashed container's logs — equivalent of `auth.log.1`

---

## Challenges

### Challenge 1 — Brute Force Investigation ✓

**Task:** How many SSH attack attempts came from IP `103.85.66.217`?

```bash
journalctl -u ssh | grep "103.85.66.217" | wc -l
```

**Answer:** 93 attempts. Usernames tried: root, admin, oracle, usuario, test, user, ftpuser, test1, test2, ubuntu, pi, baikal. All blocked — key-based auth only.

---

### Challenge 2 — Service Down Report ✓

**Task:** How many times was nginx DOWN and at what times?

```bash
grep "DOWN" ~/scripts/health.log | wc -l
grep "Run Time" ~/scripts/health.log | awk '{print $4, $5}'
```

**Answer:** 3 times. All checks ran at 15:56:47 on 2026-06-07.

---

### Challenge 3 — Auth Log Audit ✓

**Task:** List every unique user that opened a session today with a count.

```bash
grep "session opened" /var/log/auth.log | awk '{print $11}' | sort | uniq -c
```

**Answer:**
```
2 learning_gcp_devops(uid=1001)
12 root(uid=0)
```

---

### Challenge 4 — Live Monitor ✓

**Task:** Watch health log update live while running health check in a second terminal.

```bash
# Terminal 1
tail -f ~/scripts/health.log

# Terminal 2
health_script.sh >> ~/scripts/health.log 2>&1
```

**Answer:** Full health check output streamed live into Terminal 1 at 16:34:54 and 16:34:57.

---

### Challenge 5 — Real Error Hunt ✓

**Task:** Show all error-level entries from today only using journalctl.

```bash
journalctl -p err --since "2026-06-07 00:00:00"
```

**Answer:** 5 entries — 4 dhclient Permission Denied at boot (normal GCP networking), 1 SSH connection dropped mid-handshake. No critical errors.