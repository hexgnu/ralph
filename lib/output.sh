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
