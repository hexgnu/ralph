# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent system that implements features from PRDs. It uses the **Lisa → Ralph → Marge** workflow:

- **Lisa** plans (Gemba Walk → A3 Analysis → War Room → prd.json)
- **Ralph** executes (implement stories one by one)
- **Marge** reviews (quality gate before each commit)

Memory persists via git history, `progress.txt`, and `prd.json`. Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated
- Docker or Podman (for sandboxed execution)
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project

## Quick Start

```bash
# 1. Copy agents to your Claude config
cp agents/*.md ~/.claude/agents/

# 2. Run Lisa to plan a feature (in sandbox)
./sandbox.sh --agent lisa "Plan: add user authentication with OAuth"

# 3. Review the generated prd.json and artifacts

# 4. Run Ralph to execute (in sandbox)
./sandbox.sh -p "$(cat prompt.md)"
```

## The Simpsons Workflow

```
Feature Idea
    ↓
┌─────────────────────────────────────┐
│  LISA (Planning)                    │
│  1. Gemba Walk - observe codebase   │
│  2. A3 Analysis - define problem    │
│  3. War Room - adversarial review   │
│  4. Output: prd.json                │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  RALPH (Execution Loop)             │
│  For each story:                    │
│    - Implement                      │
│    - Run tests                      │
│    - MARGE reviews                  │
│    - If COMMIT: git commit          │
│    - If REJECT: fix and retry       │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  DONE                               │
│  <promise>COMPLETE</promise>        │
└─────────────────────────────────────┘
```

## Sandbox (Recommended)

Run Claude Code in an isolated container for safety:

```bash
./sandbox.sh "Your prompt here"
./sandbox.sh --agent lisa "Plan: feature description"
```

The sandbox:
- Copies your project into a container (not mounted = true isolation)
- Runs with `--dangerously-skip-permissions` (safe because containerized)
- Shows you changes before applying them to your real project
- Works with Docker or Podman automatically

## Worktree (Lightweight Alternative)

Use git worktrees for faster, lightweight feature development:

```bash
./worktree.sh add-oauth              # Create worktree and start Claude Code
./worktree.sh --create my-feature    # Create worktree only (no Claude Code)
./worktree.sh --list                 # List all ralph worktrees
./worktree.sh --remove my-feature    # Remove worktree (prompts for confirmation)
```

### Container vs Worktree

| Feature | Container (`sandbox.sh`) | Worktree (`worktree.sh`) |
|---------|-------------------------|--------------------------|
| Isolation | Full (filesystem, network) | Git-only (separate working directory) |
| Speed | Slower (container startup) | Fast (instant) |
| Filesystem access | Container only | **Full host access** |
| Use case | Untrusted code, experiments | Trusted development, parallel features |
| Setup | Docker/Podman required | Git 2.5+ only |

### Security Note

> **WARNING**: Worktree mode runs with `--dangerously-skip-permissions` and has full host filesystem access. Use `sandbox.sh` for untrusted operations or when you want true isolation.

### Merge Workflow

After completing work in a worktree, merge your changes back to main:

```bash
# 1. From your worktree, commit and push your changes
cd ../ralph-worktrees/add-oauth
git add . && git commit -m "Add OAuth support"
git push -u origin ralph/add-oauth

# 2. Create a PR or merge locally
gh pr create --base main --head ralph/add-oauth

# 3. After merging, clean up the worktree
cd /path/to/ralph
./worktree.sh --remove add-oauth --delete-branch
```

### Troubleshooting

**"Branch is already checked out" error**
```bash
# The branch is being used by another worktree
git worktree list  # Find where it's checked out
git worktree remove /path/to/other/worktree
```

**"Not a git worktree" error**
```bash
# The directory exists but isn't a valid worktree
rm -rf ../ralph-worktrees/feature-name
./worktree.sh feature-name  # Recreate it
```

**Worktree has uncommitted changes**
```bash
# Commit your changes first, or use --force to discard
./worktree.sh --remove feature-name --force
```

## Agents

| Agent | Purpose |
|-------|---------|
| `gemba-walk` | Observe codebase reality before planning |
| `war-room` | Adversarial review (Carmack, DHH, Schneier personas) |
| `lisa` | Orchestrate: gemba → A3 → war-room → prd.json |
| `marge` | Pre-commit quality gate |

### War Room Personas

- **John Carmack**: Performance, simplicity, no unnecessary abstraction
- **DHH**: Pragmatism, convention over configuration, ship it
- **Bruce Schneier**: Security, threat modeling, fail safely

### Marge Quality Gate

After tests pass, Marge reviews the diff. She blocks for:
- Security vulnerabilities
- Outage risks
- Architecture violations
- Excessive complexity

She does NOT block for style preferences or theoretical concerns.

## Key Files

| File | Purpose |
|------|---------|
| `sandbox.sh` | Run Claude Code in isolated container |
| `worktree.sh` | Run Claude Code in git worktree (lightweight) |
| `Dockerfile` | Ralph sandbox container |
| `prompt.md` | Instructions for Ralph execution loop |
| `prd.json` | User stories with `passes` status |
| `progress.txt` | Append-only learnings |
| `agents/` | Lisa, Marge, War Room, Gemba Walk agents |

## Critical Concepts

### Gemba Walk (Lean Thinking)

Before planning, observe the actual code. "Go see, ask why, show respect." Produces a Reality Report that grounds all subsequent planning in what actually exists, not assumptions.

### Story Sizing

Each story MUST complete in one context window. Split big features:

**Right-sized:**
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic

**Too big (split these):**
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### Fresh Context Per Iteration

Each Ralph iteration spawns a new Claude instance with clean context. Memory persists only via:
- Git commits
- `progress.txt` learnings
- `prd.json` story status

## Debugging

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
```

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)**

```bash
cd flowchart && npm install && npm run dev
```

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
