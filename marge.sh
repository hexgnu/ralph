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
shopt -s inherit_errexit

# Load nvm (required for claude command)
export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
# shellcheck source=/dev/null
[[ -s "${NVM_DIR}/nvm.sh" ]] && . "${NVM_DIR}/nvm.sh"
nvm use --lts --silent 2> /dev/null || true

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
  local prompt="${1}"

  claude --agent marge --dangerously-skip-permissions --verbose --output-format stream-json -p "${prompt}" 2>&1 | while IFS= read -r line; do
    # Skip non-JSON lines
    if ! printf '%s' "${line}" | jq -e '.' > /dev/null 2>&1; then
      continue
    fi

    local msg_type
    msg_type=$(printf '%s' "${line}" | jq -r '.type // empty' || :)

    case "${msg_type}" in
      assistant)
        local tool
        tool=$(printf '%s' "${line}" | jq -r '.message.content[0].name // empty' || :)
        if [[ -n "${tool}" ]]; then
          local input desc
          input=$(printf '%s' "${line}" | jq -r '.message.content[0].input // empty' || :)

          case "${tool}" in
            Bash)
              desc=$(printf '%s' "${input}" | jq -r '.description // empty' || :)
              [[ -z "${desc}" ]] && desc=$(printf '%s' "${input}" | jq -r '.command // empty' | head -c 60 || :)
              ;;
            Read | Write | Edit)
              desc=$(printf '%s' "${input}" | jq -r '.file_path // empty' | sed 's|.*/||' || :)
              ;;
            Glob | Grep)
              desc=$(printf '%s' "${input}" | jq -r '.pattern // empty' || :)
              ;;
            Task)
              desc=$(printf '%s' "${input}" | jq -r '.prompt // empty' | head -c 50 || :)
              ;;
            TodoWrite)
              desc=""
              ;;
            *)
              desc=$(printf '%s' "${input}" | jq -r '.description // .file_path // .pattern // .command // empty' | head -c 60 || :)
              ;;
          esac

          if [[ -n "${desc}" ]]; then
            echo -e "${CYAN}→ ${tool}:${NC} ${desc}"
          else
            echo -e "${CYAN}→ ${tool}${NC}"
          fi
        fi

        local text
        text=$(printf '%s' "${line}" | jq -r '.message.content[0].text // empty' || :)
        if [[ -n "${text}" ]]; then
          echo ""
          echo "${text}"
        fi
        ;;
      *) ;; # Ignore other message types
    esac
  done || :
}

