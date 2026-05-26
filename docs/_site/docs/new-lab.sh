#!/bin/bash
# new-lab.sh — run this from inside docs/ to create a new lab entry
# Usage: ./new-lab.sh "Debugging OOMKilled pods in Kubernetes"

TITLE="$1"

if [ -z "$TITLE" ]; then
  echo "Usage: ./new-lab.sh \"Your Lab Title Here\""
  exit 1
fi

DATE=$(date +%Y-%m-%d)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')
FILENAME="_labs/${DATE}-${SLUG}.md"

cat > "$FILENAME" << EOF
---
title: "$TITLE"
date: $DATE
summary: "One or two sentences describing what you built or debugged."
difficulty: intermediate
duration: 45 mins
tags: [kubernetes, debugging]
github_link: https://github.com/opsflux-labs/opsflux-app/tree/main/kubernetes/
---

## Scenario

Describe the ticket or problem here.

## Investigation

What did you check first?

\`\`\`bash
# commands you ran
\`\`\`

## Root Cause

What was the actual problem?

## Fix

How did you fix it?

\`\`\`bash
# fix commands
\`\`\`

## Result

What happened after the fix?

## Key Learnings

- Learning 1
- Learning 2
- Learning 3

---

> **Time taken:** 45 minutes | **Difficulty:** Intermediate
EOF

echo "✓ Created: $FILENAME"
echo "→ Open it in VS Code and start writing!"
