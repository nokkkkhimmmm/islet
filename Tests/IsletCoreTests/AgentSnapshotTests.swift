import XCTest
@testable import IsletCore

final class AgentSnapshotTests: XCTestCase {
    private func session(
        id: String,
        provider: AgentProvider = .codex,
        activity: AgentActivity,
        lastActivityAt: Date,
        usage: TokenUsage = TokenUsage(),
        primaryRateLimit: RateLimitWindow? = nil
    ) -> AgentSession {
        AgentSession(
            id: id,
            provider: provider,
            activity: activity,
            usage: usage,
            startedAt: lastActivityAt,
            lastActivityAt: lastActivityAt,
            primaryRateLimit: primaryRateLimit
        )
    }

    func testWorkingSessionsSortAboveWaitingOnes() {
        let now = Date()
        let snapshot = AgentSnapshot(sessions: [
            session(id: "waiting", activity: .awaitingInput, lastActivityAt: now),
            session(id: "working", activity: .working, lastActivityAt: now.addingTimeInterval(-600)),
        ])

        // Recency loses to actually being live: a running agent is what you want to see.
        XCTAssertEqual(snapshot.sessions.first?.id, "working")
        XCTAssertEqual(snapshot.headline?.id, "working")
    }

    func testHeadlineFallsBackToWaitingWhenNothingIsRunning() {
        let now = Date()
        let snapshot = AgentSnapshot(sessions: [
            session(id: "old", activity: .idle, lastActivityAt: now),
            session(id: "waiting", activity: .awaitingInput, lastActivityAt: now.addingTimeInterval(-60)),
        ])

        XCTAssertEqual(snapshot.headline?.id, "waiting")
    }

    func testHeadlineIsNilWhenEverythingIsIdle() {
        let snapshot = AgentSnapshot(sessions: [
            session(id: "a", activity: .idle, lastActivityAt: Date()),
        ])

        XCTAssertNil(snapshot.headline, "an all-idle snapshot must leave the island invisible")
        XCTAssertTrue(snapshot.liveSessions.isEmpty)
    }

    /// Equal-ranked rows must not swap places between polls, or the list visibly jitters.
    func testOrderingIsStableForIdenticalTimestamps() {
        let now = Date()
        let sessions = [
            session(id: "zeta", activity: .working, lastActivityAt: now),
            session(id: "alpha", activity: .working, lastActivityAt: now),
        ]

        XCTAssertEqual(AgentSnapshot(sessions: sessions).sessions.map(\.id), ["alpha", "zeta"])
        XCTAssertEqual(AgentSnapshot(sessions: sessions.reversed()).sessions.map(\.id), ["alpha", "zeta"])
    }

    func testTotalUsageSumsAcrossProviders() {
        let now = Date()
        let snapshot = AgentSnapshot(sessions: [
            session(id: "a", provider: .codex, activity: .working, lastActivityAt: now,
                    usage: TokenUsage(input: 100, output: 50)),
            session(id: "b", provider: .claudeCode, activity: .working, lastActivityAt: now,
                    usage: TokenUsage(input: 200, output: 25)),
        ])

        XCTAssertEqual(snapshot.totalUsage.input, 300)
        XCTAssertEqual(snapshot.totalUsage.output, 75)
    }

    func testTightestRateLimitWins() {
        let now = Date()
        let snapshot = AgentSnapshot(sessions: [
            session(id: "a", activity: .working, lastActivityAt: now,
                    primaryRateLimit: RateLimitWindow(usedPercent: 12)),
            session(id: "b", activity: .working, lastActivityAt: now,
                    primaryRateLimit: RateLimitWindow(usedPercent: 87)),
        ])

        XCTAssertEqual(snapshot.tightestRateLimit?.usedPercent, 87)
    }

    func testReportedTotalWinsOverSummingParts() {
        // Codex reports a total directly; trusting the sum instead would double-count.
        let reported = TokenUsage(input: 1, output: 1, reportedTotal: 9_999)
        XCTAssertEqual(reported.total, 9_999)

        let derived = TokenUsage(input: 10, cachedInput: 5, output: 2)
        XCTAssertEqual(derived.total, 17)
    }

    func testContextFractionNeedsBothOccupancyAndCapacity() {
        var session = self.session(id: "a", activity: .working, lastActivityAt: Date())
        XCTAssertNil(session.contextFraction)

        session.contextTokens = 50_000
        XCTAssertNil(session.contextFraction, "occupancy alone must not produce a bar")

        session.contextWindow = 200_000
        XCTAssertEqual(session.contextFraction ?? 0, 0.25, accuracy: 0.0001)
    }

    func testContextFractionIsClampedToOne() {
        var session = self.session(id: "a", activity: .working, lastActivityAt: Date())
        session.contextTokens = 300_000
        session.contextWindow = 200_000
        XCTAssertEqual(session.contextFraction ?? 0, 1.0, accuracy: 0.0001)
    }
}
