# Documentation Standards

## Inline
- Public types and methods: `///` doc comment required
- Include `- Parameter name:` and `- Returns:` for non-trivial functions
- Private code: doc comment only when behavior is non-obvious
- Comments explain WHY, never WHAT

## Architecture Decision Records
Path: `docs/decisions/NNNN-title.md`
```
# NNNN. Title
Date: YYYY-MM-DD
Status: proposed | accepted | deprecated | superseded by NNNN
## Context
## Decision
## Consequences
```
Create ADR for: architecture choices, library selections, pattern decisions.

**When to write an ADR (mandatory):**
- Choosing between multiple valid approaches
- Adopting or replacing a library/framework
- Changing data flow or processing pipeline
- Any decision you'd want to explain to your future self

## Learnings
Agents append discoveries to `## Learnings` in root `CLAUDE.md`:
- Format: `- <learning>` — one concise line
