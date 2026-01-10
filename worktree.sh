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
    local name="$1"

    if [ -z "$name" ]; then
        echo -e "${RED}Error: Feature name is required${NC}"
        echo ""
        echo "Usage: ./worktree.sh <feature-name>"
        echo "       ./worktree.sh --help"
        exit 1
    fi

    # Only allow alphanumeric, hyphens, and underscores
    if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Invalid feature name '$name'${NC}"
        echo ""
        echo "Feature names can only contain:"
        echo "  - Letters (a-z, A-Z)"
        echo "  - Numbers (0-9)"
        echo "  - Hyphens (-)"
        echo "  - Underscores (_)"
        echo ""
        echo "Examples of valid names:"
        echo "  add-oauth"
        echo "  my_feature"
        echo "  feature123"
        exit 1
    fi
}

# Detect default branch (main/master/trunk)
detect_default_branch() {
    local default_branch

    # Try to get from remote HEAD reference
    if default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'); then
        if [ -n "$default_branch" ]; then
            echo "$default_branch"
            return 0
        fi
    fi

    # Fallback: check common branch names
    for branch in main master trunk; do
        if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
            echo "$branch"
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
        echo -e "${RED}Error: git is not installed${NC}"
        exit 1
    fi

    # Check if git worktree is available (git 2.5+)
    if ! git worktree list &>/dev/null; then
        echo -e "${RED}Error: git worktree command is not available${NC}"
        echo ""
        echo "Git worktrees require git version 2.5 or later."
        echo "Please upgrade git to use this feature."
        echo ""
        echo "Check your git version: git --version"
        exit 1
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        echo ""
        echo "Run this script from within a git repository."
        exit 1
    fi

    # Check if claude command is available
    if ! command -v claude &>/dev/null; then
        echo -e "${RED}Error: claude command is not available${NC}"
        echo ""
        echo "Install Claude Code: https://claude.ai/code"
        exit 1
    fi
}

