# A3 Analysis: Shell-to-Rust Conversion for Ralph

**Date:** 2026-01-09
**Owner:** Lisa (Planning Agent)
**Question:** Would converting Ralph from shell scripts to Rust be valuable?

---

## 1. Background

Ralph is an autonomous AI agent system (~1850 lines of shell scripts) that orchestrates Claude Code for PRD-driven development. The current implementation uses bash scripts with jq for JSON processing.

**Why this question now?**
- Growing user base means distribution/installation matters more
- Windows users cannot run shell scripts
- Code duplication across scripts creates maintenance burden
- No test suite makes changes risky
- Interest in exploring Rust as potentially cleaner solution

**Business Context:**
- Ralph is a developer tool - developers have opinions about languages
- Installation friction can kill adoption
- Cross-platform support expands potential user base
- Maintenance burden affects long-term viability

---

## 2. Current Condition (From Gemba Walk)

### Quantified State:
| Metric | Value |
|--------|-------|
| Total shell script lines | ~1852 |
| Number of shell scripts | 10 |
| Duplicated stream_claude() | 5 instances (~250 lines) |
| External dependencies | 7 (jq, git, docker/podman, claude, nvm, rsync, gosu) |
| Test coverage | 0% |
| Supported platforms | Unix-like only (Linux, macOS) |

### Current Architecture:
```
User
  ↓
Shell Scripts (thin wrappers)
  ├── lisa.sh → claude CLI → Claude API
  ├── bart.sh → claude CLI → Claude API
  ├── ralph.sh → claude CLI → Claude API (loop)
  └── marge.sh → claude CLI → Claude API
  ↓
Claude Code (does the actual work)
  ↓
prd.json (state persistence)
```

### Key Observation:
The shell scripts are **thin orchestration wrappers**. The "intelligence" is in:
1. Agent markdown files (system prompts)
2. Claude CLI (process invocation)
3. prd.json (state machine)

The shell scripts add:
- Terminal UI (colors, banners)
- Process loops (iterations, retries)
- Git operations (branches, commits, worktrees)
- Container management (docker/podman)

---

## 3. Target Condition

### What would "successful Rust conversion" look like?

| Metric | Target |
|--------|--------|
| Single binary distribution | Yes - `ralph` binary, no dependencies |
| Cross-platform support | Linux, macOS, Windows |
| Test coverage | >80% for core logic |
| Installation | `cargo install ralph` or download binary |
| Maintenance | Rust expertise required, but cleaner code |
| Feature parity | All current functionality preserved |

### User Experience After:
```bash
# Installation
brew install ralph
# or
cargo install ralph
# or
curl -L https://releases.ralph.dev/latest/ralph-linux-amd64 > /usr/local/bin/ralph

# Usage (unchanged)
ralph --agent lisa "Plan: add OAuth support"
ralph run prd.json
ralph marge --squash
```

---

## 4. Root Cause Analysis (5 Whys)

### Problem: Should we invest in Rust conversion?

**Why #1:** Installation friction exists
- Because users need nvm, jq, and claude CLI

**Why #2:** Multiple dependencies required
- Because shell scripts can't parse JSON natively (need jq)
- Because claude CLI is npm-installed (need nvm)

**Why #3:** Shell was chosen
- Because it was the fastest path to working prototype

**Why #4:** Prototype became product
- Because the workflow proved valuable and users adopted it

**Why #5 (Root Cause):** Technology choice was optimized for speed-to-value, not distribution

### System-Level Insight:
The real question is not "Shell vs Rust" but "What are the actual pain points and does a rewrite solve them?"

### Pain Points Identified:
1. **Installation friction** - Real pain, affects adoption
2. **No Windows support** - Real limitation, unclear demand
3. **Code duplication** - Maintenance burden, but manageable
4. **No tests** - Real risk, but fixable without rewrite
5. **Silent failures** - UX issue, fixable in shell

---

## 5. Analysis: Build vs. Fix

### Option A: Rewrite in Rust

| Aspect | Assessment |
|--------|------------|
| **Effort** | HIGH - ~2-4 weeks full-time for feature parity |
| **Risk** | MEDIUM - New bugs, unfamiliar codebase |
| **Benefits** | Single binary, type safety, tests, Windows |
| **Costs** | Development time, Rust expertise requirement |
| **Dependencies removed** | jq, nvm (but adds Rust compilation) |

**What Rust rewrite would include:**
- CLI argument parsing (clap)
- JSON parsing (serde)
- Process spawning (std::process)
- Terminal UI (indicatif, colored)
- Git operations (git2)
- HTTP for container APIs (reqwest)

**Estimated Rust lines:** ~3000-4000 (Rust is more verbose than shell for simple tasks)

### Option B: Fix Shell Scripts

| Aspect | Assessment |
|--------|------------|
| **Effort** | LOW - ~2-3 days |
| **Risk** | LOW - Incremental changes |
| **Benefits** | Addresses immediate pain points |
| **Costs** | Still no Windows, still has dependencies |

**What shell fixes would include:**
- Extract shared `lib/stream.sh`
- Add comprehensive error handling
- Add shell-based tests (bats)
- Improve installation script
- Add dependency checker

### Option C: Hybrid Approach

