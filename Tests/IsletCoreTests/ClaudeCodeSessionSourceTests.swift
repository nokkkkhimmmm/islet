import XCTest
@testable import IsletCore

final class ClaudeCodeSessionSourceTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("islet-claude-tests-\(UUID().uuidString)", isDirectory: true)
        // Claude Code groups transcripts by a slugified workspace path.
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("-Users-dev-Projects-Widget", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func write(_ lines: [String]) throws -> URL {
        let url = root.appendingPathComponent("-Users-dev-Projects-Widget/session-uuid.jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func append(_ lines: [String], to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    private func makeSource() -> ClaudeCodeSessionSource {
        ClaudeCodeSessionSource(rootDirectory: root)
    }

    // MARK: - Fixtures

    private func assistant(
        at timestamp: String,
        stopReason: String,
        input: Int,
        cacheRead: Int,
        cacheWrite: Int,
        output: Int,
        text: String? = nil
    ) -> String {
        let content = text.map { "{\"type\":\"text\",\"text\":\"\($0)\"}" }
            ?? "{\"type\":\"tool_use\",\"name\":\"Read\",\"input\":{}}"
        return """
        {"type":"assistant","timestamp":"\(timestamp)","cwd":"/Users/dev/Projects/Widget","gitBranch":"main","sessionId":"session-uuid","message":{"role":"assistant","model":"claude-opus-5","stop_reason":"\(stopReason)","content":[\(content)],"usage":{"input_tokens":\(input),"cache_read_input_tokens":\(cacheRead),"cache_creation_input_tokens":\(cacheWrite),"output_tokens":\(output)}}}
        """
    }

    private let userMessage = """
    {"type":"user","timestamp":"2026-08-13T05:10:00.000Z","cwd":"/Users/dev/Projects/Widget","gitBranch":"main","sessionId":"session-uuid","message":{"role":"user","content":"do the thing"}}
    """

    private let sidecarRecord = """
    {"type":"ai-title","timestamp":"2026-08-13T05:10:01.000Z","aiTitle":"Parser work","sessionId":"session-uuid"}
    """

    // MARK: - Tests

    func testReadsWorkspaceBranchAndModel() throws {
        try write([userMessage, assistant(at: "2026-08-13T05:10:05.000Z", stopReason: "end_turn", input: 10, cacheRead: 100, cacheWrite: 20, output: 5, text: "done")])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)

        XCTAssertEqual(session.id, "session-uuid")
        XCTAssertEqual(session.provider, .claudeCode)
        XCTAssertEqual(session.workspaceName, "Widget")
        XCTAssertEqual(session.gitBranch, "main")
        XCTAssertEqual(session.model, "claude-opus-5")
    }

    func testToolUseStopReasonMeansStillWorking() throws {
        try write([userMessage, assistant(at: "2026-08-13T05:10:05.000Z", stopReason: "tool_use", input: 10, cacheRead: 0, cacheWrite: 0, output: 5)])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(session.activity, .working)
    }

    func testEndTurnMeansItIsTheUsersTurn() throws {
        try write([userMessage, assistant(at: "2026-08-13T05:10:05.000Z", stopReason: "end_turn", input: 10, cacheRead: 0, cacheWrite: 0, output: 5, text: "all done")])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(session.activity, .awaitingInput)
        XCTAssertEqual(session.lastMessagePreview, "all done")
    }

    func testAUserMessageMeansTheAgentIsAboutToWork() throws {
        try write([
            assistant(at: "2026-08-13T05:10:05.000Z", stopReason: "end_turn", input: 10, cacheRead: 0, cacheWrite: 0, output: 5, text: "done"),
            userMessage,
        ])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(session.activity, .working)
    }

    /// Claude Code reports usage per message, so totals accumulate — unlike Codex, where each
    /// `token_count` supersedes the last.
    func testUsageAccumulatesAcrossMessages() throws {
        try write([
            assistant(at: "2026-08-13T05:10:05.000Z", stopReason: "tool_use", input: 10, cacheRead: 1000, cacheWrite: 500, output: 100),
            assistant(at: "2026-08-13T05:10:06.000Z", stopReason: "end_turn", input: 20, cacheRead: 2000, cacheWrite: 0, output: 200, text: "finished"),
        ])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)

        XCTAssertEqual(session.usage.input, 30)
        XCTAssertEqual(session.usage.cachedInput, 3000)
        XCTAssertEqual(session.usage.cacheWrite, 500)
        XCTAssertEqual(session.usage.output, 300)

        // Occupancy is the most recent request's resident tokens, not the running total.
        XCTAssertEqual(session.contextTokens, 20 + 2000 + 0)
        // Capacity is absent from the transcript, so no bar should be drawn.
        XCTAssertNil(session.contextWindow)
        XCTAssertNil(session.contextFraction)
    }

    func testIncrementalReadAccumulatesWithoutDoubleCounting() throws {
        let url = try write([
            assistant(at: "2026-08-13T05:10:05.000Z", stopReason: "tool_use", input: 10, cacheRead: 1000, cacheWrite: 0, output: 100)
        ])
        let source = makeSource()

        let first = try XCTUnwrap(try source.scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(first.usage.output, 100)

        try append([
            assistant(at: "2026-08-13T05:10:06.000Z", stopReason: "end_turn", input: 20, cacheRead: 2000, cacheWrite: 0, output: 200, text: "finished")
        ], to: url)

        let second = try XCTUnwrap(try source.scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(second.usage.output, 300, "earlier messages must not be summed twice")
        XCTAssertEqual(second.activity, .awaitingInput)
    }

    func testSidecarRecordsAreIgnored() throws {
        try write([
            sidecarRecord,
            assistant(at: "2026-08-13T05:10:05.000Z", stopReason: "end_turn", input: 10, cacheRead: 0, cacheWrite: 0, output: 5, text: "done"),
            sidecarRecord,
        ])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(session.activity, .awaitingInput)
        XCTAssertEqual(session.usage.output, 5)
    }

    func testDetachedHeadIsNotShownAsABranch() throws {
        let record = """
        {"type":"assistant","timestamp":"2026-08-13T05:10:05.000Z","cwd":"/Users/dev/Projects/Widget","gitBranch":"HEAD","sessionId":"session-uuid","message":{"role":"assistant","model":"claude-opus-5","stop_reason":"end_turn","content":[],"usage":{"output_tokens":1}}}
        """
        try write([record])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)
        XCTAssertNil(session.gitBranch)
    }

    func testThinkingBlocksDoNotBecomeThePreview() throws {
        let record = """
        {"type":"assistant","timestamp":"2026-08-13T05:10:05.000Z","cwd":"/Users/dev/Projects/Widget","sessionId":"session-uuid","message":{"role":"assistant","model":"claude-opus-5","stop_reason":"end_turn","content":[{"type":"thinking","thinking":"internal reasoning"},{"type":"text","text":"the visible answer"}],"usage":{"output_tokens":1}}}
        """
        try write([record])

        let session = try XCTUnwrap(try makeSource().scan(now: Date(), lookback: 3600).first)
        XCTAssertEqual(session.lastMessagePreview, "the visible answer")
    }
}
