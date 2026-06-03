---
title: "BOA-001: Linux Navigation & Permissions"
date: 2026-06-03
summary: "Navigate the Linux filesystem, understand file permissions, set ownership — Day 1 on boa-devops-admin"
difficulty: beginner
duration: 2 hours
tags:
  - linux
  - permissions
  - filesystem
  - foundation
  - boa
---

---

## 🎫 JIRA-STYLE TICKET

| Field | Value |
|---|---|
| **Ticket ID** | BOA-001 |
| **Priority** | P2 — High |
| **Assigned To** | Murali |
| **Environment** | boa-devops-admin (Ubuntu 22.04) |
| **Labels** | linux, foundation, day-1 |

### Description

> **Incident Context:**
> You have just been handed access to a new Linux VM — `boa-devops-admin` — where the Bank of Anthos application will be deployed and operated. Before anything can be deployed, you need to verify the server layout, confirm permissions are correct, and ensure the right users and directories are in place.
>
> A Windows admin who is new to Linux must be able to navigate the filesystem, inspect file permissions, and set ownership correctly. This is Day 1 — your first shift on the Linux server.

**Your objective:** Navigate the Linux filesystem, understand its layout, inspect and fix file permissions, and verify ownership — all without a GUI.

---

## 🪟 Windows → Linux Reference Table

| What You Know (Windows) | What It Is in Linux | Notes |
|---|---|---|
| `C:\` drive | `/` (root) | Everything lives under `/` |
| `C:\Windows` | `/etc`, `/bin`, `/usr` | System files |
| `C:\Users\murali` | `/home/learning_gcp_devops` | Your home folder |
| `C:\Program Files` | `/usr/bin`, `/opt` | Installed programs |
| `C:\Windows\Logs` | `/var/log` | Log files |
| `C:\Windows\Temp` | `/tmp` | Temporary files |
| Right-click → Properties → Security | `ls -l` + `chmod` + `chown` | File permissions |
| `dir` | `ls` | List files |
| `cd` | `cd` | Change directory (same!) |
| File Explorer path bar | `pwd` | Print current location |
| Run As Administrator | `sudo` | Run as superuser |
| `whoami` | `whoami` | Same command! |
| NTFS ACLs (Read/Write/Execute) | `rwx` (read/write/execute) | Permission model |
| File owner in Properties | `ls -l` owner field | Who owns the file |

---

## 🗺️ Linux Filesystem Layout — The Map

Before you touch any commands, understand where you are. This is the Linux filesystem — think of it as a map of `C:\` but built differently.

```
/                        ← Root. Everything starts here. Like C:\ but only one drive.
├── home/
│   └── learning_gcp_devops/   ← YOUR home directory. Like C:\Users\murali
│       ├── opsflux-app/
│       └── opsflux-labs/
├── etc/                 ← Configuration files. Like registry + config files in Windows
├── var/
│   └── log/             ← All log files live here
├── tmp/                 ← Temporary files. Cleared on reboot
├── usr/
│   └── bin/             ← Installed programs (kubectl, helm, git, etc.)
├── opt/                 ← Large third-party software (sometimes)
└── proc/                ← Live kernel and process info (virtual — not real files)
```

---

## Phase 1 — Connect and Orient Yourself

### 1.1 — SSH into the VM

From your Windows machine:

```bash
ssh boa-devops-admin
```

> **What this does:** Uses your SSH config at `C:\Users\my pc\.ssh\config` to connect to the VM at `8.231.98.123` as `learning_gcp_devops`. It's like RDP, but text-only.

**Expected output:**
```
Welcome to Ubuntu 22.04.x LTS (GNU/Linux ...)
learning_gcp_devops@boa-devops-admin:~$
```

The `~` means you are in your home directory. The `$` means you are a normal user (not root). If you see `#`, that means root — which you should not be by default.

---

### 1.2 — Where am I?

```bash
pwd
```

