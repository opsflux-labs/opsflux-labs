#!/bin/bash
# new-lab.sh — run this from inside docs/ to create a new lab entry
# Usage: ./new-lab.sh "Lab Title" "TICKET-001"

TITLE="$1"
TICKET="$2"

if [ -z "$TITLE" ]; then
  echo "Usage: ./new-lab.sh \"Your Lab Title\" \"TICKET-001\""
  exit 1
fi

DATE=$(date +%Y-%m-%d)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')
FILENAME="docs/_labs/${DATE}-${SLUG}.md"

cat > "$FILENAME" << EOF
---
title: "${TICKET:+$TICKET: }$TITLE"
date: $DATE
summary: "Brief one line summary of what was done."
difficulty: beginner
duration: 45 mins
tags: [linux, gcp]
github_link: https://github.com/opsflux-labs/opsflux-app/tree/main/
---

## Scenario

Describe the environment and what needed to be done.

## Investigation

### Step Name

\`\`\`bash
# commands here
\`\`\`

### Step Name

\`\`\`bash
# commands here
\`\`\`

## Root Cause

What was found or identified.

## Fix

\`\`\`bash
# fix commands
\`\`\`

## Result

What was successfully validated or completed.

## Key Learnings

- Learning 1
- Learning 2
- Learning 3
EOF

echo "✓ Created: $FILENAME"
echo "→ Open it in VS Code and start writing!"
