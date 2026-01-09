#!/bin/bash
# Install Ralph agents to ~/.claude/agents/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/agents"

mkdir -p "$TARGET_DIR"

echo "Installing Ralph agents to $TARGET_DIR..."
cp "$SCRIPT_DIR/agents/"*.md "$TARGET_DIR/"

echo "Installed:"
ls -1 "$TARGET_DIR/"*.md | xargs -n1 basename

echo ""
echo "Done. Agents are now available globally."
