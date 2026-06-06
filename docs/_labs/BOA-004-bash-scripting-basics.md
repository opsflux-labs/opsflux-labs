---
layout: lab
title: "BOA-004: Bash Scripting Basics"
lab_id: BOA-004
topic: Bash Scripting Basics
order: 4
difficulty: beginner
description: "Write your first automation script — variables, loops, if/else, and functions to build a real service health checker for Bank of Anthos."
tags: [linux, bash, scripting, automation, devops-foundation]
---

# BOA-004 — Bash Scripting Basics

---

## JIRA Ticket

| Field       | Detail                                           |
|-------------|--------------------------------------------------|
| Ticket ID   | BOA-004                                          |
| Priority    | Medium                                           |
| Assigned To | Murali (learning_gcp_devops)                     |
| Labels      | Linux, Bash, Scripting, Automation               |
| Title       | Write a Health Check Script for Bank of Anthos   |

**Description:**
The on-call team currently checks each Bank of Anthos service manually
every time there is an alert. This is slow, inconsistent, and error-prone.
Write a Bash script that automatically checks whether critical services
are running on the boa-devops-admin VM and reports their status clearly.

**Acceptance Criteria:**
- Script uses variables, loops, and if/else logic
- Script checks at least 3 services and reports UP or DOWN
- Script is executable and runs without errors
- Lab documented and pushed to labs.opsflux.in

---

## Windows → Linux Reference Table

| Concept              | Windows                        | Linux / Bash                        |
|----------------------|-------------------------------|-------------------------------------|
| Variable assignment  | `$name = "value"`             | `name="value"`                      |
| Variable reading     | `$name`                       | `$name`                             |
| If/else block        | `if ($x -eq "y") { } else {}` | `if [ "$x" = "y" ]; then ... fi`    |
| Loop                 | `foreach ($x in $list) { }`   | `for x in $list; do ... done`       |
| Function             | `function Check-Service { }`  | `check_service() { }`               |
| Run script           | `.\script.ps1`                | `./script.sh`                       |
| System PATH          | `$env:PATH`                   | `$PATH`                             |
| Add to PATH          | Edit Environment Variables    | `export PATH=$PATH:/your/folder`    |
| Check service status | `Get-Service nginx`           | `systemctl is-active nginx`         |

---

## Phase 1 — Variables

Variables store values for reuse across your script.

```bash
greeting="Hello Murali"
echo $greeting

vm_name="boa-devops-admin"
echo "Checking health of: $vm_name"

service="docker"
echo "Service to check: $service"
```

**Expected Output:**
Hello Murali
Checking health of: boa-devops-admin
Service to check: docker

**Key Rules:**
- No spaces around `=` when assigning
- Use `$` when reading a variable, not when setting it
- Double quotes allow variable expansion — single quotes do not
- `%variable%` in Windows batch becomes `$variable` in Bash

---

## Phase 2 — if/else

if/else makes decisions based on a value or condition.

```bash
status="running"
if [ "$status" = "running" ]; then
  echo "Service is UP"
else
  echo "Service is DOWN"
fi
```

**Expected Output:**
Service is UP

**Common Mistakes:**
- `["$status"` — missing space after `[` causes syntax error
- `:` instead of `;` before `then` causes syntax error
- Always close the block with `fi`

---

## Phase 3 — Loops

Loops repeat logic for every item in a list.

```bash
for service in docker ssh cron; do
  if systemctl is-active --quiet $service; then
    echo "$service is UP"
  else
    echo "$service is DOWN"
  fi
done
```

**Expected Output:**
docker is UP
ssh is UP
cron is UP

`--quiet` suppresses systemctl's own output so your script controls
what gets printed.

---

## Phase 4 — Functions

Functions wrap reusable logic into a named block.

```bash
check_service() {
  if systemctl is-active --quiet $1; then
    echo "$1 is UP"
  else
    echo "$1 is DOWN"
  fi
}

check_service docker
check_service ssh
check_service cron
```

`$1` is the first argument passed to the function — same as a parameter
in PowerShell.

---

## Phase 5 — The Health Check Script

Full script saved at `~/scripts/health_script.sh`:

```bash
#!/bin/bash

# =============================================
# Bank of Anthos — Service Health Check Script
# Author  : Murali
# VM      : boa-devops-admin
# Purpose : Check if critical services are UP
# =============================================

SERVICES="docker ssh cron nginx"
VM_NAME="boa-devops-admin"
DATE=$(date "+%Y-%m-%d %H:%M:%S")
COUNT=0

echo "======================================"
echo " Health Check — $VM_NAME"
echo " Run time : $DATE"
echo "======================================"

check_service() {
  if systemctl is-active --quiet $1; then
    echo "  [UP]    $1"
  else
    echo "  [DOWN] $1"
    echo "           ACTION REQUIRED : Start the service"
  fi
}

echo ""
echo "Checking services..."
echo ""

for service in $SERVICES; do
  check_service $service
  COUNT=$((COUNT + 1))
done

echo ""
echo "======================================"
echo " Check complete."
echo " Services Checked : $COUNT"
echo "======================================"
```

