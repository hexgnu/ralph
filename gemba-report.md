# Gemba Walk: Shell-to-Rust Conversion Assessment

**Date:** 2026-01-09
**Observer:** Lisa (Planning Agent)
**Question:** Would converting Ralph from shell scripts to Rust be valuable?

---

## Executive Summary

Ralph is a ~1850 line shell script system that orchestrates Claude Code for autonomous PRD-driven development. The shell scripts are thin wrappers around Claude CLI, providing terminal UI, process orchestration, git integration, and container isolation.

**Key Finding:** The shell scripts work. The question is whether Rust would solve real problems or create new ones.

---

## Current State Summary

### Shell Script Inventory

| File | Lines | Purpose |
|------|-------|---------|
| worktree.sh | 530 | Git worktree management, feature isolation |
| marge.sh | 382 | Quality gate (4 modes: PRD review, diff review, verification, squash) |
| bart.sh | 231 | Chaos testing / adversarial PRD review |
| lisa.sh | 194 | Planning agent orchestration |
| ralph.sh | 180 | Main execution loop |
| sandbox.sh | 117 | Docker/Podman container isolation |
| lib/output.sh | 85 | Shared output formatting library |
| claude-stream.sh | 51 | Claude JSON stream parser |
| install.sh | 43 | Global installation script |
| entrypoint.sh | 39 | Docker container entrypoint |

**Total: ~1852 lines of shell code**

### Supporting Infrastructure
- Dockerfile (36 lines) - Container definition
- Agent definitions in `agents/*.md` (5 files, ~800 lines total)
- Skills in `skills/` (2 SKILL.md files)
- Flowchart visualization in `flowchart/` (React/TypeScript)

---

## Patterns In Use

### 1. JSON Stream Processing Pattern
Every agent script (lisa.sh, bart.sh, marge.sh, ralph.sh) contains a near-identical `stream_claude()` function:
```bash
stream_claude() {
    local prompt="$1"
    claude --dangerously-skip-permissions --verbose --output-format stream-json -p "$prompt" 2>&1 | while IFS= read -r line; do
        # JSON parsing with jq
        TYPE=$(echo "$line" | jq -r '.type // empty')
        # ... tool-specific formatting
    done
}
```
**Observation:** ~50 lines duplicated 5 times = ~250 lines of duplication.

### 2. Color Definition Pattern
Every script defines the same color codes:
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
```
**Observation:** Partially addressed by lib/output.sh but not consistently used.

### 3. NVM Loading Pattern
Multiple scripts have:
```bash
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use --lts --silent 2>/dev/null || true
```
**Observation:** Required because `claude` is an npm-installed command.

### 4. Container Detection Pattern (sandbox.sh)
```bash
if command -v podman &>/dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
    CONTAINER_CMD="docker"
