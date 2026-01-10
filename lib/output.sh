#!/usr/bin/env bash
# lib/output.sh - Shared output formatting library for Ralph scripts
# Compatible with bash 3.2+ (macOS)

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
