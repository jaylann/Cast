---
name: commit
description: Pre-commit workflow then commit. Runs simplify, revises CLAUDE.md, runs tests, then commits.
---

Follow these steps in order. Do NOT skip any step.

### 1. Simplify
Invoke `/simplify` on files changed in this session.

### 2. Revise CLAUDE.md
Invoke `claude-md-management:revise-claude-md` to capture learnings.

### 3. Run Tests
Use `/build test`. If tests fail, fix and re-run. Skip if changes don't affect testable code.

### 4. Commit
- Stage only your changes (no unrelated files)
- Concise commit message
- GitHub issue handling: close if fixed, comment if partially investigated, create new issues for unrelated problems noticed

$ARGUMENTS
