#!/bin/bash
# Marge - Post-flight quality gate (reviews code before commit)
#
# Usage:
#   ./marge.sh                    Review staged changes before commit
#   ./marge.sh "custom context"   Review with additional context
#
# Exit codes:
#   0 = COMMIT (safe to proceed)
#   1 = REJECT (fix issues first)

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
    echo "Marge - Quality Gate (Post-flight)"
    echo ""
    echo "Usage:"
    echo "  ./marge.sh              Review staged changes before commit"
    echo "  ./marge.sh \"context\"    Review with additional context"
    echo ""
    echo "Marge reviews code for:"
    echo "  - Security vulnerabilities"
    echo "  - Outage risks"
    echo "  - Architecture violations"
    echo "  - Excessive complexity"
    echo ""
    echo "For pre-flight PRD review, use: ./bart.sh --prd"
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

                    case "$TOOL" in
                        Bash)
                            DESC=$(echo "$INPUT" | jq -r '.description // empty')
                            [ -z "$DESC" ] && DESC=$(echo "$INPUT" | jq -r '.command // empty' | head -c 60)
                            ;;
                        Read|Write|Edit)
                            DESC=$(echo "$INPUT" | jq -r '.file_path // empty' | sed 's|.*/||')
                            ;;
                        Glob|Grep)
                            DESC=$(echo "$INPUT" | jq -r '.pattern // empty')
                            ;;
                        Task)
                            DESC=$(echo "$INPUT" | jq -r '.prompt // empty' | head -c 50)
                            ;;
                        TodoWrite)
                            DESC=""
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

# Handle help
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    usage
    exit 0
fi

# Check for staged changes
if [ -z "$(git diff --staged)" ]; then
    echo -e "${RED}No staged changes to review.${NC}"
    echo "Stage your changes first: git add <files>"
    exit 1
fi

CONTEXT="${1:-}"

echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Marge Quality Gate: Diff Review${NC}"
echo -e "${YELLOW}  \"I'm not here to nitpick. I'm here to prevent 3am pages.\"${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""

echo "Reviewing staged changes:"
git diff --staged --stat
echo ""

# Build prompt
PROMPT="As the marge agent: Review the staged changes (git diff --staged) for security, architecture, outage risk, and complexity.

You BLOCK for:
- Security vulnerabilities (OWASP top 10)
- Will-cause-outage patterns
- Architecture violations
- Excessive complexity

You DO NOT block for:
- Style preferences
- Missing nice-to-have tests
- Theoretical future problems

Output either COMMIT or REJECT.

If COMMIT:
MARGE VERDICT: COMMIT
- Brief summary of what was reviewed
- Any notes for the developer

If REJECT:
MARGE VERDICT: REJECT
- What's wrong (specific file:line)
- Why it's a real problem
- How to fix it"

if [ -n "$CONTEXT" ]; then
    PROMPT="$PROMPT

Additional context: $CONTEXT"
fi

# Run review
RESULT=$(stream_claude "$PROMPT")

echo ""

# Check verdict
if echo "$RESULT" | grep -qi "REJECT"; then
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  MARGE VERDICT: REJECT${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo "Fix the issues above and run marge again."
    exit 1
else
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  MARGE VERDICT: COMMIT${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo "Safe to commit."
    exit 0
fi