---

## Phase 6 — Make It Executable and Run It

```bash
chmod +x health_script.sh
./health_script.sh
```

**Expected Output:**
======================================
Health check - boa-devops-admin
Run Time : 2026-06-06 09:25:40
Checking services...
[UP]    docker
[UP]    ssh
[UP]    cron
[DOWN] nginx
ACTION REQUIRED : Start the service
Check complete.
Services Checked : 4

---

## Root Cause

Manual service checks are slow and inconsistent. A Bash script using
variables, loops, if/else, and functions automates this reliably and
produces consistent output every run.

---

## Fix

Wrote `health_script.sh` with:
- Variables for VM name, date, and service list
- A `check_service()` function using `systemctl is-active --quiet`
- A loop to check all services automatically
- A counter to track total services checked
- ACTION REQUIRED message for any DOWN service

---

## Result

Script runs from any directory on the VM. All services checked in under
one second. Output is consistent and actionable for on-call engineers.

---

## Key Learnings

- Variables in Bash use `$` not `%` — no spaces around `=` on assignment
- `if [ ]` requires spaces inside brackets — missing spaces cause syntax errors
- Loops iterate only over what is in the list — silent omission is a real risk
- `$1` inside a function refers to the first argument passed to it
- `--quiet` on systemctl suppresses its output so your script controls printing
- `chmod +x` is required before any script can be executed
- `export PATH=$PATH:/your/folder` makes scripts runnable from anywhere
- PATH holds folders, not file paths — the folder is registered, not the file
- `DATE=$(date "+%Y-%m-%d %H:%M:%S")` — the `+` is required for format strings
- Counter placement matters — inside the loop means every iteration is counted

---

## Command Reference Table

| Command | What It Does |
|---------|-------------|
| `name="value"` | Assign a variable |
| `echo $name` | Print a variable |
| `if [ "$x" = "y" ]; then` | Start an if block |
| `fi` | Close an if block |
| `for x in list; do` | Start a loop |
| `done` | Close a loop |
| `function_name() { }` | Define a function |
| `$1` | First argument to a function |
| `chmod +x script.sh` | Make script executable |
| `./script.sh` | Run script from current directory |
| `export PATH=$PATH:/folder` | Add folder to PATH |
| `echo $PATH` | Show current PATH |
| `systemctl is-active --quiet svc` | Check if service is active silently |
| `COUNT=$((COUNT + 1))` | Increment a counter |
| `date "+%Y-%m-%d %H:%M:%S"` | Print formatted date and time |

---

## Production Notes

**GCP Professional Cloud Engineer Refresh:**
- GCP startup scripts use Bash — same variables, loops, and functions
- Cloud Monitoring agents are configured via shell scripts on GCE VMs
- Bash health checks are used in GCE instance templates for auto-healing

**CKA / CKAD Refresh:**
- Kubernetes liveness and readiness probes can execute shell scripts
- Init containers use shell scripts to check dependencies before app starts
- `kubectl exec` drops you into a container shell — Bash skills apply directly

---

## Challenges

**Challenge 1 — New Service**
Add nginx to the health check script. Run it. What does it show and why?

Your answer: nginx showed DOWN because it is not installed on boa-devops-admin.
The script checked correctly and reported honestly.

**Challenge 2 — Action Message**
Add an ACTION REQUIRED message that only appears when a service is DOWN.

Your answer: Added a second echo inside the else branch of check_service().
UP services show no extra message. Only DOWN services trigger the action line.

**Challenge 3 — Silent Omission**
Remove cron from the SERVICES variable and run the script. What happened?

Your answer: Cron disappeared from the output entirely with no error or warning.
The loop only checks what is in the list — removing a service silently skips it.
This is a real production risk if services are accidentally removed from the list.

**Challenge 4 — Counter**
Add a counter that prints total services checked at the end of the run.

Your answer: Set COUNT=0 before the loop. Added COUNT=$((COUNT + 1)) inside
the loop after check_service. Printed the count after the loop closes.
Output showed: Services Checked : 4

**Challenge 5 — PATH**
Make the script runnable from any directory without ./ or full path.

Your answer: Added the scripts folder to PATH using:
export PATH=$PATH:/home/learning_gcp_devops/scripts
Ran health_script.sh from /tmp successfully — Bash found it via PATH.
PATH holds the folder, not the file — every executable in that folder
becomes available system-wide.