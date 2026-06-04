---
title: "BOA-002: Processes, Services & systemd"
date: 2026-06-04
summary: "Investigate running processes, manage services with systemctl, kill processes, read logs with journalctl — Day 2 on boa-devops-admin"
difficulty: beginner
duration: 2 hours
tags:
  - linux
  - processes
  - systemd
  - foundation
---

# BOA-002 — Processes, Services & systemd

**File:** `BOA-002-processes-services-systemd.md`
**Location:** `~/opsflux-labs/docs/_labs/`
**Published:** `labs.opsflux.in`

---

## 🎫 JIRA-STYLE TICKET

| Field | Value |
|-------|-------|
| **Ticket ID** | OPS-002 |
| **Priority** | High |
| **Assigned To** | Murali |
| **Environment** | boa-devops-admin — Ubuntu 22.04 |
| **Labels** | linux, processes, systemd, operations, day-2 |
| **Sprint** | Month 1 — Phase 1: Linux for DevOps |

### Ticket Description

> **[OPS-002] Bank of Anthos — Process & Service Investigation**
>
> The Bank of Anthos application has been flagged as "possibly running" on the ops VM `boa-devops-admin`.
> Before we deploy it to GKE, we need to understand how to inspect what is running on a Linux machine,
> how to manage services using `systemd`, and how to stop/start/kill processes safely.
>
> As the operations engineer, you must be able to answer:
> - What processes are currently running on this machine?
> - Is the Docker service healthy?
> - How do I restart a service if it crashes?
> - How do I kill a runaway process?
> - How do I investigate a service that won't start?
>
> Complete all investigation phases on `boa-devops-admin`.
> Document findings and push lab to GitHub on completion.

**Acceptance Criteria:**
- [ ] Can list all running processes
- [ ] Can identify CPU/memory hogs
- [ ] Can check Docker service status via systemd
- [ ] Can stop, start, restart a service
- [ ] Can kill a process by PID and by name
- [ ] Can read service logs via journalctl
- [ ] Lab pushed to GitHub and live on labs.opsflux.in

---

## 🪟 Windows → Linux Reference Table

> You already know all of these things — they just have different names in Linux.

| What You Want To Do | Windows Tool | Linux Equivalent |
|---|---|---|
| See all running processes | Task Manager → Processes | `ps aux` or `top` |
| Real-time CPU/memory view | Task Manager → Performance | `top` or `htop` |
| Check if a service is running | `services.msc` | `systemctl status <service>` |
| Start a service | Right-click → Start | `sudo systemctl start <service>` |
| Stop a service | Right-click → Stop | `sudo systemctl stop <service>` |
| Restart a service | Right-click → Restart | `sudo systemctl restart <service>` |
| Enable service on boot | Right-click → Properties → Startup | `sudo systemctl enable <service>` |
| Kill a process by name | Task Manager → End Task | `pkill <process-name>` |
| Kill a process by ID | Task Manager → End Task (PID) | `kill <PID>` or `kill -9 <PID>` |
| View service event log | Event Viewer → System | `journalctl -u <service>` |
| View all system logs | Event Viewer | `journalctl` |
| Check what's using a port | `netstat -ano` | `ss -tlnp` or `netstat -tlnp` |
| Find a process by name | Task Manager search | `pgrep <name>` or `ps aux | grep <name>` |

---

## 🔬 INVESTIGATION PHASES

---

### Phase 1 — What Is Running Right Now? (`ps`)

> **Goal:** See all processes on the machine — like opening Task Manager for the first time.

#### 1.1 — See your own running processes

```bash
ps
```

**What this does:**
`ps` stands for **Process Status**. Without any flags, it only shows processes started by *you* in *this terminal session*. Think of it as Task Manager filtered to your own user.

**Expected Output:**
```
  PID TTY          TIME CMD
 4521 pts/0    00:00:00 bash
 4598 pts/0    00:00:00 ps
```

**What to look for:**
- `PID` — Process ID. Every process gets a unique number. This is like the PID column in Windows Task Manager.
- `TTY` — Which terminal this process is tied to.
- `CMD` — The command that started this process.

---

#### 1.2 — See ALL processes from ALL users

