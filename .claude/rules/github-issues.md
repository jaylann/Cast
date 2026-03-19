---
paths:
  - ".github/**"
---

# GitHub Issues

## Requirements

**All issues MUST include:**
1. **Detailed description** - What, why, and where
2. **Acceptance criteria** - How to verify completion
3. **Appropriate labels** - type, priority, and area

## Label System

**Type (required):**
| Label | Use for |
|-------|---------|
| `type:bug` | Something broken |
| `type:feature` | New functionality |
| `type:enhancement` | Improve existing feature |
| `type:refactor` | Code restructuring |
| `type:docs` | Documentation |
| `type:chore` | Build, CI, cleanup |

**Priority (required for open issues):**
| Label | Use for |
|-------|---------|
| `priority:critical` | Blocks release, crashes, data loss |
| `priority:high` | Next sprint |
| `priority:medium` | Normal |
| `priority:low` | Backlog |

**Area (at least one):**
| Label | Use for |
|-------|---------|
| `area:grammar` | Grammar compilation, state machines |
| `area:macro` | @Castable macro, SwiftSyntax |
| `area:sampler` | Constrained sampling, logit masking |
| `area:tokenizer` | Tokenizer binding, caching |
| `area:api` | Public API, CastModel, property wrappers |
| `area:mlx` | MLX Swift integration |
| `area:benchmarking` | CastBench, performance |
| `area:prompt` | Prompt engine, chat templates |

## Title Conventions

```
[Area] Brief description
```

Examples:
- `[Grammar] State machine doesn't handle nested arrays`
- `[Macro] @Range validation missing for Double`
- `[Sampler] Token mask cache miss on repeated generation`

## Creating Issues via CLI

```bash
gh issue create --title "[Area] Description" \
  --label "type:bug,priority:high,area:grammar" \
  --body "$(cat <<'EOF'
## Description
What's happening and what should happen instead.

## Acceptance Criteria
- [ ] ...
EOF
)"
```
