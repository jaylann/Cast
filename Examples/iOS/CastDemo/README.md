# CastDemo (iOS)

A SwiftUI iOS demo of the [Cast](https://github.com/jaylann/Cast) Swift package. Demonstrates the three primary modes — `cast()`, `classify()`, and `extract()` — with live-streaming partial results.

## Prerequisites

- Xcode 15+ (Swift 6.0)
- An M-series Mac (MLX requires Apple Silicon)
- iOS Simulator or a physical iOS 17+ device
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for generating the Xcode project

## Setup

```bash
# 1. Install XcodeGen (one-time)
brew install xcodegen

# 2. From this directory, generate the Xcode project
cd Examples/iOS/CastDemo
xcodegen generate

# 3. Open in Xcode and run
open CastDemo.xcodeproj
```

## First run

The app downloads ~2 GB of model weights (Llama-3.2-3B-Instruct-4bit) on first launch. Run it on Wi-Fi, and budget for the download to complete before tapping Generate.

## Why XcodeGen

`project.pbxproj` is hand-edit-hostile and merge-conflict-prone, so we keep it out of git and regenerate it from `project.yml`. Anyone with `xcodegen` installed can produce the same project deterministically.

## Looking for a faster smoke test?

The macOS-only `SwiftUIDemo` executable (in `Examples/Sources/SwiftUIDemo/`) covers the same modes without needing Xcode — `swift run SwiftUIDemo` from the `Examples/` directory.
