# War Room Verdict: Shell-to-Rust Conversion

**Date:** 2026-01-09
**Reviewer:** Bart (Chaos Agent)
**PRD:** prd-rusty.json
**Verdict:** NEEDS WORK (but also: QUESTION THE PREMISE)

---

## Executive Summary

The A3 Analysis recommended "Fix shell first, consider Rust later." Yet here's a full Rust conversion PRD. Bart found:

1. **Several stories are too big** - US-001, US-004, US-006, US-012 need splitting
2. **Effort is underestimated** - "2-4 weeks" for 14 stories is optimistic
3. **Dependencies are misordered** - Git ops and terminal output needed early
4. **Windows support not broken down** - It's a different universe
5. **Missing stories** - Logging, config, signals, migration path
6. **The premise is questionable** - Why ignore the A3 recommendation?

---

## Story-by-Story Chaos Findings

### [US-001] Initialize Rust project with CLI structure - **SPLIT IT**

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Missing Rust edition/MSRV | HIGH | What version to support? |
| Async runtime choice not made | HIGH | Tokio vs async-std affects everything |
| Story combines 3 different concerns | HIGH | Deps, CLI, structure |

**Recommended Split:**
- US-001a: Create Cargo.toml with dependencies and MSRV
- US-001b: Create clap CLI argument parser structure
- US-001c: Create project module hierarchy

---

### [US-002] Define PRD JSON types and parsing

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Extra fields handling | MEDIUM | Deny unknown or accept? |
| Status enum casing | MEDIUM | "in_progress" vs "IN_PROGRESS" |
| BOM handling | LOW | Windows editors add these |

**Suggested criteria additions:**
- Define serde behavior for unknown fields
- Case-insensitive status parsing
- Handle UTF-8 BOM gracefully

---

### [US-003] Implement terminal output module

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Windows console API differences | HIGH | Not just ANSI codes |
| NO_COLOR env var | MEDIUM | Standard not mentioned |
| Wide character wrapping | LOW | CJK text |

**Suggested criteria additions:**
- Support NO_COLOR environment variable
- Handle Windows Console API vs Windows Terminal
- Test with Unicode/emoji output

---

### [US-004] Create Claude CLI wrapper - **SPLIT IT (CRITICAL)**

**This is the hardest story hidden as #4**

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| NVM not available to Rust | CRITICAL | How does Rust find claude? |
| Story combines 3 concerns | HIGH | Location, spawning, lifecycle |
| No timeout defined | HIGH | Claude can hang forever |
| No retry behavior defined | MEDIUM | Rate limits, network issues |

**Recommended Split:**
- US-004a: Locate Claude CLI binary (PATH, NVM, config)
- US-004b: Spawn Claude process with flags
- US-004c: Handle process lifecycle (timeout, signals, restart)

---

### [US-005] Implement JSON stream parser

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| 10MB JSON line | HIGH | Memory explosion |
| Partial line handling | HIGH | Process died mid-write |
| Non-JSON lines mixed in | MEDIUM | NVM/bash errors |

**Suggested criteria additions:**
- Define max line length handling (truncate or error)
- Handle incomplete JSON gracefully
- Filter out non-JSON stderr pollution

---

### [US-006] Implement ralph run subcommand - **SPLIT IT**

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Story is 180 shell lines | HIGH | Too big for one context |
| PRD file locking | MEDIUM | Concurrent runs |
| Ctrl+C handling | HIGH | Cleanup needed |
| Archive logic included | MEDIUM | Separate concern |

**Recommended Split:**
- US-006a: Core execution loop (pick story, invoke Claude)
- US-006b: PRD status updates and progress logging
- US-006c: Archive management and branch tracking
- US-006d: Completion detection and final verification

---

### [US-007] Implement marge subcommand

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Two modes in one story | MEDIUM | Diff review vs squash |
| Squash merge-base edge cases | MEDIUM | Orphan branches |
| Verdict parsing | LOW | Could be extracted |

**OK as-is** but add criteria for both modes working

---

### [US-008] Implement lisa subcommand

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Path injection via --name | HIGH | Sanitize input |
| Overwrite behavior undefined | MEDIUM | Fail or overwrite? |
| Artifact validation | MEDIUM | What if Claude doesn't create files? |

**Suggested criteria additions:**
- Sanitize --name to prevent path traversal
- Define overwrite vs fail behavior
- Validate all expected artifacts exist

---

### [US-009] Implement bart subcommand

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Detached HEAD in branch mode | MEDIUM | Edge case |
| Massive PRD output | LOW | 100 stories = huge report |

**OK as-is**

---

### [US-010] Implement git operations module - **REORDER**

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Needed by US-006, US-007, US-011, US-012 | CRITICAL | Wrong order |
| git2 vs git CLI choice | HIGH | Big decision buried |
| 15+ git operations to implement | HIGH | This is big |

**Recommended:** Move to US-003 or US-004 position

---

### [US-011] Implement worktree subcommand

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Relative WORKTREE_BASE path | HIGH | Shell uses "../ralph-worktrees" |
| Running process detection | MEDIUM | Remove worktree with Claude running? |
| Cross-filesystem issues | LOW | Different mount points |

**Suggested criteria additions:**
- Use absolute paths internally
- Detect and warn about running processes
- Handle filesystem boundary issues

---

