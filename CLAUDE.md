# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ralph is an autonomous AI agent system for completing PRD-based development. It uses a **Lisa → Ralph → Marge** workflow:

- **Lisa** (Opus): Strategic planner - Gemba Walk → A3 Analysis → Draft PRD → Bart Review → Refine
- **Bart** (Opus): Lisa's chaos twin - breaks PRDs before Ralph implements them
- **Ralph** (Opus): Execution loop - implements stories one by one with retry logic
- **Marge** (Sonnet): Quality gate with four modes - PRD review, diff review, verification, squash

Memory persists via git history, `prd.json`, and `{prd}-progress.txt`.

## Commands

```bash
# Run in sandboxed container (recommended for autonomous work)
./sandbox.sh "Implement user authentication"
./sandbox.sh --agent lisa "Plan: add OAuth support"

# Run in git worktree (lightweight alternative)
./worktree.sh add-oauth              # Create worktree and start Claude Code
./worktree.sh --create my-feature    # Create worktree only
./worktree.sh --list                 # List all ralph worktrees
./worktree.sh --remove my-feature    # Remove worktree

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
├── Draft PRD - initial user stories
├── Bart Review - chaos testing (edge cases, assumptions)
└── Refine - incorporate chaos findings
    ↓
Output: prd.json + gemba-report.md + a3-analysis.md + war-room-verdict.md
    ↓
RALPH (execution loop)
├── Pick highest priority pending story
├── Mark in_progress, spawn specialist agent
├── Run verification commands
├── If PASS → MARGE diff review
│   ├── COMMIT → git commit, mark completed
│   └── REJECT → fix and retry (max 3x)
├── If 3x FAIL → mark blocked
└── Repeat until all stories completed/blocked
    ↓
MARGE (verification mode) - final quality gate
    ↓
DONE (<promise>COMPLETE</promise>)
```

### Key Files

| File | Purpose |
|------|---------|
| `sandbox.sh` | Run Claude Code in isolated container |
| `worktree.sh` | Run Claude Code in git worktree (lightweight, full host access) |
| `Dockerfile` | Ralph sandbox container definition |
| `entrypoint.sh` | Container entrypoint (copies credentials) |
| `prd.json` | User stories with status, acceptance criteria, blockers |
| `{prd}-progress.txt` | Append-only learnings per PRD |
| `agents/` | Lisa, Bart, Ralph, Marge, Gemba Walk, War Room agents |

### Agents (`agents/`)

| Agent | Role |
|-------|------|
| `gemba-walk.md` | Observe codebase reality before planning (Sonnet) |
| `lisa.md` | Strategic planner: gemba → A3 → PRD → bart → refine (Opus) |
| `bart.md` | Chaos twin - finds edge cases, breaks PRDs before implementation (Opus) |
| `ralph.md` | Execution loop - implements stories with retry logic (Opus) |
| `marge.md` | Quality gate with 4 modes (Sonnet) |
| `war-room.md` | Adversarial review personas (Carmack/DHH/Schneier) |

## Key Concepts

### Lisa's 5-Step Planning

1. **Gemba Walk**: Observe actual code, don't assume
2. **A3 Analysis**: Lean problem definition (background, current/target state, root cause)
3. **Draft PRD**: Create context-window-sized stories with verifiable acceptance criteria
4. **Bart Review**: Chaos testing - find edge cases, missing pieces, broken assumptions
5. **Refine**: Incorporate chaos findings, split oversized stories

### Bart's Chaos Testing

Lisa's adversarial twin attacks the PRD before Ralph implements it:
- **Input Chaos**: Weird valid inputs, boundaries, Unicode/emojis, empty/oversized
- **State Chaos**: Simultaneous users, mid-action failures, service outages
- **Data Chaos**: No data, millions of rows, malformed, deleted relations
- **Boundary Chaos**: Limits, off-by-one, timezones, overflow

### Story Lifecycle

```
pending → in_progress → completed
                     → blocked (after 3 failures)
```

Each story MUST complete in one context window. If too big, split it:
- Schema changes first
- Then backend logic
- Then UI components

### Marge's Four Modes

1. **PRD Review** (pre-flight): Validates story sizing, acceptance criteria, dependency order
   - Verdict: GO or NO-GO

2. **Diff Review** (post-flight): Reviews after tests pass, before commit
   - Blocks for: Security vulns, outage risks, architecture violations, complexity
   - Does NOT block for: Style preferences, theoretical concerns
   - Verdict: COMMIT or REJECT

3. **Verification** (final gate): After all stories complete
   - Checks: Story-commit mapping, acceptance criteria evidence, full branch security review
   - Verdict: VERIFIED or FAILED

4. **Squash Commit**: Generates single summary commit message for entire feature

### War Room Personas

Three adversarial reviewers (used by Bart):
- **John Carmack**: Performance, simplicity, no unnecessary abstraction
- **DHH**: Pragmatism, convention over configuration, ship it
- **Bruce Schneier**: Security, threat modeling, fail safely

### Sandbox Isolation

`sandbox.sh` runs Claude Code in a Docker/Podman container:
- Project files copied in (not mounted)
- `--dangerously-skip-permissions` is safe because it's containerized
- Changes reviewed before applying to real project

### Worktree Mode

`worktree.sh` creates a git worktree for lightweight parallel development:
- No container overhead - instant startup
- Worktrees at `../ralph-worktrees/<feature-name>`
- Branches named `ralph/<feature-name>`
- **WARNING**: Full host filesystem access - use sandbox for untrusted code

**When to use worktree vs sandbox:**
| Scenario | Recommendation |
|----------|---------------|
| Trusted development work | Worktree |
| Parallel feature branches | Worktree |
| Untrusted code/experiments | Sandbox |
| Maximum isolation needed | Sandbox |

## Integrating with Your Agents

Copy the agents to your Claude config:
```bash
cp agents/*.md ~/.claude/agents/
```

Or mount them when running the sandbox (automatic if `~/.claude/agents/` exists).