```bash
ps aux
```

**What this does:**
- `a` — Show processes from **all users** (not just yours)
- `u` — Show in **user-friendly format** (username, CPU%, MEM%)
- `x` — Show processes **not attached to a terminal** (background services, daemons)

Together: `aux` = show me everything on this machine.

**Expected Output (partial):**
```
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.1 167468 11832 ?        Ss   Jun01   0:04 /sbin/init
root         456  0.0  0.2 234816 18000 ?        Ss   Jun01   0:01 /lib/systemd/systemd-journald
learning+   4521  0.0  0.0  10076  5200 pts/0    Ss   10:00   0:00 bash
```

**What to look for:**
- `USER` — Who owns this process? `root` = system-level. Your username = you started it.
- `%CPU` — How much CPU is this process using? Anything consistently above 80% is suspicious.
- `%MEM` — Memory usage. High values could mean a memory leak.
- `STAT` — Process state. `S` = sleeping (idle), `R` = running, `Z` = zombie (broken), `D` = waiting on disk.
- `COMMAND` — What actually started this process.

---

#### 1.3 — Find a specific process by name

```bash
ps aux | grep docker
```

**What this does:**
This is a **pipeline** — two commands joined by `|` (pipe character).
1. `ps aux` — generates the list of all processes
2. `|` — passes that output to the next command
3. `grep docker` — filters for lines containing the word "docker"

In Windows terms: this is like Task Manager with a search filter applied.

**Expected Output:**
```
root       856  0.1  1.2 1234560 98304 ?       Ssl  Jun01   0:45 /usr/bin/dockerd
learning+ 4612  0.0  0.0   6432   720 pts/0    S+   10:05   0:00 grep --color=auto docker
```

**What to look for:**
- The first line is the real Docker daemon process (started by `root`).
- The second line is your `grep` command itself — ignore it.
- If Docker is not running, you won't see the first line at all.

---

### Phase 2 — Real-Time Process Monitoring (`top`)

> **Goal:** Watch the machine live — like the Performance tab in Task Manager.

#### 2.1 — Launch top

```bash
top
```

**What this does:**
`top` opens a **live, updating view** of all running processes, sorted by CPU usage by default. It refreshes every 3 seconds.

**Expected Output:**
```
top - 10:15:32 up 3 days,  2:14,  1 user,  load average: 0.12, 0.08, 0.06
Tasks: 112 total,   1 running, 111 sleeping,   0 stopped,   0 zombie
%Cpu(s):  1.2 us,  0.4 sy,  0.0 ni, 98.2 id,  0.1 wa,  0.0 hi,  0.1 si
MiB Mem :   3900.0 total,   1200.4 free,   1450.2 used,   1249.4 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   2200.0 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
  856 root      20   0 1234560  98304  12800 S   2.3   2.5   0:45.12 dockerd
  457 root      20   0  234816  18000   7200 S   0.3   0.5   0:01.44 journald
```

**What to look for:**
| Line | What It Tells You |
|---|---|
| `load average: 0.12, 0.08, 0.06` | System load over last 1, 5, 15 minutes. Below 1.0 on a single-core machine = healthy. |
| `Tasks: 112 total, 0 zombie` | Zombie processes = broken processes that didn't exit cleanly. Any zombies = investigate. |
| `%Cpu(s): 98.2 id` | `id` = idle. High idle = machine is relaxed. Low idle = machine is busy. |
| `MiB Mem: used vs free` | If used is close to total, memory pressure could cause crashes. |

**Keyboard shortcuts inside top:**
| Key | Action |
|---|---|
| `q` | Quit top |
| `M` | Sort by memory usage |
| `P` | Sort by CPU usage (default) |
| `k` | Kill a process (prompts for PID) |
| `1` | Toggle per-CPU view |

> **Press `q` now to exit top before continuing.**

---

#### 2.2 — Check if htop is installed (friendlier version of top)

```bash
which htop
```

**What this does:**
`which` tells you if a command exists on your system and where it is installed. Similar to checking `C:\Program Files` for an installed program.

**Expected Output (if installed):**
```
/usr/bin/htop
```

