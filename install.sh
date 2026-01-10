#!/bin/bash
# Install Ralph agents and CLI tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$HOME/.claude/agents"
BIN_DIR="/usr/local/bin"

# Install agents to ~/.claude/agents/
mkdir -p "$AGENT_DIR"

echo "Installing Ralph agents to $AGENT_DIR..."
cp "$SCRIPT_DIR/agents/"*.md "$AGENT_DIR/"

echo "Installed agents:"
ls -1 "$AGENT_DIR/"*.md | xargs -n1 basename

# Install CLI tools to /usr/local/bin
echo ""
echo "Installing CLI tools to $BIN_DIR..."
echo "(This may require sudo password)"

for script in lisa.sh marge.sh ralph.sh bart.sh claude-stream.sh worktree.sh; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        name="${script%.sh}"
        sudo cp "$SCRIPT_DIR/$script" "$BIN_DIR/$name"
        sudo chmod +x "$BIN_DIR/$name"
        echo "  Installed: $name"
    fi
done

echo ""
echo "Done. Agents and CLI tools are now available globally."
echo ""
echo "Available commands:"
echo "  lisa           - Planning agent (creates prd.json)"
echo "  bart --prd     - Pre-flight chaos testing (try to break the PRD)"
echo "  bart --branch  - Chaos test a branch before merge"
echo "  ralph          - Execute PRD stories"
echo "  marge          - Post-flight quality gate (review before commit)"
echo "  claude-stream  - Verbose claude -p with tool visibility"
echo "  worktree       - Create git worktree for isolated development"