> **What this does:** Print Working Directory. Like clicking the address bar in File Explorer and seeing `C:\Users\murali`. Tells you exactly where you are in the filesystem.

**Expected output:**
```
/home/learning_gcp_devops
```

---

### 1.3 — Who am I logged in as?

```bash
whoami
```

> **What this does:** Prints your username. Same command as Windows. Useful when you're unsure which user context you're operating in — especially after `sudo su`.

**Expected output:**
```
learning_gcp_devops
```

---

### 1.4 — What groups do I belong to?

```bash
id
```

> **What this does:** Shows your user ID (uid), group ID (gid), and all groups you belong to. In Windows this is like checking which security groups your AD account is in.

**Expected output:**
```
uid=1001(learning_gcp_devops) gid=1001(learning_gcp_devops) groups=1001(learning_gcp_devops),4(adm),27(sudo),1000(docker)
```

> **What to look for:** `sudo` group means you can run commands as root using `sudo`. `docker` group means you can run Docker commands without `sudo`. Both should be present.

---

## Phase 2 — Navigate the Filesystem

### 2.1 — List files in your current directory

```bash
ls
```

> **What this does:** Lists files and folders — like `dir` in Windows Command Prompt or what you see in File Explorer.

**Expected output:**
```
opsflux-app  opsflux-labs
```

---

### 2.2 — List with details (permissions, owner, size)

```bash
ls -l
```

> **What this does:** Long format list. Shows permissions, owner, group, size, date, and name. This is the most important `ls` variant you will use every day.

**Expected output:**
```
total 8
drwxrwxr-x 5 learning_gcp_devops learning_gcp_devops 4096 Jun  1 09:00 opsflux-app
drwxrwxr-x 6 learning_gcp_devops learning_gcp_devops 4096 Jun  1 09:00 opsflux-labs
```

---

### 2.3 — List including hidden files

```bash
ls -la
```

> **What this does:** The `-a` flag shows ALL files, including hidden ones (files that start with `.`). In Linux, any file or folder starting with `.` is hidden — like hidden files in Windows but no separate attribute.

**Expected output (partial):**
```
drwxr-xr-x  6 learning_gcp_devops learning_gcp_devops 4096 Jun  1 09:00 .
drwxr-xr-x  4 root                root                4096 Jun  1 08:00 ..
-rw-r--r--  1 learning_gcp_devops learning_gcp_devops  220 Jun  1 08:00 .bash_logout
-rw-r--r--  1 learning_gcp_devops learning_gcp_devops 3526 Jun  1 08:00 .bashrc
-rw-r--r--  1 learning_gcp_devops learning_gcp_devops  807 Jun  1 08:00 .profile
drwxrwxr-x  5 learning_gcp_devops learning_gcp_devops 4096 Jun  1 09:00 opsflux-app
drwxrwxr-x  6 learning_gcp_devops learning_gcp_devops 4096 Jun  1 09:00 opsflux-labs
```

> **What to look for:** `.bashrc` is your shell configuration file — like `$PROFILE` in PowerShell. Every time you open a terminal, this file runs.

---

### 2.4 — Navigate into a directory

```bash
cd opsflux-labs
```

> **What this does:** Change Directory. Exactly like `cd` in Windows. Takes you inside the `opsflux-labs` folder.

```bash
pwd
```

**Expected output:**
```
/home/learning_gcp_devops/opsflux-labs
```

---

### 2.5 — Go back up one level

```bash
cd ..
```

> **What this does:** `..` means "one level up" — the parent directory. Same as in Windows. Takes you from `opsflux-labs` back to your home folder.

---

### 2.6 — Jump directly to your home directory (from anywhere)

```bash
cd ~
```

> **What this does:** `~` is a shortcut for your home directory (`/home/learning_gcp_devops`). No matter where you are in the filesystem, `cd ~` brings you home. There is no Windows equivalent — but think of it like pressing the Home button.