**Expected Output (if not installed):**
```
(empty — no output)
```

If htop is installed, run it:
```bash
htop
```

htop shows the same information as top but with colour-coded bars for CPU and memory per core, and supports mouse clicks. Press `F10` or `q` to exit.

---

### Phase 3 — systemd and Service Management (`systemctl`)

> **Goal:** Learn to manage Linux services — your equivalent of services.msc in Windows.

**Background:**
In Windows, services are managed by the Service Control Manager (`services.msc`).
In modern Ubuntu Linux, services are managed by **systemd** — the system and service manager.
The command you use to talk to systemd is `systemctl` (system control).

Every application that runs in the background on Linux is typically a **systemd service** — including Docker, SSH, networking, and later your monitoring stack (Prometheus, Grafana, Loki).

---

#### 3.1 — Check Docker service status

```bash
sudo systemctl status docker
```

**What this does:**
- `sudo` — Run as superuser (administrator). Some systemctl operations require elevated privileges.
- `systemctl` — The command to manage systemd services.
- `status` — Show the current state of the service.
- `docker` — The name of the service to inspect.

**Expected Output:**
```
● docker.service - Docker Application Container Engine
     Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2025-06-02 08:00:15 UTC; 2 days ago
       Docs: https://docs.docker.com
   Main PID: 856 (dockerd)
      Tasks: 18
     Memory: 96.8M
        CPU: 45.123s
     CGroup: /system.slice/docker.service
             └─856 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock

Jun 02 08:00:15 boa-devops-admin dockerd[856]: time="2025-06-02T08:00:15Z" level=info msg="Docker daemon"
```

**What to look for:**
| Field | Meaning |
|---|---|
| `Active: active (running)` | ✅ Service is healthy and running |
| `Active: inactive (dead)` | ❌ Service is stopped |
| `Active: failed` | ❌ Service crashed — needs investigation |
| `Loaded: enabled` | Will auto-start on boot (like "Automatic" in Windows services) |
| `Loaded: disabled` | Will NOT auto-start on boot (like "Manual" in Windows services) |
| `Main PID` | The process ID of the service — useful for deeper investigation |

> **Press `q` to exit the status view.**

---

#### 3.2 — Check SSH service status

```bash
sudo systemctl status ssh
```

**Why this matters:**
SSH is how you are connected to this VM right now. If SSH stops, you lose your connection.
This is the equivalent of checking Remote Desktop Services in Windows.

**Expected Output:**
```
● ssh.service - OpenBSD Secure Shell server
     Loaded: loaded (/lib/systemd/system/ssh.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2025-06-02 07:55:00 UTC; 2 days ago
```

---

#### 3.3 — List all running services

```bash
sudo systemctl list-units --type=service --state=running
```

**What this does:**
- `list-units` — Show all systemd units (services, timers, sockets, etc.)
- `--type=service` — Filter to services only
- `--state=running` — Only show currently running services

This is like opening `services.msc` and filtering to "Status: Running".

**Expected Output (partial):**
```
UNIT                        LOAD   ACTIVE SUB     DESCRIPTION
containerd.service          loaded active running containerd container runtime
cron.service                loaded active running Regular background program
docker.service              loaded active running Docker Application Container Engine
ssh.service                 loaded active running OpenBSD Secure Shell server
systemd-journald.service    loaded active running Journal Service
```

---

#### 3.4 — Stop a service

```bash
sudo systemctl stop docker
```

**What this does:**
Sends a stop signal to the Docker service — equivalent to right-clicking a service in `services.msc` and selecting Stop.

> ⚠️ This will stop Docker. Any running containers will be paused.

**Verify it stopped:**
```bash
sudo systemctl status docker
```

**Expected Output:**
```
● docker.service - Docker Application Container Engine
     Active: inactive (dead) since ...
```

---

#### 3.5 — Start the service again

```bash
sudo systemctl start docker
```

**Verify it started:**
```bash
sudo systemctl status docker
```

**Expected Output:**
```
● docker.service - Docker Application Container Engine
     Active: active (running) since ...
```

---

#### 3.6 — Restart a service (stop + start in one command)

```bash
sudo systemctl restart docker
```

