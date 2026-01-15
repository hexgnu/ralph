#!/bin/bash
# Ralph Sandbox - Run Claude Code in isolated container
# Usage: ./sandbox.sh [prompt]
#
# Example:
#   ./sandbox.sh "Implement user authentication"
#   ./sandbox.sh --agent lisa "Plan: add OAuth support"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
IMAGE_NAME="ralph-sandbox"
CONTAINER_NAME="ralph-$(date +%s)"

# Use podman if available, otherwise docker
if command -v podman &> /dev/null; then
  CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
  CONTAINER_CMD="docker"
else
  echo "Error: Neither docker nor podman found"
  exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Ralph Sandbox - Isolated Claude Code Environment${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"

# Check for credentials (API key or OAuth)
if [[ -z "${ANTHROPIC_API_KEY+x}" ]] && [[ ! -d "${HOME}/.claude" ]]; then
  echo -e "${RED}Error: No credentials found. Set ANTHROPIC_API_KEY or login with 'claude login'${NC}"
  exit 1
fi

# Build image if needed
if ! "${CONTAINER_CMD}" image inspect "${IMAGE_NAME}" &> /dev/null; then
  echo -e "${YELLOW}Building Ralph sandbox image...${NC}"
  "${CONTAINER_CMD}" build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
fi

# Create a temporary directory for the workspace
TEMP_WORKSPACE=$(mktemp -d)
trap 'rm -rf "${TEMP_WORKSPACE}"' EXIT

# Copy current project to temp workspace (true isolation - not mounted)
echo -e "${YELLOW}Copying project to sandbox...${NC}"
cp -r "${PROJECT_DIR}/." "${TEMP_WORKSPACE}/"

# Create a results branch name
BRANCH_NAME="ralph/sandbox-$(date +%Y%m%d-%H%M%S)"

echo -e "${YELLOW}Running in container: ${CONTAINER_NAME}${NC}"
echo -e "${YELLOW}Results will be on branch: ${BRANCH_NAME}${NC}"
echo ""

# Build mount arguments
MOUNT_ARGS="-v ${TEMP_WORKSPACE}:/workspace:rw,z"

# Copy Claude credentials (entire directory for OAuth support)
if [[ -d "${HOME}/.claude" ]]; then
  cp -r "${HOME}/.claude" "${TEMP_WORKSPACE}/.host-claude"
fi

# Copy git config
if [[ -f "${HOME}/.gitconfig" ]]; then
  cp "${HOME}/.gitconfig" "${TEMP_WORKSPACE}/.host-gitconfig"
fi

# Build env arguments (only pass API key if set)
ENV_ARGS=""
if [[ -n "${ANTHROPIC_API_KEY+x}" ]]; then
  ENV_ARGS="-e ANTHROPIC_API_KEY"
fi

# Run the container
# shellcheck disable=SC2086
"${CONTAINER_CMD}" run -it --rm \
  --name "${CONTAINER_NAME}" \
  --network host \
  --security-opt label=disable \
  ${ENV_ARGS} \
  ${MOUNT_ARGS} \
  "${IMAGE_NAME}" \
  "$@"

# After container exits, check for changes
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Sandbox Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"

# Show what changed
cd "${TEMP_WORKSPACE}"
if [[ -n "$(git status --porcelain 2> /dev/null || :)" ]]; then
  echo -e "${YELLOW}Changes made in sandbox:${NC}"
  git status --short
  echo ""

  # Ask if user wants to apply changes
  read -p "Apply these changes to your project? [y/N] " -n 1 -r
  echo
  if [[ ${REPLY} =~ ^[Yy]$ ]]; then
    # Copy changes back (excluding .git)
    rsync -av --exclude='.git' "${TEMP_WORKSPACE}/" "${PROJECT_DIR}/"
    echo -e "${GREEN}Changes applied!${NC}"
  else
    echo -e "${YELLOW}Changes discarded.${NC}"
  fi
else
  echo "No changes made."
fi
