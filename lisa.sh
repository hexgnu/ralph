#!/bin/bash
# Run Lisa planning agent
# Usage: ./lisa.sh "Plan: add feature X"

set -e

# Load nvm if available
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm use --lts --silent
fi

if [ -z "$1" ]; then
    echo "Usage: ./lisa.sh \"Plan: your feature description\""
    echo ""
    echo "Lisa will:"
    echo "  1. Gemba Walk - observe the codebase"
    echo "  2. A3 Analysis - define the problem"
    echo "  3. War Room - adversarial review"
    echo "  4. Output prd.json for Ralph"
    exit 1
fi

claude --dangerously-skip-permissions --agent lisa "$@"