```

### 5. Git Operations Pattern (worktree.sh)
Complex git worktree management with branch detection, conflict handling, and cleanup.

---

## Technical Debt Inventory

| Debt | Location | Load-bearing? | Notes |
|------|----------|---------------|-------|
| Duplicated stream_claude() | All agent scripts | Yes | Could be shared library |
| Duplicated color definitions | All scripts | No | lib/output.sh exists but underused |
| NVM loading boilerplate | All scripts | Yes | Required for claude command |
| Hardcoded paths | Multiple | No | ~/.claude, /usr/local/bin |
| No error recovery in stream | stream functions | Yes | Silent failures possible |
| JSON parsing with subshells | All stream functions | No | Performance concern at scale |
| No test suite | Entire codebase | Yes | Zero automated tests |

---

## Landmine Map

- [ ] **If you change JSON stream format, update ALL 5 files** - The stream parsing is duplicated everywhere
- [ ] **NVM dependency is implicit** - Scripts fail silently if nvm is not set up
- [ ] **jq is a hard dependency** - No graceful fallback if jq is missing
- [ ] **Container commands assume rootless mode** - May fail in some environments
- [ ] **Git worktree operations are complex** - Many edge cases around existing branches, dirty state
- [ ] **Claude output format changes would break everything** - Tight coupling to `--output-format stream-json`

---

## Hidden Dependencies

### External Tools Required
1. **jq** (JSON processing) - Hard dependency
2. **git** (version control) - Hard dependency
3. **docker/podman** (containerization) - Optional for sandbox mode
4. **claude CLI** (npm package @anthropic-ai/claude-code) - Core dependency
5. **nvm** (Node version manager) - Currently required for claude
6. **rsync** (sandbox.sh for applying changes)
7. **gosu** (Dockerfile for privilege dropping)

### Claude CLI Coupling
The scripts depend on these Claude CLI features:
- `--dangerously-skip-permissions` flag
- `--verbose` flag
- `--output-format stream-json` format
- `--agent <name>` flag for agent selection
- `-p` flag for prompt passing

### File Format Coupling
- prd.json schema
- Agent .md frontmatter format
- Progress log text format

---

## Testing Reality

- **What's actually tested?** Nothing. No test suite exists.
- **What's untested but critical?**
  - JSON stream parsing correctness
  - Git worktree edge cases
  - Container credential copying
  - Error handling in all paths
  - Cross-platform compatibility (Linux vs macOS)

---

## Integration Points with Claude Code

The shell scripts are thin wrappers around Claude Code. The actual "intelligence" lives in:

1. **Agent markdown files** - System prompts that define behavior
2. **Claude CLI** - The actual LLM invocation
3. **prd.json** - State persistence between iterations

The shell scripts provide:
- Terminal UI (colors, progress indicators)
- Process orchestration (loops, retries)
- Git integration (branches, commits)
- Container isolation
- File management (archives, progress logs)

---

## What Would Rust Change?

### Potential Benefits

| Benefit | Impact | Notes |
|---------|--------|-------|
| Single binary distribution | High | No nvm/jq dependencies |
| Type safety | Medium | Would catch JSON parsing issues at compile time |
| Cross-platform | High | Windows support (shell doesn't work) |
| Performance | Low | Not a bottleneck - Claude API is the slow part |
| Error handling | Medium | Rust forces explicit error handling |
| Testability | High | Unit testing is natural in Rust |
| Code organization | Medium | Modules instead of sourced files |

### Potential Costs

| Cost | Impact | Notes |
|------|--------|-------|
| Development time | High | Rewriting 1800 lines is significant |
| Learning curve | Medium | Contributors need Rust knowledge |
| Compilation | Low | Must compile for each platform |
| Process spawning complexity | Medium | Calling Claude CLI from Rust adds layers |
| Loss of transparency | Medium | Shell is easily inspected/modified |
| Maintenance burden shift | Unknown | Different skill set needed |

---

## Questions for War Room

1. **What problem does Rust solve here?** The scripts work. Where is the pain?

2. **What's the cost of the shell/jq dependency chain?** Is installation friction a real issue?

3. **Would a Rust CLI change the user experience meaningfully?**

4. **Can we maintain Claude CLI integration from Rust?** (Process spawning, stdout parsing)

5. **What's the maintenance burden difference?** Shell scripts are simpler to modify.

6. **Would type safety in Rust prevent any real bugs?** Current bugs are logical, not type-related.

7. **Cross-platform concern**: Do we need Windows support? Shell doesn't work there.

8. **Distribution**: Single binary vs npm install vs shell scripts - which is easiest for users?

9. **Testing**: Would a rewrite be an opportunity to add comprehensive tests?

10. **Incremental path**: Could we write Rust libraries and call them from shell?

---

## Current Pain Points (Observed)

1. **Installation friction** - Users need nvm, jq, claude CLI
2. **No Windows support** - Shell scripts are Unix-only
3. **Code duplication** - stream_claude() is copy-pasted
4. **Silent failures** - Errors don't always surface clearly
5. **No tests** - Changes are risky without verification

---

*"Go see, ask why, show respect." - The shell scripts exist because they were quick to write and easy to iterate. Rust would solve some problems but create others. The question is which problems matter more.*
