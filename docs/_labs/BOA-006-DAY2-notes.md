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
