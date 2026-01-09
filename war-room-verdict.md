# War Room Review: Remove AMP, Rely on Claude Code Only

**Date:** 2025-01-09
**Reviewers:** Carmack, DHH, Schneier (simulated)

---

## Proposal Summary

Replace all references to Amp CLI with Claude Code CLI in:
1. `ralph.sh` - Core execution loop
2. `AGENTS.md` - Main documentation
3. `skills/ralph/SKILL.md` - Skill documentation
4. `flowchart/index.html` - Page title
5. `flowchart/src/App.tsx` - UI labels

---

## John Carmack's Review

### Concerns:

**1. Stdin Piping Behavior**
> "You're assuming Claude Code handles piped input the same way Amp does. Have you verified this? The current code does `cat prompt.md | amp`, but Claude Code might need `-p` flag or different syntax."

**Response:** Valid concern. Looking at existing code:
- `lisa.sh` uses: `claude --agent lisa "$@"` (args, not piped)
- `marge.sh` uses: `claude --agent marge "..."` (args, not piped)
- `entrypoint.sh` uses: `claude --dangerously-skip-permissions "$@"`

The `-p` flag in Claude Code is for prompt input. The migration should use:
```bash
claude --dangerously-skip-permissions -p "$(cat "$SCRIPT_DIR/prompt.md")"
```

**Mitigation:** Update the story to explicitly test stdin handling.

**2. Flag Naming**
> "The flag is `--dangerously-skip-permissions`, not `--dangerously-allow-all`. Make sure you get this right or it will fail silently or error."

**Response:** Correct. This is already documented in the Gemba report.

### Verdict: **PROCEED** with explicit testing requirement

---

## DHH's Review

### Concerns:

**1. Why Are We Even Discussing This?**
> "This is a 15-minute task. You're replacing one CLI tool with another that you already use elsewhere. Stop planning and ship it."

**Response:** Fair. The changes are straightforward.

**2. Over-Engineering Alert**
> "You don't need 4 separate user stories for what is essentially a find-and-replace operation. This could be one commit."

**Response:** Counterpoint - stories should be atomic for Ralph's context window. However, DHH has a point that these are tightly coupled.

**Compromise:** Reduce to 2 stories:
1. Code changes (ralph.sh) - must work before docs
2. Documentation changes (all docs/UI) - can be one atomic update

### Verdict: **PROCEED** but simplify the stories

---

## Bruce Schneier's Review

### Concerns:

**1. Permission Model**
> "Both `--dangerously-allow-all` and `--dangerously-skip-permissions` are dangerous flags. Are you confident the sandbox isolation is sufficient?"

**Response:** The sandbox (Docker/Podman container) provides the isolation. The flag is safe because:
- Project files are copied, not mounted
- Network can be restricted
- User reviews changes before applying

This doesn't change with the migration.

**2. Supply Chain**
> "You're switching from one AI CLI to another. Have you verified the Claude Code npm package is legitimate and from Anthropic?"

**Response:** The package is `@anthropic-ai/claude-code` from npm, published by Anthropic. The Dockerfile already installs it. No new supply chain risk.

**3. Credential Handling**
> "The entrypoint.sh copies credentials. Does Claude Code handle them the same way as Amp?"

**Response:** This is already working - sandbox.sh and entrypoint.sh already use Claude Code and handle credentials. No change to credential flow.

### Verdict: **PROCEED** - no new security concerns

---

## Combined War Room Verdict

### **VERDICT: PROCEED**

### Conditions:
1. **Test stdin handling** - Verify `claude -p "$(cat prompt.md)"` works correctly
2. **Simplify stories** - Reduce from 4-5 stories to 2:
   - Story 1: Update ralph.sh (functional change)
   - Story 2: Update all documentation/UI (cosmetic changes)
3. **Verify completion detection** - Ensure `<promise>COMPLETE</promise>` parsing still works

### Risk Assessment:
| Risk | Severity | Mitigation |
|------|----------|------------|
| Stdin handling differs | Medium | Test in story 1 |
| Flag syntax error | Low | Use documented flag |
| Flowchart typecheck fails | Low | Run tsc as acceptance criteria |

### Not Blocked:
- No security concerns introduced
- No architectural issues
- No performance concerns
- Existing patterns in codebase prove the approach works

---

## Action Items for Implementation

1. Story US-001: Update ralph.sh
   - Replace amp command with claude command
   - Use `-p` flag for prompt input
   - Use `--dangerously-skip-permissions` flag
   - Test completion detection works

2. Story US-002: Update all documentation and UI
   - AGENTS.md
   - skills/ralph/SKILL.md
   - flowchart/index.html
   - flowchart/src/App.tsx
   - Run flowchart typecheck