**When to use restart vs stop+start:**
In production, you almost always use `restart`. It stops the service gracefully and starts it fresh. Equivalent to right-click → Restart in `services.msc`.

You would use `stop` followed by `start` only when you need to make configuration changes between the two steps.

---

#### 3.7 — Enable and disable service auto-start

Check if Docker is enabled to start on boot:
```bash
sudo systemctl is-enabled docker
```

**Expected Output:**
```
enabled
```

Disable it (just to test — we will re-enable it immediately):
```bash
sudo systemctl disable docker
```

Re-enable it:
```bash
sudo systemctl enable docker
```

**What this does:**
- `enable` = Create a symlink so systemd starts this service automatically when the VM boots. Equivalent to setting startup type to "Automatic" in Windows.
- `disable` = Remove that symlink. Equivalent to "Manual" in Windows.

> ⚠️ `enable`/`disable` does NOT start or stop the service right now. It only controls boot behaviour.
> To change both immediately: `sudo systemctl enable --now docker`

---

### Phase 4 — Killing Processes

> **Goal:** Learn to stop runaway processes — like "End Task" in Windows Task Manager, but more powerful.

**Why this matters in DevOps:**
Sometimes a process hangs, uses 100% CPU, or refuses to respond. You need to kill it cleanly or forcefully.

---

#### 4.1 — Find the PID of a process

```bash
pgrep -l docker
```

**What this does:**
- `pgrep` — Search for processes by name and return their PID
- `-l` — Also show the process name alongside the PID

**Expected Output:**
```
856 dockerd
```

---

#### 4.2 — The kill command and signals

```bash
kill -l
```

**What this does:**
Lists all available kill signals. Don't worry about memorising all of them — you only ever use two in practice:

| Signal | Number | Meaning | Windows Equivalent |
|---|---|---|---|
| `SIGTERM` | 15 | "Please shut down cleanly" | End Task (graceful) |
| `SIGKILL` | 9 | "I don't care — die now" | End Task → End Process Tree |

**The golden rule:**
- Always try `kill <PID>` first (SIGTERM = graceful)
- Only use `kill -9 <PID>` if the process refuses to stop

---

#### 4.3 — Practice: Start a background sleep process and kill it

Start a process that does nothing for 120 seconds (perfect test target):
```bash
sleep 120 &
```

**What this does:**
- `sleep 120` — A command that does nothing for 120 seconds
- `&` — The ampersand sends the command to the background so you get your terminal back

**Expected Output:**
```
[1] 4721
```
The number `4721` is the PID of your sleep process.

Find its PID to confirm:
```bash
pgrep -l sleep
```

**Expected Output:**
```
4721 sleep
```

Kill it gracefully:
```bash
kill 4721
```

(Replace 4721 with your actual PID from above.)

Verify it's gone:
```bash
pgrep -l sleep
```

**Expected Output:**
```
(empty — process is gone)
```

---

#### 4.4 — Kill by name (pkill)

Start two sleep processes:
```bash
sleep 200 &
sleep 300 &
```

Kill all processes named "sleep" at once:
```bash
pkill sleep
```

**What this does:**
`pkill` kills by process name instead of PID — useful when you don't want to look up PIDs individually.

**Verify:**
```bash
pgrep -l sleep
```

**Expected Output:**
```
(empty)
```

---

### Phase 5 — Reading Service Logs (`journalctl`)

> **Goal:** Investigate service failures using logs — your equivalent of Event Viewer in Windows.

**Background:**
In Windows, you read system and service logs in **Event Viewer**.
In Linux with systemd, all service logs go to the **systemd journal**, read with `journalctl`.

When a Bank of Anthos service crashes in Kubernetes, you'll read pod logs. But on a VM level, when Docker itself or the OS-level services crash, `journalctl` is your first tool.

---

#### 5.1 — View logs for the Docker service

```bash
sudo journalctl -u docker
```

**What this does:**
- `journalctl` — The journal log reader
- `-u docker` — Filter logs to the `docker` service unit only

