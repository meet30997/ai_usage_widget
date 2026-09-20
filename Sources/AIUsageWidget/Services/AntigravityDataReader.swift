import Foundation
import SQLite3

final class AntigravityDataReader {
    static let shared = AntigravityDataReader()

    private let historyRoots: [String]

    init(historyRoots: [String]? = nil) {
        self.historyRoots = historyRoots ?? [
            NSString(string: "~/.gemini/antigravity/conversations").expandingTildeInPath,
            NSString(string: "~/.gemini/antigravity-cli/conversations").expandingTildeInPath
        ]
    }

    func fetchUsageData() -> AntigravityUsageData {
        var data = AntigravityUsageData()
        fetchLiveQuota(into: &data)
        fetchHistory(into: &data)
        return data
    }

    // MARK: - Local quota service

    private struct ServerProcess {
        let pid: Int32
        let csrfToken: String
        let sourceName: String
        let priority: Int
    }

    private func fetchLiveQuota(into data: inout AntigravityUsageData) {
        if fetchCLIQuota(into: &data) { return }

        let candidates = discoverServers()
        guard !candidates.isEmpty else { return }

        var lastError = "Antigravity local quota service did not respond"
        for server in candidates {
            let ports = listeningPorts(for: server.pid)
            guard !ports.isEmpty else {
                lastError = "Antigravity is starting; no local quota port is available"
                continue
            }

            for port in ports {
                if let summary = request(endpoint: "RetrieveUserQuotaSummary", port: port, token: server.csrfToken),
                   applyQuotaSummary(summary, source: server.sourceName, to: &data) {
                    applyIdentity(port: port, token: server.csrfToken, to: &data)
                    return
                }

                if let status = request(endpoint: "GetUserStatus", port: port, token: server.csrfToken),
                   applyLegacyStatus(status, source: server.sourceName, to: &data) {
                    return
                }
            }
        }
        data.liveError = lastError
    }

    @discardableResult
    private func fetchCLIQuota(into data: inout AntigravityUsageData) -> Bool {
        guard let binary = findAgyBinary(),
              let output = run(
                binary,
                arguments: ["-p", "/usage", "--output-format", "json"],
                timeout: 30,
                maximumBytes: 2_000_000
              ),
              let root = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any],
              string(root["status"])?.uppercased() == "SUCCESS",
              let command = root["command"] as? [String: Any],
              let commandData = command["data"] as? [String: Any],
              let groups = commandData["groups"] as? [[String: Any]] else { return false }

