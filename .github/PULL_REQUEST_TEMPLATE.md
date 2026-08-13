## What this changes

<!-- One or two sentences. If it fixes an issue, link it. -->

## Why

<!-- The problem this solves. For a parser fix, say which version of Codex or Claude Code you
     observed the format change in. -->

## Checklist

- [ ] `swift test` passes
- [ ] New logic in `IsletCore` has tests
- [ ] `IsletCore` still imports no AppKit or SwiftUI
- [ ] No force unwraps or `try!` outside tests
- [ ] If a transcript format changed: the old fixture is kept alongside the new one, so
      existing transcripts still parse

## Verified how

<!-- What you actually ran. For UI changes, which island states you checked (idle, active,
     expanded) and on what hardware — notch behaviour differs by Mac model. -->
