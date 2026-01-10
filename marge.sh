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
    echo "  ./marge.sh --squash     Squash Ralph's commits into one (run after Ralph completes)"
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

    claude --agent marge --dangerously-skip-permissions --verbose --output-format stream-json -p "$prompt" 2>&1 | while IFS= read -r line; do
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

# Squash Ralph's commits into one
squash_commits() {
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Marge: Squash Ralph's Commits${NC}"
    echo -e "${YELLOW}  \"Let's tidy this up before it goes to main.\"${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""

    # Get current branch
    CURRENT_BRANCH=$(git branch --show-current)

    # Find the base branch (usually main)
    BASE_BRANCH="main"
    if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
        BASE_BRANCH="master"
    fi

    # Find merge base
    MERGE_BASE=$(git merge-base "$BASE_BRANCH" HEAD)

    # Find Ralph's commits (those with US-XXX pattern)
    RALPH_COMMITS=$(git log --oneline "$MERGE_BASE"..HEAD --grep="US-[0-9]" --format="%H")
    RALPH_COMMIT_COUNT=$(echo "$RALPH_COMMITS" | grep -c . || echo 0)

    if [ "$RALPH_COMMIT_COUNT" -eq 0 ]; then
        echo -e "${RED}No Ralph commits found (looking for US-XXX pattern).${NC}"
        echo "Ralph commits should have 'US-001', 'US-002', etc. in the message."
        echo ""
        echo "All commits on branch:"
        git log --oneline "$MERGE_BASE"..HEAD
        exit 1
    fi

    if [ "$RALPH_COMMIT_COUNT" -eq 1 ]; then
        echo -e "${GREEN}Only 1 Ralph commit on branch - nothing to squash.${NC}"
        exit 0
    fi

    # Get the oldest Ralph commit's parent (where we'll reset to)
    OLDEST_RALPH_COMMIT=$(echo "$RALPH_COMMITS" | tail -1)
    SQUASH_BASE=$(git rev-parse "$OLDEST_RALPH_COMMIT^")

    echo -e "Branch: ${CYAN}$CURRENT_BRANCH${NC}"
    echo -e "Base: ${CYAN}$BASE_BRANCH${NC}"
    echo -e "Ralph commits to squash: ${CYAN}$RALPH_COMMIT_COUNT${NC}"
    echo ""

    echo "Ralph's commits (US-XXX):"
    git log --oneline "$MERGE_BASE"..HEAD --grep="US-[0-9]"
    echo ""

    echo "Changes:"
    git diff --stat "$SQUASH_BASE"..HEAD
    echo ""

    # Get Ralph's commit messages for context
    COMMIT_MESSAGES=$(git log --format="- %s" "$MERGE_BASE"..HEAD --grep="US-[0-9]")

    # Get the diff for review (from squash base, not merge base)
    DIFF_STAT=$(git diff --stat "$SQUASH_BASE"..HEAD)
    FULL_DIFF=$(git diff "$SQUASH_BASE"..HEAD)

    echo -e "${CYAN}Marge is reviewing Ralph's work before squashing...${NC}"
    echo ""

    # First, have Marge review the full diff
    REVIEW_PROMPT="SQUASH REVIEW MODE

As Marge, review ALL of Ralph's work on this feature branch before we squash it into one commit.

Branch: $CURRENT_BRANCH
Ralph's commits ($RALPH_COMMIT_COUNT total, identified by US-XXX pattern):
$COMMIT_MESSAGES

Files changed:
$DIFF_STAT

Full diff:
$FULL_DIFF

Review this work for:
- Security issues
- Architecture concerns
- Outage risks
- Anything that should NOT go to main

Then provide your verdict:

If APPROVE:
MARGE SQUASH VERDICT: APPROVE

[Brief summary of what looks good]

SQUASH_MESSAGE:
<type>(<scope>): <subject>

<body describing the overall change>

If REJECT:
MARGE SQUASH VERDICT: REJECT

Blocking Issues:
- [Issue 1]
- [Issue 2]

These must be fixed before squashing."

    # Run the review
    REVIEW_RESULT=$(claude --agent marge --dangerously-skip-permissions -p "$REVIEW_PROMPT" 2>/dev/null)

    # Check if rejected
    if echo "$REVIEW_RESULT" | grep -qi "VERDICT: REJECT"; then
        echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  MARGE SQUASH VERDICT: REJECT${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo "$REVIEW_RESULT" | grep -A 100 "Blocking Issues:" || echo "$REVIEW_RESULT"
        echo ""
        echo "Fix the issues above, commit the fixes, then run squash again."
        exit 1
    fi

    # Extract the commit message
    SQUASH_MSG=$(echo "$REVIEW_RESULT" | awk '/SQUASH_MESSAGE:/{found=1; next} found{print}' | sed 's/^[[:space:]]*//')

    echo -e "${CYAN}Proposed squash commit message:${NC}"
    echo "────────────────────────────────────────────────────────"
    echo "$SQUASH_MSG"
    echo "────────────────────────────────────────────────────────"
    echo ""

    # Ask for confirmation
    echo -e "${YELLOW}This will squash $RALPH_COMMIT_COUNT Ralph commits into one.${NC}"
    read -p "Proceed with squash? [y/N] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Squash cancelled."
        exit 0
    fi

    # Perform the squash using soft reset to before Ralph's first commit
    echo -e "${CYAN}Squashing commits...${NC}"
    git reset --soft "$SQUASH_BASE"

    # Commit with the generated message
    git commit -m "$SQUASH_MSG

Co-Authored-By: Ralph (Claude Agent) <noreply@anthropic.com>
Reviewed-By: Marge (Claude Agent) <noreply@anthropic.com>"

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Squash Complete${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "New commit:"
    git log -1 --oneline
    echo ""
    echo "Ready to push or create PR."
}

# Handle help
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    usage
    exit 0
fi

# Handle squash
if [ "$1" == "--squash" ]; then
    squash_commits
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
PROMPT="DIFF REVIEW MODE

As the marge agent: Review the staged changes (git diff --staged) for security, architecture, outage risk, and complexity.

You BLOCK for:
- Security vulnerabilities (OWASP top 10)
- Will-cause-outage patterns
- Architecture violations
- Excessive complexity

You DO NOT block for:
- Style preferences
- Missing nice-to-have tests
- Theoretical future problems

Output either COMMIT or REJECT using the exact format below.

If COMMIT:
MARGE VERDICT: COMMIT

Reviewed: [N files, M lines changed]

Checks:
- Security: PASS
- Architecture: PASS
- Outage Risk: PASS
- Simplicity: PASS
- Operability: PASS

COMMIT_MESSAGE:
<type>(<scope>): <subject>

<body - what changed and why>

Where type is: feat | fix | refactor | docs | test | chore | perf | style

If REJECT:
MARGE VERDICT: REJECT

Blocking Issue:
- Category: [Security | Architecture | Outage | Complexity | Operability]
- File: [path:line]
- Confidence: HIGH
- What's wrong and how to fix it"

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
    echo ""

    # Extract commit message (everything after COMMIT_MESSAGE: to end)
    COMMIT_MSG=$(echo "$RESULT" | awk '/COMMIT_MESSAGE:/{found=1; next} found{print}' | sed 's/^[[:space:]]*//')

    if [ -n "$COMMIT_MSG" ]; then
        echo -e "${CYAN}Suggested commit message:${NC}"
        echo "────────────────────────────────────────────────────────"
        echo "$COMMIT_MSG"
        echo "────────────────────────────────────────────────────────"
        echo ""
        echo "To commit, run:"
        echo "  git commit -m \"\$COMMIT_MSG\""
        echo ""
        echo "Or copy the message above."
    else
        echo "Safe to commit. (No commit message generated)"
    fi
    exit 0
fi
