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
  echo "Lisa - Planning Agent"
  echo ""
  echo "Usage: ./lisa.sh [--name <name>] \"Plan: your feature description\""
  echo ""
  echo "Lisa will:"
  echo "  1. Gemba Walk - observe the codebase"
  echo "  2. A3 Analysis - define the problem"
  echo "  3. War Room - adversarial review"
  echo "  4. Output PRD for Ralph"
  echo ""
  echo "Options:"
  echo "  --name <name>  Output to prd-<name>.json (default: prd.json)"
  echo "  --help         Show this help"
  echo ""
  echo "Examples:"
  echo "  ./lisa.sh \"Plan: add user authentication\""
  echo "  ./lisa.sh --name oauth \"Plan: add OAuth support\""
  echo "  ./lisa.sh --name 2024-01-15 \"Plan: refactor API\""
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
    msg_type=$(printf '%s' "${line}" | jq -r '.type // empty' || :)

    case "${msg_type}" in
      assistant)
        local tool
        tool=$(printf '%s' "${line}" | jq -r '.message.content[0].name // empty' || :)
        if [[ -n "${tool}" ]]; then
          local input desc
          input=$(printf '%s' "${line}" | jq -r '.message.content[0].input // empty' || :)

          # Get description based on tool type (prefer description field)
          case "${tool}" in
            Bash)
              desc=$(printf '%s' "${input}" | jq -r '.description // empty' || :)
              [[ -z "${desc}" ]] && desc=$(printf '%s' "${input}" | jq -r '.command // empty' | head -c 60 || :)
              ;;
            Read | Write | Edit)
              desc=$(printf '%s' "${input}" | jq -r '.file_path // empty' | sed 's|.*/||' || :) # basename only
              ;;
            Glob | Grep)
              desc=$(printf '%s' "${input}" | jq -r '.pattern // empty' || :)
              ;;
            Task)
              desc=$(printf '%s' "${input}" | jq -r '.prompt // empty' | head -c 50 || :)
              ;;
            TodoWrite)
              desc="" # No meaningful short description
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

# Parse arguments
PRD_NAME=""
PROMPT=""

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --help | -h)
      usage
      exit 0
      ;;
    --name)
      if [[ -z "${2}" ]]; then
        echo "Error: --name requires a value"
        exit 1
      fi
      PRD_NAME="${2}"
      shift 2
      ;;
    *)
      PROMPT="$*"
      break
      ;;
  esac
done

if [[ -z "${PROMPT}" ]]; then
  usage
  exit 1
fi

# Set PRD filename
if [[ -n "${PRD_NAME}" ]]; then
  PRD_FILE="prd-${PRD_NAME}.json"
else
  PRD_FILE="prd.json"
fi

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Lisa Planning Agent${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Planning:${NC} ${PROMPT}"
echo -e "${YELLOW}PRD File:${NC} ${PRD_FILE}"
echo ""

# Run with streaming output
# Be explicit about following the full workflow to produce artifacts
stream_claude "As the lisa agent, follow your complete workflow (Gemba Walk → A3 Analysis → Bart chaos review → PRD).

Your task: ${PROMPT}

You MUST produce these artifacts:
- gemba-report.md
- a3-analysis.md
- war-room-verdict.md (from Bart)
- ${PRD_FILE} (the PRD file - use this exact filename)

Do not just answer the question. Execute your full planning workflow and create the files."

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Lisa Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Show what was created
echo "Artifacts:"
for file in "${PRD_FILE}" gemba-report.md a3-analysis.md war-room-verdict.md progress.txt; do
  if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
    echo -e "  ${GREEN}✓${NC} ${file}"
  else
    echo -e "  ${RED}✗${NC} ${file} (not created)"
  fi
done

echo ""

# Show PRD summary if it exists
if [[ -f "${SCRIPT_DIR}/${PRD_FILE}" ]]; then
  echo "PRD Summary:"
  jq -r '.userStories[] | "  [\(.id)] \(.title)"' "${SCRIPT_DIR}/${PRD_FILE}" 2> /dev/null || echo "  (could not parse ${PRD_FILE})"
  echo ""
  echo "Next steps:"
  echo "  1. Review the PRD:     cat ${PRD_FILE} | jq ."
  echo "  2. Chaos test:         ./bart.sh --prd ${PRD_FILE}"
  echo "  3. Execute:            ./ralph.sh ${PRD_FILE}"
fi
