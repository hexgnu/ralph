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