        var windows: [AntigravityQuotaWindow] = []
        for group in groups {
            let family = normalizedFamily(string(group["name"]) ?? "Antigravity")
            for bucket in group["buckets"] as? [[String: Any]] ?? [] {
                let cadence = quotaCadence(
                    [string(bucket["name"]), string(bucket["id"]), string(bucket["window"])]
                        .compactMap { $0 }.joined(separator: " ")
                )
                guard let remaining = number(bucket["remaining_fraction"]) else { continue }
                let remainingPercent = max(0, min(100, remaining * 100))
                windows.append(AntigravityQuotaWindow(
                    family: family,
                    cadence: cadence,
                    remainingPercent: remainingPercent,
                    resetText: quotaResetText(
                        remainingFraction: remaining,
                        resetTime: string(bucket["reset_time"]),
                        fallback: string(bucket["description"])
                    )
                ))
            }
        }
        guard !windows.isEmpty else { return false }
        data.quotaWindows = windows.sorted(by: quotaSort)
        data.hasLiveStatus = true
        data.liveSource = "agy CLI"
        data.liveError = ""
        data.quotaFetchedAt = Date()
        return true
    }

    private func discoverServers() -> [ServerProcess] {
        guard let output = run("/bin/ps", arguments: ["-axo", "pid=,command="], timeout: 3) else { return [] }
        return output.split(separator: "\n").compactMap { rawLine in
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard line.localizedCaseInsensitiveContains("language_server"),
                  line.localizedCaseInsensitiveContains("antigravity"),
                  let firstSpace = line.firstIndex(where: { $0 == " " || $0 == "\t" }),
                  let pid = Int32(line[..<firstSpace].trimmingCharacters(in: .whitespaces)),
                  let token = argument(named: "--csrf_token", in: line),
                  !token.isEmpty else { return nil }

            let isDesktop = line.contains("/Antigravity.app/") || line.contains("--app_data_dir antigravity ")
            let isIDE = line.contains("/Antigravity IDE.app/") || line.contains("--app_data_dir antigravity-ide")
            guard isDesktop || isIDE else { return nil }
            return ServerProcess(
                pid: pid,
                csrfToken: token,
                sourceName: isDesktop ? "Antigravity" : "Antigravity IDE",
                priority: isDesktop ? 0 : 1
            )
        }
        .sorted { lhs, rhs in
            lhs.priority == rhs.priority ? lhs.pid < rhs.pid : lhs.priority < rhs.priority
        }
    }

    private func listeningPorts(for pid: Int32) -> [Int] {
        guard let output = run(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-a", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN"],
            timeout: 3
        ) else { return [] }

        let regex = try? NSRegularExpression(pattern: #"127\.0\.0\.1:(\d+)\s+\(LISTEN\)"#)
        return output.split(separator: "\n").compactMap { line -> Int? in
            let value = String(line)
            guard let match = regex?.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                  let range = Range(match.range(at: 1), in: value) else { return nil }
            return Int(value[range])
        }
    }

    private func request(endpoint: String, port: Int, token: String) -> [String: Any]? {
        let body = #"{"metadata":{"ideName":"antigravity","extensionName":"antigravity","locale":"en","ideVersion":"unknown"}}"#
        guard let output = run(
            "/usr/bin/curl",
            arguments: [
                "-ksS", "--max-time", "5",
                "-H", "Content-Type: application/json",
                "-H", "Connect-Protocol-Version: 1",
                "-H", "X-Codeium-Csrf-Token: \(token)",
                "--data", body,
                "https://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/\(endpoint)"
            ],
            timeout: 7,
            maximumBytes: 2_000_000
        ), let json = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any] else {
            return nil
        }
        return json
    }

    @discardableResult
    func applyQuotaSummary(_ root: [String: Any], source: String, to data: inout AntigravityUsageData) -> Bool {
        guard let response = root["response"] as? [String: Any],
              let groups = response["groups"] as? [[String: Any]] else { return false }

        var windows: [AntigravityQuotaWindow] = []
        for group in groups {
            let rawFamily = string(group["displayName"]) ?? "Antigravity"
            let family = normalizedFamily(rawFamily)
            for bucket in group["buckets"] as? [[String: Any]] ?? [] {
                let cadence = quotaCadence(
                    [string(bucket["displayName"]), string(bucket["bucketId"]), string(bucket["window"])]
                        .compactMap { $0 }.joined(separator: " ")
                )
                let remaining = number(bucket["remainingFraction"])
                    ?? number((bucket["remaining"] as? [String: Any])?["remainingFraction"])
                let remainingPercent = remaining.map { max(0, min(100, $0 * 100)) }
                let reset = remaining.map {
                    quotaResetText(
                        remainingFraction: $0,
                        resetTime: string(bucket["resetTime"]),
                        fallback: string(bucket["description"])
                    )
                } ?? ""
                windows.append(AntigravityQuotaWindow(
                    family: family,
                    cadence: cadence,
                    remainingPercent: remainingPercent,
                    resetText: reset
                ))
            }
        }

        let deduplicated = Dictionary(grouping: windows, by: \.id).compactMap { _, values in
            values.max { ($0.usedPercent ?? -1) < ($1.usedPercent ?? -1) }
        }
        guard deduplicated.contains(where: { $0.remainingPercent != nil }) else { return false }
        data.quotaWindows = deduplicated.sorted(by: quotaSort)
        data.hasLiveStatus = true
        data.liveSource = source
        data.liveError = ""
        data.quotaFetchedAt = Date()
        return true
    }

    @discardableResult
    func applyLegacyStatus(_ root: [String: Any], source: String, to data: inout AntigravityUsageData) -> Bool {
        guard let status = root["userStatus"] as? [String: Any] else { return false }
        applyIdentity(status: status, to: &data)
        let configs = ((status["cascadeModelConfigData"] as? [String: Any])?["clientModelConfigs"] as? [[String: Any]]) ?? []
        var representatives: [String: AntigravityQuotaWindow] = [:]
        for config in configs {
            let label = string(config["label"]) ?? string(config["modelId"]) ?? "Model"
            let lowered = label.lowercased()
            if lowered.contains("lite") || lowered.contains("image") || lowered.contains("autocomplete") { continue }
            guard let quota = config["quotaInfo"] as? [String: Any],
                  let remaining = number(quota["remainingFraction"]) else { continue }
            let family = normalizedFamily(label)
            let item = AntigravityQuotaWindow(
                family: family,
                cadence: .fiveHour,
                remainingPercent: max(0, min(100, remaining * 100)),
                resetText: quotaResetText(
                    remainingFraction: remaining,
                    resetTime: string(quota["resetTime"]),
                    fallback: nil
                )
            )
            if (item.usedPercent ?? -1) > (representatives[family]?.usedPercent ?? -1) {
                representatives[family] = item
            }
        }
        guard !representatives.isEmpty else { return false }
        data.quotaWindows = representatives.values.sorted(by: quotaSort)
        data.hasLiveStatus = true
        data.liveSource = source
        data.liveError = ""
        data.quotaFetchedAt = Date()
        return true
    }

    private func applyIdentity(port: Int, token: String, to data: inout AntigravityUsageData) {
        guard let root = request(endpoint: "GetUserStatus", port: port, token: token),
              let status = root["userStatus"] as? [String: Any] else { return }
        applyIdentity(status: status, to: &data)
    }

    private func applyIdentity(status: [String: Any], to data: inout AntigravityUsageData) {
        data.accountEmail = string(status["email"]) ?? ""
        data.accountPlan = string(((status["planStatus"] as? [String: Any])?["planInfo"] as? [String: Any])?["planName"])
            ?? string((status["userTier"] as? [String: Any])?["name"])
            ?? ""
    }

    // MARK: - Local history

    private struct HistoryRecord {
        let sessionID: String
        let date: String
        let model: String
        let input: Int64
        let output: Int64
        let cacheRead: Int64
    }

    private struct StepTimestamps {
        var byResponseID: [String: Date] = [:]
        var byGenerationIndex: [Int64: Date] = [:]
    }

    private func fetchHistory(into data: inout AntigravityUsageData) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var records: [HistoryRecord] = []
        var rejected = 0
        var rejectionReasons: [String: Int] = [:]
        var databaseCount = 0
        var seenSessions = Set<String>()

        for root in historyRoots {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in files.filter({ $0.pathExtension == "db" }).prefix(500) {
                let sessionID = url.deletingPathExtension().lastPathComponent
                guard seenSessions.insert(sessionID).inserted else { continue }
                databaseCount += 1
                let result = parseHistoryDatabase(url, sessionID: sessionID, formatter: formatter)
                records.append(contentsOf: result.records)
                rejected += result.rejected
                for (reason, count) in result.reasons { rejectionReasons[reason, default: 0] += count }
            }
        }

        var dayTokens: [String: Int64] = [:]
        var daySessions: [String: Set<String>] = [:]
        var models: [String: (sessions: Set<String>, input: Int64, output: Int64, cache: Int64)] = [:]
        for record in records {
            dayTokens[record.date, default: 0] += record.input + record.output
            daySessions[record.date, default: []].insert(record.sessionID)
            var model = models[record.model] ?? ([], 0, 0, 0)
            model.sessions.insert(record.sessionID)
            model.input += record.input
            model.output += record.output
            model.cache += record.cacheRead
            models[record.model] = model
        }

        data.dailyUsage = dayTokens.keys.sorted(by: >).map {
            AntigravityDailyUsage(date: $0, sessionCount: daySessions[$0]?.count ?? 0, tokensUsed: dayTokens[$0] ?? 0)
        }
        data.modelUsage = models.map {
            AntigravityModelUsage(
                modelName: $0.key,
                sessionCount: $0.value.sessions.count,
                inputTokens: $0.value.input,
                outputTokens: $0.value.output,
                cacheReadTokens: $0.value.cache
            )
        }.sorted { $0.totalTokens > $1.totalTokens }
        data.totalSessions = Set(records.map(\.sessionID)).count
        data.totalTokens = records.reduce(0) { $0 + $1.input + $1.output }
        data.historyIsPartial = rejected > 0
        if databaseCount == 0 {
            data.historyDiagnostic = "No local Antigravity conversations found"
        } else if rejected > 0 {
            let reasonText = rejectionReasons.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            data.historyDiagnostic = "\(rejected) generation\(rejected == 1 ? "" : "s") skipped (\(reasonText))"
        }
    }

    private func parseHistoryDatabase(
        _ url: URL,
        sessionID: String,
        formatter: DateFormatter
    ) -> (records: [HistoryRecord], rejected: Int, reasons: [String: Int]) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            if let db { sqlite3_close(db) }
            return ([], 1, ["database": 1])
        }
        defer { sqlite3_close(db) }

        let stepTimestamps = readStepTimestamps(db)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT idx, data FROM gen_metadata ORDER BY idx LIMIT 10000", -1, &statement, nil) == SQLITE_OK else {
            return ([], 1, ["schema": 1])
        }
        defer { sqlite3_finalize(statement) }

        var records: [HistoryRecord] = []
        var rejected = 0
        var reasons: [String: Int] = [:]
        var seenResponseIDs = Set<String>()
        func reject(_ reason: String) {
            rejected += 1
            reasons[reason, default: 0] += 1
        }
        while sqlite3_step(statement) == SQLITE_ROW {
            let generationIndex = sqlite3_column_type(statement, 0) == SQLITE_NULL
                ? nil
                : sqlite3_column_int64(statement, 0)
            guard let bytes = sqlite3_column_blob(statement, 1) else { reject("empty"); continue }
            let count = Int(sqlite3_column_bytes(statement, 1))
            guard count > 0, count <= 16 * 1024 * 1024 else { reject("size"); continue }
            let blob = Data(bytes: bytes, count: count)
            guard let outer = try? ProtobufMessage(blob) else { reject("envelope"); continue }
            guard let chatData = outer.firstData(1) else { reject("chat"); continue }
            guard let chat = try? ProtobufMessage(chatData) else { reject("chat-format"); continue }
            guard let usageData = chat.firstData(4) else { reject("usage"); continue }
            guard let usage = try? ProtobufMessage(usageData) else { reject("usage-format"); continue }
            let responseID = usage.firstString(11)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let responseID, !responseID.isEmpty, !seenResponseIDs.insert(responseID).inserted {
                continue
            }
            guard let timestamp = (generationTimestamp(chat)
                    ?? responseID.flatMap { stepTimestamps.byResponseID[$0] }
                    ?? generationIndex.flatMap { stepTimestamps.byGenerationIndex[$0] }),
                  timestamp.timeIntervalSince1970 > 0 else {
                reject("timestamp")
                continue
            }

            let model = chat.firstString(19) ?? chat.firstString(21) ?? "Unknown Antigravity model"
            let input = clampedInt64(usage.firstVarint(1)) + clampedInt64(usage.firstVarint(2))
            let cache = clampedInt64(usage.firstVarint(5))
            let textOutput = usage.firstVarint(9)
            let reasoning = usage.firstVarint(10)
            let legacyOutput = usage.firstVarint(3)
            let output: Int64
            if textOutput != nil || reasoning != nil {
                output = clampedInt64(textOutput) + clampedInt64(reasoning)
            } else {
                output = clampedInt64(legacyOutput)
            }
            guard input > 0 || output > 0 else { reject("zero-usage"); continue }
            records.append(HistoryRecord(
                sessionID: sessionID,
                date: formatter.string(from: timestamp),
                model: model,
                input: input,
                output: output,
                cacheRead: cache
            ))
        }
        return (records, rejected, reasons)
    }

    private func readStepTimestamps(_ db: OpaquePointer) -> StepTimestamps {
        var result = StepTimestamps()
        var statement: OpaquePointer?
        let query = "SELECT metadata FROM steps WHERE step_type = 15 AND metadata IS NOT NULL LIMIT 20000"
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return result }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0) else { continue }
            let count = Int(sqlite3_column_bytes(statement, 0))
            guard count > 0, count <= 16 * 1024 * 1024,
                  let metadata = try? ProtobufMessage(Data(bytes: bytes, count: count)),
                  let timestampData = metadata.firstData(1),
                  let timestamp = protobufTimestamp(timestampData) else { continue }

            if let responseData = metadata.firstData(9),
               let response = try? ProtobufMessage(responseData),
               let responseID = response.firstString(11)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !responseID.isEmpty {
                result.byResponseID[responseID] = timestamp
            }
            if let generationData = metadata.firstData(20),
               let generation = try? ProtobufMessage(generationData),
               let index = generation.firstVarint(3),
               index <= UInt64(Int64.max) {
                result.byGenerationIndex[Int64(index)] = timestamp
            }
        }
        return result
    }

    private func generationTimestamp(_ chat: ProtobufMessage) -> Date? {
        guard let timeData = chat.firstData(9),
              let time = try? ProtobufMessage(timeData),
              let timestampData = time.firstData(4) else { return nil }
        return protobufTimestamp(timestampData)
    }

    private func protobufTimestamp(_ data: Data) -> Date? {
        guard let timestamp = try? ProtobufMessage(data),
              let seconds = timestamp.firstVarint(1),
              seconds <= UInt64(Int64.max) else { return nil }
        let nanos = timestamp.firstVarint(2) ?? 0
        guard nanos <= 999_999_999 else { return nil }
        return Date(timeIntervalSince1970: Double(seconds) + Double(nanos) / 1_000_000_000)
    }

    private func clampedInt64(_ value: UInt64?) -> Int64 {
        guard let value else { return 0 }
        return value > UInt64(Int64.max) ? Int64.max : Int64(value)
    }

    // MARK: - Helpers

    private func normalizedFamily(_ value: String) -> String {
        let lower = value.lowercased()
        if lower.contains("gemini") { return "Gemini" }
        if lower.contains("claude") || lower.contains("gpt") { return "Claude + GPT" }
        return value.replacingOccurrences(of: " Models", with: "")
    }

    private func quotaCadence(_ label: String) -> AntigravityQuotaCadence {
        label.lowercased().contains("week") ? .weekly : .fiveHour
    }

    private func quotaSort(_ lhs: AntigravityQuotaWindow, _ rhs: AntigravityQuotaWindow) -> Bool {
        if lhs.family != rhs.family { return lhs.family < rhs.family }
        return lhs.cadence == .fiveHour && rhs.cadence == .weekly
    }

    private func quotaResetText(remainingFraction: Double, resetTime: String?, fallback: String?) -> String {
        if remainingFraction >= 0.999_999 { return "Quota available" }
        guard let raw = resetTime, !raw.isEmpty else { return fallback ?? "" }
        let input = ISO8601DateFormatter()
        guard let date = input.date(from: raw) else { return fallback ?? raw }
        let totalMinutes = max(0, Int(date.timeIntervalSinceNow / 60))
        return "Refreshes in \(totalMinutes / 60)h \(totalMinutes % 60)m"
    }

    private func findAgyBinary() -> String? {
        let candidates = [
            NSString(string: "~/.local/bin/agy").expandingTildeInPath,
            "/opt/homebrew/bin/agy",
            "/usr/local/bin/agy"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func string(_ value: Any?) -> String? {
        if let value = value as? String, !value.isEmpty { return value }
        return nil
    }

    private func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private func argument(named name: String, in command: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        guard let regex = try? NSRegularExpression(pattern: "(?:^|\\s)\(escaped)\\s+([^\\s]+)"),
              let match = regex.firstMatch(in: command, range: NSRange(command.startIndex..., in: command)),
              let range = Range(match.range(at: 1), in: command) else { return nil }
        return String(command[range])
    }

    private func run(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval,
        maximumBytes: Int = 1_000_000
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        let lock = NSLock()
        var captured = Data()
        var exceededLimit = false
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            lock.lock()
            if captured.count + chunk.count <= maximumBytes {
                captured.append(chunk)
            } else {
                exceededLimit = true
            }
            lock.unlock()
        }
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                return nil
            }
            pipe.fileHandleForReading.readabilityHandler = nil
            let tail = pipe.fileHandleForReading.readDataToEndOfFile()
            lock.lock()
            if captured.count + tail.count <= maximumBytes { captured.append(tail) } else { exceededLimit = true }
            let bytes = captured
            let tooLarge = exceededLimit
            lock.unlock()
            guard process.terminationStatus == 0, !tooLarge else { return nil }
            return String(data: bytes, encoding: .utf8)
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }
    }
}

