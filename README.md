# TokenBar — macOS AI Usage Monitor

A lightweight, local macOS menu bar app for tracking real-time rate limits, usage quotas, and token consumption across **Claude Code**, **OpenAI Codex**, and **Google Antigravity** — no cloud sync, no telemetry, 100% on-device.

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-blue">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9%2B-orange">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
</p>

<p align="center">
  <img src="assets/overview.png" alt="TokenBar Overview" width="420" style="border-radius: 8px;"/>
</p>

---

## Features

- **Claude Code Limits**: Reads live session percentages, weekly quotas, and reset countdowns by querying the local `claude` CLI (`-p /usage`), combined with historical usage metrics from `~/.claude/stats-cache.json`.
- **OpenAI Codex Limits**: Queries live account status and rate limit reset credits via `codex app-server --stdio` JSON-RPC (with fallback to `~/.codex/sessions/*.jsonl`), extracts subscription tier from `~/.codex/auth.json`, and parses historical 14-day token breakdown per model from `~/.codex/state_5.sqlite`.
- **Google Antigravity Limits**: Reads model-family 5-hour and weekly quotas from `agy /usage`, with a running Antigravity desktop app or IDE as a local fallback, and parses local conversation databases under `~/.gemini` for token history.
- **14-Day Activity Visualization**: Stacked daily token chart comparing Claude Code, Codex, and Antigravity.
- **Model Breakdown**: Provider-qualified token totals for every locally observed model.
- **Auto & Manual Refresh**: Configurable auto-refresh intervals (1, 5, or 15 minutes) or instant manual refresh.
- **100% Local & Native**: Built with SwiftUI (`MenuBarExtra`) for macOS 13+. Operates entirely on your local machine with zero remote tracking, telemetry, or external network dependencies.

---

## Showcase

| Overview | Model Breakdown |
| :---: | :---: |
| ![Overview](assets/overview.png) | ![Models](assets/models.png) |

| Claude Detail | Codex Detail |
| :---: | :---: |
| ![Claude](assets/claude.png) | ![Codex](assets/codex.png) |

<p align="center">
  <img src="assets/settings.png" alt="Settings & Customization" width="480" style="border-radius: 8px;"/>
</p>

---

## How It Works

TokenBar inspects local CLI environment state and local application stores:

1. **Claude Code Integration (`ClaudeDataReader.swift`)**
   - **Live Status**: Spawns `claude -p /usage --output-format json` in a background subprocess (15s timeout) to extract active 5-hour session and weekly rate limit percentages.
   - **History**: Reads `~/.claude/stats-cache.json` for historical daily message counts, session numbers, tool call counts, and per-model input/output/cache token stats.

2. **OpenAI Codex Integration (`CodexDataReader.swift`)**
   - **Live Status**: Runs `codex app-server --stdio` over JSON-RPC to invoke `account/rateLimits/read` for active window limits and reset credits. If the app-server process is inactive, falls back to parsing recent `~/.codex/sessions/*.jsonl` files.
   - **Account & Config**: Decodes user email and plan tier (`chatgpt_plan_type`) from JWT tokens in `~/.codex/auth.json`, and reads configured active model from `~/.codex/config.toml`.
   - **Database**: Opens `~/.codex/state_5.sqlite` using SQLite3 in read-only mode (`threads` table) to calculate total sessions, 7-day token totals, and historical model token usage.

3. **Google Antigravity Integration (`AntigravityDataReader.swift`)**
   - **Live Status**: Runs `agy -p /usage --output-format json` for the authoritative quota report. If unavailable, it connects to the authenticated localhost service of a running Antigravity app or IDE. It does not copy or persist local credentials.
   - **History**: Opens Antigravity and Antigravity CLI conversation databases under `~/.gemini` in read-only mode, deduplicates responses, and recovers modern per-turn timestamps from the `steps` table.
   - **Availability**: Historical activity remains available while Antigravity is closed. Live quota refresh uses a signed-in `agy` CLI or a running desktop app/IDE.

---

## Building & Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Swift 5.9+ / Xcode Command Line Tools
- `claude`, `codex`, and/or Antigravity installed locally

### Build from Source

```bash
# Clone the repository
git clone https://github.com/meet30997/ai_usage_widget.git
cd ai_usage_widget

# Run tests
swift test

# Build the release app bundle
./build_app.sh

# Open the app bundle
open "build/AI Usage Tracker.app"
```

To install system-wide, move `build/AI Usage Tracker.app` into your `/Applications` folder.

---

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for details.