---

### 2.7 — Explore the system directories

```bash
ls /etc | head -20
```

> **What this does:** Lists the first 20 items inside `/etc`. The pipe `|` sends the output of `ls /etc` into `head -20`, which shows only the first 20 lines. This prevents the terminal from flooding with hundreds of filenames.

```bash
ls /var/log
```

> **What this does:** Shows the log files directory. You'll spend a lot of time here investigating incidents.

**Expected output (partial):**
```
auth.log  dpkg.log  kern.log  syslog  ubuntu-advantage.log
```

---

## Phase 3 — Understanding File Permissions

### 3.1 — Read the permission string

Run this in your home directory:

```bash
ls -l
```

Look at a line like this:
```
drwxrwxr-x  5  learning_gcp_devops  learning_gcp_devops  4096  Jun 1 09:00  opsflux-labs
```

Break it down character by character:

```
d  rwx  rwx  r-x
│   │    │    │
│   │    │    └── Other users: can read and execute, cannot write
│   │    └─────── Group: can read, write, execute
│   └──────────── Owner: can read, write, execute
└──────────────── d = directory, - = file, l = symlink
```

**The 3-character blocks (rwx):**

| Symbol | Meaning | On a File | On a Directory |
|---|---|---|---|
| `r` | Read | Open and read the file | List contents with `ls` |
| `w` | Write | Edit or delete the file | Create/delete files inside |
| `x` | Execute | Run the file as a program | Enter with `cd` |
| `-` | No permission | That permission is denied | That permission is denied |

**The 3 groups:**
1. **Owner** — The user who owns the file
2. **Group** — The group assigned to the file
3. **Other** — Everyone else on the system

> **Windows Analogy:** Owner = file creator in NTFS. Group = AD security group. Other = Everyone in NTFS permissions.

---

### 3.2 — Create a test directory and file to practice permissions

```bash
mkdir ~/permissions-lab
cd ~/permissions-lab
touch testfile.sh
ls -l
```

> **`mkdir`** — Make Directory. Like right-click → New Folder in Windows Explorer.
> **`touch`** — Creates an empty file if it doesn't exist. Updates timestamp if it does. Like creating a new empty `.txt` file.

**Expected output:**
```
-rw-rw-r-- 1 learning_gcp_devops learning_gcp_devops 0 Jun  1 10:00 testfile.sh
```

Note: The file has no execute permission yet (`-rw-rw-r--`). It's just a text file right now.

---

### 3.3 — Add execute permission to the file

```bash
chmod +x testfile.sh
ls -l
```

> **`chmod`** — Change Mode (change permissions). The `+x` means "add execute permission for everyone."

**Expected output:**
```
-rwxrwxr-x 1 learning_gcp_devops learning_gcp_devops 0 Jun  1 10:00 testfile.sh
```

> **What changed:** The three permission blocks now all have `x`. This is what turns a plain text file into a runnable script. You will do this every time you write a shell script.

---

### 3.4 — Set permissions using numbers (Octal notation)

Linux permissions can also be set with numbers. This is faster and more precise than `+x`.

| Number | Permission | Binary |
|---|---|---|
| 7 | rwx — full | 111 |
| 6 | rw- — read/write | 110 |
| 5 | r-x — read/execute | 101 |
| 4 | r-- — read only | 100 |
| 0 | --- — none | 000 |

**Three digits = Owner / Group / Other**

```bash
chmod 755 testfile.sh
ls -l testfile.sh
```

> **What this does:** Sets permissions to `rwxr-xr-x`. Owner gets full access (7=rwx). Group gets read+execute (5=r-x). Others get read+execute (5=r-x). This is the standard permission for scripts and executables.

**Expected output:**
```
-rwxr-xr-x 1 learning_gcp_devops learning_gcp_devops 0 Jun  1 10:00 testfile.sh
```

```bash
chmod 644 testfile.sh
ls -l testfile.sh
```

