# Contributing to Islet

Thanks for taking a look. Islet is small and deliberately so — the fastest way to get a change
merged is to keep it focused.

## Getting set up

You need macOS 14 or later and the Xcode command line tools.

```bash
git clone https://github.com/nokkkkhimmmm/islet.git
cd islet
swift build
swift test
Scripts/build-app.sh release && open dist/Islet.app
```

Working in Xcode instead? Open `Package.swift` directly, then **set the run destination to
"My Mac"**. Xcode tends to pick an iOS simulator by default, which fails on macOS-only API with
errors such as `'homeDirectoryForCurrentUser' is unavailable in iOS`. Nothing here targets iOS.

Read [AGENTS.md](AGENTS.md) before changing anything structural. It documents the invariants
that are easy to break without noticing — chiefly that the notch is a physical cutout with no
pixels behind it, and that `IsletCore` must stay free of AppKit and SwiftUI.

## Reporting a bug

Include the output of both diagnostic flags. Between them they usually identify the problem
without any back and forth:

```bash
dist/Islet.app/Contents/MacOS/Islet --diagnose        # your display and notch geometry
dist/Islet.app/Contents/MacOS/Islet --dump-sessions   # what the parsers see
```

`--dump-sessions` prints workspace paths, branch names and message previews from your own
sessions. **Read it before pasting it** and redact anything you would rather not publish.

## Transcript format changes

The most likely reason Islet stops showing something is that Codex or Claude Code changed its
on-disk format. These are undocumented formats and they do drift.

If you are fixing one:

- Add a fixture to the relevant test file showing the new shape, and keep the old fixture. Both
  shapes will exist in the wild for a long time, and users have months of old transcripts.
- Read the new field optionally. Never make a previously-working transcript fail to parse.
- Say which version of the tool you observed the change in.

## Pull requests

- One concern per PR. A parser fix and a UI redesign in the same branch will take much longer
  to review than two separate ones.
- Add tests for logic in `IsletCore`. It has no UI dependencies precisely so that it can be
  tested properly.
- Run `swift test` before pushing. CI runs the same thing plus a build of the app bundle.
- Match the surrounding style. Comments explain *why* something is the way it is; if a comment
  is describing *what* the code does, a better name usually removes the need for it.
- No force unwraps or `try!` outside tests.

## Adding support for another agent

Conform to `AgentSessionSource` and add it to the defaults in `AgentActivityMonitor`. The UI
reads only `AgentSession` values and needs no changes.

What makes a good candidate: the tool keeps a local, append-only transcript that records turn
boundaries and token usage. What Islet needs from it, in rough order of value, is turn state,
token usage, workspace path, and rate limits.

## Scope

Islet is an agent cockpit first. The other notch features on the [roadmap](ROADMAP.md) are
welcome, but a change that makes agent monitoring worse to make something else better is
unlikely to land.

Two things Islet will not do, so nobody spends effort on them: it makes no network requests of
any kind, and it does not guess values it has not been told (a context window inferred from a
model name is worse than no context bar).

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
