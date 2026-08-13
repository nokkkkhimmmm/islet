<h1 align="center">Islet</h1>

<p align="center">
  <strong>Your MacBook's notch, watching your coding agents.</strong>
</p>

<p align="center">
  <a href="https://github.com/nokkkkhimmmm/islet/actions/workflows/ci.yml">
    <img src="https://github.com/nokkkkhimmmm/islet/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift 6.0">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT"></a>
</p>

<p align="center">
  <a href="#installing">Install</a> ·
  <a href="#what-it-shows">What it shows</a> ·
  <a href="#privacy">Privacy</a> ·
  <a href="ROADMAP.md">Roadmap</a> ·
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

---

When you hand a task to Codex or Claude Code, you lose sight of it. Is it still working, or has
it been waiting on you for ten minutes? How much of the rate limit has today burned through?
Answering either question means switching away from what you were doing — which is exactly
what handing off the task was supposed to avoid.

Islet puts the answer in the notch. It reads the session transcripts the tools already write to
disk and turns the dead space around your camera into a live readout.

## What it shows

**Idle** — nothing. The island is exactly the size of the cutout, so it is invisible until it
has something to say.

**Active** — an agent is running. A pulsing dot, the workspace it is working in, and a live
token count appear in the strips either side of the notch.

**Expanded** — hover the notch for the full panel: every recent session across both tools, what
each is doing right now, the workspace and branch, tokens consumed, context window occupancy,
and how much of your rate-limit window is gone.

Islet distinguishes three states per session, and it reads them from the transcript rather than
guessing from timing:

| State | Meaning |
| --- | --- |
| **Working** | Mid-turn — thinking, or running a tool |
| **Your turn** | The agent finished and is waiting on you |
| **Idle** | No activity for a while; the session is over |

## Supported agents

| Agent | Live state | Tokens | Context window | Rate limits |
| --- | --- | --- | --- | --- |
| **Codex** | ✅ exact turn boundaries | ✅ | ✅ when reported | ✅ |
| **Claude Code** | ✅ from `stop_reason` | ✅ | ⚠️ not reported on disk | ➖ not reported on disk |

Both are read-only. Islet never writes to either tool's directory.

## Installing

Requires macOS 14 or later and the Xcode command line tools.

```bash
git clone https://github.com/nokkkkhimmmm/islet.git
cd islet
Scripts/build-app.sh release
open dist/Islet.app
```

Islet lives in the menu bar — there is no dock icon. Quit it from the menu bar item.

A notch is not required. On Macs without one, Islet shows a pill just below the menu bar
instead.

## Privacy

Islet makes **no network requests of any kind**. There is no telemetry, no analytics, no
account, and no update check. It reads two directories in your home folder, and that is the
whole of its access to your machine:

- `~/.codex/sessions/`
- `~/.claude/projects/`

Everything shown in the island is derived on your machine and never leaves it. Nothing is
written back to either directory.

Two flags let you see exactly what Islet reads:

```bash
dist/Islet.app/Contents/MacOS/Islet --dump-sessions   # every session it can see
dist/Islet.app/Contents/MacOS/Islet --diagnose        # display and notch geometry
```

## How it works

Codex and Claude Code both keep append-only JSONL transcripts of every session. Islet follows
those files incrementally — remembering a byte offset per file so it only parses what was
appended — and derives state from the records each tool writes: `task_started` / `task_complete`
for Codex, assistant `stop_reason` for Claude Code.

Neither format is a documented public API, so every field is read defensively. When a tool
changes its transcript format, Islet shows less rather than breaking. If you hit that, please
[open an issue](https://github.com/nokkkkhimmmm/islet/issues) with your `--dump-sessions`
output.

## Building from source

```bash
swift build     # compile
swift test      # run the IsletCore test suite
```

There is no `.xcodeproj`; the project is SwiftPM so everything is reviewable plain text. Xcode
can open `Package.swift` directly. See [AGENTS.md](AGENTS.md) for the architecture and the
invariants worth preserving.

## Roadmap

The agent cockpit is the reason Islet exists, but the notch has room. Music controls, timers,
calendar events and a drag-and-drop file shelf are planned — see [ROADMAP.md](ROADMAP.md).

## License

[MIT](LICENSE).
