#!/bin/bash
# Ralph Worktree - Lightweight parallel feature development using git worktrees
# Usage: ./worktree.sh <feature-name>
#        ./worktree.sh --help
#
# Example:
#   ./worktree.sh add-oauth
#   ./worktree.sh my-feature

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_BASE="../ralph-worktrees"

# Colors (matching sandbox.sh patterns)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print header banner
print_header() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Ralph Worktree - Lightweight Feature Development${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
}

# Print security warning
print_security_warning() {
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  WARNING: Worktree mode runs with full host filesystem${NC}"
    echo -e "${RED}  access. Use sandbox.sh for untrusted operations.${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Print usage help
print_help() {
    print_header
    echo ""
    echo "Usage: ./worktree.sh <feature-name>"
    echo "       ./worktree.sh --create <feature-name>"
    echo "       ./worktree.sh --remove <feature-name> [--force] [--delete-branch]"
    echo "       ./worktree.sh --list"
    echo "       ./worktree.sh --help"
    echo ""
    echo "Creates a git worktree for isolated feature development and runs"
    echo "Claude Code in it. Worktrees are faster than containers but have"
    echo "full filesystem access."
    echo ""
    echo "Arguments:"
    echo "  <feature-name>   Name for the feature (alphanumeric, hyphens, underscores)"
    echo ""
    echo "Options:"
    echo "  --create <name>   Create worktree without starting Claude Code"
    echo "  --remove <name>   Remove a worktree (prompts for confirmation)"
    echo "    --force         Force removal even if worktree has uncommitted changes"
    echo "    --delete-branch Also delete the local branch after removing worktree"
    echo "  --list            List all ralph worktrees with status"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./worktree.sh add-oauth              # Create worktree and start Claude Code"
    echo "  ./worktree.sh my_feature             # Underscores are allowed"
    echo "  ./worktree.sh --create oauth         # Create worktree only (no Claude Code)"
    echo "  ./worktree.sh --remove oauth         # Remove worktree (keeps branch)"
    echo "  ./worktree.sh --remove oauth --delete-branch  # Remove worktree and branch"
    echo "  ./worktree.sh --list                 # Show all worktrees"
    echo ""
    echo "Worktrees are created at: $WORKTREE_BASE/<feature-name>"
    echo "Branches are named: ralph/<feature-name>"
    echo ""
}

# Validate feature name
validate_feature_name() {
    local name="${1}"

    if [[ -z "${name}" ]]; then
        printf '%b%s%b\n' "${RED}" "Error: Feature name is required" "${NC}"
        printf '\n'
        printf 'Usage: ./worktree.sh <feature-name>\n'
        printf '       ./worktree.sh --help\n'
        exit 1
    fi

    # Only allow alphanumeric, hyphens, and underscores
    if ! [[ "${name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        printf '%b%s%b\n' "${RED}" "Error: Invalid feature name '${name}'" "${NC}"
        printf '\n'
        printf 'Feature names can only contain:\n'
        printf '  - Letters (a-z, A-Z)\n'
        printf '  - Numbers (0-9)\n'
        printf '  - Hyphens (-)\n'
        printf '  - Underscores (_)\n'
        printf '\n'
        printf 'Examples of valid names:\n'
        printf '  add-oauth\n'
        printf '  my_feature\n'
        printf '  feature123\n'
        exit 1
    fi
}

# Detect default branch (main/master/trunk)
detect_default_branch() {
    local default_branch

    # Try to get from remote HEAD reference
    if default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'); then
        if [[ -n "${default_branch}" ]]; then
            printf '%s' "${default_branch}"
            return 0
        fi
    fi

    # Fallback: check common branch names
    local branch
    for branch in main master trunk; do
        if git show-ref --verify --quiet "refs/heads/${branch}" 2>/dev/null; then
            printf '%s' "${branch}"
            return 0
        fi
    done

    # Last resort: use current branch
    git branch --show-current
}

# Check prerequisites
check_prerequisites() {
    # Check if git is available
    if ! command -v git &>/dev/null; then
        printf '%b%s%b\n' "${RED}" "Error: git is not installed" "${NC}"
        exit 1
    fi

    # Check if git worktree is available (git 2.5+)
    if ! git worktree list &>/dev/null; then
        printf '%b%s%b\n' "${RED}" "Error: git worktree command is not available" "${NC}"
        printf '\n'
        printf 'Git worktrees require git version 2.5 or later.\n'
        printf 'Please upgrade git to use this feature.\n'
        printf '\n'
        printf 'Check your git version: git --version\n'
        exit 1
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        printf '%b%s%b\n' "${RED}" "Error: Not in a git repository" "${NC}"
        printf '\n'
        printf 'Run this script from within a git repository.\n'
        exit 1
    fi

    # Check if claude command is available
    if ! command -v claude &>/dev/null; then
        printf '%b%s%b\n' "${RED}" "Error: claude command is not available" "${NC}"
        printf '\n'
        printf 'Install Claude Code: https://claude.ai/code\n'
        exit 1
    fi
}

# Remove a worktree with safety checks
remove_worktree() {
    local feature_name="${1}"
    local force_remove="${2}"
    local delete_branch="${3}"

    # Get absolute path to worktree base
    local worktree_base_abs
    worktree_base_abs=$(cd "${SCRIPT_DIR}" && cd "${WORKTREE_BASE}" 2>/dev/null && pwd) || worktree_base_abs=""

    local worktree_path="${worktree_base_abs}/${feature_name}"
    local branch_name="ralph/${feature_name}"

    # Check if worktree exists
    if [[ ! -d "${worktree_path}" ]]; then
        printf '%b%s%b\n' "${RED}" "Error: Worktree '${feature_name}' does not exist" "${NC}"
        printf '\n'
        printf 'Available worktrees:\n'
        if [[ -n "${worktree_base_abs}" ]] && [[ -d "${worktree_base_abs}" ]]; then
            local dir
            for dir in "${worktree_base_abs}"/*/; do
                [[ -d "${dir}" ]] && printf '  - %s\n' "$(basename "${dir}")"
            done
        else
            printf '  (none)\n'
        fi
        printf '\n'
        printf "Use './worktree.sh --list' to see all worktrees\n"
        exit 1
    fi

    # Check if it's actually a git worktree
    if [[ ! -f "${worktree_path}/.git" ]]; then
        printf '%b%s%b\n' "${RED}" "Error: '${worktree_path}' is not a git worktree" "${NC}"
        exit 1
    fi

    # Check for uncommitted changes
    local is_dirty=false
    if ! (cd "${worktree_path}" && git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null); then
        is_dirty=true
    fi

    # If dirty and not forced, warn and exit
    if [[ "${is_dirty}" == "true" ]] && [[ "${force_remove}" != "true" ]]; then
        printf '%b%s%b\n' "${RED}" "Error: Worktree '${feature_name}' has uncommitted changes" "${NC}"
        printf '\n'
        printf 'Uncommitted changes:\n'
        (cd "${worktree_path}" && git status --short)
        printf '\n'
        printf 'Options:\n'
        printf '  1. Commit or stash your changes first\n'
        printf '  2. Use --force to discard changes and remove anyway:\n'
        printf '     ./worktree.sh --remove %s --force\n' "${feature_name}"
        exit 1
    fi

    # Prompt for confirmation
    printf '%b%s%b\n' "${YELLOW}" "About to remove worktree:" "${NC}"
    printf '  Name:   %s\n' "${feature_name}"
    printf '  Path:   %s\n' "${worktree_path}"
    printf '  Branch: %s\n' "${branch_name}"
    if [[ "${is_dirty}" == "true" ]]; then
        printf '  Status: %bdirty (uncommitted changes will be lost!)%b\n' "${RED}" "${NC}"
    else
        printf '  Status: %bclean%b\n' "${GREEN}" "${NC}"
    fi
    if [[ "${delete_branch}" == "true" ]]; then
        printf '  %bBranch will also be deleted (local only)%b\n' "${YELLOW}" "${NC}"
    fi
    printf '\n'

    # Read confirmation
    local response
    read -r -p "Are you sure you want to remove this worktree? [y/N] " response
    case "${response}" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            printf 'Aborted.\n'
            exit 0
            ;;
    esac

    # Remove the worktree
    printf '\n'
    printf '%b%s%b\n' "${YELLOW}" "Removing worktree..." "${NC}"

    if [[ "${force_remove}" == "true" ]]; then
        git worktree remove --force "${worktree_path}"
    else
        git worktree remove "${worktree_path}"
    fi

    printf '%b%s%b\n' "${GREEN}" "Worktree removed: ${worktree_path}" "${NC}"

    # Optionally delete the branch
    if [[ "${delete_branch}" == "true" ]]; then
        # Check if branch exists
        if git show-ref --verify --quiet "refs/heads/${branch_name}" 2>/dev/null; then
            printf '%b%s%b\n' "${YELLOW}" "Deleting local branch: ${branch_name}" "${NC}"
            git branch -D "${branch_name}"
            printf '%b%s%b\n' "${GREEN}" "Branch deleted: ${branch_name}" "${NC}"
        else
            printf '%b%s%b\n' "${YELLOW}" "Branch '${branch_name}' does not exist (already deleted or never created)" "${NC}"
        fi
        printf '\n'
        printf '%b%s%b\n' "${YELLOW}" "Note: Remote branch (if any) was NOT deleted." "${NC}"
        printf 'To delete remote branch, run:\n'
        printf '  git push origin --delete %s\n' "${branch_name}"
    fi

    printf '\n'
    printf '%b%s%b\n' "${GREEN}" "Done!" "${NC}"
}

# List all ralph worktrees with status
list_worktrees() {
    print_header
    printf '\n'

    # Get absolute path to worktree base
    local worktree_base_abs
    worktree_base_abs=$(cd "${SCRIPT_DIR}" && cd "${WORKTREE_BASE}" 2>/dev/null && pwd) || worktree_base_abs=""

    # Check if worktree directory exists and has subdirectories
    if [[ -z "${worktree_base_abs}" ]] || [[ ! -d "${worktree_base_abs}" ]]; then
        printf '%b%s%b\n' "${YELLOW}" "No ralph worktrees found." "${NC}"
        printf '\n'
        printf 'Create your first worktree with:\n'
        printf '  ./worktree.sh <feature-name>\n'
        printf '\n'
        printf 'Worktrees will be created at: %s/\n' "${WORKTREE_BASE}"
        return 0
    fi

    # Count worktrees
    local worktree_count=0
    local dir
    for dir in "${worktree_base_abs}"/*/; do
        [[ -d "${dir}" ]] && ((worktree_count++)) || true
    done

    if [[ "${worktree_count}" -eq 0 ]]; then
        printf '%b%s%b\n' "${YELLOW}" "No ralph worktrees found." "${NC}"
        printf '\n'
        printf 'Create your first worktree with:\n'
        printf '  ./worktree.sh <feature-name>\n'
        printf '\n'
        printf 'Worktrees will be created at: %s/\n' "${WORKTREE_BASE}"
        return 0
    fi

    printf '%b%s%b\n' "${CYAN}" "Ralph Worktrees:" "${NC}"
    printf '\n'

    # Print header row
    printf "  %-20s %-25s %-8s %s\n" "NAME" "BRANCH" "STATUS" "PATH"
    printf "  %-20s %-25s %-8s %s\n" "----" "------" "------" "----"

    # Iterate through worktree directories
    for dir in "${worktree_base_abs}"/*/; do
        [[ -d "${dir}" ]] || continue

        local name
        name=$(basename "${dir}")
        local path="${dir%/}"

        # Get branch name
        local branch=""
        if [[ -f "${path}/.git" ]]; then
            branch=$(cd "${path}" && git rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="(detached)"
        else
            branch="(not a git worktree)"
        fi

        # Check status (clean/dirty)
        local status=""
        if [[ -f "${path}/.git" ]]; then
            if (cd "${path}" && git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null); then
                status="${GREEN}clean${NC}"
            else
                status="${YELLOW}dirty${NC}"
            fi
        else
            status="${RED}error${NC}"
        fi

        # Print formatted row
        printf "  %-20s %-25s " "${name}" "${branch}"
        printf '%b' "${status}"
        # Pad status to 8 chars (accounting for color codes)
        printf "%*s" $((8 - 5)) ""
        printf ' %s\n' "${path}"
    done

    printf '\n'
}

# Create and enter worktree
create_worktree() {
    local feature_name="${1}"
    local worktree_path="${WORKTREE_BASE}/${feature_name}"
    local branch_name="ralph/${feature_name}"
    local default_branch

    # Detect default branch
    default_branch=$(detect_default_branch)
    printf '%b%s%b\n' "${YELLOW}" "Using base branch: ${default_branch}" "${NC}"

    # Create parent directory if needed
    if [[ ! -d "${WORKTREE_BASE}" ]]; then
        printf '%b%s%b\n' "${YELLOW}" "Creating worktree directory: ${WORKTREE_BASE}" "${NC}"
        mkdir -p "${WORKTREE_BASE}"
    fi

    # Check if worktree already exists
    if [[ -d "${worktree_path}" ]]; then
        printf '%b%s%b\n' "${YELLOW}" "Using existing worktree: ${worktree_path}" "${NC}"
    else
        # Check if branch already exists and is checked out elsewhere
        if git show-ref --verify --quiet "refs/heads/${branch_name}" 2>/dev/null; then
            # Branch exists - check if it's checked out somewhere
            local checked_out_path
            checked_out_path=$(git worktree list --porcelain | grep -A2 "branch refs/heads/${branch_name}" | grep "worktree" | cut -d' ' -f2 || true)

            if [[ -n "${checked_out_path}" ]]; then
                printf '%b%s%b\n' "${RED}" "Error: Branch '${branch_name}' is already checked out at:" "${NC}"
                printf '  %s\n' "${checked_out_path}"
                printf '\n'
                printf 'Either use that worktree or remove it first:\n'
                printf "  git worktree remove '%s'\n" "${checked_out_path}"
                exit 1
            fi

            # Branch exists but not checked out - use it
            printf '%b%s%b\n' "${YELLOW}" "Creating worktree with existing branch: ${branch_name}" "${NC}"
            git worktree add "${worktree_path}" "${branch_name}"
        else
            # Create new branch from default branch
            printf '%b%s%b\n' "${YELLOW}" "Creating worktree: ${worktree_path}" "${NC}"
            printf '%b%s%b\n' "${YELLOW}" "Creating branch: ${branch_name} (from ${default_branch})" "${NC}"
            git worktree add -b "${branch_name}" "${worktree_path}" "${default_branch}"
        fi
    fi

    printf '%s' "${worktree_path}"
}

# Main execution
main() {
    # Handle --help
    if [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
        print_help
        exit 0
    fi

    # Handle --list
    if [[ "${1}" == "--list" ]] || [[ "${1}" == "-l" ]]; then
        list_worktrees
        exit 0
    fi

    # Handle --create
    if [[ "${1}" == "--create" ]] || [[ "${1}" == "-c" ]]; then
        local feature_name="${2}"

        # Check prerequisites first
        check_prerequisites

        # Validate feature name
        validate_feature_name "${feature_name}"

        # Print header
        print_header

        # Print security warning
        print_security_warning

        # Create worktree (without starting Claude Code)
        local worktree_path
        worktree_path=$(create_worktree "${feature_name}")

        printf '\n'
        printf '%b%s%b\n' "${GREEN}" "═══════════════════════════════════════════════════════" "${NC}"
        printf '%b%s%b\n' "${GREEN}" "  Worktree created successfully!" "${NC}"
        printf '%b%s%b\n' "${GREEN}" "═══════════════════════════════════════════════════════" "${NC}"
        printf '\n'
        printf 'Path: %b%s%b\n' "${CYAN}" "${worktree_path}" "${NC}"
        printf 'Branch: %b%s%b\n' "${CYAN}" "ralph/${feature_name}" "${NC}"
        printf '\n'
        printf '%b%s%b\n' "${YELLOW}" "Next steps:" "${NC}"
        printf '  cd %s\n' "${worktree_path}"
        printf '  claude --dangerously-skip-permissions  # Start Claude Code\n'
        printf '\n'
        printf 'Or run without --create to start Claude Code automatically:\n'
        printf '  ./worktree.sh %s\n' "${feature_name}"
        printf '\n'
        exit 0
    fi

    # Handle --remove
    if [[ "${1}" == "--remove" ]] || [[ "${1}" == "-r" ]]; then
        local feature_name="${2}"
        local force_remove="false"
        local delete_branch="false"

        # Parse additional flags
        shift 2 || true
        while [[ $# -gt 0 ]]; do
            case "${1}" in
                --force|-f)
                    force_remove="true"
                    ;;
                --delete-branch|-d)
                    delete_branch="true"
                    ;;
                *)
                    printf '%b%s%b\n' "${RED}" "Error: Unknown option '${1}'" "${NC}"
                    printf 'Usage: ./worktree.sh --remove <name> [--force] [--delete-branch]\n'
                    exit 1
                    ;;
            esac
            shift
        done

        # Validate feature name
        validate_feature_name "${feature_name}"

        # Print header
        print_header

        # Remove worktree with safety checks
        remove_worktree "${feature_name}" "${force_remove}" "${delete_branch}"
        exit 0
    fi

    # Check prerequisites
    check_prerequisites

    # Get feature name
    local feature_name="${1}"

    # Validate feature name
    validate_feature_name "${feature_name}"

    # Print header
    print_header

    # Print security warning
    print_security_warning

    # Create worktree
    local worktree_path
    worktree_path=$(create_worktree "${feature_name}")

    printf '\n'
    printf '%b%s%b\n' "${GREEN}" "Worktree ready at: ${worktree_path}" "${NC}"
    printf '%b%s%b\n' "${YELLOW}" "Starting Claude Code..." "${NC}"
    printf '\n'

    # Change to worktree and run Claude Code
    cd "${worktree_path}"
    claude --dangerously-skip-permissions
}

main "$@"
