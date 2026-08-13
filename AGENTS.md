# AGENTS.md

Working notes for anyone — human or coding agent — changing this repository.

## What Islet is

A macOS menu-bar app that turns the MacBook notch into a live status surface. Its first and
defining feature is an **AI agent cockpit**: it reads the session transcripts that Codex and
Claude Code already write to disk and shows, in the notch, which agents are running, what they
are doing, how many tokens they have consumed, and how close the account is to a rate limit.

The point is that you stop alt-tabbing to check whether the agent is still working.

## Build, run, test

```bash
swift build                      # compile everything
swift test                       # run IsletCore tests
Scripts/build-app.sh release     # assemble dist/Islet.app
open dist/Islet.app              # run it
```

Two flags exist for debugging without a UI, and both are the right first ask on a bug report:

```bash
dist/Islet.app/Contents/MacOS/Islet --dump-sessions   # what the parsers currently see
dist/Islet.app/Contents/MacOS/Islet --diagnose        # display and notch geometry
```

There is no `.xcodeproj`. The project is SwiftPM so that every file is reviewable plain text
and CI needs nothing but the command line tools. Xcode can open `Package.swift` directly.
`Scripts/build-app.sh` exists because SwiftPM emits a bare executable, not an `.app`.

If you open the package in Xcode, **set the run destination to "My Mac"**. Xcode often defaults
to an iOS simulator, and the build then fails on macOS-only API with errors like
`'homeDirectoryForCurrentUser' is unavailable in iOS`. Islet is a Mac app; nothing here is
meant to compile for iOS.

## Layout

```
Sources/IsletCore/    Pure logic. Models, transcript parsers, aggregation. No AppKit, no UI.
Sources/Islet/        The app. Notch geometry, window, SwiftUI views, menu bar item.
Tests/IsletCoreTests/ Tests for IsletCore, driven by fixtures — never by the real home directory.
Resources/            Info.plist for the assembled bundle.
Scripts/              Build tooling.
```

`IsletCore` must never import AppKit or SwiftUI. That boundary is what keeps the parsing logic
testable in CI without a display, and it is the first thing to preserve when adding a feature.

## Architecture invariants

**The notch has no pixels behind it.** It is a physical cutout. Anything drawn inside
`NotchMetrics.notchFrame` is invisible. Content lives in the strips either side of it, or below
it. `ActiveIslandView` reserves the middle span deliberately — that empty `Color.clear` is
load-bearing, not an oversight.

**Presentation is derived, never assigned.** `IslandModel.recomputePresentation()` is the only
place that decides between idle, active and expanded. Views and the window controller both read
that decision; neither is allowed to make its own, or they drift out of sync.

**The window resizes to match the island.** When idle it covers only the notch, so the rest of
the menu bar stays clickable. Do not make the window permanently large and transparent — it
swallows menu bar clicks.

**Parsers must be defensive.** Neither `~/.codex/sessions/**.jsonl` nor
`~/.claude/projects/**.jsonl` is a documented public format, and both change between releases
of their respective tools. Read every field optionally, skip records you do not recognise, and
never let an unexpected shape throw. A transcript that stops making sense should degrade to
less information on screen, never to a crash. Use `JSONObject`, not `Codable`, for this reason.

**Parsing is incremental.** `JSONLReader` remembers a byte offset per file and only reads what
was appended. Sessions reach tens of megabytes; re-reading them every two seconds would be
noticeable. If you add a field, make sure it accumulates correctly when it arrives in a later
chunk rather than assuming the whole file is in hand.

**Scanning is off the main thread, publishing is on it.** `AgentScanner` holds all mutable
parse state and is confined to one serial queue — that confinement is what its
`@unchecked Sendable` is claiming, so do not hand one to anything else.
`AgentActivityMonitor` is `@MainActor` and owns everything the UI reads.

## Reading agent transcripts

Both providers are read-only inputs. Islet never writes to their directories.

**Codex** — `~/.codex/sessions/<yyyy>/<MM>/<dd>/rollout-*.jsonl`. Records are
`{timestamp, type, payload}`. `session_meta` carries `cwd` and `git.branch`; `event_msg` with
`payload.type == "token_count"` carries cumulative usage, `model_context_window`, and
account-wide `rate_limits`; `task_started` and `task_complete` give exact turn boundaries;
`turn_context` carries the model name. Note that `session_meta.context_window` is an unrelated
identifier object — the real capacity is `info.model_context_window`.

**Claude Code** — `~/.claude/projects/<slugified-cwd>/<session-uuid>.jsonl`. Flat records with
`type`, `cwd`, `gitBranch`, `sessionId` and a nested Anthropic-shaped `message`. There are no
turn-boundary records; activity comes from the last assistant message's `stop_reason`, where
`tool_use` means mid-turn. Usage is per-message and is summed.

Fields are absent in older sessions more often than you would expect. `--dump-sessions` against
your own history is the fastest way to check an assumption.

## Token semantics

Getting these confused produces numbers that look plausible and are wrong.

- `usage` is **cumulative consumption** since the session began. It grows monotonically and
  will exceed the context window on any long session. That is correct, not a bug.
- `contextTokens` is **current occupancy** of the context window.
- `contextWindow` is capacity, and is only ever set when the provider actually reported it.
  Do not infer it from a model name — a wrong denominator is worse than no bar at all.

## Conventions

Comments explain *why*, not *what*. If a line needs a comment to say what it does, rename
something instead. Load-bearing oddities — an empty view that reserves the cutout, a
concurrency claim, a format quirk — do deserve a comment, because the next person will
otherwise remove them.

No force unwraps and no `try!` outside tests. Prefer letting a value be absent and rendering
less over asserting it must be there; on-disk formats will violate any assumption eventually.

Tests run against fixtures committed under `Tests/`, never against the developer's real home
directory. A test that reads `~/.codex` passes on the author's machine and nowhere else.

## Things that will trip you up

- The island is on the **built-in** display. `NSScreen.screens.first` is whichever screen
  contains the origin, which on a docked Mac is usually an external monitor.
  `NotchGeometry.islandScreen()` picks the notched one.
- Macs without a notch get a synthetic pill placed *below* the menu bar, because on those Macs
  that space contains real menu items rather than a cutout.
- The panel is `.nonactivatingPanel` on purpose. Clicking the island must not pull focus out of
  the editor the user is in.
- The app is ad-hoc signed by the build script. That is fine locally; distributing to other
  people needs a Developer ID signature and notarisation.
