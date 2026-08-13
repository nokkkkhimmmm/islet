import Foundation

/// A provider-specific reader that turns on-disk transcripts into `AgentSession` values.
///
/// Implementations are stateful: they keep a byte cursor per transcript so repeated scans only
/// parse newly appended lines. They are *not* thread safe; `AgentActivityMonitor` owns one of
/// each and drives them from a single serial queue.
public protocol AgentSessionSource: AnyObject {
    var provider: AgentProvider { get }

    /// Root directory holding this provider's transcripts. May not exist if the tool is absent.
    var rootDirectory: URL { get }

    /// Re-reads whatever changed since the last call and returns every session seen within
    /// `lookback` of `now`.
    func scan(now: Date, lookback: TimeInterval) throws -> [AgentSession]
}

extension AgentSessionSource {
    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: rootDirectory.path)
    }
}

/// Shared bookkeeping for a transcript file being followed.
struct TranscriptCursor {
    var offset: UInt64 = 0
    var modifiedAt: Date = .distantPast
    var session: AgentSession?
}

/// Lists `*.jsonl` files under `root`, newest first, skipping anything untouched since `cutoff`.
///
/// Both providers nest transcripts in dated subdirectories, so this walks recursively but
/// prunes on modification date to keep the common case cheap — a machine with hundreds of
/// historical sessions only ever parses the handful that are actually recent.
func recentTranscripts(in root: URL, modifiedAfter cutoff: Date) -> [URL] {
    let manager = FileManager.default
    guard manager.fileExists(atPath: root.path) else { return [] }

    let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
    guard let enumerator = manager.enumerator(
        at: root,
        includingPropertiesForKeys: keys,
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else { return [] }

    var results: [(url: URL, modifiedAt: Date)] = []
    for case let url as URL in enumerator {
        guard url.pathExtension == "jsonl" else { continue }
        guard let values = try? url.resourceValues(forKeys: Set(keys)),
              values.isRegularFile == true,
              let modifiedAt = values.contentModificationDate,
              modifiedAt >= cutoff
        else { continue }
        results.append((url, modifiedAt))
    }

    return results
        .sorted { $0.modifiedAt > $1.modifiedAt }
        .map(\.url)
}

/// Collapses whitespace and truncates, so a multi-line agent message fits one island row.
func previewText(_ text: String, limit: Int = 120) -> String? {
    let collapsed = text
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .split(separator: " ", omittingEmptySubsequences: true)
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !collapsed.isEmpty else { return nil }
    guard collapsed.count > limit else { return collapsed }
    return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
}
