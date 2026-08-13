import XCTest
@testable import IsletCore

/// Exercises the Codex parser against synthetic transcripts shaped like the real thing.
///
/// Fixtures are written to a temporary directory rather than read from the developer's
/// `~/.codex`, so these tests give the same answer on any machine and in CI.
final class CodexSessionSourceTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("islet-codex-tests-\(UUID().uuidString)", isDirectory: true)
        // Codex nests transcripts under dated directories; the scanner must find them anyway.
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("2026/08/13", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ lines: [String], to name: String = "rollout-test.jsonl") throws -> URL {
        let url = root.appendingPathComponent("2026/08/13/\(name)")
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func append(_ lines: [String], to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    private func makeSource() -> CodexSessionSource {
        CodexSessionSource(rootDirectory: root)
    }

    // MARK: - Fixtures

    private let sessionMeta = """
    {"timestamp":"2026-08-13T05:09:53.896Z","type":"session_meta","payload":{"session_id":"abc-123","id":"abc-123","timestamp":"2026-08-13T05:09:53.896Z","cwd":"/Users/dev/Projects/Widget","originator":"Codex CLI","cli_version":"0.147.0","model_provider":"openai","git":{"commit_hash":"deadbeef","branch":"feature/parser","repository_url":"https://example.com/widget.git"}}}
    """

    private let turnContext = """
    {"timestamp":"2026-08-13T05:09:54.000Z","type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"medium","summary":"auto"}}
    """

    private let taskStarted = """
    {"timestamp":"2026-08-13T05:09:55.000Z","type":"event_msg","payload":{"type":"task_started"}}
    """

    private let tokenCount = """
    {"timestamp":"2026-08-13T05:09:56.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1200,"cached_input_tokens":800,"cache_write_input_tokens":100,"output_tokens":450,"reasoning_output_tokens":50,"total_tokens":2600},"last_token_usage":{"total_tokens":1800},"model_context_window":258400},"rate_limits":{"limit_id":"codex","primary":{"used_percent":42.5,"window_minutes":10080,"resets_at":1787039092},"secondary":null,"plan_type":"plus"}}}
    """

    private let agentMessage = """
    {"timestamp":"2026-08-13T05:09:57.000Z","type":"event_msg","payload":{"type":"agent_message","message":"Renamed the parser\\nand updated the tests."}}
    """

    private let taskComplete = """
    {"timestamp":"2026-08-13T05:09:58.000Z","type":"event_msg","payload":{"type":"task_complete"}}
    """

    // MARK: - Tests

    func testParsesACompletedTurn() throws {
        _ = try write([sessionMeta, turnContext, taskStarted, tokenCount, agentMessage, taskComplete])

        let sessions = try makeSource().scan(now: Date(), lookback: 3600)
        let session = try XCTUnwrap(sessions.first)

        XCTAssertEqual(session.id, "abc-123")
        XCTAssertEqual(session.provider, .codex)
        XCTAssertEqual(session.workspacePath, "/Users/dev/Projects/Widget")
        XCTAssertEqual(session.workspaceName, "Widget")
        XCTAssertEqual(session.gitBranch, "feature/parser")
        XCTAssertEqual(session.model, "gpt-5.6-terra")
        XCTAssertEqual(session.activity, .awaitingInput)
    }

    func testReadsUsageAndContextWindow() throws {
        _ = try write([sessionMeta, taskStarted, tokenCount, taskComplete])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)

        XCTAssertEqual(session.usage.input, 1200)
        XCTAssertEqual(session.usage.cachedInput, 800)
        XCTAssertEqual(session.usage.output, 450)
        XCTAssertEqual(session.usage.reasoning, 50)
        // The provider reported a total, which wins over summing the parts.
        XCTAssertEqual(session.usage.total, 2600)

        // Occupancy comes from the last turn, capacity from model_context_window.
        XCTAssertEqual(session.contextTokens, 1800)
        XCTAssertEqual(session.contextWindow, 258_400)
    }

    func testReadsAccountRateLimits() throws {
        _ = try write([sessionMeta, tokenCount])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)
        let limit = try XCTUnwrap(session.primaryRateLimit)

        XCTAssertEqual(limit.usedPercent, 42.5)
        XCTAssertEqual(limit.windowMinutes, 10_080)
        XCTAssertEqual(limit.resetsAt, Date(timeIntervalSince1970: 1_787_039_092))
        XCTAssertNil(session.secondaryRateLimit)
        XCTAssertEqual(session.planType, "plus")
    }

    func testTurnStillRunningReportsWorking() throws {
        _ = try write([sessionMeta, taskStarted, tokenCount])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(session.activity, .working)
    }

    func testAbandonedSessionDecaysToIdle() throws {
        // A transcript that stopped mid-turn must not stay "working" forever.
        _ = try write([sessionMeta, taskStarted])

        let source = CodexSessionSource(rootDirectory: root, idleThreshold: 60)
        let muchLater = Date().addingTimeInterval(3600)

        let session = try XCTUnwrap(try source.scan(now: muchLater, lookback: 86_400).first)
        XCTAssertEqual(session.activity, .idle)
    }

    /// The byte-cursor path is the easiest thing to break, and the failure mode is silent
    /// double counting rather than a crash.
    func testIncrementalReadDoesNotReparseEarlierLines() throws {
        let url = try write([sessionMeta, taskStarted, tokenCount])
        let source = makeSource()

        let first = try XCTUnwrap(try source.scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(first.usage.total, 2600)
        XCTAssertEqual(first.activity, .working)

        try append([agentMessage, taskComplete], to: url)

        let second = try XCTUnwrap(try source.scan(now: Date(), lookback: 3600).first)
        // Usage is a replaced cumulative figure, not an accumulated one — it must not double.
        XCTAssertEqual(second.usage.total, 2600)
        XCTAssertEqual(second.activity, .awaitingInput)
        XCTAssertEqual(second.lastMessagePreview, "Renamed the parser and updated the tests.")
    }

    func testMalformedLinesAreSkippedRatherThanFatal() throws {
        _ = try write([sessionMeta, "{ this is not json", "", taskStarted, tokenCount])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(session.usage.total, 2600)
        XCTAssertEqual(session.activity, .working)
    }

    func testTranscriptsOutsideTheLookbackAreIgnored() throws {
        _ = try write([sessionMeta, taskStarted])

        let sessions = try makeSource().scan(now: Date().addingTimeInterval(7200), lookback: 60)
        XCTAssertTrue(sessions.isEmpty)
    }

    func testMissingDirectoryIsNotAnError() throws {
        let source = CodexSessionSource(rootDirectory: root.appendingPathComponent("nope"))
        XCTAssertFalse(source.isInstalled)
        XCTAssertTrue(try source.scan(now: Date(), lookback: 3600).isEmpty)
    }
}
