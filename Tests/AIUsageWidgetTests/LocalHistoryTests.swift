import XCTest
import SQLite3
@testable import AIUsageWidget

final class LocalHistoryTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalHistoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func assistantLine(uuid: String, messageID: String, session: String, at date: Date, input: Int, output: Int, toolUse: Bool = false) -> String {
        let content = toolUse ? #"[{"type":"tool_use","name":"Bash"}]"# : #"[{"type":"text","text":"hi"}]"#
        return """
        {"type":"assistant","uuid":"\(uuid)","sessionId":"\(session)","timestamp":"\(isoString(date))","message":{"id":"\(messageID)","model":"claude-test","content":\(content),"usage":{"input_tokens":\(input),"output_tokens":\(output),"cache_creation_input_tokens":5,"cache_read_input_tokens":1000}}}
        """
    }

    private func userLine(uuid: String, session: String, at date: Date) -> String {
        """
        {"type":"user","uuid":"\(uuid)","sessionId":"\(session)","timestamp":"\(isoString(date))","message":{"role":"user","content":"hello"}}
        """
    }

    func testTranscriptScannerDedupesAndRespectsCutoff() throws {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(3600)
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: today)!

        let project = tempDir.appendingPathComponent("proj", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let lines = [
            userLine(uuid: "u0", session: "s1", at: lastWeek),          // before cutoff
            userLine(uuid: "u1", session: "s1", at: yesterday),
            assistantLine(uuid: "a1", messageID: "m1", session: "s1", at: yesterday, input: 10, output: 20, toolUse: true),
            // Same message id streamed on a second line: tokens counted once.
            assistantLine(uuid: "a2", messageID: "m1", session: "s1", at: yesterday, input: 10, output: 20),
            assistantLine(uuid: "a3", messageID: "m2", session: "s2", at: now, input: 1, output: 2),
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: project.appendingPathComponent("s1.jsonl"), atomically: true, encoding: .utf8)
        // A forked session that copied an earlier line verbatim.
        try (lines[2] + "\n").write(to: project.appendingPathComponent("fork.jsonl"), atomically: true, encoding: .utf8)

        let cutoff = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        let summary = ClaudeTranscriptScanner(projectsDirectory: tempDir).scan(since: cutoff)

        let yesterdayKey = dayString(yesterday)
        XCTAssertNil(summary.activityByDay[dayString(lastWeek)])
        XCTAssertEqual(summary.tokensByDay[yesterdayKey]?["claude-test"]?.total, 10 + 20 + 5)
        XCTAssertEqual(summary.tokensByDay[yesterdayKey]?["claude-test"]?.cacheRead, 1000)
        XCTAssertEqual(summary.activityByDay[yesterdayKey]?.messageCount, 3)
        XCTAssertEqual(summary.activityByDay[yesterdayKey]?.toolCallCount, 1)
        XCTAssertEqual(summary.activityByDay[dayString(now)]?.messageCount, 1)
        // s1 started last week (before the cutoff), s2 started today.
        XCTAssertEqual(summary.sessionStarts["s1"], ISO8601DateFormatter.fractional.date(from: isoString(lastWeek)))
        XCTAssertNotNil(summary.sessionStarts["s2"])
    }

    func testTranscriptScannerReadsAppendedLinesIncrementally() throws {
        let now = Date()
        let file = tempDir.appendingPathComponent("s.jsonl")
        try (assistantLine(uuid: "a1", messageID: "m1", session: "s", at: now, input: 1, output: 1) + "\n")
            .write(to: file, atomically: true, encoding: .utf8)

        let scanner = ClaudeTranscriptScanner(projectsDirectory: tempDir)
        let cutoff = Calendar.current.startOfDay(for: now)
        XCTAssertEqual(scanner.scan(since: cutoff).activityByDay[dayString(now)]?.messageCount, 1)

        // Append one full line plus a partial line that is still being written.
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        let appended = assistantLine(uuid: "a2", messageID: "m2", session: "s", at: now, input: 2, output: 2) + "\n" + #"{"type":"assist"#
        try handle.write(contentsOf: Data(appended.utf8))
        try handle.close()

        let summary = scanner.scan(since: cutoff)
        XCTAssertEqual(summary.activityByDay[dayString(now)]?.messageCount, 2)
        XCTAssertEqual(summary.tokensByDay[dayString(now)]?["claude-test"]?.total, (1 + 1 + 5) + (2 + 2 + 5))
    }

    func testReadOnlyOpenHandlesWALDatabaseWithoutSharedMemoryFile() throws {
        let url = tempDir.appendingPathComponent("wal.db")
        var writer: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &writer), SQLITE_OK)
        sqlite3_exec(writer, "PRAGMA journal_mode=WAL; CREATE TABLE t(x); INSERT INTO t VALUES (42);", nil, nil, nil)
        sqlite3_close(writer)
        // Reproduce how Antigravity leaves its databases: still in WAL mode
        // but with no -wal/-shm beside them. (Apple's SQLite may keep them
        // after close, so remove them explicitly.)
        try? FileManager.default.removeItem(atPath: url.path + "-wal")
        try? FileManager.default.removeItem(atPath: url.path + "-shm")
        var plain: OpaquePointer?
        sqlite3_open_v2(url.path, &plain, SQLITE_OPEN_READONLY, nil)
        XCTAssertNotEqual(sqlite3_exec(plain, "SELECT x FROM t", nil, nil, nil), SQLITE_OK, "plain read-only open should fail here")
        sqlite3_close(plain)

        let db = try XCTUnwrap(SQLiteReadOnly.open(url))
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT x FROM t", -1, &statement, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(statement, 0), 42)
        sqlite3_finalize(statement)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path + "-shm"), "must not write next to the database")
    }
}

private extension ISO8601DateFormatter {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