# Squash Ralph's commits into one
squash_commits() {
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  Marge: Squash Ralph's Commits${NC}"
  echo -e "${YELLOW}  \"Let's tidy this up before it goes to main.\"${NC}"
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
  echo ""

  # Get current branch
  local current_branch base_branch merge_base
  current_branch=$(git branch --show-current)

  # Find the base branch (usually main)
  base_branch="main"
  if ! git rev-parse --verify "${base_branch}" > /dev/null 2>&1; then
    base_branch="master"
  fi

  # Find merge base
  merge_base=$(git merge-base "${base_branch}" HEAD)

  # Find Ralph's commits (those with US-XXX pattern)
  local ralph_commits ralph_commit_count
  ralph_commits=$(git log --oneline "${merge_base}"..HEAD --grep="US-[0-9][0-9]*" --format="%H")
  ralph_commit_count=$(printf '%s' "${ralph_commits}" | grep -c . || echo 0)

  if [[ "${ralph_commit_count}" -eq 0 ]]; then
    echo -e "${RED}No Ralph commits found (looking for US-XXX pattern).${NC}"
    echo "Ralph commits should have 'US-001', 'US-002', 'US-100', etc. in the message."
    echo ""
    echo "All commits on branch:"
    git log --oneline "${merge_base}"..HEAD
    exit 1
  fi

  if [[ "${ralph_commit_count}" -eq 1 ]]; then
    echo -e "${GREEN}Only 1 Ralph commit on branch - nothing to squash.${NC}"
    exit 0
  fi

  # Get the oldest Ralph commit's parent (where we'll reset to)
  local oldest_ralph_commit squash_base
  oldest_ralph_commit=$(printf '%s' "${ralph_commits}" | tail -1)
  squash_base=$(git rev-parse "${oldest_ralph_commit}^")

  echo -e "Branch: ${CYAN}${current_branch}${NC}"
  echo -e "Base: ${CYAN}${base_branch}${NC}"
  echo -e "Ralph commits to squash: ${CYAN}${ralph_commit_count}${NC}"
  echo ""

  echo "Ralph's commits (US-XXX):"
  git log --oneline "${merge_base}"..HEAD --grep="US-[0-9][0-9]*"
  echo ""

  echo "Changes:"
  git diff --stat "${squash_base}"..HEAD
  echo ""

  # Get Ralph's commit messages for context
  local commit_messages diff_stat full_diff
  commit_messages=$(git log --format="- %s" "${merge_base}"..HEAD --grep="US-[0-9][0-9]*")

  # Get the diff for review (from squash base, not merge base)
  diff_stat=$(git diff --stat "${squash_base}"..HEAD)
  full_diff=$(git diff "${squash_base}"..HEAD)

  echo -e "${CYAN}Marge is reviewing Ralph's work before squashing...${NC}"
  echo ""

  # First, have Marge review the full diff
  local review_prompt
  review_prompt="SQUASH REVIEW MODE

As Marge, review ALL of Ralph's work on this feature branch before we squash it into one commit.

Branch: ${current_branch}
Ralph's commits (${ralph_commit_count} total, identified by US-XXX pattern):
${commit_messages}

Files changed:
${diff_stat}

Full diff:
${full_diff}

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
  local review_result
  review_result=$(claude --agent marge --dangerously-skip-permissions -p "${review_prompt}" 2> /dev/null)

  # Check if rejected
  if printf '%s' "${review_result}" | grep -qi "VERDICT: REJECT"; then
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  MARGE SQUASH VERDICT: REJECT${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo ""
    printf '%s' "${review_result}" | grep -A 100 "Blocking Issues:" || printf '%s' "${review_result}"
    echo ""
    echo "Fix the issues above, commit the fixes, then run squash again."
    exit 1
  fi

  # Extract the commit message
  local squash_msg
  squash_msg=$(printf '%s' "${review_result}" | awk '/SQUASH_MESSAGE:/{found=1; next} found{print}' | sed 's/^[[:space:]]*//' || :)

  echo -e "${CYAN}Proposed squash commit message:${NC}"
  echo "────────────────────────────────────────────────────────"
  echo "${squash_msg}"
  echo "────────────────────────────────────────────────────────"
  echo ""

  # Ask for confirmation
  echo -e "${YELLOW}This will squash ${ralph_commit_count} Ralph commits into one.${NC}"
  read -p "Proceed with squash? [y/N] " -n 1 -r
  echo ""

  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo "Squash cancelled."
    exit 0
  fi

  # Perform the squash using soft reset to before Ralph's first commit
  echo -e "${CYAN}Squashing commits...${NC}"
  git reset --soft "${squash_base}"

  # Commit with the generated message
  git commit -m "${squash_msg}

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
if [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
  usage
  exit 0
fi

# Handle squash
if [[ "${1}" == "--squash" ]]; then
  squash_commits
  exit 0
fi

# Check for staged changes
if [[ -z "$(git diff --staged || :)" ]]; then
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

if [[ -n "${CONTEXT}" ]]; then
  PROMPT="${PROMPT}

Additional context: ${CONTEXT}"
fi

# Run review
RESULT=$(stream_claude "${PROMPT}")

echo ""

# Check verdict
if printf '%s' "${RESULT}" | grep -qi "REJECT"; then
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
  COMMIT_MSG=$(printf '%s' "${RESULT}" | awk '/COMMIT_MESSAGE:/{found=1; next} found{print}' | sed 's/^[[:space:]]*//' || :)

  if [[ -n "${COMMIT_MSG}" ]]; then
    echo -e "${CYAN}Suggested commit message:${NC}"
    echo "────────────────────────────────────────────────────────"
    echo "${COMMIT_MSG}"
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
