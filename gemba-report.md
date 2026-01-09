# Gemba Walk Reality Report
## Feature: Remove AMP, Rely on Claude Code Only

**Date:** 2025-01-09
**Observer:** Lisa (Planning Agent)

---

## Executive Summary

The Ralph project currently uses **Amp** as its execution engine but references **Claude Code** in documentation and sandbox tooling. This creates confusion and inconsistency. The goal is to fully migrate from Amp to Claude Code.

---

## Current State: AMP References Found

### 1. `ralph.sh` (Execution Loop)
**Location:** Line 63
```bash
OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
```
- **Reality:** Uses `amp` command to execute the Ralph prompt
- **Impact:** Core execution - this is the heart of the system

### 2. `AGENTS.md` (Documentation)
**Locations:** Lines 5, 22-24, 40
```markdown
Ralph is an autonomous AI agent loop that runs Amp repeatedly...
- `ralph.sh` - The bash loop that spawns fresh Amp instances
- `prompt.md` - Instructions given to each Amp instance
- Each iteration spawns a fresh Amp instance with clean context
```
- **Reality:** Documentation describes Amp as the engine
- **Impact:** User/developer confusion

### 3. `skills/ralph/SKILL.md`
**Location:** Line 49
```markdown
Ralph spawns a fresh Amp instance per iteration with no memory of previous work.
```
- **Reality:** Skill documentation references Amp
- **Impact:** Inconsistent with Claude Code branding

### 4. `flowchart/index.html`
**Location:** Line 7
```html
<title>How Ralph Works with Amp</title>
```
- **Reality:** Page title references Amp
- **Impact:** Public-facing inconsistency

### 5. `flowchart/src/App.tsx`
**Locations:** Lines 43, 328
```tsx
{ id: '4', label: 'Amp picks a story', ...}
<h1>How Ralph Works with Amp</h1>
```
- **Reality:** Flowchart UI shows "Amp" terminology
- **Impact:** Public demo inconsistency

---

## Current State: Claude Code Already Used

### Already Using Claude Code:
1. **`sandbox.sh`** - Runs `claude --dangerously-skip-permissions`
2. **`Dockerfile`** - Installs `@anthropic-ai/claude-code` npm package
3. **`entrypoint.sh`** - Executes `gosu ralph claude --dangerously-skip-permissions`
4. **`lisa.sh`** - Uses `claude --agent lisa`
5. **`marge.sh`** - Uses `claude --agent marge`
6. **`README.md`** - References Claude Code, links to documentation
7. **`CLAUDE.md`** - Configuration for Claude Code

### Summary
| Component | Current State | Target State |
|-----------|--------------|--------------|
| `ralph.sh` | Uses `amp` | Use `claude` |
| `sandbox.sh` | Uses `claude` | Keep as-is |
| `lisa.sh` | Uses `claude` | Keep as-is |
| `marge.sh` | Uses `claude` | Keep as-is |
| `Dockerfile` | Installs Claude Code | Keep as-is |
| `entrypoint.sh` | Runs `claude` | Keep as-is |
| `AGENTS.md` | References Amp | Update to Claude Code |
| `skills/ralph/SKILL.md` | References Amp | Update to Claude Code |
| `flowchart/` | References Amp | Update to Claude Code |

---

## Technical Considerations

### Command Equivalence
- **Amp:** `amp --dangerously-allow-all`
- **Claude Code:** `claude --dangerously-skip-permissions`

The flag name differs but serves the same purpose (skip interactive permission prompts).

### Piping Input
Current ralph.sh:
```bash
cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all
```

Claude Code equivalent:
```bash
claude --dangerously-skip-permissions -p "$(cat "$SCRIPT_DIR/prompt.md")"
# OR
cat "$SCRIPT_DIR/prompt.md" | claude --dangerously-skip-permissions
```

Need to verify: Does Claude Code accept piped stdin the same way Amp does?

### Completion Signal
The current system uses `<promise>COMPLETE</promise>` as a completion marker. This is parsed from stdout:
```bash
if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
```
This should work identically with Claude Code.

---

## Files to Change

| File | Change Type | Risk |
|------|-------------|------|
| `ralph.sh` | Replace `amp` with `claude` | **HIGH** - Core execution |
| `AGENTS.md` | Update terminology | LOW - Documentation |
| `skills/ralph/SKILL.md` | Update terminology | LOW - Documentation |
| `flowchart/index.html` | Update title | LOW - UI |
| `flowchart/src/App.tsx` | Update labels | LOW - UI |

---

## Patterns Observed

1. **Consistency exists in new code:** The newer scripts (lisa.sh, marge.sh) already use `claude` command
2. **Sandbox already migrated:** Container infrastructure uses Claude Code
3. **Only `ralph.sh` is the holdout:** The main loop script is the only functional code still using `amp`
4. **Documentation lags behind:** AGENTS.md and flowchart haven't been updated

---

## Risks Identified

1. **Flag syntax:** `--dangerously-allow-all` vs `--dangerously-skip-permissions` - must use correct flag
2. **Input handling:** Need to verify stdin piping works identically
3. **Output capture:** Must ensure stdout/stderr capture still works for completion detection
4. **Breaking change:** If anyone is using the old `amp` command externally

---

## Recommendation

This is a **straightforward migration** with:
- 1 critical code change (`ralph.sh`)
- 4 documentation/UI updates
- Minimal risk since sandbox already proves Claude Code works

The pattern is already established in `lisa.sh`, `marge.sh`, and `entrypoint.sh`.
