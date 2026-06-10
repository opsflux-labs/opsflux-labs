---
layout: lab
title: "BOA-006 Day 2: GitOps Workflow"
date: 2025-01-01
lab_id: BOA-006-DAY2
phase: 2
difficulty: intermediate
duration: 90 mins
summary: "Master the production GitOps workflow — feature branch, PR review, squash merge, and branch protection rules on GitHub."
tags: [git, github, gitops, branch-protection, pull-request, squash-merge]
---

# BOA-006 Day 2 — GitOps Workflow

## 🎫 JIRA Ticket

```
Ticket   : BOA-006-DAY2
Priority : High
Assigned : Murali (DevOps Engineer)
Phase    : 2 — Git & GitHub

TITLE: GitOps Workflow — Feature Branch, PR Review, Squash Merge & Branch Protection

DESCRIPTION:
Yesterday covered Git fundamentals — clone, branch, commit, push.
Today we operate Git the way production teams actually use it.

In production, no one pushes directly to main.
Every change goes through: feature branch → PR → review → squash merge.
Branch protection rules enforce this — even senior engineers cannot bypass them
without explicit admin override.

ACCEPTANCE CRITERIA:
- Understand WHY feature branches exist (not just how to create them)
- Create a PR and understand what reviewers look for
- Squash merge a PR and understand what it does to history
- Set up branch protection rules on main
- Understand the difference between merge commit, squash merge, rebase merge
```

---

## Windows → Linux / GitHub Reference

| Windows Concept | Git / GitHub Equivalent | What it does |
|---|---|---|
| Saving a draft document | Feature branch | Work in isolation without affecting the live version |
| Uploading draft to SharePoint for review | `git push` + Pull Request | Share your changes for others to review |
| Manager approving the document | PR approval + merge | Changes land in the official version |
| Pressing Ctrl+Z on a save | `git reset --soft HEAD~1` | Undo last commit, keep file changes |
| Undoing file edits | `git checkout -- <file>` | Restore file to last committed state |
| Event Viewer history | `git log` | Full record of what changed, when, and by whom |
| Folder cleanup — removing shortcuts | `git remote prune origin` | Remove stale remote branch references |

---

## Phase 1 — Read the Git History

Before touching anything, understand where you are.

```bash
cd ~/opsflux-labs
git log --oneline -10
```

**What each part means:**
- `git log` — show the commit history (like Event Viewer for your repo)
- `--oneline` — one line per commit, compact view
- `-10` — show only the last 10 commits

**Real output from boa-devops-admin:**
```
78b683a (HEAD -> main, origin/main, origin/HEAD) feat: add BOA-006 git and github lab (#11)
77bb5ba Add BOA-REVIEW-01 Linux Phase Review (#10)
1441377 Add BOA-005: Logs and Text Processing (#9)
944aa57 Fix BOA-004 frontmatter: add difficulty, description, tags
7b2a11a Fix BOA-004 frontmatter: add difficulty, description, tags
935a5de Feature/boa 004 bash scripting basics (#8)
6c18f81 fix: correct frontmatter in BOA-003 networking commands lab (#7)
f54ac92 feat: add BOA-003 networking commands lab (#6)
e9dda81 docs: add challenge answers to BOA-002
f3e7750 (origin/feature/BOA-002-processes-services-systemd) fix: add Jekyll frontmatter to BOA-002
```

**What to look for:**
- Commits with `(#PR number)` — went through proper PR workflow ✅
- Commits without `(#PR number)` — pushed directly to main ⚠️
- `HEAD -> main` and `origin/main` on the same commit — local and remote are in sync ✅

**Key finding:** Commits `944aa57` and `7b2a11a` have no PR number — they were pushed directly to main. Branch protection rules will prevent this going forward.

---

## Phase 2 — Audit and Clean Stale Branches

### Step 1 — List all branches

```bash
git branch -a
```

**What this does:**
- `git branch` — list branches
- `-a` — "all": shows local branches AND remote branches
- Remote branches are prefixed with `remotes/origin/`