> **What this does:** Sets permissions to `rw-r--r--`. Owner can read/write. Group and others can only read. This is the standard permission for config files and log files.

**Expected output:**
```
-rw-r--r-- 1 learning_gcp_devops learning_gcp_devops 0 Jun  1 10:00 testfile.sh
```

---

### 3.5 — Permission cheat sheet for operators

| Permission | Octal | Use Case |
|---|---|---|
| `rwxr-xr-x` | `755` | Shell scripts, executables, directories |
| `rw-r--r--` | `644` | Config files, text files, logs |
| `rw-rw-r--` | `664` | Shared files (team editable) |
| `rwx------` | `700` | Private scripts (owner only) |
| `rw-------` | `600` | Private keys, secrets, credentials |

> **Security note:** Never set permissions to `777` (rwxrwxrwx — everyone can do everything). This is a security risk in production.

---

## Phase 4 — File Ownership (chown)

### 4.1 — Check current ownership

```bash
ls -l ~/permissions-lab/testfile.sh
```

**Expected output:**
```
-rw-r--r-- 1 learning_gcp_devops learning_gcp_devops 0 Jun  1 10:00 testfile.sh
```

The two names after the permission string are: `owner` then `group`.

---

### 4.2 — Change file owner

```bash
sudo chown root testfile.sh
ls -l testfile.sh
```

> **`chown`** — Change Ownership. The `sudo` is needed because only root can reassign ownership to another user. Here we're changing the owner to `root`.

**Expected output:**
```
-rw-r--r-- 1 root learning_gcp_devops 0 Jun  1 10:00 testfile.sh
```

---

### 4.3 — Change both owner and group

```bash
sudo chown root:root testfile.sh
ls -l testfile.sh
```

> **What this does:** `chown owner:group filename`. Changes both the owner and the group in one command.

**Expected output:**
```
-rw-r--r-- 1 root root 0 Jun  1 10:00 testfile.sh
```

---

### 4.4 — Change it back to yourself

```bash
sudo chown learning_gcp_devops:learning_gcp_devops testfile.sh
ls -l testfile.sh
```

**Expected output:**
```
-rw-r--r-- 1 learning_gcp_devops learning_gcp_devops 0 Jun  1 10:00 testfile.sh
```

---

### 4.5 — Recursively change ownership of a directory

```bash
sudo chown -R learning_gcp_devops:learning_gcp_devops ~/permissions-lab/
```

> **What this does:** The `-R` flag means Recursive — applies the ownership change to all files and subdirectories inside `permissions-lab`. Like checking "Apply to subfolders" in Windows NTFS permissions.

---

## Phase 5 — Verify the opsflux-labs Directory

This is a real operational check. Verify that your opsflux-labs repo directory has correct permissions before you start pushing labs.

```bash
ls -la ~/opsflux-labs/
```

> **What to look for:**
> - Owner should be `learning_gcp_devops`
> - Directory permission should be `drwxrwxr-x` (755) or similar
> - No files owned by `root` (that would block your git operations)

```bash
ls -la ~/opsflux-labs/docs/
```

```bash
ls -la ~/opsflux-labs/docs/_labs/ 2>/dev/null || echo "Directory does not exist yet — we will create it"
```

> **`2>/dev/null`** — Redirects error messages to nowhere (discards them silently). The `||` means "if the previous command failed, run this instead." This is a safe way to check if a directory exists without crashing the script.

---

### 5.1 — Create the labs directory if it does not exist

```bash
mkdir -p ~/opsflux-labs/docs/_labs/
```

> **What this does:** `mkdir -p` creates the full directory path, including any missing parent directories. The `-p` flag means "no error if it already exists, and create parents as needed." Like creating `C:\docs\labs` even if `C:\docs` doesn't exist yet — it creates both.

```bash
ls -la ~/opsflux-labs/docs/_labs/
```

---

