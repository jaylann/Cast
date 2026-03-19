# Contributing to Cast

Thanks for your interest in contributing to Cast! This guide will help you get started.

## Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/jaylann/Cast.git
   cd Cast
   ```

2. **Build the package**
   ```bash
   swift build
   ```

3. **Run tests**
   ```bash
   swift test
   ```

### Requirements

- macOS 14+ with Apple Silicon
- Xcode 16+ or Swift 6.0+ toolchain
- SwiftFormat (`brew install swiftformat`)
- SwiftLint (`brew install swiftlint`)

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feat/castable-macro` — new features
- `fix/tokenizer-cache-miss` — bug fixes
- `refactor/grammar-engine` — refactoring
- `docs/api-examples` — documentation

### Code Style

- SwiftFormat and SwiftLint enforce style automatically
- Config files: `.swiftformat` and `.swiftlint.yml` in the project root
- Run manually if needed:
  ```bash
  swiftformat .
  swiftlint --fix
  ```

### Testing

- All PRs must pass `swift test`
- New features require tests
- Bug fixes should include a regression test
- Use Swift Testing framework (`import Testing`)
- Macro changes need expansion tests using `assertMacroExpansion`

## Pull Request Process

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Ensure `swift test` passes
5. Open a PR against `main`
6. Fill out the PR template

### PR Guidelines

- Keep PRs focused — one feature or fix per PR
- Write a clear description of what and why
- Reference related issues with `Closes #XX`
- Respond to review feedback promptly

## Filing Issues

- Use the issue templates (bug report or feature request)
- Search existing issues before creating a new one
- Include reproduction steps for bugs
- Be specific about expected vs actual behavior

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