**Expected Output:**
```
Jun 02 08:00:12 boa-devops-admin systemd[1]: Starting Docker Application Container Engine...
Jun 02 08:00:15 boa-devops-admin dockerd[856]: time="..." level=info msg="Starting up"
Jun 02 08:00:15 boa-devops-admin systemd[1]: Started Docker Application Container Engine.
```

> Press `q` to exit.

---

#### 5.2 — View only the last 20 lines of logs

```bash
sudo journalctl -u docker -n 20
```

**What this does:**
- `-n 20` — Show only the last 20 log lines

In Windows terms: like filtering Event Viewer to show the last 20 entries.

---

#### 5.3 — Follow logs in real time

```bash
sudo journalctl -u docker -f
```

**What this does:**
- `-f` — Follow mode. New log lines appear on screen as they are written — exactly like `tail -f` from BOA-005.

This is your go-to command during an incident. Open this in one terminal, trigger the action in another terminal, and watch what happens.

> **Press `Ctrl + C` to stop following.**

---

#### 5.4 — View logs from the last hour only

```bash
sudo journalctl -u docker --since "1 hour ago"
```

**What this does:**
`--since` filters logs to a time window. Useful during incident investigation when you know roughly when something broke.

Other useful time formats:
```bash
sudo journalctl -u docker --since "2025-06-01 10:00:00"
sudo journalctl -u docker --since "30 minutes ago"
sudo journalctl -u docker --since today
```

---

#### 5.5 — View logs for ALL services (system-wide)

```bash
sudo journalctl -n 50
```

**What this does:**
Without `-u`, journalctl shows logs from every service on the machine. `-n 50` limits it to the last 50 lines.

This is your "Event Viewer → Windows Logs → System" equivalent — the first place you go when something is wrong and you don't know which service caused it.

---

### Phase 6 — Connecting It All: Docker Investigation Drill

> **Goal:** Simulate a real operations scenario — you receive an alert that Docker is "behaving oddly". Investigate it like a senior engineer would.

Work through this sequence independently. Each step builds on the previous one.

**Step 1:** Check if Docker is running.
```bash
sudo systemctl status docker
```

**Step 2:** Check how long Docker has been running and its PID.

> Look at the `Active:` line in the output. Note the PID from `Main PID:`.

**Step 3:** Find the Docker process in `ps aux` using that PID.
```bash
ps aux | grep <PID from above>
```

**Step 4:** Check the last 30 lines of Docker logs for any errors.
```bash
sudo journalctl -u docker -n 30
```

**Step 5:** Confirm Docker is enabled to survive a reboot.
```bash
sudo systemctl is-enabled docker
```

**Step 6:** Do a clean restart of Docker and verify it came back healthy.
```bash
sudo systemctl restart docker
sudo systemctl status docker
```

---

## 🔍 ROOT CAUSE (Conceptual)

On a production Linux server, the most common causes of service failures are:

| Symptom | Likely Cause | Investigation Tool |
|---|---|---|
| Service `Active: failed` | Crash on startup — usually misconfiguration or missing file | `journalctl -u <service> -n 50` |
| High CPU on a service | Runaway loop, memory leak, or spike in traffic | `top` then `ps aux` |
| Process won't kill with `kill <PID>` | Process is in uninterruptible sleep (`D` state) | `kill -9 <PID>` |
| Service stops after reboot | Service is not `enabled` | `systemctl enable <service>` |
| Container won't start | Docker daemon itself is down | `systemctl status docker` |

---

## ✅ FIX (Summary of Actions)

The standard operating procedure for any service issue:

```
1. systemctl status <service>     → Is it running? What's the PID?
2. journalctl -u <service> -n 50  → What did it log before failing?
3. ps aux | grep <service>        → Is the process actually alive?
4. systemctl restart <service>    → Attempt recovery
5. systemctl status <service>     → Confirm recovery
6. journalctl -u <service> -f     → Watch logs to confirm stability
```

This six-step pattern applies to Docker, Kubernetes node agents, Prometheus, Grafana, Nginx, and every other service you will manage in this training.

---

## 🏁 RESULT

After completing this lab, you can:
- List all running processes with `ps aux`
- Monitor live CPU/memory with `top`
- Check, start, stop, restart, enable, disable any systemd service
- Kill processes gracefully and forcefully
- Read service logs with `journalctl`
- Follow logs in real time during an incident

