# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ralph is an autonomous AI agent system for completing PRD-based development. It uses a **Lisa → Ralph → Marge** workflow:

- **Lisa**: Pre-planning (Gemba Walk → A3 Analysis → War Room → prd.json)
- **Ralph**: Execution loop (implement stories one by one)
- **Marge**: Quality gate (pre-commit review)

Memory persists via git history, `progress.txt`, and `prd.json`.

## Commands

```bash
# Run in sandboxed container (recommended for autonomous work)
./sandbox.sh "Implement user authentication"
./sandbox.sh --agent lisa "Plan: add OAuth support"

# Build the sandbox image
docker build -t ralph-sandbox .
# or
podman build -t ralph-sandbox .

# Flowchart visualization
cd flowchart && npm install && npm run dev
```

## Architecture

### The Simpsons Workflow

```
Feature Idea
    ↓
LISA (planning)
├── Gemba Walk - observe actual codebase
├── A3 Analysis - lean problem definition
├── War Room - Carmack/DHH/Schneier review
└── Output: prd.json
    ↓
RALPH (execution loop)
├── Pick highest priority story (passes: false)
├── Implement
├── Run tests
├── MARGE reviews (quality gate)
├── If COMMIT: git commit
├── If REJECT: fix and retry
└── Repeat until all stories pass
    ↓
DONE (<promise>COMPLETE</promise>)
```

### Key Files

| File | Purpose |
|------|---------|
| `sandbox.sh` | Run Claude Code in isolated container |
| `Dockerfile` | Ralph sandbox container definition |
| `entrypoint.sh` | Container entrypoint (copies credentials) |
| `prompt.md` | Instructions for Ralph execution loop |
| `prd.json` | User stories with `passes` status |
| `progress.txt` | Append-only learnings |
| `agents/` | Lisa, Ralph, Marge, War Room, Gemba Walk agents |

### Agents (`agents/`)

| Agent | Role |
|-------|------|
| `gemba-walk.md` | Observe codebase reality before planning |
| `war-room.md` | Adversarial review (Carmack, DHH, Schneier) |
| `lisa.md` | Orchestrate planning: gemba → A3 → war-room → prd.json |
| `marge.md` | Pre-commit quality gate |

## Key Concepts

### Gemba Walk (Lean)
Before planning, observe the actual code. Don't assume—read. Produces a Reality Report that grounds all subsequent planning.

### War Room Personas
Three adversarial reviewers attack the PRD:
- **John Carmack**: Performance, simplicity, no unnecessary abstraction
- **DHH**: Pragmatism, convention over configuration, ship it
- **Bruce Schneier**: Security, threat modeling, fail safely

### Story Sizing
Each story MUST complete in one context window. If too big, split it:
- Schema changes first
- Then backend logic
- Then UI components

### Marge Quality Gate
After tests pass, Marge reviews the diff before commit. She blocks for:
- Security issues
- Outage risks
- Architecture violations
- Excessive complexity

She does NOT block for style preferences or theoretical concerns.

### Sandbox Isolation
`sandbox.sh` runs Claude Code in a Docker/Podman container:
- Project files copied in (not mounted)
- `--dangerously-skip-permissions` is safe because it's containerized
- Changes reviewed before applying to real project

## Integrating with Your Agents

Copy the agents to your Claude config:
```bash
cp agents/*.md ~/.claude/agents/
```

Or mount them when running the sandbox (automatic if `~/.claude/agents/` exists).
