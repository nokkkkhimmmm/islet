# Roadmap

Islet's reason to exist is the agent cockpit. Everything else earns its place only if it is
worth interrupting that.

Items are ordered by intent, not by date. Feedback on priority is welcome in
[issues](https://github.com/nokkkkhimmmm/islet/issues).

## Shipped — v0.1

- Notch detection with a synthetic fallback for Macs without one
- Idle / active / expanded island states, driven by real agent activity
- Codex session tracking: turn state, tokens, context window, account rate limits
- Claude Code session tracking: turn state from `stop_reason`, per-message token totals
- `--dump-sessions` and `--diagnose` for debugging without a UI

## Next — agent cockpit depth

- **Notifications when an agent needs you.** The genuinely useful moment is the transition to
  *your turn*; that should be able to reach you when the notch is not in view.
- **Session history.** Tokens per day and per workspace, so "where did the week go" has an
  answer.
- **Click through to a session.** Focus the terminal or editor a session belongs to.
- **Claude Code context window.** Capacity is not in the transcript. Options are reading it
  from the tool's own config or letting the user set it — but never guessing it from the model
  name, since a wrong denominator is worse than no bar.
- **More agents.** The `AgentSessionSource` protocol is the extension point; any tool that
  keeps a local transcript can be added without touching the UI.

## Later — the rest of the notch

Each of these is a well-trodden notch-app feature. They make Islet a daily driver rather than a
single-purpose tool.

- **File shelf.** Drag files onto the notch to park them, drag them off somewhere else. Fully
  local, needs no permissions, and is the most requested notch feature generally.
- **Timers.** Islet's own timers, surfaced in the island. The system Clock app's timers are not
  readable by third-party apps.
- **Calendar.** Next event and time until it, via EventKit. Requires calendar permission.
- **Now playing.** Harder than it looks: the private MediaRemote framework has required an
  entitlement since macOS 15.4, so this needs a supported route rather than the approach older
  notch apps used. Planned as an adapter with several backends.

## Not planned

- **iPhone Live Activities mirrored to the Mac.** There is no public API for a Mac app to
  receive them. Doing it properly would require a companion iOS app pushing over the local
  network — a separate product, not a feature. Listed here because it gets asked for.
- **Telemetry or analytics.** Islet makes no network requests, and that is a fixed property
  rather than a default.

## Known limitations

- Transcript formats for both tools are undocumented and change between releases. Islet reads
  defensively and degrades to showing less, but format drift will happen.
- Older sessions frequently lack fields newer ones have — model name and context window in
  particular.
- Rate limits are only as fresh as the last time the tool wrote one to disk.