These are the exact skills used in every on-call incident response scenario.

---

## 💡 KEY LEARNINGS

- Every program running on Linux is a **process** with a unique **PID** (like Task Manager)
- `ps aux` = full process list; `top` = live view; both are your Task Manager
- **systemd** is the Linux service manager; `systemctl` is how you talk to it
- `systemctl status` is always your first command when investigating a service
- `kill <PID>` sends a polite shutdown request; `kill -9 <PID>` is the last resort
- `journalctl -u <service>` is your Event Viewer — always check this when a service fails
- `journalctl -f` is your real-time log stream — essential during live incidents
- `enable` ≠ `start` — enabling a service only affects boot behaviour, not right now
- The `&` symbol sends a command to the background, freeing your terminal
- Pipe `|` connects two commands — output of the first becomes input of the second

---

## 📋 COMMAND REFERENCE TABLE

| Command | What It Does | Windows Equivalent |
|---|---|---|
| `ps` | Show your own processes | Task Manager (filtered) |
| `ps aux` | Show ALL processes from ALL users | Task Manager → All processes |
| `ps aux \| grep <name>` | Find a specific process | Task Manager → Search |
| `top` | Live process monitor | Task Manager → Performance tab |
| `htop` | Friendlier live process monitor | Task Manager → Performance tab |
| `pgrep -l <name>` | Find PID by process name | — |
| `kill <PID>` | Graceful terminate (SIGTERM) | End Task |
| `kill -9 <PID>` | Force kill (SIGKILL) | End Process Tree |
| `pkill <name>` | Kill all processes by name | — |
| `sleep 120 &` | Run a command in background | — |
| `systemctl status <svc>` | Check service state | services.msc → Status |
| `systemctl start <svc>` | Start a service | Right-click → Start |
| `systemctl stop <svc>` | Stop a service | Right-click → Stop |
| `systemctl restart <svc>` | Restart a service | Right-click → Restart |
| `systemctl enable <svc>` | Auto-start on boot | Startup type: Automatic |
| `systemctl disable <svc>` | No auto-start on boot | Startup type: Manual |
| `systemctl is-enabled <svc>` | Check if auto-start is set | Properties → Startup type |
| `systemctl list-units --type=service --state=running` | List all running services | services.msc → filter Running |
| `journalctl -u <svc>` | Service logs | Event Viewer → filter by source |
| `journalctl -u <svc> -n 50` | Last 50 lines of service logs | Event Viewer → last 50 entries |
| `journalctl -u <svc> -f` | Follow logs live | — |
| `journalctl -u <svc> --since "1 hour ago"` | Logs from last hour | Event Viewer → filter by time |

---

## 🎓 PRODUCTION NOTES

### GCP Professional Cloud Engineer Refresh

**Compute Engine VM management** connects directly to what you learned today:
- When you SSH into a GCE VM and check services, you use `systemctl` exactly as above
- GCP's **Ops Agent** (formerly Stackdriver) is itself a systemd service: `sudo systemctl status google-cloud-ops-agent`
- GCP **VM health checks** monitor the state of services on your VMs — if a service fails, a health check can trigger auto-healing
- In GCP, `journalctl` logs can be forwarded to **Cloud Logging** via the Ops Agent — everything you see in `journalctl`, GCP can capture and alert on

### CKA / CKAD Cert Refresh

**Kubernetes connects directly to processes and services:**
- Each GKE worker **node** runs `kubelet` — a systemd service. If kubelet dies, the node goes `NotReady`
- Check it with: `sudo systemctl status kubelet`
- `containerd` is also a systemd service that Kubernetes uses instead of Docker in modern clusters
- When a Kubernetes **pod crashes**, you use `kubectl logs <pod>` — which is the pod-level equivalent of `journalctl -u <service>`
- CrashLoopBackOff (BOA-013) is essentially a pod process that keeps failing — the same pattern as `Active: failed` in systemd, investigated the same way

---

## 🏋️ CHALLENGES

> Attempt each challenge independently on `boa-devops-admin`.
> Refer back to the lab only if stuck after trying.
> Write your answer in the "Your answer:" space below each challenge.

