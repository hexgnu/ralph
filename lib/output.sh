#!/usr/bin/env bash
# lib/output.sh - Shared output formatting library for Ralph scripts
# Compatible with bash 3.2+ (macOS)
#
# shellcheck disable=SC2034  # Variables are exported for sourcing scripts

# Guard against double-sourcing
if [[ -n "${OUTPUT_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
OUTPUT_SH_LOADED=1

# TTY detection - disable colors when stdout is not a terminal
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    BOLD=''
    NC=''
fi

# check_dependencies - Verify required tools are installed
# Usage: check_dependencies
# Returns: 0 if all dependencies present, 1 otherwise
check_dependencies() {
    if ! command -v jq &>/dev/null; then
        printf "%sError: jq is required but not installed.%s\n" "$RED" "$NC" >&2
        printf "Install with: brew install jq (macOS) or apt-get install jq (Linux)\n" >&2
        return 1
    fi
    return 0
}

# print_header - Display agent name and optional elapsed time
# Usage: print_header "Agent Name" ["elapsed time"]
print_header() {
    local agent_name="${1:-}"
    local elapsed="${2:-}"

    if [[ -n "$elapsed" ]]; then
        printf "%s%s=== %s [%s] ===%s\n" "$BOLD" "$CYAN" "$agent_name" "$elapsed" "$NC"
    else
        printf "%s%s=== %s ===%s\n" "$BOLD" "$CYAN" "$agent_name" "$NC"
    fi
}

# print_tool - Format tool invocations with arrow prefix
# Usage: print_tool "tool_name" ["tool_input"]
print_tool() {
    local tool_name="${1:-}"
    local tool_input="${2:-}"

    if [[ -n "$tool_input" ]]; then
        printf "%s-> %s:%s %s\n" "$YELLOW" "$tool_name" "$NC" "$tool_input"
    else
        printf "%s-> %s%s\n" "$YELLOW" "$tool_name" "$NC"
    fi
}

# print_success - Show green checkmark + message
# Usage: print_success "message"
print_success() {
    local message="${1:-}"
    printf "%s[OK]%s %s\n" "$GREEN" "$NC" "$message"
}

# print_error - Show red X + message
# Usage: print_error "message"
print_error() {
    local message="${1:-}"
    printf "%s[ERROR]%s %s\n" "$RED" "$NC" "$message"
}

# print_info - General informational output
# Usage: print_info "message"
print_info() {
    local message="${1:-}"
    printf "%s[INFO]%s %s\n" "$CYAN" "$NC" "$message"
}

# parse_tool_result - Extract exit code and output from tool result JSON
# Usage: parse_tool_result "json_string" [max_lines]
# Output: Prints extracted fields, sets global variables:
#   TOOL_EXIT_CODE - exit code (0 if not present)
#   TOOL_OUTPUT - truncated output string
#   TOOL_IS_ERROR - 1 if error detected, 0 otherwise
#   TOOL_TOTAL_LINES - total number of lines in original output
parse_tool_result() {
    local json="${1:-}"
    local max_lines="${2:-5}"
    local max_line_length=500

    # Initialize globals
    TOOL_EXIT_CODE=0
    TOOL_OUTPUT=""
    TOOL_IS_ERROR=0
    TOOL_TOTAL_LINES=0

    # Check dependencies
    if ! check_dependencies; then
        TOOL_IS_ERROR=1
        TOOL_OUTPUT="jq not installed"
        return 1
    fi

    # Handle empty input
    if [[ -z "$json" ]]; then
        TOOL_IS_ERROR=1
        TOOL_OUTPUT="Empty JSON input"
        return 1
    fi

    # Try to parse JSON - handle malformed gracefully
    local exit_code output
    exit_code=$(printf '%s' "$json" | jq -r '.exit_code // .exitCode // 0' 2>/dev/null) || {
        TOOL_IS_ERROR=1
        TOOL_OUTPUT="Malformed JSON"
        return 1
    }

    output=$(printf '%s' "$json" | jq -r '.output // .stdout // .result // ""' 2>/dev/null) || {
        TOOL_IS_ERROR=1
        TOOL_OUTPUT="Malformed JSON"
        return 1
    }

    TOOL_EXIT_CODE="${exit_code:-0}"

    # Count total lines
    if [[ -n "$output" ]]; then
        TOOL_TOTAL_LINES=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
    else
        TOOL_TOTAL_LINES=0
    fi

    # Truncate to max_lines
    local truncated_output
    if [[ "$TOOL_TOTAL_LINES" -gt "$max_lines" ]]; then
        truncated_output=$(printf '%s' "$output" | head -n "$max_lines")
    else
        truncated_output="$output"
    fi

    # Truncate long lines
    local final_output=""
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "${#line}" -gt "$max_line_length" ]]; then
            line="${line:0:$max_line_length}..."
        fi
        if [[ -n "$final_output" ]]; then
            final_output="${final_output}
${line}"
        else
            final_output="$line"
        fi
    done <<< "$truncated_output"

    TOOL_OUTPUT="$final_output"

    # Detect errors - case insensitive patterns
    local lower_output
    lower_output=$(printf '%s' "$output" | tr '[:upper:]' '[:lower:]')

    # Check exit code first
    if [[ "$TOOL_EXIT_CODE" -ne 0 ]]; then
        TOOL_IS_ERROR=1
    fi

    # Check for error patterns (case-insensitive)
    if printf '%s' "$lower_output" | grep -qE '(error|failed|exception|permission denied|no such file|command not found)'; then
        TOOL_IS_ERROR=1
    fi

    return 0
}