**Real output:**
```
* main
  remotes/origin/HEAD -> origin/main
  remotes/origin/feature/BOA-001-linux-navigation
  remotes/origin/feature/BOA-002-processes-services-systemd
  remotes/origin/feature/BOA-003-networking-commands
  remotes/origin/feature/BOA-004-bash-scripting-basics
  remotes/origin/feature/BOA-005-logs-text-processing
  remotes/origin/feature/BOA-006-git-github
  remotes/origin/feature/BOA-REVIEW-01-linux-phase-review
  remotes/origin/main
```

**Finding:** 7 stale feature branches sitting on GitHub — all merged, all dead weight.

### Step 2 — Enable auto-delete on GitHub

Go to: **GitHub → Repository Settings → General → Pull Requests section**

Enable: ✅ **Automatically delete head branches**

From this point forward, every branch is auto-deleted the moment its PR is merged.

### Step 3 — Delete the 7 existing stale branches

```bash
git push origin --delete feature/BOA-001-linux-navigation
git push origin --delete feature/BOA-002-processes-services-systemd
git push origin --delete feature/BOA-003-networking-commands
git push origin --delete feature/BOA-004-bash-scripting-basics
git push origin --delete feature/BOA-005-logs-text-processing
git push origin --delete feature/BOA-006-git-github
git push origin --delete feature/BOA-REVIEW-01-linux-phase-review
```

**What this does:** Tells GitHub to remove the branch pointer. The commits are safe — they are merged into main. You are only removing the branch label.

**Windows analogy:** Deleting a shortcut, not the actual file.

**Real output (repeated for each branch):**
```
To github.com:opsflux-labs/opsflux-labs.git
 - [deleted]         feature/BOA-001-linux-navigation
```

### Step 4 — Prune local stale references

```bash
git remote prune origin
git branch -a
```

**`git remote prune origin`** — removes local tracking references for branches that no longer exist on GitHub.

**Real output after cleanup:**
```
* main
  remotes/origin/HEAD -> origin/main
  remotes/origin/main
```

Only `main` remains. Repo is clean.

---

## Phase 3 — Set Up Branch Protection Rules

Branch protection rules prevent anyone from pushing directly to main — enforcing the PR workflow at the infrastructure level.

### Step 1 — Create the ruleset

Go to: **GitHub → Repository Settings → Rules → Rulesets → New ruleset**

**Configuration:**

| Setting | Value |
|---|---|
| Ruleset name | `protect-main` |
| Enforcement status | Active |
| Target branch | `main` |
| Bypass list | Repository admin (Role) |

**Rules to enable:**

| Rule | Enabled | Reason |
|---|---|---|
| Restrict creations | ✅ | Only admins can create refs |
| Restrict updates | ✅ | Only admins can update main |
| Restrict deletions | ✅ | Nobody can delete main |
| Require a pull request before merging | ✅ | All changes must go through PR |
| Block force pushes | ✅ | Nobody can overwrite history |
| Require linear history | ❌ | Disabled — conflicts with squash merge on solo repo without CI |

**Under "Require a pull request before merging":**
- Required approvals: `0` (solo repo — you can merge your own PRs)

**Bypass list:** Add `Repository admin` role — repo owners can override when needed.

### Step 2 — Prove it works

Attempt a direct push to main:

```bash
echo "# test direct push" >> README.md
git add README.md
git commit -m "test: direct push to main"
git push origin main
```

**Real output — push rejected:**
```
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - Cannot update this protected ref.
! [remote rejected] main -> main (push declined due to repository rule violations)
error: failed to push some refs to 'github.com:opsflux-labs/opsflux-labs.git'
```

Branch protection is working. Main is locked.

### Step 3 — Clean up the rejected commit

The commit was rejected by GitHub but still exists locally. Clean it up:

```bash
git reset --soft HEAD~1
git restore --staged README.md
git checkout -- README.md
git status
```

**`git reset --soft HEAD~1`** — undo the last commit, keep file changes staged
**`git restore --staged README.md`** — unstage the file
**`git checkout -- README.md`** — discard the file change, restore to last clean version

**Real output:**
```
On branch main
nothing to commit, working tree clean
```

---

## Phase 4 — Full GitOps Workflow End to End

### Step 1 — Create feature branch

```bash
git checkout -b feature/BOA-006-day2-gitops-workflow
```

**`git checkout -b`** — creates a new branch AND switches to it in one command.

