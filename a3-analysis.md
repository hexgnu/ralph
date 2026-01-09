# A3 Analysis: Remove AMP, Rely on Claude Code Only

**Date:** 2025-01-09
**Owner:** Lisa (Planning Agent)

---

## 1. Background

Ralph is an autonomous AI agent system for PRD-based development. It was originally built using Amp (Sourcegraph's AI CLI tool) but the project now wants to standardize on Claude Code (Anthropic's official CLI).

**Why now?**
- Claude Code is the officially supported tool from Anthropic
- The project already partially migrated (sandbox, lisa.sh, marge.sh use Claude Code)
- Maintaining two different AI CLI tools creates confusion and maintenance burden
- Documentation inconsistency confuses users

---

## 2. Current Condition (From Gemba Walk)

### Quantified State:
| Metric | Value |
|--------|-------|
| Files referencing `amp` command | 1 (`ralph.sh`) |
| Files referencing "Amp" in docs/UI | 4 |
| Files already using `claude` command | 5 |
| Percentage migrated | ~83% functional code, 0% docs/UI |

### Key Finding:
The core execution loop (`ralph.sh`) is the **only** functional code still using `amp`. Everything else has already migrated to Claude Code.

### Current User Experience:
1. User reads README - sees "Claude Code"
2. User looks at AGENTS.md - sees "Amp"
3. User views flowchart - sees "Amp"
4. User runs sandbox - uses Claude Code
5. User runs ralph.sh directly - uses Amp
6. **Result:** Confusion

---

## 3. Target Condition

### Success Metrics:
- [ ] Zero references to `amp` command in code
- [ ] Zero references to "Amp" (capitalized product name) in documentation
- [ ] All scripts use `claude` command consistently
- [ ] Flowchart updated to show "Claude Code"
- [ ] All tests pass (if any)
- [ ] Typecheck passes (for flowchart)

### User Experience After:
1. User reads any documentation - sees "Claude Code"
2. User views flowchart - sees "Claude Code"
3. User runs any script - uses Claude Code
4. **Result:** Consistency

---

## 4. Root Cause Analysis (5 Whys)

### Problem: The codebase has inconsistent AI CLI tool references

**Why #1:** ralph.sh still uses the `amp` command
- Because it was the original implementation

**Why #2:** The original implementation used Amp
- Because Amp was the available/chosen tool when Ralph was created

**Why #3:** Documentation wasn't updated when sandbox migrated
- Because the sandbox migration was focused on containerization, not terminology

**Why #4:** No single source of truth for which tool to use
- Because the migration happened incrementally without a formal decision

**Why #5 (Root Cause):** The project evolved from Amp to Claude Code organically without a deliberate, complete migration

### System-Level Insight:
Incremental migrations without explicit completion criteria lead to inconsistent states. This migration needs to be treated as a discrete, completable unit of work with verification.

---

## 5. Countermeasures

### Proposed Solution: Complete the Migration

**Approach:** Replace all `amp` references with `claude` equivalents

### Changes Required:

| File | Change | Rationale |
|------|--------|-----------|
| `ralph.sh` | Replace `amp --dangerously-allow-all` with `claude -p --dangerously-skip-permissions` | Core execution |
| `AGENTS.md` | Replace "Amp" with "Claude Code" | Documentation consistency |
| `skills/ralph/SKILL.md` | Replace "Amp" with "Claude Code" | Skill documentation |
| `flowchart/index.html` | Update title | UI consistency |
| `flowchart/src/App.tsx` | Update labels and header | UI consistency |

### Why This Approach:
1. **Minimal change:** Only 5 files need modification
2. **Pattern exists:** lisa.sh and marge.sh already show the correct pattern
3. **Proven infrastructure:** sandbox.sh proves Claude Code works in containers
4. **No architectural changes:** Same execution model, different CLI tool

### Alternatives Considered:

| Alternative | Reason Rejected |
|-------------|-----------------|
| Keep Amp for ralph.sh only | Inconsistent, confuses users |
| Abstract CLI behind a wrapper | Over-engineering, adds complexity |
| Remove ralph.sh entirely | Breaks core functionality |

---

## 6. Implementation Plan

### Order (by dependency):
1. **First:** Update `ralph.sh` (core functionality)
2. **Then:** Update `AGENTS.md` (main documentation)
3. **Then:** Update `skills/ralph/SKILL.md` (skill documentation)
4. **Then:** Update flowchart files (UI)
5. **Finally:** Verify typecheck passes

### Verification:
- Run `ralph.sh` in sandbox to verify it works
- Run typecheck on flowchart
- Grep for remaining "amp" or "Amp" references

---

## 7. Follow-up

### After Implementation:
- [ ] Document the migration in progress.txt
- [ ] Consider adding a CI check for "amp" references to prevent regression

### Lessons Learned:
- When migrating tools, create a complete checklist upfront
- Documentation should be updated atomically with code changes
- Incremental migrations need explicit "done" criteria
