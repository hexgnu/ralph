#!/bin/bash
# Run Marge quality gate on staged changes
# Usage: ./marge.sh

set -e

if [ -z "$(git diff --staged)" ]; then
    echo "No staged changes to review."
    echo "Stage your changes first: git add <files>"
    exit 1
fi

claude --agent marge "Review the staged changes (git diff --staged)"
