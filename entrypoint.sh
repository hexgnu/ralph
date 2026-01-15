#!/bin/bash
# Entrypoint for Ralph sandbox
# Runs as root to copy credentials, then drops to ralph user

# Copy credentials from workspace (sandbox.sh puts them there)
if [[ -d /workspace/.host-claude ]]; then
  mkdir -p /home/ralph/.claude
  cp -r /workspace/.host-claude/. /home/ralph/.claude/
  chown -R ralph:ralph /home/ralph/.claude
  chmod -R 700 /home/ralph/.claude
  rm -rf /workspace/.host-claude
fi

# Copy git config from workspace
if [[ -f /workspace/.host-gitconfig ]]; then
  cp /workspace/.host-gitconfig /home/ralph/.gitconfig
  chown ralph:ralph /home/ralph/.gitconfig
  rm /workspace/.host-gitconfig
fi

# Drop to ralph user and run command
# If first arg is a known command (bash, sh, etc), run it directly
# Otherwise, run claude with the args
case "${1:-}" in
  bash | sh | /bin/bash | /bin/sh)
    exec gosu ralph "$@"
    ;;
  *)
    gosu ralph claude --dangerously-skip-permissions "$@"
    printf '\e[?1004l'
    ;;
esac