# print_tool_result - Display tool result with success/failure indicator
# Usage: print_tool_result "tool_name" "json_result" [max_lines]
print_tool_result() {
    local tool_name="${1:-}"
    local json="${2:-}"
    local max_lines="${3:-5}"

    # Parse the result
    parse_tool_result "$json" "$max_lines"
    local parse_status=$?

    # Display based on error status
    if [[ "$TOOL_IS_ERROR" -eq 1 ]]; then
        printf "%s[FAIL]%s %s (exit: %s)\n" "$RED" "$NC" "$tool_name" "$TOOL_EXIT_CODE"
    else
        printf "%s[OK]%s %s\n" "$GREEN" "$NC" "$tool_name"
    fi

    # Print output if present
    if [[ -n "$TOOL_OUTPUT" ]]; then
        printf "%s\n" "$TOOL_OUTPUT"
    fi

    # Show truncation message if applicable
    if [[ "$TOOL_TOTAL_LINES" -gt "$max_lines" ]]; then
        local remaining=$((TOOL_TOTAL_LINES - max_lines))
        printf "%s[... %d more lines]%s\n" "$YELLOW" "$remaining" "$NC"
    fi

    return "$parse_status"
}

# get_story_progress - Read PRD file and extract story progress information
# Usage: get_story_progress "/path/to/prd.json"
# Output: Sets global variables:
#   STORY_CURRENT_ID - ID of first in_progress story (or first pending if none in progress)
#   STORY_CURRENT_TITLE - Title of current story
#   STORY_COMPLETED_COUNT - Number of completed stories
#   STORY_TOTAL_COUNT - Total number of stories
#   STORY_CURRENT_INDEX - 1-based index of current story
get_story_progress() {
    local prd_file="${1:-}"

    # Initialize globals with defaults
    STORY_CURRENT_ID="unknown"
    STORY_CURRENT_TITLE="unknown"
    STORY_COMPLETED_COUNT=0
    STORY_TOTAL_COUNT=0
    STORY_CURRENT_INDEX=0

    # Check if file path provided
    if [[ -z "$prd_file" ]]; then
        return 1
    fi

    # Check if file exists
    if [[ ! -f "$prd_file" ]]; then
        return 1
    fi

    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi

    # Try to parse the PRD file
    local json_content
    json_content=$(cat "$prd_file" 2>/dev/null) || {
        return 1
    }

    # Validate it's valid JSON
    if ! printf '%s' "$json_content" | jq empty 2>/dev/null; then
        return 1
    fi

    # Get total count
    STORY_TOTAL_COUNT=$(printf '%s' "$json_content" | jq -r '.userStories | length // 0' 2>/dev/null) || {
        STORY_TOTAL_COUNT=0
    }

    # Get completed count
    STORY_COMPLETED_COUNT=$(printf '%s' "$json_content" | jq -r '[.userStories[] | select(.status == "completed")] | length // 0' 2>/dev/null) || {
        STORY_COMPLETED_COUNT=0
    }

    # Find current story (first in_progress, or first pending if none in progress)
    local current_story
    current_story=$(printf '%s' "$json_content" | jq -r '
        .userStories | to_entries |
        (map(select(.value.status == "in_progress"))[0] //
         map(select(.value.status == "pending"))[0]) //
        {key: -1, value: {id: "unknown", title: "unknown"}}
    ' 2>/dev/null)

    if [[ -n "$current_story" && "$current_story" != "null" ]]; then
        STORY_CURRENT_ID=$(printf '%s' "$current_story" | jq -r '.value.id // "unknown"' 2>/dev/null)
        STORY_CURRENT_TITLE=$(printf '%s' "$current_story" | jq -r '.value.title // "unknown"' 2>/dev/null)
        local key_index
        key_index=$(printf '%s' "$current_story" | jq -r '.key // -1' 2>/dev/null)
        if [[ "$key_index" -ge 0 ]]; then
            STORY_CURRENT_INDEX=$((key_index + 1))
        fi
    fi

    return 0
}

# print_story_header - Display story progress header
# Usage: print_story_header "/path/to/prd.json"
# Output: Prints "[US-XXX/Y] Story Title" format
print_story_header() {
    local prd_file="${1:-}"

    # Get story progress
    get_story_progress "$prd_file"

    # Format: [US-001 2/10] Story Title
    printf "%s[%s %d/%d]%s %s\n" \
        "$BOLD" \
        "$STORY_CURRENT_ID" \
        "$STORY_COMPLETED_COUNT" \
        "$STORY_TOTAL_COUNT" \
        "$NC" \
        "$STORY_CURRENT_TITLE"
}

# print_story_complete - Display story completion message with duration
# Usage: print_story_complete "story_id" "duration_string"
print_story_complete() {
    local story_id="${1:-}"
    local duration="${2:-}"

    if [[ -n "$duration" ]]; then
        printf "%s[DONE]%s %s completed in %s\n" "$GREEN" "$NC" "$story_id" "$duration"
    else
        printf "%s[DONE]%s %s completed\n" "$GREEN" "$NC" "$story_id"
    fi
}

# ==============================================================================
# Timer Functions
# ==============================================================================

# Global variable to store timer start value
_OUTPUT_TIMER_START=0

# init_timer - Initialize timer by recording current SECONDS value
# Usage: init_timer
# Note: Uses bash SECONDS variable for BSD/GNU portability
init_timer() {
    _OUTPUT_TIMER_START=$SECONDS
}

# get_elapsed - Get elapsed seconds since init_timer was called
# Usage: get_elapsed
# Output: Prints elapsed seconds to stdout
# Returns: 0 on success
get_elapsed() {
    local elapsed=$((SECONDS - _OUTPUT_TIMER_START))
    # Never return negative time (handle clock going backwards)
    if [[ "$elapsed" -lt 0 ]]; then
        elapsed=0
    fi
    printf '%d' "$elapsed"
}

# format_elapsed - Format elapsed seconds into human-readable string
# Usage: format_elapsed [seconds]
# If no argument provided, uses get_elapsed() to get current elapsed time
# Output format based on duration:
#   - Under 60 seconds: "Xs" (e.g., "45s")
#   - 60-3599 seconds: "Xm Ys" (e.g., "5m 30s")
#   - 3600+ seconds: "HH:MM:SS" (e.g., "02:15:30")
# Supports durations exceeding 24 hours
format_elapsed() {
    local seconds="${1:-}"

    # If no argument, get current elapsed time
    if [[ -z "$seconds" ]]; then
        seconds=$(get_elapsed)
    fi

    # Handle non-numeric or negative input
    if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
        printf '0s'
        return 0
    fi

    # Never display negative time
    if [[ "$seconds" -lt 0 ]]; then
        seconds=0
    fi

    # Format based on thresholds
    if [[ "$seconds" -lt 60 ]]; then
        # Under 60 seconds: "Xs"
        printf '%ds' "$seconds"
    elif [[ "$seconds" -lt 3600 ]]; then
        # 60-3599 seconds: "Xm Ys"
        local minutes=$((seconds / 60))
        local secs=$((seconds % 60))
        printf '%dm %ds' "$minutes" "$secs"
    else
        # 3600+ seconds: "HH:MM:SS" (supports >24 hours)
        local hours=$((seconds / 3600))
        local mins=$(((seconds % 3600) / 60))
        local secs=$((seconds % 60))
        printf '%02d:%02d:%02d' "$hours" "$mins" "$secs"
    fi
}

# ==============================================================================
# Stream JSON Parsing Functions
# ==============================================================================

# Global variables set by parse_stream_line()
STREAM_TYPE=""           # Message type: assistant, result, system, or unknown
STREAM_TOOL_NAME=""      # Tool name (for assistant type with tool use)
STREAM_TOOL_INPUT=""     # Tool input JSON (for assistant type with tool use)
STREAM_TEXT=""           # Text content (for assistant type with text)
STREAM_RESULT_OUTPUT=""  # Tool output (for result type)
STREAM_RESULT_EXIT=""    # Exit code (for result type)

# parse_stream_line - Parse a single line of Claude's stream-json output
# Usage: parse_stream_line "json_line"
# Output: Sets global variables:
#   STREAM_TYPE - Message type: "assistant", "result", "system", or "unknown"
#   STREAM_TOOL_NAME - Tool name if this is a tool invocation (empty otherwise)
#   STREAM_TOOL_INPUT - Tool input JSON if this is a tool invocation (empty otherwise)
#   STREAM_TEXT - Text content if this is a text response (empty otherwise)
#   STREAM_RESULT_OUTPUT - Tool output for result messages (empty otherwise)
#   STREAM_RESULT_EXIT - Exit code for result messages (empty otherwise)
# Returns: 0 on success, 1 on malformed/partial JSON
parse_stream_line() {
    local json_line="${1:-}"

    # Reset all global variables
    STREAM_TYPE=""
    STREAM_TOOL_NAME=""
    STREAM_TOOL_INPUT=""
    STREAM_TEXT=""
    STREAM_RESULT_OUTPUT=""
    STREAM_RESULT_EXIT=""

    # Handle empty input
    if [[ -z "$json_line" ]]; then
        return 1
    fi

    # Check dependencies (jq required)
    if ! check_dependencies; then
        return 1
    fi

    # Validate JSON and extract type
    local msg_type
    msg_type=$(printf '%s' "$json_line" | jq -r '.type // empty' 2>/dev/null)

    # Handle malformed JSON (jq returns non-zero or empty)
    if [[ -z "$msg_type" ]]; then
        # Try to see if it's valid JSON but missing type
        if ! printf '%s' "$json_line" | jq -e '.' >/dev/null 2>&1; then
            # Not valid JSON - skip silently
            return 1
        fi
        # Valid JSON but no type field
        STREAM_TYPE="unknown"
        return 0
    fi

    STREAM_TYPE="$msg_type"

    case "$msg_type" in
        assistant)
            # Extract tool name from .message.content[0].name
            STREAM_TOOL_NAME=$(printf '%s' "$json_line" | jq -r '.message.content[0].name // empty' 2>/dev/null)

            if [[ -n "$STREAM_TOOL_NAME" ]]; then
                # This is a tool invocation - extract input
                STREAM_TOOL_INPUT=$(printf '%s' "$json_line" | jq -c '.message.content[0].input // {}' 2>/dev/null)
            else
                # Check for text content
                STREAM_TEXT=$(printf '%s' "$json_line" | jq -r '.message.content[0].text // empty' 2>/dev/null)
            fi
            ;;
        result)
            # Extract tool output and exit code
            # Result format can vary - try multiple paths
            STREAM_RESULT_OUTPUT=$(printf '%s' "$json_line" | jq -r '.result.output // .result.stdout // .result // empty' 2>/dev/null)
            STREAM_RESULT_EXIT=$(printf '%s' "$json_line" | jq -r '.result.exit_code // .result.exitCode // "0"' 2>/dev/null)

            # Handle case where result is the entire content
            if [[ -z "$STREAM_RESULT_OUTPUT" ]]; then
                STREAM_RESULT_OUTPUT=$(printf '%s' "$json_line" | jq -r '.result' 2>/dev/null)
            fi
            ;;
        system)
            # System/init messages - nothing to extract
            ;;
        *)
            # Unknown type - log but don't crash
            STREAM_TYPE="unknown"
            ;;
    esac

    return 0
}