**Windows analogy:** Creating a new draft folder and opening it at the same time — your changes go there, not into the original.

**Real output:**
```
Switched to a new branch 'feature/BOA-006-day2-gitops-workflow'
```

### Step 2 — Create a file on the feature branch

```bash
cat > ~/opsflux-labs/docs/_labs/BOA-006-DAY2-notes.md << 'EOF'
# BOA-006 Day 2 — GitOps Workflow Notes
## What was done today
- Enabled auto-delete branches on GitHub
- Deleted 7 stale remote feature branches
- Set up branch protection ruleset on main
- Proved direct push to main is blocked
- Practising full GitOps workflow end to end
## Branch Protection Rules enabled
- Restrict deletions
- Require pull request before merging
- Block force pushes
- Require linear history
## Key commands used
- git branch -a
- git push origin --delete <branch>
- git remote prune origin
- git reset --soft HEAD~1
- git restore --staged <file>
EOF
```

### Step 3 — Commit to feature branch

```bash
git add docs/_labs/BOA-006-DAY2-notes.md
git commit -m "feat: add BOA-006 day2 gitops workflow notes"
git status
```

**Real output:**
```
[feature/BOA-006-day2-gitops-workflow 20c73d8] feat: add BOA-006 day2 gitops workflow notes
 1 file changed, 21 insertions(+)
 create mode 100644 docs/_labs/BOA-006-DAY2-notes.md
```

### Step 4 — Push feature branch to GitHub

```bash
git push origin feature/BOA-006-day2-gitops-workflow
```

**Real output:**
```
remote: Create a pull request for 'feature/BOA-006-day2-gitops-workflow' on GitHub by visiting:
remote:      https://github.com/opsflux-labs/opsflux-labs/pull/new/feature/BOA-006-day2-gitops-workflow
* [new branch]      feature/BOA-006-day2-gitops-workflow -> feature/BOA-006-day2-gitops-workflow
```

GitHub immediately offers the PR link — the branch is live on GitHub.

### Step 5 — Raise the Pull Request

On GitHub, click the yellow banner: **"Compare & pull request"**

**PR Title:** `feat: BOA-006 Day 2 — GitOps Workflow`

**PR Description:**
```
## What this PR does
- Adds BOA-006 Day 2 notes covering GitOps workflow
- Documents branch protection setup
- Documents stale branch cleanup

## Changes
- Added docs/_labs/BOA-006-DAY2-notes.md

## Tested
- Branch protection ruleset confirmed working
- Direct push to main blocked and verified
```

**Merge type:** Squash and merge (always)

### Step 6 — Squash merge

Because you are the Repository admin, GitHub shows:

```
☐ Merge without waiting for requirements to be met (bypass rules)
```

Check this box and click **Squash and merge**.

### Step 7 — Sync local main

```bash
git checkout main
git pull origin main
git log --oneline -5
```

**Real output:**
```
b72048b (HEAD -> main, origin/main, origin/HEAD) feat: add BOA-006 day2 gitops workflow notes (#12)
78b683a feat: add BOA-006 git and github lab (#11)
77bb5ba Add BOA-REVIEW-01 Linux Phase Review (#10)
1441377 Add BOA-005: Logs and Text Processing (#9)
944aa57 Fix BOA-004 frontmatter: add difficulty, description, tags
```

PR #12 is on main. One clean squash commit.

### Step 8 — Clean up branches

```bash
# Force delete local branch (-D needed after squash merge)
git branch -D feature/BOA-006-day2-gitops-workflow

# Prune stale remote references
git remote prune origin

# Verify
git branch -a
```

**Why `-D` and not `-d`?**
Squash merge creates a brand new commit on main (`b72048b`) instead of replaying your original commit (`20c73d8`). Git thinks your original commit never merged — so `-d` (safe delete) refuses. `-D` force-deletes, which is correct here because you know the content is in main.

**Real output:**
```
* main
  remotes/origin/HEAD -> origin/main
  remotes/origin/main
```

Clean. Only main remains.

---

## Root Cause

**Why were direct pushes to main possible before today?**

No branch protection rules were configured. Anyone with push access could push directly to main, bypassing code review entirely. This is a common gap in solo or early-stage repos — no enforcement mechanism existed.

