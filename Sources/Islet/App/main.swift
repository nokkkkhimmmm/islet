import AppKit
import IsletCore

// `--dump-sessions` prints what the parsers currently see and exits, without touching the UI.
// Useful when reporting a bug: the output shows whether a transcript was understood at all.
if CommandLine.arguments.contains("--dump-sessions") {
    print(AgentDiagnostics.describe(AgentDiagnostics.snapshot()))
    exit(0)
}

// `--diagnose` reports the display and notch geometry Islet derived for this Mac. Notch
// dimensions differ per model, so this is the first thing to ask for in a layout bug report.
if CommandLine.arguments.contains("--diagnose") {
    print(Diagnostics.describeDisplays())
    exit(0)
}

// Islet is a menu-bar accessory: no dock icon, no main window, and it must never steal focus
// from whatever the user is actually working in.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
