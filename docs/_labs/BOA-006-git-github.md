---
layout: lab
title: "BOA-006: Git & GitHub"
date: 2026-06-09
summary: "Understand git internals, feature branch workflow, conflict resolution and recovery techniques for production DevOps work"
difficulty: beginner
duration: "120 mins"
description: "Go beyond running git commands mechanically — understand what git is doing under the hood so you can troubleshoot, recover from mistakes, and explain your workflow confidently in a Senior DevOps interview."
tags: [git, github, gitops, version-control, devops-foundation]
---

# BOA-006 — Git & GitHub

## JIRA Ticket

| Field | Value |
|---|---|
| Ticket | BOA-006 |
| Priority | High |
| Assigned | Murali (learning_gcp_devops) |
| Environment | boa-devops-admin / Ubuntu 22.04 |
| Labels | git, github, gitops, version-control |

**Title:** Git & GitHub — Understand and operate version control the way a Senior DevOps Engineer actually uses it

**Description:** The OpsFlux platform team has flagged that BOA lab commits are being made mechanically. Before moving into Docker and Kubernetes, this gap must be closed. This lab teaches git internals so you can troubleshoot, recover from mistakes, and explain your workflow confidently.

---

## Windows → Git Mental Model

| Git Concept | Windows Equivalent | What It Actually Means |
|---|---|---|
| Repository | Project folder with full change history | Every file change ever made, stored forever |
| Working Directory | Current file state in Explorer | Files as they look right now on disk |
| Staging Area | A "ready to save" checklist | Files queued for the next snapshot |
| Commit | A System Restore Point | Permanent snapshot of staged files |
| Branch | A separate copy of the project | Independent line of work |
| Remote (origin) | A network share on GitHub | Copy of repo stored on GitHub |
| Push | Copy local changes to network share | Upload commits to GitHub |
| Pull | Sync from network share | Download commits to local machine |
| HEAD | "You Are Here" marker | Points to current position in history |
| Merge | Combine two folders back into one | Join branch changes back into main |

---

## Phase 1 — See What Git Already Knows

### Commands

```bash
cd ~/opsflux-labs
git status
git log --oneline --graph --decorate -20
git remote -v
```

### What to Look For
- Which branch HEAD points to
- Whether local and origin/main are in sync
- Where push and fetch are pointed

---

## Phase 2 — Git Internals

### Commands

```bash
cat .git/HEAD
cat .git/refs/heads/main
cat .git/COMMIT_EDITMSG
ls .git/
```

### Key Learning
HEAD is a text file. It points to a branch. That branch is a text file containing a commit hash. That hash is a snapshot stored in `.git/objects/`. There is no magic.
.git/HEAD → refs/heads/main → commit hash → .git/objects/

---

## Phase 3 — Feature Branch

### Commands

```bash
git checkout -b feature/BOA-006-git-github
cat .git/HEAD
git branch
```

### Key Learning
Creating a branch creates a new file in `.git/refs/heads/`. Switching branches rewrites `.git/HEAD`. That is all that happens.

---

## Phase 4 — The Three Areas of Git

### Commands

```bash
touch docs/_labs/BOA-006-git-github.md
git status                                    # Untracked
git add docs/_labs/BOA-006-git-github.md
git status                                    # Staged
git commit -m "feat: add BOA-006 placeholder"
git status                                    # Clean
```

### The Three Areas

| Area | Location | Stage |
|---|---|---|
| Working Directory | Files on disk | Untracked / Modified |
| Staging Area | .git/index | Changes to be committed |
| Repository | .git/objects | Committed — permanent |

---

## Phase 5 — Clean Up Stale Branches

### Commands

```bash
git branch -d feature/BOA-001-linux-navigation \
  feature/BOA-002-processes-services-systemd
git branch -D feature/BOA-003-networking-commands \
  feature/BOA-004-bash-scripting-basics \
  feature/BOA-005-logs-text-processing \
  feature/BOA-REVIEW-01-linux-phase-review
git branch
```

### Key Learning
`-d` only deletes merged branches. `-D` force deletes. Squash merge causes `-d` to fail because the original commits no longer exist in main's history — the code is there but the hashes don't match.

---

