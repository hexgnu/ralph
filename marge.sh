#!/bin/bash
# Run Marge quality gate on staged changes
# Usage: ./marge.sh

set -e

# Load nvm if available
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm use --lts --silent
fi

if [ -z "$(git diff --staged)" ]; then
    echo "No staged changes to review."
    echo "Stage your changes first: git add <files>"
    exit 1
fi

claude --dangerously-skip-permissions --agent marge "Review the staged changes (git diff --staged)"
