# Ralph Sandbox - Isolated Claude Code environment
# Lisa → Ralph → Marge workflow runs safely in here
FROM node:22-slim

# Install dependencies and create ralph user
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    jq \
    ca-certificates \
    gosu \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash ralph

# Install Claude Code (use latest for up-to-date features)
# hadolint ignore=DL3016
RUN npm install -g @anthropic-ai/claude-code

# Stay root for entrypoint (it will drop to ralph after copying creds)
WORKDIR /home/ralph

# Set git defaults (entrypoint will copy host's .gitconfig if available)
USER ralph
RUN git config --global init.defaultBranch main
USER root

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Project gets copied here (not mounted = true isolation)
WORKDIR /workspace

# Entrypoint copies credentials from /host-claude (if mounted) then runs claude
ENTRYPOINT ["/entrypoint.sh"]