| Aspect | Assessment |
|--------|------------|
| **Effort** | MEDIUM - ~1 week |
| **Risk** | LOW-MEDIUM |
| **Benefits** | Best of both worlds |
| **Costs** | Two codebases to maintain |

**What hybrid would include:**
- Rust CLI for core (JSON parsing, state management, TUI)
- Shell scripts for platform-specific (git, docker)
- Gradual migration path

---

## 6. Recommendation

### Verdict: **Option B (Fix Shell) with Option C (Hybrid) as Future Path**

**Rationale:**
1. **Immediate pain is not language** - It's code duplication and error handling
2. **Windows demand is unproven** - No evidence users need Windows support
3. **Rust rewrite is speculative investment** - Solving theoretical problems
4. **Shell fixes are incremental** - Low risk, immediate benefit
5. **Hybrid path keeps options open** - Can migrate to Rust gradually if needed

### If We Did Rust Anyway:

**When it would make sense:**
- Significant Windows user demand emerges
- Claude CLI is deprecated (need direct API calls)
- Distribution to non-developer users (single binary matters)
- Team has strong Rust expertise and time

**Implementation order if proceeding:**
1. Start with `ralph` binary (most complex, most used)
2. Add `marge` (quality gate logic)
3. Add `lisa` and `bart` (agent invocation)
4. Last: `sandbox` and `worktree` (platform-specific)

---

## 7. If Proceeding with Rust: Architecture

### Proposed Structure:
```
ralph/
├── Cargo.toml
├── src/
│   ├── main.rs              # CLI entry point
│   ├── cli/
│   │   ├── mod.rs
│   │   ├── lisa.rs          # Lisa subcommand
│   │   ├── bart.rs          # Bart subcommand
│   │   ├── ralph.rs         # Ralph execution loop
│   │   └── marge.rs         # Marge quality gate
│   ├── claude/
│   │   ├── mod.rs
│   │   ├── client.rs        # Claude CLI wrapper
│   │   └── stream.rs        # JSON stream parser
│   ├── prd/
│   │   ├── mod.rs
│   │   ├── types.rs         # PRD JSON types
│   │   └── state.rs         # State machine
│   ├── git/
│   │   ├── mod.rs
│   │   ├── worktree.rs      # Worktree management
│   │   └── branch.rs        # Branch operations
│   ├── container/
│   │   ├── mod.rs
│   │   ├── docker.rs        # Docker support
│   │   └── podman.rs        # Podman support
│   └── output/
│       ├── mod.rs
│       ├── terminal.rs      # Terminal UI
│       └── colors.rs        # Color definitions
└── tests/
    ├── cli_tests.rs
    ├── prd_tests.rs
    └── integration_tests.rs
```

### Key Dependencies:
```toml
[dependencies]
clap = { version = "4", features = ["derive"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
git2 = "0.18"
colored = "2"
indicatif = "0.17"
thiserror = "1"
```

---

## 8. Implementation Stories (If Proceeding)

### US-001: Project Setup and CLI Structure
- Initialize Cargo project
- Set up clap CLI with subcommands
- Create module structure

### US-002: PRD Type Definitions and Parsing
- Define PRD JSON types with serde
- Implement prd.json read/write
- Add validation

### US-003: Claude CLI Wrapper
- Process spawning for `claude` binary
- JSON stream parsing
- Error handling

### US-004: Terminal Output System
- Progress indicators
- Colored output
- Tool result formatting

### US-005: Ralph Execution Loop
- Story selection logic
- Retry mechanism
- Status updates

### US-006: Marge Quality Gate
- PRD review mode
- Diff review mode
- Squash commit generation

### US-007: Lisa Planning Agent
- Gemba walk invocation
- A3 analysis generation
- Bart chaos review

### US-008: Git Operations
- Branch management
- Worktree creation/removal
- Commit operations

### US-009: Container Support
- Docker detection and invocation
- Podman support
- Credential handling

### US-010: Tests and Documentation
- Unit tests for all modules
- Integration tests
- README and usage docs

---

## 9. Follow-up

### If Choosing Shell Fixes:
- [ ] Extract lib/stream.sh shared library
- [ ] Add dependency checker to install.sh
- [ ] Add bats test suite
- [ ] Improve error messages

### If Choosing Rust:
- [ ] Create rust-ralph branch
- [ ] Start with US-001, iterate
- [ ] Maintain shell scripts until parity
- [ ] Plan deprecation timeline

### Metrics to Track:
- Installation success rate
- User platform distribution
- Bug reports by category
- Contribution rate (affected by language choice)

---

## 10. Conclusion

**The question "Would Rust be valuable?" has a nuanced answer:**

| Scenario | Answer |
|----------|--------|
| "Valuable for current users?" | Marginally - they already got it working |
| "Valuable for Windows users?" | Yes - if they exist |
| "Valuable for maintainability?" | Maybe - depends on team expertise |
| "Valuable for distribution?" | Yes - single binary is cleaner |
| "Worth the investment now?" | Probably not - fix shell first |

**Recommendation:** Fix the immediate shell script pain points (code duplication, error handling, tests). Revisit Rust if Windows demand materializes or if Claude CLI deprecation forces direct API integration.
