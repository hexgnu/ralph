#!/bin/bash
# Wrapper for claude -p that shows tool usage in real-time
# Usage: ./claude-stream.sh "your prompt here"

# Load nvm
export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
# shellcheck source=/dev/null
[[ -s "${NVM_DIR}/nvm.sh" ]] && . "${NVM_DIR}/nvm.sh"
nvm use --lts --silent 2> /dev/null || true

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

# Process claude stream output
process_stream() {
  while IFS= read -r line; do
    # Skip non-JSON lines (like bash_profile errors)
    if ! printf '%s' "${line}" | jq -e '.' > /dev/null 2>&1; then
      continue
    fi

    local msg_type tool text desc
    msg_type=$(printf '%s' "${line}" | jq -r '.type // empty' || :)

    case "${msg_type}" in
      assistant)
        # Check for tool use
        tool=$(printf '%s' "${line}" | jq -r '.message.content[0].name // empty' || :)
        if [[ -n "${tool}" ]]; then
          if [[ "${tool}" == "TodoWrite" ]]; then
            echo -e "${CYAN}→ ${tool}${NC}:"
            printf '%s' "${line}" | jq -r '.message.content[0].input.todos[] | "  [\(.status)] \(.content)"' 2> /dev/null || :
          else
            desc=$(printf '%s' "${line}" | jq -r '.message.content[0].input.description // .message.content[0].input.file_path // .message.content[0].input.command // .message.content[0].input.pattern // ""' 2> /dev/null | head -c 60 || :)
            echo -e "${CYAN}→ ${tool}${NC}: ${desc}"
          fi
        fi

        # Check for text response
        text=$(printf '%s' "${line}" | jq -r '.message.content[0].text // empty' || :)
        if [[ -n "${text}" ]]; then
          echo ""
          echo -e "${GREEN}${text}${NC}"
        fi
        ;;
      result)
        # Final result - skip since we already showed text above
        ;;
      system)
        # Init message - skip
        ;;
      *) ;; # Ignore other message types
    esac
  done
}

claude --verbose --output-format stream-json -p "$@" 2>&1 | process_stream || :
