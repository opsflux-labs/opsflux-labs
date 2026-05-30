#!/bin/bash
# new-lab.sh — run from ~/opsflux-labs/docs/
# Usage: bash new-lab.sh "Lab Title" "TICKET-001"

TITLE="$1"
TICKET="$2"

if [ -z "$TITLE" ]; then
  echo "Usage: bash new-lab.sh \"Your Lab Title\" \"TICKET-001\""
  exit 1
fi

DATE=$(date +%Y-%m-%d)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')
FILENAME="docs/_labs/${DATE}-${SLUG}.md"

cat > "$FILENAME" << EOF
---
title: "${TICKET:+$TICKET: }$TITLE"
date: $DATE
summary: "Brief one-line description of what this lab covers"
difficulty: beginner
duration: 60 mins
tags:
  - linux
  - gcp
github_link: ""
---

## Scenario

Describe the JIRA ticket and production context here.

## Investigation

### Phase 1 — Name
\`\`\`bash
# commands here
\`\`\`

**Output:**
\`\`\`
paste output here
\`\`\`

**What this means:**
Explain the output in production context.

## Root Cause

What was found or confirmed.

## Fix

\`\`\`bash
# fix commands if any
\`\`\`

## Result

What was validated and confirmed working.

## Challenges

### Challenge 1 — Name
**Command:**
\`\`\`bash
# command used
\`\`\`
**Output:**
\`\`\`
paste output
\`\`\`
**Finding:** one line summary

## Key Learnings

- Learning 1
- Learning 2
- Learning 3

## Command Reference

| Command | What it does | When to use |
|---|---|---|
| \`command\` | description | when |

EOF

echo "✅ Created: $FILENAME"
echo "→ Open in VS Code: code $FILENAME"