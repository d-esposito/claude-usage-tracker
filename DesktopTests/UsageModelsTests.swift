import XCTest
@testable import ClaudeUsageTrackerDesktop

final class UsageModelsTests: XCTestCase {
    func testModernResponseBecomesRemainingCapacity() throws {
        let json = #"{"limits":[{"kind":"session","percent":56,"resets_at":"2026-08-17T19:30:00.145857+00:00","scope":null},{"kind":"weekly_all","percent":7,"resets_at":"2026-08-23T21:00:00.145884+00:00","scope":null},{"kind":"weekly_scoped","percent":10,"resets_at":"2026-08-23T21:00:00.146198+00:00","scope":{"model":{"display_name":"Fable"}}}]}"#
        let response = try JSONDecoder.claudeUsage.decode(ClaudeUsageResponse.self, from: Data(json.utf8))
        let snapshot = response.snapshot()

        XCTAssertEqual(snapshot.limits.map(\.title), ["5-hour limit", "Weekly · All models", "Weekly · Fable"])
        XCTAssertEqual(snapshot.limits.map(\.remainingPercent), [44, 93, 90])
    }
}