## Phase 6 — Recover From Mistakes

### Mistake 1 — Committed to Wrong Branch

```bash
# Simulate
git checkout main
echo "accidental" >> README.md
git add README.md
git commit -m "oops: accidental commit on main"

# Fix
git reset HEAD~1
git restore README.md
git status
```

### Mistake 2 — Staged Wrong File

```bash
# Simulate
echo "sensitive data" > accidental.txt
git add accidental.txt

# Fix
git restore --staged accidental.txt
rm accidental.txt
git status
```

### Recovery Reference

| Mistake | Fix | Effect |
|---|---|---|
| Committed to wrong branch | `git reset HEAD~1` | Removes commit, keeps changes |
| Staged wrong file | `git restore --staged <file>` | Unstages, keeps file on disk |
| Unwanted file change | `git restore <file>` | Discards change permanently |

---

## Phase 7 — Merge Conflict Resolution

### Commands

```bash
# Create conflict
git checkout main
echo "line added on main" >> README.md
git add README.md && git commit -m "test: main change"

git checkout feature/BOA-006-git-github
echo "line added on feature" >> README.md
git add README.md && git commit -m "test: feature change"

git merge main
# CONFLICT appears

# Resolve in VS Code — remove markers, keep both lines
code README.md

# Complete merge
git add README.md
git commit -m "fix: resolve merge conflict in README.md"
git log --oneline --graph -5
```

### Conflict Marker Anatomy
<<<<<<< HEAD
your change on feature branch
their change on main







main








Remove all three marker lines. Keep the lines you want. Stage and commit.

---

## Key Learnings

- HEAD is a text file pointing to your current branch
- A branch is a text file containing a commit hash
- Three areas: Working Directory → Staging Area → Repository
- `git add` moves files to staging — `git commit` creates the snapshot
- `git reset HEAD~1` removes last commit but keeps the changes
- `git restore --staged` unstages without losing file
- `-d` vs `-D`: safe delete vs force delete
- Squash merge rewrites history — original branch hashes disappear
- Merge conflicts are git asking you to make a decision — not an error

---

## Command Reference

| Command | What It Does |
|---|---|
| `git status` | Show current state of working dir and staging area |
| `git log --oneline --graph --decorate` | Visual commit history with branch labels |
| `git checkout -b <branch>` | Create and switch to new branch |
| `git branch -d / -D` | Delete branch (safe / force) |
| `git branch -m <old> <new>` | Rename a branch |
| `git add <file>` | Stage a file |
| `git commit -m "message"` | Create a snapshot |
| `git reset HEAD~1` | Undo last commit, keep changes |
| `git restore <file>` | Discard working dir changes |
| `git restore --staged <file>` | Unstage a file |
| `git merge <branch>` | Merge branch into current branch |
| `git log origin/main..HEAD` | Show commits not yet on origin/main |
| `cat .git/HEAD` | See where HEAD points |
| `cat .git/refs/heads/<branch>` | See commit hash of a branch |

---

## Production Notes

### GCP Professional Cloud Engineer
- Cloud Source Repositories uses same git concepts
- IAM controls who can push to protected branches
- Cloud Build triggers on push — understanding branches = understanding pipeline triggers

### CKA / CKAD
- Kubernetes manifests are stored in git — GitOps means git IS the source of truth
- Helm chart values files are versioned in git
- Knowing git recovery commands is essential when a bad manifest gets pushed

---

## Challenges

**Challenge 1:**
You committed a file with a hardcoded password directly to main. Nobody has pulled yet. How do you remove it from history completely?

Your answer:

---

**Challenge 2:**
You are on `feature/payment-service` and run `git merge main`. You see 6 files with CONFLICT. What is your step-by-step process to resolve without losing any work?

Your answer:

---

**Challenge 3:**
A colleague says "just push directly to main, it's faster." Explain why your team's feature branch + squash merge workflow exists and what problems it prevents.

Your answer:

---

**Challenge 4:**
You ran `git branch -D feature/BOA-005` and immediately realized it had one unmerged commit you needed. How do you recover it?

Your answer:

---

**Challenge 5:**
Explain what `git log --oneline origin/main..HEAD` shows and when you would use it in your daily workflow.

Your answer: