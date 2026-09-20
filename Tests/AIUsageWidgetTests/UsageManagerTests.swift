import XCTest
@testable import AIUsageWidget

final class UsageManagerTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testCombinedPointsCoverFourteenDaysEndingToday() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-19T12:00:00Z"))
        let points = UsageManager.computeCombinedPoints(
            claude: ClaudeUsageData(),
            codex: CodexUsageData(),
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(points.count, 14)
        XCTAssertEqual(points.first?.date, "2026-07-06")
        XCTAssertEqual(points.last?.date, "2026-07-19")
    }

    func testCombinedPointsAggregateDuplicateDatesAndIgnoreFutureWindowShift() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-19T12:00:00Z"))
        var claude = ClaudeUsageData()
        claude.dailyModelTokens = [
            ClaudeDailyModelTokens(date: "2026-07-19", tokensByModel: ["a": 10]),
            ClaudeDailyModelTokens(date: "2026-07-19", tokensByModel: ["b": 15]),
            ClaudeDailyModelTokens(date: "2099-01-01", tokensByModel: ["future": 99])
        ]
        var codex = CodexUsageData()
        codex.dailyUsage = [
            CodexDailyUsage(date: "2026-07-19", sessionCount: 1, tokensUsed: 20),
            CodexDailyUsage(date: "2026-07-19", sessionCount: 2, tokensUsed: 30)
        ]

        let points = UsageManager.computeCombinedPoints(
            claude: claude,
            codex: codex,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(points.last?.date, "2026-07-19")
        XCTAssertEqual(points.last?.claudeTokens, 25)
        XCTAssertEqual(points.last?.codexTokens, 50)
        XCTAssertEqual(points.last?.codexSessions, 3)
    }

    func testTodayUsageRequiresAnExactDateMatch() {
        var codex = CodexUsageData()
        codex.dailyUsage = [
            CodexDailyUsage(date: "2099-01-01", sessionCount: 1, tokensUsed: 100)
        ]

        XCTAssertNil(codex.todayUsage)
        XCTAssertEqual(codex.todayTokens, 0)
    }

    func testApplyResetCreditsParsesAvailableCreditsWithSequentialIndices() {
        let samplePayload: [String: Any] = [
            "availableCount": 2,
            "credits": [
                [
                    "id": "c1",
                    "status": "used",
                    "title": "Used reset"
                ],
                [
                    "id": "c2",
                    "status": "AVAILABLE",
                    "expiresAt": 1785529424.0,
                    "title": "Full reset"
                ],
                [
                    "id": "c3",
                    "status": "available",
                    "expiresAt": 1786557880.0,
                    "title": "Bonus reset"
                ]
            ]
        ]

        var data = CodexUsageData()
        CodexDataReader.shared.applyResetCredits(samplePayload, to: &data)

        XCTAssertEqual(data.availableResetCreditsCount, 2)
        XCTAssertEqual(data.availableResetsCount, 2)
        XCTAssertTrue(data.hasResetsAvailable)
        XCTAssertEqual(data.resets.count, 2)
        XCTAssertEqual(data.resets[0].index, 1)
        XCTAssertEqual(data.resets[0].name, "Full reset")
        XCTAssertEqual(data.resets[1].index, 2)
        XCTAssertEqual(data.resets[1].name, "Bonus reset")
    }

    func testApplyRateLimitsMapsCurrentCodexWindowsByDuration() {
        let samplePayload: [String: Any] = [
            "primary": [
                "usedPercent": 47,
                "windowDurationMins": 300,
                "resetsAt": 1_788_691_661
            ],
            "secondary": [
                "usedPercent": 28,
                "windowDurationMins": 10_080,
                "resetsAt": 1_788_768_725
            ]
        ]

        var data = CodexUsageData()
        CodexDataReader.shared.applyRateLimits(samplePayload, to: &data)

        XCTAssertEqual(data.fiveHourLimitUsedPct, 47)
        XCTAssertEqual(data.weeklyLimitUsedPct, 28)
        XCTAssertFalse(data.fiveHourLimitResetText.isEmpty)
        XCTAssertFalse(data.weeklyLimitResetText.isEmpty)
    }

    func testApplyRateLimitsSupportsSessionLogFieldNames() {
        let samplePayload: [String: Any] = [
            "primary": [
                "used_percent": 12.5,
                "window_minutes": 300,
                "resets_at": 1_788_691_661
            ],
            "secondary": [
                "used_percent": 63.5,
                "window_minutes": 10_080,
                "resets_at": 1_788_768_725
            ]
        ]

        var data = CodexUsageData()
        CodexDataReader.shared.applyRateLimits(samplePayload, to: &data)

        XCTAssertEqual(data.fiveHourLimitUsedPct, 12.5)
        XCTAssertEqual(data.weeklyLimitUsedPct, 63.5)
    }

    func testRateLimitDurationOverridesPrimarySecondaryPosition() {
        let samplePayload: [String: Any] = [
            "primary": [
                "usedPercent": 70,
                "windowDurationMins": 10_080
            ],
            "secondary": [
                "usedPercent": 20,
                "windowDurationMins": 300
            ]
        ]

        var data = CodexUsageData()
        CodexDataReader.shared.applyRateLimits(samplePayload, to: &data)

        XCTAssertEqual(data.fiveHourLimitUsedPct, 20)
        XCTAssertEqual(data.weeklyLimitUsedPct, 70)
    }

    func testMenuBarUsesWeeklyPercentUsedForBothProviders() {
        var claude = ClaudeUsageData()
        claude.hasLiveStatus = true
        claude.sessionUsedPct = 81
        claude.weekAllModelsPct = 36

        var codex = CodexUsageData()
        codex.fiveHourLimitUsedPct = 74
        codex.weeklyLimitUsedPct = 29

        XCTAssertEqual(UsageManager.claudeWeeklyMenuBarText(for: claude), "36%")
        XCTAssertEqual(UsageManager.codexWeeklyMenuBarText(for: codex), "29%")
    }

    func testAntigravityQuotaSummaryMapsFamiliesAndCadences() {
        let payload: [String: Any] = [
            "response": [
                "groups": [
                    [
                        "displayName": "Gemini Models",
                        "buckets": [
                            ["bucketId": "five_hour", "remainingFraction": 0.65, "resetTime": "2026-09-20T12:00:00Z"],
                            ["bucketId": "weekly", "remainingFraction": 0.25, "description": "resets Sunday"]
                        ]
                    ],
                    [
                        "displayName": "Claude and GPT models",
                        "buckets": [
                            ["displayName": "Weekly limit", "remainingFraction": 0.50]
                        ]
                    ]
                ]
            ]
        ]

        var data = AntigravityUsageData()
        XCTAssertTrue(AntigravityDataReader.shared.applyQuotaSummary(payload, source: "fixture", to: &data))
        XCTAssertTrue(data.hasLiveStatus)
        XCTAssertEqual(data.quotaWindows.count, 3)
        XCTAssertEqual(data.weeklyUsedPercent, 75)
        XCTAssertEqual(UsageManager.antigravityWeeklyMenuBarText(for: data), "75%")
        XCTAssertTrue(data.quotaWindows.contains { $0.family == "Claude + GPT" && $0.cadence == .weekly })
        XCTAssertEqual(data.quotaWindows.first { $0.family == "Gemini" && $0.cadence == .weekly }?.remainingPercent, 25)
        XCTAssertEqual(data.quotaWindows.first { $0.family == "Gemini" && $0.cadence == .fiveHour }?.remainingPercent, 65)
    }

    func testAntigravityMenuBarRequiresFreshWeeklyQuota() {
        var data = AntigravityUsageData()
        data.quotaWindows = [
            AntigravityQuotaWindow(family: "Gemini", cadence: .fiveHour, remainingPercent: 20, resetText: "")
        ]
        data.hasLiveStatus = true
        XCTAssertNil(UsageManager.antigravityWeeklyMenuBarText(for: data))

        data.quotaWindows.append(
            AntigravityQuotaWindow(family: "Gemini", cadence: .weekly, remainingPercent: 57.6, resetText: "")
        )
        XCTAssertEqual(UsageManager.antigravityWeeklyMenuBarText(for: data), "42%")
        data.hasLiveStatus = false
        XCTAssertNil(UsageManager.antigravityWeeklyMenuBarText(for: data))
    }

    func testCombinedPointsIncludeAntigravityUsage() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-19T12:00:00Z"))
        var antigravity = AntigravityUsageData()
        antigravity.dailyUsage = [
            AntigravityDailyUsage(date: "2026-07-19", sessionCount: 2, tokensUsed: 123)
        ]
        let points = UsageManager.computeCombinedPoints(
            claude: ClaudeUsageData(),
            codex: CodexUsageData(),
            antigravity: antigravity,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(points.last?.antigravityTokens, 123)
        XCTAssertEqual(points.last?.antigravitySessions, 2)
        XCTAssertEqual(points.last?.totalTokens, 123)
    }

    func testAntigravityLocalIntegrationWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["ANTIGRAVITY_INTEGRATION"] == "1" else {
            throw XCTSkip("Set ANTIGRAVITY_INTEGRATION=1 while Antigravity is running")
        }
        let data = AntigravityDataReader.shared.fetchUsageData()
        XCTAssertTrue(data.hasLiveStatus, data.liveError)
        XCTAssertEqual(data.liveSource, "agy CLI")
        XCTAssertFalse(data.quotaWindows.isEmpty)
        XCTAssertTrue(data.quotaWindows.contains { $0.cadence == .weekly })
        XCTAssertTrue(data.quotaWindows.contains { $0.cadence == .fiveHour })
        XCTAssertGreaterThan(data.totalTokens, 0, data.historyDiagnostic)
        XCTAssertFalse(data.modelUsage.isEmpty, data.historyDiagnostic)
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        XCTAssertTrue(
            data.dailyUsage.contains { item in
                guard let date = formatter.date(from: item.date) else { return false }
                return date >= recentCutoff
            },
            data.historyDiagnostic
        )
    }
}