---

**Challenge 1 — Service Audit**

You've just been handed access to a new production VM. List all currently running services on `boa-devops-admin`.
How many services are running? Which ones look critical to keep running?

```
ps aux
20 + services are running
Systemd, SSHD and Docker are important services to keep running
```

---

**Challenge 2 — Process Hunt**

A colleague says "there's a process called `containerd` running on the VM — is it healthy?"
Find the process using `ps aux`, get its PID, then confirm the service status using `systemctl`.

```
ps aux | grep containerd
root         452  0.1  0.8 1793620 34220 ?       Ssl  18:05   0:07 /usr/bin/containerd
systemctl status containerd 
Loaded: loaded (/lib/systemd/system/containerd.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2026-06-04 18:05:19 UTC; 1h 15min ago
       Docs: https://containerd.io
   Main PID: 452 (containerd)
      Tasks: 8
     Memory: 36.7M
        CPU: 7.120s
```

---

**Challenge 3 — Simulate a Hang**

Start a `sleep 999 &` process to simulate a hung background task.
Find its PID. Try killing it gracefully first. If it doesn't die, use force kill.
Verify it's gone.

```
sleep 999 &
[1] 9227

ps au | grep sleep
learnin+    9227  0.0  0.0   6192  2104 pts/0    S    19:05   0:00 sleep 999
learnin+    9556  0.0  0.0   7008  2420 pts/0    S+   19:06   0:00 grep --color=auto 

kill 9227
[1]+  Terminated              sleep 999

learning_gcp_devops@boa-devops-admin:~/opsflux-labs$ ps au | grep sleep
learnin+    9634  0.0  0.0   7008  2420 pts/0    S+   19:06   0:00 grep --color=auto sleep      
```

---

**Challenge 4 — Boot Safety Check**

Before a planned VM reboot, you need to confirm that both `docker` and `ssh` will come back automatically after the machine restarts.
How do you verify this without actually rebooting?

```
sudo systemctl is-enabled docker
enabled
sudo systemctl is-enabled ssh
enabled
```

---

**Challenge 5 — Incident Log Investigation**

It's 2am. You get paged: "Docker is down on `boa-devops-admin`."
You restart Docker and it comes back. But your team lead asks: "What caused the crash?"
How do you find the answer? Write the exact command(s) and describe what you would look for in the output.

```
sudo journalctl -u docker -n 50
sudo journalctl -u docker --since "18:15" --until "18:20"
Jun 04 18:18:31 boa-devops-admin dockerd[618]: time="2026-06-04T18:18:31.864261777Z" level=info msg="Processing signal 'terminated'"

Jun 04 18:19:24 boa-devops-admin dockerd[3677]: time="2026-06-04T18:19:24.720072028Z" level=info msg="Starting up"

The cause was SIGTERM — meaning someone (you) deliberately stopped it with systemctl stop docker. Not a crash, not a memory issue, not a bug — a clean intentional shutdown.
```

---

## 🚀 GIT PUSH — End of Session

Every lab ends with a push to GitHub. No exceptions.

```bash
# Step 1: Navigate to your labs repo
cd ~/opsflux-labs

# Step 2: Check current status
git status

# Step 3: Create a feature branch for this lab
git checkout -b lab/boa-002-processes-services-systemd

# Step 4: Copy this file into the labs directory (if not already there)
# The file should be at: docs/_labs/BOA-002-processes-services-systemd.md

# Step 5: Stage the new file
git add docs/_labs/BOA-002-processes-services-systemd.md

# Step 6: Commit with a descriptive message
git commit -m "feat: add BOA-002 processes services systemd lab"

# Step 7: Push to GitHub
git push origin lab/boa-002-processes-services-systemd

# Step 8: Create a Pull Request on GitHub, get it reviewed, merge to main
# Auto-deploy to labs.opsflux.in triggers on merge
```

**Verify lab is live:**
Open `labs.opsflux.in` in your browser and confirm BOA-002 appears.

---

*BOA-002 complete. You can now investigate any process or service on a Linux machine the way you would in Windows Task Manager and Event Viewer — but faster and with more precision.*
