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
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./worktree.sh add-oauth        # Create worktree and start Claude Code"
    echo "  ./worktree.sh my_feature       # Underscores are allowed"
    echo ""
    echo "Worktrees are created at: $WORKTREE_BASE/<feature-name>"
    echo "Branches are named: ralph/<feature-name>"
    echo ""
    echo "To clean up:"
    echo "  cd $WORKTREE_BASE/<feature-name>"
    echo "  git worktree remove <feature-name>"
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