### [US-012] Implement sandbox subcommand - **SPLIT IT (BIG)**

**This story is 117 shell lines doing:**
1. Container runtime detection
2. Image building
3. Workspace copying
4. Credential management
5. Container execution
6. Change detection
7. Interactive apply prompt
8. rsync back

**Recommended Split:**
- US-012a: Container runtime detection (docker vs podman)
- US-012b: Image build and workspace setup
- US-012c: Container execution with credential handling
- US-012d: Post-exit change detection and application

---

### [US-013] Add comprehensive test suite

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| "Comprehensive" undefined | HIGH | 80%? 90%? |
| Mock Claude responses | HIGH | How to test without API? |
| Container tests in CI | MEDIUM | No docker in most CI |

**Suggested criteria additions:**
- Define coverage target (e.g., 80% line coverage)
- Document mocking strategy for Claude CLI
- Define which tests need real containers

---

### [US-014] Create release binaries

**Chaos Points:**
| Issue | Severity | Notes |
|-------|----------|-------|
| Cross-compilation complexity | HIGH | aarch64-apple-darwin from Linux? |
| Code signing/notarization | MEDIUM | macOS requires this |
| glibc compatibility | MEDIUM | Static vs dynamic linking |

**Suggested criteria additions:**
- Define exact target triples
- Decide on static vs dynamic linking
- Define whether signing is in scope

---

## Missing Stories Identified

| Missing Piece | Why Needed | Suggested ID |
|--------------|------------|--------------|
| Logging framework | Debugging production issues | US-003.5 |
| Configuration file support | User preferences, paths | US-002.5 |
| Signal handling | Ctrl+C, SIGTERM cleanup | US-005.5 |
| Windows platform specifics | Paths, consoles, containers | US-010.5 |
| Migration from shell | Upgrade path for existing users | US-015 |
| Dependency audit | Supply chain security | US-016 |

---

## Assumptions Questioned

| Assumption | Risk | What If Wrong? |
|------------|------|----------------|
| "2-4 weeks of effort" | HIGH | More like 2-4 months realistically |
| "3000-4000 lines" | MEDIUM | Could be 8000+ with error handling |
| Claude CLI format is stable | HIGH | Stream parser breaks on update |
| NVM environment replicable | HIGH | May still need shell wrapper |
| Users want single binary | MEDIUM | Current system "just works" |
| Windows support is desired | MEDIUM | No evidence of demand |

---

## Effort Reality Check

**A3 said 2-4 weeks.** Let's count:

| Story Group | Stories | Realistic Days |
|-------------|---------|----------------|
| Project setup (US-001) | 3 (after split) | 2 |
| Types & parsing (US-002) | 1 | 1 |
| Terminal output (US-003) | 1 | 2 |
| Claude wrapper (US-004) | 3 (after split) | 5 |
| Stream parser (US-005) | 1 | 2 |
| Ralph run (US-006) | 4 (after split) | 8 |
| Marge (US-007) | 1 | 3 |
| Lisa (US-008) | 1 | 2 |
| Bart (US-009) | 1 | 1 |
| Git operations (US-010) | 1 | 5 |
| Worktree (US-011) | 1 | 3 |
| Sandbox (US-012) | 4 (after split) | 8 |
| Tests (US-013) | 1 | 5 |
| Release (US-014) | 1 | 3 |

**Total: 50+ working days = 10+ weeks**

---

## Meta-Chaos: Question the Premise

The A3 Analysis concluded:
> "Fix shell first, consider Rust later if Windows demand materializes or if Claude CLI deprecation forces direct API integration."

This PRD ignores that recommendation. Questions:

1. **Has Windows demand materialized?** If not, why are we doing this?
2. **Is Claude CLI being deprecated?** If not, why direct integration?
3. **What pain point does this solve TODAY?** Installation friction? Fix that in shell.
4. **Who asked for Rust?** Developer ego or user need?

**If the answer is "We want to explore Rust"** - that's valid! But say so in the PRD instead of pretending it's solving user problems.

---

## Critical Fixes Required Before Implementation

### 1. Split these stories immediately:
- US-001 → 3 stories
- US-004 → 3 stories
- US-006 → 4 stories
- US-012 → 4 stories

### 2. Reorder for dependencies:
```
US-001 (project setup)
US-002 (types)
US-003 (terminal output) ← move here
US-010 (git operations) ← move here
US-004 (claude wrapper)
US-005 (stream parser)
... rest in dependency order
```

### 3. Add missing stories:
- Logging framework
- Configuration management
- Signal handling
- Windows platform support
- Migration path

### 4. Update effort estimate:
Change "2-4 weeks" to "8-12 weeks" for realistic planning

### 5. Answer the meta-question:
Why are we doing this when A3 said not to?

---

## Final Verdict

**NEEDS WORK** - Specifically:

| Fix | Priority | Impact |
|-----|----------|--------|
| Split 4 oversized stories | CRITICAL | Context window failures |
| Reorder for dependencies | HIGH | Build order broken |
| Add missing stories | HIGH | Incomplete feature |
| Update effort estimate | HIGH | Planning failure |
| Answer "why Rust now?" | MEDIUM | Clarity of purpose |

The PRD can proceed after these fixes, but the team should explicitly acknowledge this is a speculative investment, not an urgent user need.

---

*"Eat my shorts... but also, did anyone ask for this?"*
-- Bart