## Phase 6 — Write and Save This Lab File

Now you will save this lab file into the labs directory.

### 6.1 — Navigate to the labs folder

```bash
cd ~/opsflux-labs/docs/_labs/
pwd
```

**Expected output:**
```
/home/learning_gcp_devops/opsflux-labs/docs/_labs
```

---

### 6.2 — Confirm the lab file exists (it should be here already if pasted)

```bash
ls -l BOA-001-linux-navigation-permissions.md
```

If it does not exist, you will create it using VS Code via Remote SSH — open the file in VS Code, paste the content, and save. Then run the `ls -l` command again to confirm.

---

## Phase 7 — Git Push to opsflux-labs

This is the final step of every lab. Non-negotiable.

### 7.1 — Go to the repo root

```bash
cd ~/opsflux-labs
```

### 7.2 — Check the current git status

```bash
git status
```

> **What this does:** Shows which files have been modified or added since the last commit. Like seeing a diff in Azure DevOps before raising a PR.

**Expected output:**
```
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
        docs/_labs/BOA-001-linux-navigation-permissions.md

nothing added to commit but untracked files present
```

---

### 7.3 — Create a feature branch (GitOps rule — never push directly to main)

```bash
git checkout -b feature/BOA-001-linux-navigation
```

> **What this does:** Creates a new branch and switches to it. Like creating a feature branch in Azure DevOps before starting work. The `-b` means "create and switch."

---

### 7.4 — Stage the new file

```bash
git add docs/_labs/BOA-001-linux-navigation-permissions.md
```

> **What this does:** Stages the file for commit. Think of staging as "selecting files to include in this change set" — like the Files tab in a TFS/Azure DevOps changeset.

---

### 7.5 — Commit the file

```bash
git commit -m "BOA-001: Linux Navigation & Permissions lab — Day 1"
```

> **What this does:** Creates a commit — a permanent snapshot of your changes with a message. Like "Check In" in TFS or "Save Version" in Azure DevOps.

---

### 7.6 — Push to GitHub

```bash
git push origin feature/BOA-001-linux-navigation
```

> **What this does:** Uploads your local branch and commit to GitHub. Like pushing a local branch in Azure DevOps to the remote repo.

---

### 7.7 — Create a Pull Request on GitHub

1. Go to `github.com/opsflux-labs`
2. Open the `opsflux-labs` repository
3. Click **Compare & pull request** on the `feature/BOA-001-linux-navigation` branch
4. Title: `BOA-001: Linux Navigation & Permissions`
5. Click **Create pull request**
6. Review the changes
7. Click **Squash and merge**
8. Confirm the merge

---

### 7.8 — Verify the lab is live

After the merge triggers the Cloudflare Pages / auto-deploy pipeline:

```
https://labs.opsflux.in/docs/_labs/BOA-001-linux-navigation-permissions
```

> Confirm the page loads and the lab content is visible.

---

## 🔍 Root Cause (of the fictional incident)

The Bank of Anthos deployment VM (`boa-devops-admin`) was handed over without confirming the filesystem layout, directory ownership, or operator permissions. Without this baseline check, any future deployment could fail silently due to permission denied errors or wrong directory structure.

---

## ✅ Fix

Navigated the filesystem, verified ownership and permissions on all relevant directories, corrected any issues using `chmod` and `chown`, and confirmed the opsflux-labs labs directory structure is ready for future lab files.

---

## 🎯 Result

- Filesystem structure understood and mapped
- Home directory confirmed: `/home/learning_gcp_devops`
- Labs directory created: `~/opsflux-labs/docs/_labs/`
- File permissions understood: rwx, octal notation, chmod, chown
- BOA-001 lab file published to labs.opsflux.in ✅

---

## 💡 Key Learnings

