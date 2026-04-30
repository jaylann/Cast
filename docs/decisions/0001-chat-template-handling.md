# 0001 — Chat template handling

## Status

Accepted.

## Context

Different LLM families wrap prompts in incompatible chat-template formats. A
non-exhaustive list of the markers Cast must produce correctly:

- Qwen: `<|im_start|>system ... <|im_end|><|im_start|>user ... <|im_end|>`
- Llama 3.x: `<|begin_of_text|><|start_header_id|>system<|end_header_id|> ...`
- Mistral: `<s>[INST] ... [/INST]`
- Phi 3.x: `<|system|> ... <|user|> ... <|assistant|>`
- Gemma: `<start_of_turn>user ... <end_of_turn>`

Each family ships a Jinja `chat_template` in its `tokenizer_config.json`.
`MLXLMCommon`'s `UserInput` + `processor.prepare(input:)` already runs that
template against the tokenizer when preparing model input.

Cast's generation entry points (`Sources/Cast/API/CastModel+Generation.swift`,
lines 118 and 197) compose a flat string of the form `"\(system)\n\n\(prompt)"`
and hand it to `UserInput(prompt:)`. The downstream `processor.prepare(input:)`
call then templates the result.

## Decision

Cast delegates chat templating entirely to `MLXLMCommon`. We do not detect the
model family, do not maintain a per-family template registry, and do not call
the tokenizer's `apply_chat_template` ourselves.

The flat-string `"\(system)\n\n\(prompt)"` concatenation is intentional: it
keeps the system context in the same conversational turn the user model is
trained to expect, and it matches what `UserInput(prompt:)` consumers across
the MLX Swift ecosystem use.

## Verification

`Tests/CastTests/ChatTemplateTests.swift` runs the same `cast()` call against a
4-bit MLX build of each family and asserts non-empty structured output:

- Qwen — `mlx-community/Qwen2.5-1.5B-Instruct-4bit`
- Llama — `mlx-community/Llama-3.2-1B-Instruct-4bit`
- Mistral — `mlx-community/Mistral-7B-Instruct-v0.3-4bit`
- Phi — `mlx-community/Phi-3.5-mini-instruct-4bit`
- Gemma — `mlx-community/gemma-2-2b-it-4bit`

All five tests are gated with the `.requiresMetal` trait. They run locally on
Apple Silicon and skip on GitHub Actions runners (which cannot load
`default.metallib`; see issue #75).

`Examples/Sources/ChatTemplates/main.swift` is the runnable counterpart for
manual verification and as an end-user demonstration.

## Consequences

- Any new family whose tokenizer ships a `chat_template` in
  `tokenizer_config.json` works automatically — no Cast change required.
- Family-specific quirks (whitespace normalization, missing `bos_token`, broken
  Jinja templates, etc.) are `MLXLMCommon`'s responsibility. Cast surfaces such
  failures as `CastError.generationFailed` rather than catching and rewriting
  them.
- Custom system prompts are joined with the user prompt by a single blank line.
  Templates that draw a strong distinction between the system and user roles
  (e.g. Llama's separate `system` header) still work because the templating
  step sees a single user message and routes it correctly; we do not currently
  expose a separate `system` channel through `UserInput`.
- If a future family ships a template that is meaningfully damaged by the
  blank-line join, the fix lives in `CastModel+Generation.swift` (the two
  call sites that build `fullPrompt`), not in any per-family code path.
