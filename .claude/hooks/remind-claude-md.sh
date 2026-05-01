#!/usr/bin/env bash
# Stop / SubagentStop hook: prompt the agent to capture non-obvious learnings
# before ending the session. Fires once per stop attempt; the second attempt
# (stop_hook_active=true) lets the agent stop normally.
#
# Reads the standard Claude Code hook payload on stdin:
#   { "hook_event_name": "Stop"|"SubagentStop", "stop_hook_active": bool, ... }
#
# Exit semantics:
#   0 — normal stop, hook is a no-op
#   2 — block the stop and feed stderr back to the agent as a reminder

set -u

INPUT=$(cat)

# Already prompted once this stop cycle — let the agent stop normally.
if printf '%s' "$INPUT" | grep -q '"stop_hook_active":[[:space:]]*true'; then
    exit 0
fi

EVENT=$(printf '%s' "$INPUT" | sed -n 's/.*"hook_event_name":[[:space:]]*"\([^"]*\)".*/\1/p')

cat >&2 <<EOF
Before ending this ${EVENT:-stop} — did this session produce any non-obvious learnings about Cast that future sessions should know? Examples: a surprising SPM quirk, a CI edge case, a project-specific convention that's not visible from the code, an upstream dependency gotcha, a workflow decision and its rationale.

If yes, capture them now in one of:
  - CLAUDE.md "## Learnings" section — one-line bullets, terse
  - .claude/rules/<topic>.md — focused multi-paragraph rule, when the topic warrants it

If nothing non-obvious came up (routine bug fix, simple feature, no surprises), just acknowledge and stop. Do not invent learnings.
EOF
exit 2
