# Parallel Work: Subagents & Agent Teams

## Default Mindset
Before starting any non-trivial task, ask: **"Can I split this into independent pieces?"**
- Multiple files to search -> parallel Explore agents
- Code to write + tests to run -> background build while editing
- Feature spanning macro + sampler + tests -> consider a team

## Subagents (Task Tool) — Quick Focused Workers

Independent agents spawned via `Task` tool. Fire-and-forget, results return to parent only.

**When to use:**
- Research/exploration
- Independent file edits that don't overlap
- Build/test in background while you continue coding
- Any focused task where you just need results back

**Properties:**
- Match `subagent_type` to work: `swift-expert` (features), `spm-builder` (builds), `swift-test-writer` (TDD), `Explore` (search), `Plan` (architecture)
- `model: "haiku"` for simple/cheap tasks; omit for complex work

## Agent Teams (TeamCreate) — Coordinated Project Crews

Multiple persistent agents sharing a task list. Use for multi-module features.

## Decision Matrix

| Scenario | Use |
|----------|-----|
| Search codebase from multiple angles | Subagents (Explore) |
| Build in background while coding | Subagent (spm-builder, `run_in_background`) |
| Write tests for code you just wrote | Subagent (swift-test-writer) |
| Implement macro + sampler + tests in parallel | Agent Team |
| Single focused task (any complexity) | Subagent |

## Anti-Patterns
- Teams for single-file changes
- Multiple agents editing the same file
- Spawning agents for trivial inline tasks
- Forgetting `run_in_background` for builds/tests