- Linux has one filesystem tree starting at `/` — not multiple drive letters like Windows
- `pwd` tells you where you are — use it constantly when starting out
- `ls -l` is your most-used command for checking files and permissions
- The permission string `rwxr-xr-x` = owner / group / others — three blocks of three
- `chmod 755` = standard for scripts; `chmod 644` = standard for config files
- `chown user:group file` changes who owns a file
- `sudo` is "Run as Administrator" in Linux — use it only when needed
- Hidden files start with `.` — visible only with `ls -a`
- `mkdir -p` creates the full path safely, even if parents don't exist
- Never push directly to `main` — always use feature branches

---

## 📋 Command Reference Table

| Command | What It Does | Windows Equivalent |
|---|---|---|
| `pwd` | Print current directory path | Address bar in File Explorer |
| `ls` | List files | `dir` |
| `ls -l` | List files with details | `dir` with properties |
| `ls -la` | List all files including hidden | `dir /a` |
| `cd dirname` | Enter a directory | `cd dirname` |
| `cd ..` | Go up one level | `cd ..` |
| `cd ~` | Go to home directory | `cd %USERPROFILE%` |
| `mkdir dirname` | Create a directory | `mkdir` or New Folder |
| `mkdir -p path` | Create full path | `mkdir` with `/p` (PowerShell) |
| `touch filename` | Create empty file | `echo.> filename` (CMD) |
| `chmod 755 file` | Set rwxr-xr-x permissions | NTFS permission dialog |
| `chmod +x file` | Add execute permission | NTFS permission dialog |
| `chown user:group file` | Change file ownership | File Properties → Security |
| `chown -R user dir` | Change ownership recursively | Apply to subfolders checkbox |
| `whoami` | Current username | `whoami` |
| `id` | User ID and group memberships | `whoami /groups` |
| `sudo command` | Run as root/superuser | Run as Administrator |

---

## 🏭 Production Notes

### GCP Professional Cloud Architect Refresh
- GCP VMs use Linux service accounts — understanding Linux file ownership is essential for service account permission management on GCE instances
- GCS (Cloud Storage) objects also have IAM — Linux permission concepts map to GCS IAM roles (Owner, Editor, Viewer)
- GKE node pools run Ubuntu — the Linux skills in this lab apply directly to node troubleshooting

### CKA / CKAD Cert Refresh
- Kubernetes config files live in `~/.kube/config` — understanding home directories and hidden files is needed here
- `kubectl` is an executable at `/usr/bin/kubectl` — chmod and PATH concepts apply
- Kubernetes Secret and ConfigMap files are deployed from local filesystem — permissions matter when accessing them

---

## 🧩 Challenges — Real Incident-Style Tasks

Attempt each one independently. Read the scenario, investigate, then write your answer.

---

**Challenge 1**

> You SSH into `boa-devops-admin` and run `kubectl get pods`. You get: `bash: kubectl: command not found`. What do you check first, and what command would you use to verify kubectl is installed and where it is?

**Your answer:**

---

**Challenge 2**

> You need to run a deployment script at `/opt/boa/deploy.sh` but get `Permission denied`. What single command checks the permissions on that file, and what command would fix it so only the owner can execute it?

**Your answer:**

---

**Challenge 3**

> A config file at `/etc/boa/config.yaml` is owned by `root:root` with permissions `600`. Your user is `learning_gcp_devops`. Can you read it without `sudo`? What permission change (with the exact command) would let your user read it without changing the owner?

**Your answer:**

---

**Challenge 4**

> Someone tells you there's a hidden config folder in your home directory that contains GCP credentials. What command would you run to list all hidden folders in your home directory?

**Your answer:**

---

**Challenge 5**

> You're setting up a shared directory `/opt/boa-logs` that needs to be: owned by `learning_gcp_devops`, readable and writable by the group `devops`, and unreadable by everyone else. Write the exact two commands (`chown` and `chmod`) to set this up.

**Your answer:**

---

*BOA-001 Complete — Day 1 Done. Push to labs.opsflux.in before ending the session.*