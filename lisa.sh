#!/bin/bash
# Run Lisa planning agent
# Usage: ./lisa.sh "Plan: add feature X"

set -e

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

claude --agent lisa "$@"
