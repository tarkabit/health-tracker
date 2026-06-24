import Foundation

/// Reads & writes `log.md` — a Markdown table, one row per logged session/day.
/// Column headers are field ids (date first) so the table round-trips reliably.
enum LogFile {

    static let filename = "log.md"

    static func read(from folder: URL, habit: Habit) -> [LogEntry] {
        let url = folder.appendingPathComponent(filename)
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: true)
        let rows = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("|") }
        guard rows.count >= 2 else { return [] }

        let header = cells(rows[0])
        var entries: [LogEntry] = []

        for row in rows.dropFirst() {
            let c = cells(row)
            // Skip the |---|---| separator row.
            if c.allSatisfy({ $0.allSatisfy { ch in ch == "-" || ch == ":" } && !$0.isEmpty }) { continue }
            if c.first == "date" { continue }

            var values: [String: String] = [:]
            for (i, col) in header.enumerated() where i < c.count {
                let value = unescape(c[i])
                if !value.isEmpty { values[col] = value }
            }
            guard let dateStr = values["date"], let date = DayMath.parse(dateStr) else { continue }
            values.removeValue(forKey: "date")
            entries.append(LogEntry(date: date, values: values))
        }

        return entries.sorted { $0.date < $1.date }
    }

    static func write(_ entries: [LogEntry], for habit: Habit, to folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let columns = habit.logColumns
        let sorted = entries.sorted { $0.date < $1.date }

        var out = "# \(habit.name) — Log\n\n"
        out += "| " + columns.joined(separator: " | ") + " |\n"
        out += "| " + columns.map { _ in "---" }.joined(separator: " | ") + " |\n"

        for entry in sorted {
            let cells = columns.map { col -> String in
                if col == "date" { return entry.dateString }
                return escape(entry.values[col] ?? "")
            }
            out += "| " + cells.joined(separator: " | ") + " |\n"
        }

        let url = folder.appendingPathComponent(filename)
        try out.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: Cell parsing

    private static func cells(_ line: Substring) -> [String] {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
         .replacingOccurrences(of: "|", with: "\\|")
    }

    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\|", with: "|")
    }
}
