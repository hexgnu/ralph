#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [prd_file.json] [max_iterations]
# Examples:
#   ./ralph.sh                  # uses prd.json, 10 iterations
#   ./ralph.sh prd1.json        # uses prd1.json, 10 iterations
#   ./ralph.sh prd1.json 20     # uses prd1.json, 20 iterations
#   ./ralph.sh 20               # uses prd.json, 20 iterations

set -e

# Load nvm (required for claude command)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use --lts --silent 2>/dev/null || true

# Parse arguments: [prd_file.json] [max_iterations]
# Examples: ./ralph.sh prd1.json 10
#           ./ralph.sh prd1.json
#           ./ralph.sh 10
#           ./ralph.sh
if [[ "$1" == *.json ]]; then
  PRD_ARG="$1"
  MAX_ITERATIONS=${2:-10}
else
  PRD_ARG=""
  MAX_ITERATIONS=${1:-10}
fi

WORK_DIR="$(pwd)"
PRD_FILE="${PRD_ARG:-$WORK_DIR/prd.json}"
# Make relative paths absolute
[[ "$PRD_FILE" != /* ]] && PRD_FILE="$WORK_DIR/$PRD_FILE"
SESSION_DATE=$(date +%Y-%m-%d_%H%M%S)
PROGRESS_FILE="$WORK_DIR/progress-$SESSION_DATE.txt"
ARCHIVE_DIR="$WORK_DIR/archive"
LAST_BRANCH_FILE="$WORK_DIR/.last-branch"

# Colors
CYAN='\033[0;36m'
NC='\033[0m'

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
                    # Write to temp file for completion check
                    echo "$TEXT" >> /tmp/ralph-output-$$
                fi
                ;;
        esac
    done
}

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Verify PRD file exists
if [ ! -f "$PRD_FILE" ]; then
  echo "Error: PRD file not found: $PRD_FILE"
  exit 1
fi

echo "Starting Ralph"
echo "  PRD file: $PRD_FILE"
echo "  Progress: $PROGRESS_FILE"
echo "  Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Ralph Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════"

  # Clear temp output file
  rm -f /tmp/ralph-output-$$

  # Run with streaming
  stream_claude "As the ralph agent: Execute the next story from $PRD_FILE"

  # Check for completion signal
  if [ -f /tmp/ralph-output-$$ ] && grep -q "<promise>COMPLETE</promise>" /tmp/ralph-output-$$; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    rm -f /tmp/ralph-output-$$
    exit 0
  fi

  rm -f /tmp/ralph-output-$$
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