# Remove a worktree with safety checks
remove_worktree() {
    local feature_name="$1"
    local force_remove="$2"
    local delete_branch="$3"

    # Get absolute path to worktree base
    local worktree_base_abs
    worktree_base_abs=$(cd "$SCRIPT_DIR" && cd "$WORKTREE_BASE" 2>/dev/null && pwd) || worktree_base_abs=""

    local worktree_path="$worktree_base_abs/$feature_name"
    local branch_name="ralph/$feature_name"

    # Check if worktree exists
    if [ ! -d "$worktree_path" ]; then
        echo -e "${RED}Error: Worktree '$feature_name' does not exist${NC}"
        echo ""
        echo "Available worktrees:"
        if [ -n "$worktree_base_abs" ] && [ -d "$worktree_base_abs" ]; then
            for dir in "$worktree_base_abs"/*/; do
                [ -d "$dir" ] && echo "  - $(basename "$dir")"
            done
        else
            echo "  (none)"
        fi
        echo ""
        echo "Use './worktree.sh --list' to see all worktrees"
        exit 1
    fi

    # Check if it's actually a git worktree
    if [ ! -f "$worktree_path/.git" ]; then
        echo -e "${RED}Error: '$worktree_path' is not a git worktree${NC}"
        exit 1
    fi

    # Check for uncommitted changes
    local is_dirty=false
    if ! (cd "$worktree_path" && git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null); then
        is_dirty=true
    fi

    # If dirty and not forced, warn and exit
    if [ "$is_dirty" = true ] && [ "$force_remove" != "true" ]; then
        echo -e "${RED}Error: Worktree '$feature_name' has uncommitted changes${NC}"
        echo ""
        echo "Uncommitted changes:"
        (cd "$worktree_path" && git status --short)
        echo ""
        echo "Options:"
        echo "  1. Commit or stash your changes first"
        echo "  2. Use --force to discard changes and remove anyway:"
        echo "     ./worktree.sh --remove $feature_name --force"
        exit 1
    fi

    # Prompt for confirmation
    echo -e "${YELLOW}About to remove worktree:${NC}"
    echo "  Name:   $feature_name"
    echo "  Path:   $worktree_path"
    echo "  Branch: $branch_name"
    if [ "$is_dirty" = true ]; then
        echo -e "  Status: ${RED}dirty (uncommitted changes will be lost!)${NC}"
    else
        echo -e "  Status: ${GREEN}clean${NC}"
    fi
    if [ "$delete_branch" = "true" ]; then
        echo -e "  ${YELLOW}Branch will also be deleted (local only)${NC}"
    fi
    echo ""

    # Read confirmation
    read -r -p "Are you sure you want to remove this worktree? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            echo "Aborted."
            exit 0
            ;;
    esac

    # Remove the worktree
    echo ""
    echo -e "${YELLOW}Removing worktree...${NC}"

    if [ "$force_remove" = "true" ]; then
        git worktree remove --force "$worktree_path"
    else
        git worktree remove "$worktree_path"
    fi

    echo -e "${GREEN}Worktree removed: $worktree_path${NC}"

    # Optionally delete the branch
    if [ "$delete_branch" = "true" ]; then
        # Check if branch exists
        if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
            echo -e "${YELLOW}Deleting local branch: $branch_name${NC}"
            git branch -D "$branch_name"
            echo -e "${GREEN}Branch deleted: $branch_name${NC}"
        else
            echo -e "${YELLOW}Branch '$branch_name' does not exist (already deleted or never created)${NC}"
        fi
        echo ""
        echo -e "${YELLOW}Note: Remote branch (if any) was NOT deleted.${NC}"
        echo "To delete remote branch, run:"
        echo "  git push origin --delete $branch_name"
    fi

    echo ""
    echo -e "${GREEN}Done!${NC}"
}

# List all ralph worktrees with status
list_worktrees() {
    print_header
    echo ""

    # Get absolute path to worktree base
    local worktree_base_abs
    worktree_base_abs=$(cd "$SCRIPT_DIR" && cd "$WORKTREE_BASE" 2>/dev/null && pwd) || worktree_base_abs=""

    # Check if worktree directory exists and has subdirectories
    if [ -z "$worktree_base_abs" ] || [ ! -d "$worktree_base_abs" ]; then
        echo -e "${YELLOW}No ralph worktrees found.${NC}"
        echo ""
        echo "Create your first worktree with:"
        echo "  ./worktree.sh <feature-name>"
        echo ""
        echo "Worktrees will be created at: $WORKTREE_BASE/"
        return 0
    fi

    # Count worktrees
    local worktree_count=0
    for dir in "$worktree_base_abs"/*/; do
        [ -d "$dir" ] && ((worktree_count++)) || true
    done

    if [ "$worktree_count" -eq 0 ]; then
        echo -e "${YELLOW}No ralph worktrees found.${NC}"
        echo ""
        echo "Create your first worktree with:"
        echo "  ./worktree.sh <feature-name>"
        echo ""
        echo "Worktrees will be created at: $WORKTREE_BASE/"
        return 0
    fi

    echo -e "${CYAN}Ralph Worktrees:${NC}"
    echo ""

    # Print header row
    printf "  %-20s %-25s %-8s %s\n" "NAME" "BRANCH" "STATUS" "PATH"
    printf "  %-20s %-25s %-8s %s\n" "----" "------" "------" "----"

    # Iterate through worktree directories
    for dir in "$worktree_base_abs"/*/; do
        [ -d "$dir" ] || continue

        local name
        name=$(basename "$dir")
        local path="${dir%/}"

        # Get branch name
        local branch=""
        if [ -f "$path/.git" ]; then
            branch=$(cd "$path" && git rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="(detached)"
        else
            branch="(not a git worktree)"
        fi

        # Check status (clean/dirty)
        local status=""
        if [ -f "$path/.git" ]; then
            if (cd "$path" && git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null); then
                status="${GREEN}clean${NC}"
            else
                status="${YELLOW}dirty${NC}"
            fi
        else
            status="${RED}error${NC}"
        fi

        # Print formatted row
        printf "  %-20s %-25s " "$name" "$branch"
        echo -en "$status"
        # Pad status to 8 chars (accounting for color codes)
        printf "%*s" $((8 - 5)) ""
        echo " $path"
    done

    echo ""
}

# Create and enter worktree
create_worktree() {
    local feature_name="$1"
    local worktree_path="$WORKTREE_BASE/$feature_name"
    local branch_name="ralph/$feature_name"
    local default_branch

    # Detect default branch
    default_branch=$(detect_default_branch)
    echo -e "${YELLOW}Using base branch: $default_branch${NC}"

    # Create parent directory if needed
    if [ ! -d "$WORKTREE_BASE" ]; then
        echo -e "${YELLOW}Creating worktree directory: $WORKTREE_BASE${NC}"
        mkdir -p "$WORKTREE_BASE"
    fi

    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        echo -e "${YELLOW}Using existing worktree: $worktree_path${NC}"
    else
        # Check if branch already exists and is checked out elsewhere
        if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
            # Branch exists - check if it's checked out somewhere
            local checked_out_path
            checked_out_path=$(git worktree list --porcelain | grep -A2 "branch refs/heads/$branch_name" | grep "worktree" | cut -d' ' -f2 || true)

            if [ -n "$checked_out_path" ]; then
                echo -e "${RED}Error: Branch '$branch_name' is already checked out at:${NC}"
                echo "  $checked_out_path"
                echo ""
                echo "Either use that worktree or remove it first:"
                echo "  git worktree remove '$checked_out_path'"
                exit 1
            fi

            # Branch exists but not checked out - use it
            echo -e "${YELLOW}Creating worktree with existing branch: $branch_name${NC}"
            git worktree add "$worktree_path" "$branch_name"
        else
            # Create new branch from default branch
            echo -e "${YELLOW}Creating worktree: $worktree_path${NC}"
            echo -e "${YELLOW}Creating branch: $branch_name (from $default_branch)${NC}"
            git worktree add -b "$branch_name" "$worktree_path" "$default_branch"
        fi
    fi

    echo "$worktree_path"
}

# Main execution
main() {
    # Handle --help
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        print_help
        exit 0
    fi

    # Handle --list
    if [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
        list_worktrees
        exit 0
    fi

    # Handle --create
    if [ "$1" = "--create" ] || [ "$1" = "-c" ]; then
        local feature_name="$2"

        # Check prerequisites first
        check_prerequisites

        # Validate feature name
        validate_feature_name "$feature_name"

        # Print header
        print_header

        # Print security warning
        print_security_warning

        # Create worktree (without starting Claude Code)
        local worktree_path
        worktree_path=$(create_worktree "$feature_name")

        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Worktree created successfully!${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "Path: ${CYAN}$worktree_path${NC}"
        echo -e "Branch: ${CYAN}ralph/$feature_name${NC}"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "  cd $worktree_path"
        echo "  claude --dangerously-skip-permissions  # Start Claude Code"
        echo ""
        echo "Or run without --create to start Claude Code automatically:"
        echo "  ./worktree.sh $feature_name"
        echo ""
        exit 0
    fi

    # Handle --remove
    if [ "$1" = "--remove" ] || [ "$1" = "-r" ]; then
        local feature_name="$2"
        local force_remove="false"
        local delete_branch="false"

        # Parse additional flags
        shift 2 || true
        while [ $# -gt 0 ]; do
            case "$1" in
                --force|-f)
                    force_remove="true"
                    ;;
                --delete-branch|-d)
                    delete_branch="true"
                    ;;
                *)
                    echo -e "${RED}Error: Unknown option '$1'${NC}"
                    echo "Usage: ./worktree.sh --remove <name> [--force] [--delete-branch]"
                    exit 1
                    ;;
            esac
            shift
        done

        # Validate feature name
        validate_feature_name "$feature_name"

        # Print header
        print_header

        # Remove worktree with safety checks
        remove_worktree "$feature_name" "$force_remove" "$delete_branch"
        exit 0
    fi

    # Check prerequisites
    check_prerequisites

    # Get feature name
    local feature_name="$1"

    # Validate feature name
    validate_feature_name "$feature_name"

    # Print header
    print_header

    # Print security warning
    print_security_warning

    # Create worktree
    local worktree_path
    worktree_path=$(create_worktree "$feature_name")

    echo ""
    echo -e "${GREEN}Worktree ready at: $worktree_path${NC}"
    echo -e "${YELLOW}Starting Claude Code...${NC}"
    echo ""

    # Change to worktree and run Claude Code
    cd "$worktree_path"
    claude --dangerously-skip-permissions
}

main "$@"
