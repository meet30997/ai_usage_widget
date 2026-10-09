# Contributing to TokenBar

Thanks for helping improve TokenBar. Bug reports, fixes, and new provider integrations are all welcome.

## Getting started

Requirements: macOS 13+, Swift 5.9+ (Xcode or the Command Line Tools).

```bash
git clone https://github.com/meet30997/ai_usage_widget.git
cd ai_usage_widget
swift build
swift test
./build_app.sh && open "build/AI Usage Tracker.app"
```

## Project layout

| Path | What lives there |
| --- | --- |
| `Sources/AIUsageWidget/Models` | Plain data types for each provider |
| `Sources/AIUsageWidget/Services` | Readers that query local CLIs and files, plus `UsageManager` |
| `Sources/AIUsageWidget/Views` | SwiftUI views for the popover and settings |
| `Tests/AIUsageWidgetTests` | XCTest suite |

## Guidelines

- **Stay local.** TokenBar must not send usage data anywhere or add telemetry. Read local files and local CLIs only, and never copy or persist credentials.
- **Open provider data read-only.** Use read-only SQLite handles and don't write into `~/.claude`, `~/.codex`, or `~/.gemini`.
- **Fail soft.** A missing CLI or an unexpected file format should hide a section, not crash the app or block the refresh loop.
- **Add tests for parsing logic.** CLI output and file formats change; a test with a real-looking sample is the best defense. Keep tests runnable without the CLIs installed.
- **Match the surrounding style.** Follow the naming and comment density of nearby code.

## Pull requests

1. Fork and create a branch from `main`.
2. Keep each PR focused on one change.
3. Run `swift test` and confirm the app builds with `./build_app.sh`.
4. For UI changes, include a before/after screenshot.
5. Fill in the pull request template.

## Reporting bugs

Open an issue using the bug report template. Include your macOS version, the TokenBar version (Settings → Application), and which CLIs you have installed. Please redact emails, tokens, and file paths you don't want public.

For security issues, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.
