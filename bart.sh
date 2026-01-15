#!/bin/bash
# Bart - Pre-flight chaos agent
#
# Usage:
#   ./bart.sh --prd              Chaos test the PRD before Ralph starts
#   ./bart.sh --branch           Chaos test a branch before merging
#   ./bart.sh "custom prompt"    Chaos test anything
#
# Exit codes:
#   0 = Chaos testing complete (findings reported, not blocking)
#   1 = Error

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="${PRD_FILE:-${SCRIPT_DIR}/prd.json}"

# Load nvm (required for claude command)
export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
# shellcheck source=/dev/null
[[ -s "${NVM_DIR}/nvm.sh" ]] && . "${NVM_DIR}/nvm.sh"
nvm use --lts --silent 2> /dev/null || true

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  echo "Bart - Chaos Agent"
  echo ""
  echo "Usage:"
  echo "  ./bart.sh --prd [file]  Chaos test PRD before execution (default: prd.json)"
  echo "  ./bart.sh --branch      Chaos test current branch before merge"
  echo "  ./bart.sh \"prompt\"      Chaos test anything"
  echo ""
  echo "Examples:"
  echo "  ./bart.sh --prd                    # uses prd.json"
  echo "  ./bart.sh --prd prd-oauth.json     # uses prd-oauth.json"
  echo ""
  echo "Bart tries to break things. He finds edge cases, challenges"
  echo "assumptions, and asks 'what could go wrong?'"
}

# Stream claude output with tool visibility (Claude Code style)
stream_claude() {
  local prompt="${1}"

  claude --dangerously-skip-permissions --verbose --output-format stream-json -p "${prompt}" 2>&1 | while IFS= read -r line; do
    # Skip non-JSON lines
    if ! printf '%s' "${line}" | jq -e '.' > /dev/null 2>&1; then
      continue
    fi

    local msg_type
    msg_type=$(printf '%s' "${line}" | jq -r '.type // empty')

    case "${msg_type}" in
      assistant)
        local tool
        tool=$(printf '%s' "${line}" | jq -r '.message.content[0].name // empty')
        if [[ -n "${tool}" ]]; then
          local input desc
          input=$(printf '%s' "${line}" | jq -r '.message.content[0].input // empty')

          case "${tool}" in
            Bash)
              desc=$(printf '%s' "${input}" | jq -r '.description // empty')
              [[ -z "${desc}" ]] && desc=$(printf '%s' "${input}" | jq -r '.command // empty' | head -c 60)
              ;;
            Read | Write | Edit)
              desc=$(printf '%s' "${input}" | jq -r '.file_path // empty' | sed 's|.*/||')
              ;;
            Glob | Grep)
              desc=$(printf '%s' "${input}" | jq -r '.pattern // empty')
              ;;
            Task)
              desc=$(printf '%s' "${input}" | jq -r '.prompt // empty' | head -c 50)
              ;;
            TodoWrite)
              desc=""
              ;;
            *)
              desc=$(printf '%s' "${input}" | jq -r '.description // .file_path // .pattern // .command // empty' | head -c 60)
              ;;
          esac

          if [[ -n "${desc}" ]]; then
            echo -e "${CYAN}→ ${tool}:${NC} ${desc}"
          else
            echo -e "${CYAN}→ ${tool}${NC}"
          fi
        fi

        local text
        text=$(printf '%s' "${line}" | jq -r '.message.content[0].text // empty')
        if [[ -n "${text}" ]]; then
          echo ""
          echo "${text}"
        fi
        ;;
      *) ;;  # Ignore other message types
    esac
  done
}

# Chaos test the PRD
chaos_prd() {
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  Bart Chaos Test: PRD Review${NC}"
  echo -e "${YELLOW}  \"Eat my shorts... but first, let me break your plan\"${NC}"
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
  echo ""

  if [[ ! -f "${PRD_FILE}" ]]; then
    echo -e "${RED}Error: PRD file not found: ${PRD_FILE}${NC}"
    echo "Run Lisa first to generate a PRD, or specify the correct file:"
    echo "  ./bart.sh --prd prd-oauth.json"
    exit 1
  fi

  echo -e "PRD File: ${CYAN}${PRD_FILE}${NC}"

  echo "PRD Stories:"
  jq -r '.userStories[] | "  [\(.id)] \(.title)"' "${PRD_FILE}" 2> /dev/null || cat "${PRD_FILE}"
  echo ""

  stream_claude "As the bart agent (chaos tester): Review this PRD and try to break it.

Your job is to be adversarial. For each story, ask:
- What's the weirdest valid input?
- What happens at the boundaries?
- What if two things happen simultaneously?
- What assumptions might be wrong?
- What edge cases will bite us in production?

Don't just say 'looks good'. Find the holes. Be mischievous but constructive.

Output format:
## Chaos Report

### [Story ID]: [Ways it could break]
- Edge case 1
- Edge case 2

### Assumptions I'm Questioning
- Assumption: why I'm suspicious

### Recommended Tests Before Shipping
1. Test case
2. Test case

PRD Contents:
$(cat "${PRD_FILE}")"

  echo ""
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  Bart Complete - Review findings above${NC}"
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
}

# Chaos test a branch
chaos_branch() {
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  Bart Chaos Test: Branch Review${NC}"
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
  echo ""

  local branch
  branch=$(git branch --show-current)
  echo "Branch: ${branch}"
  echo ""

  echo "Changes from main:"
  git diff main...HEAD --stat 2> /dev/null || git diff HEAD~5 --stat
  echo ""

  stream_claude "As the bart agent (chaos tester): Review this branch and try to break it.

Look at the git diff and find:
- Edge cases nobody tested
- Race conditions
- Assumptions that could be wrong
- Ways a malicious or confused user could cause problems
- What happens under load?
- What happens with bad data?

Be adversarial. Find the holes.

Output:
## Chaos Report for branch: ${branch}

### Things That Could Break
1. [Scenario]: [How it breaks]

### Edge Cases to Test
1. [Test case]

### Questions for the Developer
1. [Question about an assumption]"

  echo ""
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  Bart Complete${NC}"
  echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
}

# Parse arguments
case "${1:-}" in
  --prd)
    # Check for optional PRD filename argument
    if [[ -n "${2:-}" ]] && [[ "${2}" == *.json ]]; then
      PRD_FILE="${SCRIPT_DIR}/${2}"
    fi
    chaos_prd
    ;;
  --branch)
    chaos_branch
    ;;
  --help | -h)
    usage
    exit 0
    ;;
  "")
    usage
    exit 1
    ;;
  *)
    # Custom prompt
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Bart Chaos Test${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    stream_claude "As the bart agent (chaos tester): $*"
    ;;
esac
