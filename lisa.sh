#!/bin/bash
# Lisa - Non-interactive planning agent
#
# Usage: ./lisa.sh "Plan: add feature X"
#
# Output:
#   - prd.json (user stories for Ralph)
#   - gemba-report.md (codebase reality report)
#   - a3-analysis.md (problem definition)
#   - war-room-verdict.md (adversarial review)
#   - progress.txt (initialized for Ralph)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load nvm (required for claude command)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use --lts --silent 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Lisa - Planning Agent"
    echo ""
    echo "Usage: ./lisa.sh \"Plan: your feature description\""
    echo ""
    echo "Lisa will:"
    echo "  1. Gemba Walk - observe the codebase"
    echo "  2. A3 Analysis - define the problem"
    echo "  3. War Room - adversarial review"
    echo "  4. Output prd.json for Ralph"
    echo ""
    echo "Options:"
    echo "  --help    Show this help"
}

# Stream claude output with tool visibility (Claude Code style)
stream_claude() {
    local prompt="$1"

    claude --dangerously-skip-permissions --verbose --output-format stream-json -p "$prompt" 2>&1 | while IFS= read -r line; do
        # Skip non-JSON lines
        if ! echo "$line" | jq -e '.' >/dev/null 2>&1; then
            continue
        fi

        TYPE=$(echo "$line" | jq -r '.type // empty')

        case "$TYPE" in
            assistant)
                TOOL=$(echo "$line" | jq -r '.message.content[0].name // empty')
                if [ -n "$TOOL" ]; then
                    INPUT=$(echo "$line" | jq -r '.message.content[0].input // empty')

                    # Get description based on tool type (prefer description field)
                    case "$TOOL" in
                        Bash)
                            DESC=$(echo "$INPUT" | jq -r '.description // empty')
                            [ -z "$DESC" ] && DESC=$(echo "$INPUT" | jq -r '.command // empty' | head -c 60)
                            ;;
                        Read|Write|Edit)
                            DESC=$(echo "$INPUT" | jq -r '.file_path // empty' | sed 's|.*/||')  # basename only
                            ;;
                        Glob|Grep)
                            DESC=$(echo "$INPUT" | jq -r '.pattern // empty')
                            ;;
                        Task)
                            DESC=$(echo "$INPUT" | jq -r '.prompt // empty' | head -c 50)
                            ;;
                        TodoWrite)
                            DESC=""  # No meaningful short description
                            ;;
                        *)
                            DESC=$(echo "$INPUT" | jq -r '.description // .file_path // .pattern // .command // empty' | head -c 60)
                            ;;
                    esac

                    if [ -n "$DESC" ]; then
                        echo -e "${CYAN}→ ${TOOL}:${NC} ${DESC}"
                    else
                        echo -e "${CYAN}→ ${TOOL}${NC}"
                    fi
                fi

                TEXT=$(echo "$line" | jq -r '.message.content[0].text // empty')
                if [ -n "$TEXT" ]; then
                    echo ""
                    echo "$TEXT"
                fi
                ;;
        esac
    done
}

if [ -z "$1" ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    usage
    exit 1
fi

PROMPT="$*"

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Lisa Planning Agent${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Planning:${NC} $PROMPT"
echo ""

# Run with streaming output
# Be explicit about following the full workflow to produce artifacts
stream_claude "As the lisa agent, follow your complete workflow (Gemba Walk → A3 Analysis → Bart chaos review → prd.json).

Your task: $PROMPT

You MUST produce these artifacts:
- gemba-report.md
- a3-analysis.md
- war-room-verdict.md (from Bart)
- prd.json

Do not just answer the question. Execute your full planning workflow and create the files."

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Lisa Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Show what was created
echo "Artifacts:"
for file in prd.json gemba-report.md a3-analysis.md war-room-verdict.md progress.txt; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file (not created)"
    fi
done

echo ""

# Show PRD summary if it exists
if [ -f "$SCRIPT_DIR/prd.json" ]; then
    echo "PRD Summary:"
    jq -r '.userStories[] | "  [\(.id)] \(.title)"' "$SCRIPT_DIR/prd.json" 2>/dev/null || echo "  (could not parse prd.json)"
    echo ""
    echo "Next steps:"
    echo "  1. Review the PRD:     cat prd.json | jq ."
    echo "  2. Chaos test:         ./bart.sh --prd"
    echo "  3. Execute:            ./ralph.sh"
fi
