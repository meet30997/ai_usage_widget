import Foundation

/// Rebuilds Claude Code usage from the session transcripts in
/// `~/.claude/projects`. Claude Code only rewrites `stats-cache.json`
/// occasionally (it can go weeks without an update), so every day after the
/// cache's `lastComputedDate` has to come from the transcripts instead.
///
/// Transcripts are append-only, so each file is parsed incrementally: a
/// refresh only reads the bytes added since the previous one.
final class ClaudeTranscriptScanner {
    struct TokenCounts: Equatable {
        var input: Int64 = 0
        var output: Int64 = 0
        var cacheRead: Int64 = 0
        var cacheCreation: Int64 = 0

        /// Same definition as stats-cache.json's dailyModelTokens: cache
        /// reads are excluded because they replay the whole context on
        /// nearly every turn and would dwarf everything else.
        var total: Int64 { input + output + cacheCreation }
    }

    struct DayActivity: Equatable {
        var messageCount = 0
        var toolCallCount = 0
        var sessionIDs = Set<String>()
    }

    struct Summary {
        /// "yyyy-MM-dd" -> model -> tokens
        var tokensByDay: [String: [String: TokenCounts]] = [:]
        var activityByDay: [String: DayActivity] = [:]
        /// sessionId -> earliest message timestamp seen
        var sessionStarts: [String: Date] = [:]
    }

    private struct Usage {
        let messageID: String?
        let model: String
        let counts: TokenCounts
    }

    private struct Line {
        let uuid: String?
        let day: String
        let sessionID: String?
        let toolCalls: Int
        let usage: Usage?
    }

    private struct FileState {
        var cutoff: Date
        var timeZone: String
        var parsedBytes: UInt64
        var lines: [Line]
        var sessionStarts: [String: Date]
    }

    private var files: [String: FileState] = [:]
    private let lock = NSLock()
    private let projectsDirectory: URL

    init(projectsDirectory: URL = URL(fileURLWithPath: NSString(string: "~/.claude/projects").expandingTildeInPath)) {
        self.projectsDirectory = projectsDirectory
    }

    /// Aggregates every user/assistant entry timestamped at or after `cutoff`.
    func scan(since cutoff: Date) -> Summary {
        lock.lock()
        defer { lock.unlock() }

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            files.removeAll()
            return Summary()
        }

        var visited = Set<String>()
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            // A file untouched since the cutoff can't hold newer entries.
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modified = values.contentModificationDate,
                  modified >= cutoff else { continue }
            visited.insert(url.path)
            update(url, size: UInt64(values.fileSize ?? 0), cutoff: cutoff)
        }
        files = files.filter { visited.contains($0.key) }

        return aggregate()
    }

    private func update(_ url: URL, size: UInt64, cutoff: Date) {
        let timeZone = TimeZone.current.identifier
        var state = files[url.path]
        if let existing = state,
           existing.cutoff != cutoff || existing.timeZone != timeZone || size < existing.parsedBytes {
            state = nil  // settings changed or file was rewritten: start over
        }
        var current = state ?? FileState(cutoff: cutoff, timeZone: timeZone, parsedBytes: 0, lines: [], sessionStarts: [:])
        guard size > current.parsedBytes,
              let handle = try? FileHandle(forReadingFrom: url) else {
            files[url.path] = current
            return
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: current.parsedBytes)
        } catch {
            return
        }
        let chunk = handle.readDataToEndOfFile()
        // Only consume complete lines; a partially written last line is
        // picked up on the next refresh.
        guard let lastNewline = chunk.lastIndex(of: UInt8(ascii: "\n")) else {
            files[url.path] = current
            return
        }
        let complete = chunk[chunk.startIndex...lastNewline]
        parse(complete, cutoff: cutoff, into: &current)
        current.parsedBytes += UInt64(complete.count)
        files[url.path] = current
    }

    private func parse(_ data: Data, cutoff: Date, into state: inout FileState) {
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = .current
        dayFormatter.dateFormat = "yyyy-MM-dd"

        for rawLine in data.split(separator: UInt8(ascii: "\n")) {
            guard let obj = try? JSONSerialization.jsonObject(with: rawLine) as? [String: Any],
                  let type = obj["type"] as? String,
                  type == "user" || type == "assistant",
                  obj["isMeta"] as? Bool != true,
                  let timestampString = obj["timestamp"] as? String,
                  let timestamp = isoFractional.date(from: timestampString) ?? isoPlain.date(from: timestampString)
            else { continue }

            let isSidechain = obj["isSidechain"] as? Bool == true
            let sessionID = isSidechain ? nil : obj["sessionId"] as? String
            if let sessionID {
                state.sessionStarts[sessionID] = min(state.sessionStarts[sessionID] ?? timestamp, timestamp)
            }
            guard timestamp >= cutoff else { continue }

            let message = obj["message"] as? [String: Any]
            var toolCalls = 0
            var usage: Usage?
            if type == "assistant", let message {
                if let content = message["content"] as? [[String: Any]] {
                    toolCalls = content.filter { $0["type"] as? String == "tool_use" }.count
                }
                if let rawUsage = message["usage"] as? [String: Any],
                   let model = message["model"] as? String,
                   model != "<synthetic>" {
                    usage = Usage(
                        messageID: message["id"] as? String,
                        model: model,
                        counts: TokenCounts(
                            input: (rawUsage["input_tokens"] as? NSNumber)?.int64Value ?? 0,
                            output: (rawUsage["output_tokens"] as? NSNumber)?.int64Value ?? 0,
                            cacheRead: (rawUsage["cache_read_input_tokens"] as? NSNumber)?.int64Value ?? 0,
                            cacheCreation: (rawUsage["cache_creation_input_tokens"] as? NSNumber)?.int64Value ?? 0
                        )
                    )
                }
            }

            state.lines.append(Line(
                uuid: obj["uuid"] as? String,
                day: dayFormatter.string(from: timestamp),
                sessionID: sessionID,
                toolCalls: toolCalls,
                usage: usage
            ))
        }
    }

    private func aggregate() -> Summary {
        var summary = Summary()
        // Resumed and forked sessions copy earlier entries into a new file
        // under the same uuid; streamed responses log one message id on
        // several lines with the same cumulative usage. Count each once.
        var seenLines = Set<String>()
        var seenMessages = Set<String>()

        for state in files.values {
            for (session, start) in state.sessionStarts {
                summary.sessionStarts[session] = min(summary.sessionStarts[session] ?? start, start)
            }
            for line in state.lines {
                if let uuid = line.uuid, !seenLines.insert(uuid).inserted { continue }

                var activity = summary.activityByDay[line.day] ?? DayActivity()
                activity.messageCount += 1
                activity.toolCallCount += line.toolCalls
                if let session = line.sessionID { activity.sessionIDs.insert(session) }
                summary.activityByDay[line.day] = activity

                guard let usage = line.usage else { continue }
                if let id = usage.messageID, !seenMessages.insert(id).inserted { continue }
                var counts = summary.tokensByDay[line.day, default: [:]][usage.model] ?? TokenCounts()
                counts.input += usage.counts.input
                counts.output += usage.counts.output
                counts.cacheRead += usage.counts.cacheRead
                counts.cacheCreation += usage.counts.cacheCreation
                summary.tokensByDay[line.day, default: [:]][usage.model] = counts
            }
        }
        return summary
    }
}
