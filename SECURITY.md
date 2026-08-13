# Security Policy

## Reporting a vulnerability

Please report security issues privately through
[GitHub's private vulnerability reporting](https://github.com/nokkkkhimmmm/islet/security/advisories/new)
rather than opening a public issue.

Include what you did, what happened, and the version or commit you were on. You can expect an
initial response within a week.

## What Islet touches

Islet's attack surface is small on purpose, and it is worth stating exactly what it is:

- **It makes no network requests.** No telemetry, no analytics, no update check, no account.
  Any observed network activity from Islet is a bug and worth reporting.
- **It reads two directories**, both under your home folder: `~/.codex/sessions/` and
  `~/.claude/projects/`. It opens files there read-only and never writes to them.
- **It writes nothing** outside its own build output.
- **It runs unsandboxed** and ad-hoc signed when built from source, because it reads paths
  outside an app container.

## Data that leaves your machine only if you send it

`--dump-sessions` prints workspace paths, git branch names, and previews of agent messages
taken from your own transcripts. That output is intended for debugging and bug reports.

Review it before pasting it into an issue. Islet cannot know which of your project names or
message contents are sensitive.

## Scope

Reports about the following are in scope: reading files outside the two directories above, any
outbound network connection, crashes triggerable by a malformed transcript, and privilege
issues in the built bundle.

Out of scope: the fact that the app is unsandboxed and ad-hoc signed when built locally, and
anything requiring an attacker who already has write access to your home directory — at that
point the transcripts themselves are already compromised.