private struct ProtobufMessage {
    enum Value {
        case varint(UInt64)
        case data(Data)
    }

    private let fields: [Int: [Value]]

    init(_ data: Data) throws {
        var parsed: [Int: [Value]] = [:]
        var index = data.startIndex
        while index < data.endIndex {
            let key = try Self.readVarint(data, index: &index)
            let field = Int(key >> 3)
            switch Int(key & 7) {
            case 0:
                parsed[field, default: []].append(.varint(try Self.readVarint(data, index: &index)))
            case 1:
                guard data.distance(from: index, to: data.endIndex) >= 8 else { throw ParseError.invalid }
                index = data.index(index, offsetBy: 8)
            case 2:
                let length = try Self.readVarint(data, index: &index)
                guard length <= UInt64(data.count),
                      let end = data.index(index, offsetBy: Int(length), limitedBy: data.endIndex) else { throw ParseError.invalid }
                parsed[field, default: []].append(.data(Data(data[index..<end])))
                index = end
            case 5:
                guard data.distance(from: index, to: data.endIndex) >= 4 else { throw ParseError.invalid }
                index = data.index(index, offsetBy: 4)
            default:
                throw ParseError.invalid
            }
        }
        fields = parsed
    }

    func firstVarint(_ field: Int) -> UInt64? {
        for case let .varint(value) in fields[field] ?? [] { return value }
        return nil
    }

    func firstData(_ field: Int) -> Data? {
        for case let .data(value) in fields[field] ?? [] { return value }
        return nil
    }

    func firstString(_ field: Int) -> String? {
        guard let data = firstData(field), let string = String(data: data, encoding: .utf8), !string.isEmpty else { return nil }
        return string
    }

    private static func readVarint(_ data: Data, index: inout Data.Index) throws -> UInt64 {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while index < data.endIndex && shift < 64 {
            let byte = data[index]
            index = data.index(after: index)
            value |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return value }
            shift += 7
        }
        throw ParseError.invalid
    }

    private enum ParseError: Error { case invalid }
}