---

## Fix

1. Enabled auto-delete branches on GitHub (permanent — applies to all future PRs)
2. Manually deleted 7 existing stale remote branches
3. Created `protect-main` ruleset with: Restrict updates, Restrict deletions, Require PR before merge, Block force pushes
4. Added Repository admin role to bypass list (allows owner to operate without being blocked)

---

## Result

- Main branch is fully protected — direct pushes rejected at the remote level
- All future branches auto-deleted after merge
- Full GitOps workflow validated end to end: feature branch → commit → push → PR → squash merge → sync
- Git history is clean — every change traceable to a PR number

---

## Key Learnings

- **Branch protection is infrastructure** — it enforces process at the platform level, not through trust
- **Squash merge = 1 PR = 1 commit** — keeps history readable; every `(#PR)` in `git log` is one unit of work
- **`-D` vs `-d`** — squash merge changes the commit hash, so Git thinks the branch is unmerged; always use `-D` after squash merges
- **Restrict updates vs Require PR** — these are different rules; Restrict updates blocks all updates including PR merges unless you have bypass rights
- **Bypass list = admin escape hatch** — Repository admin role in bypass list allows legitimate overrides without disabling protection entirely
- **`git remote prune origin`** — cleans stale local tracking references; run after deleting remote branches
- **Auto-delete branches** — one GitHub setting that permanently eliminates branch clutter going forward

---

## Command Reference Table

| Command | What it does | Windows analogy |
|---|---|---|
| `git log --oneline -10` | Show last 10 commits, compact | Event Viewer — recent history |
| `git branch -a` | List all local and remote branches | `net use` — show all mapped drives |
| `git push origin --delete <branch>` | Delete a branch on GitHub | Delete a shortcut on a shared drive |
| `git remote prune origin` | Remove stale local remote references | Refresh Network Neighborhood |
| `git checkout -b <branch>` | Create and switch to new branch | Create new draft folder and open it |
| `git reset --soft HEAD~1` | Undo last commit, keep changes staged | Ctrl+Z on a save in Word |
| `git restore --staged <file>` | Unstage a file | Uncheck a file from a pending upload |
| `git checkout -- <file>` | Discard file changes, restore to last commit | Revert to last saved version |
| `git branch -D <branch>` | Force delete local branch | Delete folder ignoring "are you sure" |
| `git pull origin main` | Sync local main with GitHub | Sync offline files from SharePoint |

---

## Production Notes

### GCP Professional Cloud Engineer Refresh
In GCP, branch protection maps directly to **IAM policies on Cloud Source Repositories**. You restrict who can push to protected branches using IAM roles — the same concept as GitHub's bypass list. In production GCP environments, only CI/CD service accounts (not humans) have push rights to main.

### CKA / CKAD Refresh
GitOps is the standard deployment model for Kubernetes. Tools like **ArgoCD** and **Flux** watch your main branch and automatically sync your cluster state to match. Branch protection on main is therefore critical in Kubernetes environments — a bad push to main triggers an automatic deploy to production. The `protect-main` ruleset you configured today is the foundation that makes GitOps safe.

---

## Challenges

**Challenge 1:**
You have a feature branch with 8 messy commits (typo fixes, "oops" commits, etc.). You squash merge it to main. How many commits appear on main from this PR? What happens to the 8 original commits?

```
Your answer:
```

---

**Challenge 2:**
A colleague says "I can't push my hotfix directly to main — the branch protection is blocking me and we have a production incident." What is the correct production procedure to handle this? What should they do?

```
Your answer:
```

---

**Challenge 3:**
You run `git branch -d feature/my-fix` and get this error:
```
error: The branch 'feature/my-fix' is not fully merged.
```
But you are certain the PR was merged to main 10 minutes ago. What caused this error and what command do you run to fix it?

```
Your answer:
```

---

**Challenge 4:**
Run these commands on `boa-devops-admin` and explain what each line of output means:
```bash
git log --oneline -5
git branch -a
```

```
Your answer:
```

---

**Challenge 5:**
You want to check if your local main is behind GitHub's main (i.e. someone else merged a PR while you were working). What single command tells you this without actually pulling any changes?

```
Your answer:
```