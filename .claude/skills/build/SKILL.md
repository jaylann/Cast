---
name: build
description: Build, test, clean Cast package, or search Apple docs. Delegates to spm-builder subagent.
---

Delegate to the **spm-builder** subagent via the Task tool. Pass `$ARGUMENTS`:

- No args / "build" — build the package
- "test" — run all tests
- "test-macro" — run macro tests only
- "clean" — clean build
- "resolve" — resolve dependencies
- "docs \<query\>" — search Apple docs

Report results back concisely.
